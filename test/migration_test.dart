import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firestop_tracker/database/database.dart';
import 'package:firestop_tracker/database/tables/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Montée de version de la base locale.
///
/// Une tablette en service porte un relevé qui n'existe peut-être nulle part
/// ailleurs : une migration qui échoue, c'est une application qui ne s'ouvre
/// plus sur ces données. Chaque chemin de montée est donc rejoué ici sur une
/// base construite **telle qu'elle était**, en SQL figé — pas depuis les
/// définitions Dart courantes, qui ne prouveraient rien.
void main() {
  /// `setting_options`, `projects` et `points` tels que la version 1 les
  /// créait.
  Database baseV1() {
    final brute = sqlite3.openInMemory()
      ..execute('''
        CREATE TABLE points (
          id TEXT NOT NULL,
          project_id TEXT NOT NULL REFERENCES projects(id),
          ref_number INTEGER NULL,
          purchase_order TEXT NULL,
          building TEXT NULL,
          floor_level INTEGER NULL,
          room TEXT NULL,
          description TEXT NULL,
          configuration_id TEXT NULL REFERENCES setting_options(id),
          configuration_detail_id TEXT NULL REFERENCES setting_options(id),
          ei_level_id TEXT NULL REFERENCES setting_options(id),
          supplier_id TEXT NULL REFERENCES setting_options(id),
          product_type_id TEXT NULL REFERENCES setting_options(id),
          product1_id TEXT NULL REFERENCES setting_options(id),
          product2_id TEXT NULL REFERENCES setting_options(id),
          product3_id TEXT NULL REFERENCES setting_options(id),
          product4_id TEXT NULL REFERENCES setting_options(id),
          product5_id TEXT NULL REFERENCES setting_options(id),
          author_id TEXT NOT NULL REFERENCES profiles(id),
          captured_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL,
          PRIMARY KEY (id)
        )
      ''')
      ..execute(
        'INSERT INTO points (id, project_id, ref_number, purchase_order, '
        'author_id, captured_at, updated_at) '
        "VALUES ('pt1', 'ch1', 12, 'PO-ANCIEN', 'u1', 1789000000, 1789000000)",
      )
      ..execute('''
        CREATE TABLE projects (
          id TEXT NOT NULL,
          client_id TEXT NOT NULL REFERENCES clients(id),
          code TEXT NULL,
          name TEXT NOT NULL,
          description TEXT NULL,
          started_on INTEGER NULL,
          ended_on INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'inProgress',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL,
          PRIMARY KEY (id)
        )
      ''')
      ..execute(
        'INSERT INTO projects (id, client_id, code, name, created_at, '
        'updated_at) '
        "VALUES ('ch1', 'c1', '2026-118', 'Chantier A', 1789000000, "
        '1789000000)',
      )
      ..execute('''
        CREATE TABLE setting_options (
          id TEXT NOT NULL,
          kind TEXT NOT NULL,
          label TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL,
          PRIMARY KEY (id)
        )
      ''')
      ..execute(
        'CREATE INDEX idx_setting_options_kind '
        'ON setting_options (kind, deleted_at, sort_order)',
      )
      ..execute(
        'INSERT INTO setting_options (id, kind, label, sort_order, updated_at) '
        "VALUES ('p1', 'product', 'Promastop-FC', 0, 1789000000)",
      )
      ..execute('PRAGMA user_version = 1');
    return brute;
  }

  test('1 vers 2 : les produits existants survivent, sans fournisseur',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(baseV1()));
    addTearDown(db.close);

    final produit = await db.select(db.settingOptions).getSingle();
    expect(produit.label, 'Promastop-FC');
    expect(produit.kind, SettingKind.product);
    // Nul, et non le texte « parent_id » : SQLite relit un identifiant inconnu
    // comme une chaîne littérale, c'est le piège décrit dans CLAUDE.md.
    expect(produit.parentId, isNull);

    // La colonne est réellement inscriptible après la montée. Écritures
    // directes : les DAO mettent en file dans l'outbox, absente de cette base
    // réduite à la table migrée.
    const fournisseur = 'f1';
    await db.into(db.settingOptions).insert(
          SettingOption(
            id: fournisseur,
            kind: SettingKind.supplier,
            label: 'Promat',
            sortOrder: 0,
            updatedAt: DateTime(2026, 10, 3),
          ),
        );
    await (db.update(db.settingOptions)..where((t) => t.id.equals('p1')))
        .write(const SettingOptionsCompanion(parentId: Value(fournisseur)));
    expect(
      [for (final o in await db.settingsDao.watchProducts(fournisseur).first) o.id],
      ['p1'],
    );
  });

  /// La base telle que la version 2 la laissait : la version 1, montée.
  Database baseV2() => baseV1()
    ..execute('ALTER TABLE setting_options ADD COLUMN parent_id TEXT')
    ..execute(
      'CREATE INDEX idx_setting_options_parent '
      'ON setting_options (parent_id, deleted_at, sort_order)',
    )
    ..execute('PRAGMA user_version = 2');

  for (final (depart, base) in [(1, baseV1), (2, baseV2)]) {
    test('$depart vers 3 : le chantier survit, bon de commande et batiment nuls',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.opened(base()));
      addTearDown(db.close);

      final chantier = await db.select(db.projects).getSingle();
      expect(chantier.name, 'Chantier A');
      expect(chantier.code, '2026-118');
      expect(chantier.purchaseOrder, isNull);
      expect(chantier.building, isNull);

      await (db.update(db.projects)..where((t) => t.id.equals('ch1'))).write(
        const ProjectsCompanion(
          purchaseOrder: Value('PO-4471'),
          building: Value('Bloc A'),
        ),
      );
      final apres = await db.select(db.projects).getSingle();
      expect(apres.purchaseOrder, 'PO-4471');
      expect(apres.building, 'Bloc A');
    });
  }

  /// La base telle que la version 3 la laissait.
  Database baseV3() => baseV2()
    ..execute('ALTER TABLE projects ADD COLUMN purchase_order TEXT')
    ..execute('ALTER TABLE projects ADD COLUMN building TEXT')
    ..execute('PRAGMA user_version = 3');

  for (final (depart, base) in [(1, baseV1), (2, baseV2), (3, baseV3)]) {
    test('$depart vers 4 : la traversee survit, sans ecart au chantier',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.opened(base()));
      addTearDown(db.close);

      final point = await db.select(db.points).getSingle();
      expect(point.refNumber, 12);
      // Nuls, et non le texte « project_code » : voir le piège de CLAUDE.md.
      expect(point.projectCode, isNull);
      expect(point.projectName, isNull);
      // La saisie d'avant le passage du champ au chantier est conservée.
      expect(point.purchaseOrder, 'PO-ANCIEN');

      await (db.update(db.points)..where((t) => t.id.equals('pt1'))).write(
        const PointsCompanion(
          projectCode: Value('2026-999'),
          projectName: Value('Zone B'),
        ),
      );
      final apres = await db.select(db.points).getSingle();
      expect(apres.projectCode, '2026-999');
      expect(apres.projectName, 'Zone B');
    });
  }

  test('une version inconnue est refusee en clair', () async {
    final brute = baseV1()..execute('PRAGMA user_version = 7');
    final db = AppDatabase.forTesting(NativeDatabase.opened(brute));
    addTearDown(db.close);

    await expectLater(
      db.select(db.settingOptions).get(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('version 7'),
        ),
      ),
    );
  });
}
