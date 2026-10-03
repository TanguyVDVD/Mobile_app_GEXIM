// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fullNameMeta =
      const VerificationMeta('fullName');
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
      'full_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<UserRole, String> role =
      GeneratedColumn<String>('role', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<UserRole>($ProfilesTable.$converterrole);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, fullName, email, role, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<Profile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(_fullNameMeta,
          fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta));
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      fullName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}full_name'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      role: $ProfilesTable.$converterrole.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<UserRole, String, String> $converterrole =
      const EnumNameConverter<UserRole>(UserRole.values);
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final DateTime updatedAt;
  const Profile(
      {required this.id,
      required this.fullName,
      required this.email,
      required this.role,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['full_name'] = Variable<String>(fullName);
    map['email'] = Variable<String>(email);
    {
      map['role'] = Variable<String>($ProfilesTable.$converterrole.toSql(role));
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      fullName: Value(fullName),
      email: Value(email),
      role: Value(role),
      updatedAt: Value(updatedAt),
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      fullName: serializer.fromJson<String>(json['fullName']),
      email: serializer.fromJson<String>(json['email']),
      role: $ProfilesTable.$converterrole
          .fromJson(serializer.fromJson<String>(json['role'])),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fullName': serializer.toJson<String>(fullName),
      'email': serializer.toJson<String>(email),
      'role':
          serializer.toJson<String>($ProfilesTable.$converterrole.toJson(role)),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Profile copyWith(
          {String? id,
          String? fullName,
          String? email,
          UserRole? role,
          DateTime? updatedAt}) =>
      Profile(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        role: role ?? this.role,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      email: data.email.present ? data.email.value : this.email,
      role: data.role.present ? data.role.value : this.role,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('email: $email, ')
          ..write('role: $role, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fullName, email, role, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.fullName == this.fullName &&
          other.email == this.email &&
          other.role == this.role &&
          other.updatedAt == this.updatedAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String> fullName;
  final Value<String> email;
  final Value<UserRole> role;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.email = const Value.absent(),
    this.role = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String fullName,
    required String email,
    required UserRole role,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        fullName = Value(fullName),
        email = Value(email),
        role = Value(role),
        updatedAt = Value(updatedAt);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? fullName,
    Expression<String>? email,
    Expression<String>? role,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email,
      if (role != null) 'role': role,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? fullName,
      Value<String>? email,
      Value<UserRole>? role,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ProfilesCompanion(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (role.present) {
      map['role'] =
          Variable<String>($ProfilesTable.$converterrole.toSql(role.value));
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('email: $email, ')
          ..write('role: $role, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClientsTable extends Clients with TableInfo<$ClientsTable, Client> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _contactNameMeta =
      const VerificationMeta('contactName');
  @override
  late final GeneratedColumn<String> contactName = GeneratedColumn<String>(
      'contact_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactEmailMeta =
      const VerificationMeta('contactEmail');
  @override
  late final GeneratedColumn<String> contactEmail = GeneratedColumn<String>(
      'contact_email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactPhoneMeta =
      const VerificationMeta('contactPhone');
  @override
  late final GeneratedColumn<String> contactPhone = GeneratedColumn<String>(
      'contact_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address =
      GeneratedColumn<String>('address', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _logoPathMeta =
      const VerificationMeta('logoPath');
  @override
  late final GeneratedColumn<String> logoPath =
      GeneratedColumn<String>('logo_path', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        contactName,
        contactEmail,
        contactPhone,
        address,
        logoPath,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients';
  @override
  VerificationContext validateIntegrity(Insertable<Client> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('contact_name')) {
      context.handle(
          _contactNameMeta,
          contactName.isAcceptableOrUnknown(
              data['contact_name']!, _contactNameMeta));
    }
    if (data.containsKey('contact_email')) {
      context.handle(
          _contactEmailMeta,
          contactEmail.isAcceptableOrUnknown(
              data['contact_email']!, _contactEmailMeta));
    }
    if (data.containsKey('contact_phone')) {
      context.handle(
          _contactPhoneMeta,
          contactPhone.isAcceptableOrUnknown(
              data['contact_phone']!, _contactPhoneMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('logo_path')) {
      context.handle(_logoPathMeta,
          logoPath.isAcceptableOrUnknown(data['logo_path']!, _logoPathMeta));
    } else if (isInserting) {
      context.missing(_logoPathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Client map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Client(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      contactName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_name']),
      contactEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_email']),
      contactPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_phone']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address'])!,
      logoPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}logo_path'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $ClientsTable createAlias(String alias) {
    return $ClientsTable(attachedDatabase, alias);
  }
}

class Client extends DataClass implements Insertable<Client> {
  final String id;
  final String name;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String address;

  /// Chemin du logo dans le bucket `client-logos`, posé dans la case « logo
  /// client » de chaque fiche.
  final String logoPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Client(
      {required this.id,
      required this.name,
      this.contactName,
      this.contactEmail,
      this.contactPhone,
      required this.address,
      required this.logoPath,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || contactName != null) {
      map['contact_name'] = Variable<String>(contactName);
    }
    if (!nullToAbsent || contactEmail != null) {
      map['contact_email'] = Variable<String>(contactEmail);
    }
    if (!nullToAbsent || contactPhone != null) {
      map['contact_phone'] = Variable<String>(contactPhone);
    }
    map['address'] = Variable<String>(address);
    map['logo_path'] = Variable<String>(logoPath);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ClientsCompanion toCompanion(bool nullToAbsent) {
    return ClientsCompanion(
      id: Value(id),
      name: Value(name),
      contactName: contactName == null && nullToAbsent
          ? const Value.absent()
          : Value(contactName),
      contactEmail: contactEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(contactEmail),
      contactPhone: contactPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(contactPhone),
      address: Value(address),
      logoPath: Value(logoPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Client.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Client(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      contactName: serializer.fromJson<String?>(json['contactName']),
      contactEmail: serializer.fromJson<String?>(json['contactEmail']),
      contactPhone: serializer.fromJson<String?>(json['contactPhone']),
      address: serializer.fromJson<String>(json['address']),
      logoPath: serializer.fromJson<String>(json['logoPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'contactName': serializer.toJson<String?>(contactName),
      'contactEmail': serializer.toJson<String?>(contactEmail),
      'contactPhone': serializer.toJson<String?>(contactPhone),
      'address': serializer.toJson<String>(address),
      'logoPath': serializer.toJson<String>(logoPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Client copyWith(
          {String? id,
          String? name,
          Value<String?> contactName = const Value.absent(),
          Value<String?> contactEmail = const Value.absent(),
          Value<String?> contactPhone = const Value.absent(),
          String? address,
          String? logoPath,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Client(
        id: id ?? this.id,
        name: name ?? this.name,
        contactName: contactName.present ? contactName.value : this.contactName,
        contactEmail:
            contactEmail.present ? contactEmail.value : this.contactEmail,
        contactPhone:
            contactPhone.present ? contactPhone.value : this.contactPhone,
        address: address ?? this.address,
        logoPath: logoPath ?? this.logoPath,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Client copyWithCompanion(ClientsCompanion data) {
    return Client(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      contactName:
          data.contactName.present ? data.contactName.value : this.contactName,
      contactEmail: data.contactEmail.present
          ? data.contactEmail.value
          : this.contactEmail,
      contactPhone: data.contactPhone.present
          ? data.contactPhone.value
          : this.contactPhone,
      address: data.address.present ? data.address.value : this.address,
      logoPath: data.logoPath.present ? data.logoPath.value : this.logoPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Client(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contactName: $contactName, ')
          ..write('contactEmail: $contactEmail, ')
          ..write('contactPhone: $contactPhone, ')
          ..write('address: $address, ')
          ..write('logoPath: $logoPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, contactName, contactEmail,
      contactPhone, address, logoPath, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Client &&
          other.id == this.id &&
          other.name == this.name &&
          other.contactName == this.contactName &&
          other.contactEmail == this.contactEmail &&
          other.contactPhone == this.contactPhone &&
          other.address == this.address &&
          other.logoPath == this.logoPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ClientsCompanion extends UpdateCompanion<Client> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> contactName;
  final Value<String?> contactEmail;
  final Value<String?> contactPhone;
  final Value<String> address;
  final Value<String> logoPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ClientsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.contactName = const Value.absent(),
    this.contactEmail = const Value.absent(),
    this.contactPhone = const Value.absent(),
    this.address = const Value.absent(),
    this.logoPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientsCompanion.insert({
    required String id,
    required String name,
    this.contactName = const Value.absent(),
    this.contactEmail = const Value.absent(),
    this.contactPhone = const Value.absent(),
    required String address,
    required String logoPath,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        address = Value(address),
        logoPath = Value(logoPath),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Client> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? contactName,
    Expression<String>? contactEmail,
    Expression<String>? contactPhone,
    Expression<String>? address,
    Expression<String>? logoPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (contactName != null) 'contact_name': contactName,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (address != null) 'address': address,
      if (logoPath != null) 'logo_path': logoPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? contactName,
      Value<String?>? contactEmail,
      Value<String?>? contactPhone,
      Value<String>? address,
      Value<String>? logoPath,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return ClientsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      logoPath: logoPath ?? this.logoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contactName.present) {
      map['contact_name'] = Variable<String>(contactName.value);
    }
    if (contactEmail.present) {
      map['contact_email'] = Variable<String>(contactEmail.value);
    }
    if (contactPhone.present) {
      map['contact_phone'] = Variable<String>(contactPhone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (logoPath.present) {
      map['logo_path'] = Variable<String>(logoPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contactName: $contactName, ')
          ..write('contactEmail: $contactEmail, ')
          ..write('contactPhone: $contactPhone, ')
          ..write('address: $address, ')
          ..write('logoPath: $logoPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientIdMeta =
      const VerificationMeta('clientId');
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
      'client_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES clients(id)');
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _purchaseOrderMeta =
      const VerificationMeta('purchaseOrder');
  @override
  late final GeneratedColumn<String> purchaseOrder = GeneratedColumn<String>(
      'purchase_order', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _buildingMeta =
      const VerificationMeta('building');
  @override
  late final GeneratedColumn<String> building = GeneratedColumn<String>(
      'building', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startedOnMeta =
      const VerificationMeta('startedOn');
  @override
  late final GeneratedColumn<DateTime> startedOn = GeneratedColumn<DateTime>(
      'started_on', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endedOnMeta =
      const VerificationMeta('endedOn');
  @override
  late final GeneratedColumn<DateTime> endedOn = GeneratedColumn<DateTime>(
      'ended_on', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<ProjectStatus, String> status =
      GeneratedColumn<String>('status', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('inProgress'))
          .withConverter<ProjectStatus>($ProjectsTable.$converterstatus);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        clientId,
        code,
        purchaseOrder,
        building,
        name,
        description,
        startedOn,
        endedOn,
        status,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(Insertable<Project> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    }
    if (data.containsKey('purchase_order')) {
      context.handle(
          _purchaseOrderMeta,
          purchaseOrder.isAcceptableOrUnknown(
              data['purchase_order']!, _purchaseOrderMeta));
    }
    if (data.containsKey('building')) {
      context.handle(_buildingMeta,
          building.isAcceptableOrUnknown(data['building']!, _buildingMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('started_on')) {
      context.handle(_startedOnMeta,
          startedOn.isAcceptableOrUnknown(data['started_on']!, _startedOnMeta));
    }
    if (data.containsKey('ended_on')) {
      context.handle(_endedOnMeta,
          endedOn.isAcceptableOrUnknown(data['ended_on']!, _endedOnMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      clientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code']),
      purchaseOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}purchase_order']),
      building: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}building']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      startedOn: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_on']),
      endedOn: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_on']),
      status: $ProjectsTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProjectStatus, String, String> $converterstatus =
      const EnumNameConverter<ProjectStatus>(ProjectStatus.values);
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String clientId;

  /// Numéro de chantier du donneur d'ordre, reporté sur chaque fiche du
  /// rapport (ligne « Numéro Projet » du gabarit).
  ///
  /// Texte et non entier : les numéros de chantier portent presque toujours un
  /// préfixe ou un millésime (« 2026-118 », « BE/447 »). Nullable, parce qu'un
  /// chantier se crée sur le terrain avant que l'administratif ne suive.
  final String? code;

  /// Bon de commande du client, reporté sur chaque fiche du rapport (ligne
  /// « Purchase Order »). Saisi ici et non sur les traversées, pour la même
  /// raison que [code] : un seul endroit où le corriger.
  final String? purchaseOrder;

  /// Bâtiment proposé **par défaut** à chaque nouvelle traversée.
  ///
  /// Une valeur de départ, pas une valeur partagée : elle est recopiée dans
  /// `Points.building` à la création, où elle reste modifiable. La changer ici
  /// ne réécrit donc pas les traversées déjà relevées.
  final String? building;
  final String name;
  final String? description;
  final DateTime? startedOn;
  final DateTime? endedOn;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Project(
      {required this.id,
      required this.clientId,
      this.code,
      this.purchaseOrder,
      this.building,
      required this.name,
      this.description,
      this.startedOn,
      this.endedOn,
      required this.status,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_id'] = Variable<String>(clientId);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || purchaseOrder != null) {
      map['purchase_order'] = Variable<String>(purchaseOrder);
    }
    if (!nullToAbsent || building != null) {
      map['building'] = Variable<String>(building);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || startedOn != null) {
      map['started_on'] = Variable<DateTime>(startedOn);
    }
    if (!nullToAbsent || endedOn != null) {
      map['ended_on'] = Variable<DateTime>(endedOn);
    }
    {
      map['status'] =
          Variable<String>($ProjectsTable.$converterstatus.toSql(status));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      clientId: Value(clientId),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      purchaseOrder: purchaseOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(purchaseOrder),
      building: building == null && nullToAbsent
          ? const Value.absent()
          : Value(building),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      startedOn: startedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(startedOn),
      endedOn: endedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(endedOn),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Project.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      code: serializer.fromJson<String?>(json['code']),
      purchaseOrder: serializer.fromJson<String?>(json['purchaseOrder']),
      building: serializer.fromJson<String?>(json['building']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      startedOn: serializer.fromJson<DateTime?>(json['startedOn']),
      endedOn: serializer.fromJson<DateTime?>(json['endedOn']),
      status: $ProjectsTable.$converterstatus
          .fromJson(serializer.fromJson<String>(json['status'])),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientId': serializer.toJson<String>(clientId),
      'code': serializer.toJson<String?>(code),
      'purchaseOrder': serializer.toJson<String?>(purchaseOrder),
      'building': serializer.toJson<String?>(building),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'startedOn': serializer.toJson<DateTime?>(startedOn),
      'endedOn': serializer.toJson<DateTime?>(endedOn),
      'status': serializer
          .toJson<String>($ProjectsTable.$converterstatus.toJson(status)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Project copyWith(
          {String? id,
          String? clientId,
          Value<String?> code = const Value.absent(),
          Value<String?> purchaseOrder = const Value.absent(),
          Value<String?> building = const Value.absent(),
          String? name,
          Value<String?> description = const Value.absent(),
          Value<DateTime?> startedOn = const Value.absent(),
          Value<DateTime?> endedOn = const Value.absent(),
          ProjectStatus? status,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Project(
        id: id ?? this.id,
        clientId: clientId ?? this.clientId,
        code: code.present ? code.value : this.code,
        purchaseOrder:
            purchaseOrder.present ? purchaseOrder.value : this.purchaseOrder,
        building: building.present ? building.value : this.building,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        startedOn: startedOn.present ? startedOn.value : this.startedOn,
        endedOn: endedOn.present ? endedOn.value : this.endedOn,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      code: data.code.present ? data.code.value : this.code,
      purchaseOrder: data.purchaseOrder.present
          ? data.purchaseOrder.value
          : this.purchaseOrder,
      building: data.building.present ? data.building.value : this.building,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      startedOn: data.startedOn.present ? data.startedOn.value : this.startedOn,
      endedOn: data.endedOn.present ? data.endedOn.value : this.endedOn,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('code: $code, ')
          ..write('purchaseOrder: $purchaseOrder, ')
          ..write('building: $building, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('startedOn: $startedOn, ')
          ..write('endedOn: $endedOn, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      clientId,
      code,
      purchaseOrder,
      building,
      name,
      description,
      startedOn,
      endedOn,
      status,
      createdAt,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.code == this.code &&
          other.purchaseOrder == this.purchaseOrder &&
          other.building == this.building &&
          other.name == this.name &&
          other.description == this.description &&
          other.startedOn == this.startedOn &&
          other.endedOn == this.endedOn &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> clientId;
  final Value<String?> code;
  final Value<String?> purchaseOrder;
  final Value<String?> building;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime?> startedOn;
  final Value<DateTime?> endedOn;
  final Value<ProjectStatus> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.code = const Value.absent(),
    this.purchaseOrder = const Value.absent(),
    this.building = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.endedOn = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String clientId,
    this.code = const Value.absent(),
    this.purchaseOrder = const Value.absent(),
    this.building = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.endedOn = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        clientId = Value(clientId),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? code,
    Expression<String>? purchaseOrder,
    Expression<String>? building,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? startedOn,
    Expression<DateTime>? endedOn,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (code != null) 'code': code,
      if (purchaseOrder != null) 'purchase_order': purchaseOrder,
      if (building != null) 'building': building,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (startedOn != null) 'started_on': startedOn,
      if (endedOn != null) 'ended_on': endedOn,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith(
      {Value<String>? id,
      Value<String>? clientId,
      Value<String?>? code,
      Value<String?>? purchaseOrder,
      Value<String?>? building,
      Value<String>? name,
      Value<String?>? description,
      Value<DateTime?>? startedOn,
      Value<DateTime?>? endedOn,
      Value<ProjectStatus>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return ProjectsCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      code: code ?? this.code,
      purchaseOrder: purchaseOrder ?? this.purchaseOrder,
      building: building ?? this.building,
      name: name ?? this.name,
      description: description ?? this.description,
      startedOn: startedOn ?? this.startedOn,
      endedOn: endedOn ?? this.endedOn,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (purchaseOrder.present) {
      map['purchase_order'] = Variable<String>(purchaseOrder.value);
    }
    if (building.present) {
      map['building'] = Variable<String>(building.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (startedOn.present) {
      map['started_on'] = Variable<DateTime>(startedOn.value);
    }
    if (endedOn.present) {
      map['ended_on'] = Variable<DateTime>(endedOn.value);
    }
    if (status.present) {
      map['status'] =
          Variable<String>($ProjectsTable.$converterstatus.toSql(status.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('code: $code, ')
          ..write('purchaseOrder: $purchaseOrder, ')
          ..write('building: $building, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('startedOn: $startedOn, ')
          ..write('endedOn: $endedOn, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectMembersTable extends ProjectMembers
    with TableInfo<$ProjectMembersTable, ProjectMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES projects(id)');
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES profiles(id)');
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [projectId, userId, addedAt, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_members';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectMember> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId, userId};
  @override
  ProjectMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectMember(
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $ProjectMembersTable createAlias(String alias) {
    return $ProjectMembersTable(attachedDatabase, alias);
  }
}

class ProjectMember extends DataClass implements Insertable<ProjectMember> {
  final String projectId;
  final String userId;
  final DateTime addedAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ProjectMember(
      {required this.projectId,
      required this.userId,
      required this.addedAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['user_id'] = Variable<String>(userId);
    map['added_at'] = Variable<DateTime>(addedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProjectMembersCompanion toCompanion(bool nullToAbsent) {
    return ProjectMembersCompanion(
      projectId: Value(projectId),
      userId: Value(userId),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ProjectMember.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectMember(
      projectId: serializer.fromJson<String>(json['projectId']),
      userId: serializer.fromJson<String>(json['userId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'userId': serializer.toJson<String>(userId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ProjectMember copyWith(
          {String? projectId,
          String? userId,
          DateTime? addedAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      ProjectMember(
        projectId: projectId ?? this.projectId,
        userId: userId ?? this.userId,
        addedAt: addedAt ?? this.addedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  ProjectMember copyWithCompanion(ProjectMembersCompanion data) {
    return ProjectMember(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      userId: data.userId.present ? data.userId.value : this.userId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectMember(')
          ..write('projectId: $projectId, ')
          ..write('userId: $userId, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(projectId, userId, addedAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectMember &&
          other.projectId == this.projectId &&
          other.userId == this.userId &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProjectMembersCompanion extends UpdateCompanion<ProjectMember> {
  final Value<String> projectId;
  final Value<String> userId;
  final Value<DateTime> addedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProjectMembersCompanion({
    this.projectId = const Value.absent(),
    this.userId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectMembersCompanion.insert({
    required String projectId,
    required String userId,
    required DateTime addedAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : projectId = Value(projectId),
        userId = Value(userId),
        addedAt = Value(addedAt),
        updatedAt = Value(updatedAt);
  static Insertable<ProjectMember> custom({
    Expression<String>? projectId,
    Expression<String>? userId,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (userId != null) 'user_id': userId,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectMembersCompanion copyWith(
      {Value<String>? projectId,
      Value<String>? userId,
      Value<DateTime>? addedAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return ProjectMembersCompanion(
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectMembersCompanion(')
          ..write('projectId: $projectId, ')
          ..write('userId: $userId, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingOptionsTable extends SettingOptions
    with TableInfo<$SettingOptionsTable, SettingOption> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingOptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<SettingKind, String> kind =
      GeneratedColumn<String>('kind', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<SettingKind>($SettingOptionsTable.$converterkind);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, kind, label, sortOrder, parentId, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting_options';
  @override
  VerificationContext validateIntegrity(Insertable<SettingOption> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingOption map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingOption(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: $SettingOptionsTable.$converterkind.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!),
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $SettingOptionsTable createAlias(String alias) {
    return $SettingOptionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SettingKind, String, String> $converterkind =
      const EnumNameConverter<SettingKind>(SettingKind.values);
}

class SettingOption extends DataClass implements Insertable<SettingOption> {
  final String id;
  final SettingKind kind;
  final String label;

  /// Rang d'affichage dans la liste déroulante.
  ///
  /// Explicite plutôt qu'alphabétique : « EI30, EI60, EI90, EI120 » est un
  /// ordre croissant que l'alphabet casserait — EI120 passerait avant EI30 —
  /// et les configurations ont un ordre métier que l'administrateur connaît.
  final int sortOrder;

  /// Fournisseur d'un produit ; `null` pour toute autre liste.
  ///
  /// **Sans clause `REFERENCES`, et c'est délibéré** — la seule colonne du
  /// schéma dans ce cas. La descente trie par `synced_at`, et un fournisseur
  /// renommé après la création de ses produits porte un `synced_at` plus récent
  /// qu'eux : sur une tablette neuve, le produit arriverait toujours avant son
  /// parent. `PullEngine._parentManquant` le différerait, le curseur
  /// n'avancerait pas, et le cycle suivant buterait sur la même ligne — la
  /// descente des listes serait figée pour de bon. Le serveur, lui, porte la
  /// clé étrangère.
  final String? parentId;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const SettingOption(
      {required this.id,
      required this.kind,
      required this.label,
      required this.sortOrder,
      this.parentId,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] =
          Variable<String>($SettingOptionsTable.$converterkind.toSql(kind));
    }
    map['label'] = Variable<String>(label);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SettingOptionsCompanion toCompanion(bool nullToAbsent) {
    return SettingOptionsCompanion(
      id: Value(id),
      kind: Value(kind),
      label: Value(label),
      sortOrder: Value(sortOrder),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SettingOption.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingOption(
      id: serializer.fromJson<String>(json['id']),
      kind: $SettingOptionsTable.$converterkind
          .fromJson(serializer.fromJson<String>(json['kind'])),
      label: serializer.fromJson<String>(json['label']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer
          .toJson<String>($SettingOptionsTable.$converterkind.toJson(kind)),
      'label': serializer.toJson<String>(label),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'parentId': serializer.toJson<String?>(parentId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SettingOption copyWith(
          {String? id,
          SettingKind? kind,
          String? label,
          int? sortOrder,
          Value<String?> parentId = const Value.absent(),
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      SettingOption(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        label: label ?? this.label,
        sortOrder: sortOrder ?? this.sortOrder,
        parentId: parentId.present ? parentId.value : this.parentId,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  SettingOption copyWithCompanion(SettingOptionsCompanion data) {
    return SettingOption(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingOption(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, label, sortOrder, parentId, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingOption &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.sortOrder == this.sortOrder &&
          other.parentId == this.parentId &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SettingOptionsCompanion extends UpdateCompanion<SettingOption> {
  final Value<String> id;
  final Value<SettingKind> kind;
  final Value<String> label;
  final Value<int> sortOrder;
  final Value<String?> parentId;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SettingOptionsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingOptionsCompanion.insert({
    required String id,
    required SettingKind kind,
    required String label,
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind),
        label = Value(label),
        updatedAt = Value(updatedAt);
  static Insertable<SettingOption> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<int>? sortOrder,
    Expression<String>? parentId,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (parentId != null) 'parent_id': parentId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingOptionsCompanion copyWith(
      {Value<String>? id,
      Value<SettingKind>? kind,
      Value<String>? label,
      Value<int>? sortOrder,
      Value<String?>? parentId,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return SettingOptionsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
          $SettingOptionsTable.$converterkind.toSql(kind.value));
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingOptionsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PointsTable extends Points with TableInfo<$PointsTable, Point> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES projects(id)');
  static const VerificationMeta _refNumberMeta =
      const VerificationMeta('refNumber');
  @override
  late final GeneratedColumn<int> refNumber = GeneratedColumn<int>(
      'ref_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _projectCodeMeta =
      const VerificationMeta('projectCode');
  @override
  late final GeneratedColumn<String> projectCode = GeneratedColumn<String>(
      'project_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _projectNameMeta =
      const VerificationMeta('projectName');
  @override
  late final GeneratedColumn<String> projectName = GeneratedColumn<String>(
      'project_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _purchaseOrderMeta =
      const VerificationMeta('purchaseOrder');
  @override
  late final GeneratedColumn<String> purchaseOrder = GeneratedColumn<String>(
      'purchase_order', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _buildingMeta =
      const VerificationMeta('building');
  @override
  late final GeneratedColumn<String> building = GeneratedColumn<String>(
      'building', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _floorLevelMeta =
      const VerificationMeta('floorLevel');
  @override
  late final GeneratedColumn<int> floorLevel = GeneratedColumn<int>(
      'floor_level', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _roomMeta = const VerificationMeta('room');
  @override
  late final GeneratedColumn<String> room = GeneratedColumn<String>(
      'room', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _configurationIdMeta =
      const VerificationMeta('configurationId');
  @override
  late final GeneratedColumn<String> configurationId = GeneratedColumn<String>(
      'configuration_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _configurationDetailIdMeta =
      const VerificationMeta('configurationDetailId');
  @override
  late final GeneratedColumn<String> configurationDetailId =
      GeneratedColumn<String>('configuration_detail_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _eiLevelIdMeta =
      const VerificationMeta('eiLevelId');
  @override
  late final GeneratedColumn<String> eiLevelId = GeneratedColumn<String>(
      'ei_level_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _supplierIdMeta =
      const VerificationMeta('supplierId');
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
      'supplier_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _productTypeIdMeta =
      const VerificationMeta('productTypeId');
  @override
  late final GeneratedColumn<String> productTypeId = GeneratedColumn<String>(
      'product_type_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _product1IdMeta =
      const VerificationMeta('product1Id');
  @override
  late final GeneratedColumn<String> product1Id = GeneratedColumn<String>(
      'product1_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _product2IdMeta =
      const VerificationMeta('product2Id');
  @override
  late final GeneratedColumn<String> product2Id = GeneratedColumn<String>(
      'product2_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _product3IdMeta =
      const VerificationMeta('product3Id');
  @override
  late final GeneratedColumn<String> product3Id = GeneratedColumn<String>(
      'product3_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _product4IdMeta =
      const VerificationMeta('product4Id');
  @override
  late final GeneratedColumn<String> product4Id = GeneratedColumn<String>(
      'product4_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _product5IdMeta =
      const VerificationMeta('product5Id');
  @override
  late final GeneratedColumn<String> product5Id = GeneratedColumn<String>(
      'product5_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES setting_options(id)');
  static const VerificationMeta _authorIdMeta =
      const VerificationMeta('authorId');
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
      'author_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES profiles(id)');
  static const VerificationMeta _capturedAtMeta =
      const VerificationMeta('capturedAt');
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
      'captured_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        refNumber,
        projectCode,
        projectName,
        purchaseOrder,
        building,
        floorLevel,
        room,
        description,
        configurationId,
        configurationDetailId,
        eiLevelId,
        supplierId,
        productTypeId,
        product1Id,
        product2Id,
        product3Id,
        product4Id,
        product5Id,
        authorId,
        capturedAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'points';
  @override
  VerificationContext validateIntegrity(Insertable<Point> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('ref_number')) {
      context.handle(_refNumberMeta,
          refNumber.isAcceptableOrUnknown(data['ref_number']!, _refNumberMeta));
    }
    if (data.containsKey('project_code')) {
      context.handle(
          _projectCodeMeta,
          projectCode.isAcceptableOrUnknown(
              data['project_code']!, _projectCodeMeta));
    }
    if (data.containsKey('project_name')) {
      context.handle(
          _projectNameMeta,
          projectName.isAcceptableOrUnknown(
              data['project_name']!, _projectNameMeta));
    }
    if (data.containsKey('purchase_order')) {
      context.handle(
          _purchaseOrderMeta,
          purchaseOrder.isAcceptableOrUnknown(
              data['purchase_order']!, _purchaseOrderMeta));
    }
    if (data.containsKey('building')) {
      context.handle(_buildingMeta,
          building.isAcceptableOrUnknown(data['building']!, _buildingMeta));
    }
    if (data.containsKey('floor_level')) {
      context.handle(
          _floorLevelMeta,
          floorLevel.isAcceptableOrUnknown(
              data['floor_level']!, _floorLevelMeta));
    }
    if (data.containsKey('room')) {
      context.handle(
          _roomMeta, room.isAcceptableOrUnknown(data['room']!, _roomMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('configuration_id')) {
      context.handle(
          _configurationIdMeta,
          configurationId.isAcceptableOrUnknown(
              data['configuration_id']!, _configurationIdMeta));
    }
    if (data.containsKey('configuration_detail_id')) {
      context.handle(
          _configurationDetailIdMeta,
          configurationDetailId.isAcceptableOrUnknown(
              data['configuration_detail_id']!, _configurationDetailIdMeta));
    }
    if (data.containsKey('ei_level_id')) {
      context.handle(
          _eiLevelIdMeta,
          eiLevelId.isAcceptableOrUnknown(
              data['ei_level_id']!, _eiLevelIdMeta));
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
          _supplierIdMeta,
          supplierId.isAcceptableOrUnknown(
              data['supplier_id']!, _supplierIdMeta));
    }
    if (data.containsKey('product_type_id')) {
      context.handle(
          _productTypeIdMeta,
          productTypeId.isAcceptableOrUnknown(
              data['product_type_id']!, _productTypeIdMeta));
    }
    if (data.containsKey('product1_id')) {
      context.handle(
          _product1IdMeta,
          product1Id.isAcceptableOrUnknown(
              data['product1_id']!, _product1IdMeta));
    }
    if (data.containsKey('product2_id')) {
      context.handle(
          _product2IdMeta,
          product2Id.isAcceptableOrUnknown(
              data['product2_id']!, _product2IdMeta));
    }
    if (data.containsKey('product3_id')) {
      context.handle(
          _product3IdMeta,
          product3Id.isAcceptableOrUnknown(
              data['product3_id']!, _product3IdMeta));
    }
    if (data.containsKey('product4_id')) {
      context.handle(
          _product4IdMeta,
          product4Id.isAcceptableOrUnknown(
              data['product4_id']!, _product4IdMeta));
    }
    if (data.containsKey('product5_id')) {
      context.handle(
          _product5IdMeta,
          product5Id.isAcceptableOrUnknown(
              data['product5_id']!, _product5IdMeta));
    }
    if (data.containsKey('author_id')) {
      context.handle(_authorIdMeta,
          authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta));
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
          _capturedAtMeta,
          capturedAt.isAcceptableOrUnknown(
              data['captured_at']!, _capturedAtMeta));
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Point map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Point(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      refNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ref_number']),
      projectCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_code']),
      projectName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_name']),
      purchaseOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}purchase_order']),
      building: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}building']),
      floorLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}floor_level']),
      room: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      configurationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}configuration_id']),
      configurationDetailId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}configuration_detail_id']),
      eiLevelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ei_level_id']),
      supplierId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_id']),
      productTypeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_type_id']),
      product1Id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product1_id']),
      product2Id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product2_id']),
      product3Id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product3_id']),
      product4Id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product4_id']),
      product5Id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product5_id']),
      authorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_id'])!,
      capturedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}captured_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PointsTable createAlias(String alias) {
    return $PointsTable(attachedDatabase, alias);
  }
}

class Point extends DataClass implements Insertable<Point> {
  final String id;
  final String projectId;

  /// Numéro de la traversée, **saisi par le technicien**.
  ///
  /// Il suit le repérage du chantier — plans, étiquettes posées sur place. La
  /// création propose le suivant du plus grand numéro connu de l'appareil,
  /// modifiable. Nullable : une fiche peut rester sans numéro le temps de la
  /// saisie.
  ///
  /// **Aucune unicité n'est imposée**, ni ici ni sur le serveur. Deux
  /// techniciens hors ligne peuvent saisir le même numéro ; une contrainte
  /// ferait refuser le second relevé à la synchronisation. Le doublon est
  /// signalé sur la fiche (`PointDao.watchRefNumberTaken`).
  final int? refNumber;
  final String? projectCode;
  final String? projectName;

  /// Terme anglais conservé : c'est celui de la fiche et des pièces
  /// contractuelles.
  final String? purchaseOrder;

  /// Bâtiment(s) concerné(s). Champ libre : aucune nomenclature ne s'impose
  /// d'un site à l'autre.
  final String? building;

  /// Étage, de -3 à 5 (voir [floorRange]).
  ///
  /// Entier et non texte : l'étage est un axe ordonné, et c'est ce qui permet
  /// de lire un relevé du sous-sol au dernier niveau.
  final int? floorLevel;

  /// Local. Hors gabarit du rapport, conservé comme repère de terrain.
  final String? room;

  /// Observations libres. Hors gabarit du rapport, lui aussi.
  final String? description;
  final String? configurationId;
  final String? configurationDetailId;
  final String? eiLevelId;
  final String? supplierId;
  final String? productTypeId;
  final String? product1Id;
  final String? product2Id;
  final String? product3Id;
  final String? product4Id;
  final String? product5Id;
  final String authorId;

  /// Date de la traversée — la « Date » du gabarit.
  final DateTime capturedAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Point(
      {required this.id,
      required this.projectId,
      this.refNumber,
      this.projectCode,
      this.projectName,
      this.purchaseOrder,
      this.building,
      this.floorLevel,
      this.room,
      this.description,
      this.configurationId,
      this.configurationDetailId,
      this.eiLevelId,
      this.supplierId,
      this.productTypeId,
      this.product1Id,
      this.product2Id,
      this.product3Id,
      this.product4Id,
      this.product5Id,
      required this.authorId,
      required this.capturedAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || refNumber != null) {
      map['ref_number'] = Variable<int>(refNumber);
    }
    if (!nullToAbsent || projectCode != null) {
      map['project_code'] = Variable<String>(projectCode);
    }
    if (!nullToAbsent || projectName != null) {
      map['project_name'] = Variable<String>(projectName);
    }
    if (!nullToAbsent || purchaseOrder != null) {
      map['purchase_order'] = Variable<String>(purchaseOrder);
    }
    if (!nullToAbsent || building != null) {
      map['building'] = Variable<String>(building);
    }
    if (!nullToAbsent || floorLevel != null) {
      map['floor_level'] = Variable<int>(floorLevel);
    }
    if (!nullToAbsent || room != null) {
      map['room'] = Variable<String>(room);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || configurationId != null) {
      map['configuration_id'] = Variable<String>(configurationId);
    }
    if (!nullToAbsent || configurationDetailId != null) {
      map['configuration_detail_id'] = Variable<String>(configurationDetailId);
    }
    if (!nullToAbsent || eiLevelId != null) {
      map['ei_level_id'] = Variable<String>(eiLevelId);
    }
    if (!nullToAbsent || supplierId != null) {
      map['supplier_id'] = Variable<String>(supplierId);
    }
    if (!nullToAbsent || productTypeId != null) {
      map['product_type_id'] = Variable<String>(productTypeId);
    }
    if (!nullToAbsent || product1Id != null) {
      map['product1_id'] = Variable<String>(product1Id);
    }
    if (!nullToAbsent || product2Id != null) {
      map['product2_id'] = Variable<String>(product2Id);
    }
    if (!nullToAbsent || product3Id != null) {
      map['product3_id'] = Variable<String>(product3Id);
    }
    if (!nullToAbsent || product4Id != null) {
      map['product4_id'] = Variable<String>(product4Id);
    }
    if (!nullToAbsent || product5Id != null) {
      map['product5_id'] = Variable<String>(product5Id);
    }
    map['author_id'] = Variable<String>(authorId);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PointsCompanion toCompanion(bool nullToAbsent) {
    return PointsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      refNumber: refNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(refNumber),
      projectCode: projectCode == null && nullToAbsent
          ? const Value.absent()
          : Value(projectCode),
      projectName: projectName == null && nullToAbsent
          ? const Value.absent()
          : Value(projectName),
      purchaseOrder: purchaseOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(purchaseOrder),
      building: building == null && nullToAbsent
          ? const Value.absent()
          : Value(building),
      floorLevel: floorLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(floorLevel),
      room: room == null && nullToAbsent ? const Value.absent() : Value(room),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      configurationId: configurationId == null && nullToAbsent
          ? const Value.absent()
          : Value(configurationId),
      configurationDetailId: configurationDetailId == null && nullToAbsent
          ? const Value.absent()
          : Value(configurationDetailId),
      eiLevelId: eiLevelId == null && nullToAbsent
          ? const Value.absent()
          : Value(eiLevelId),
      supplierId: supplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierId),
      productTypeId: productTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(productTypeId),
      product1Id: product1Id == null && nullToAbsent
          ? const Value.absent()
          : Value(product1Id),
      product2Id: product2Id == null && nullToAbsent
          ? const Value.absent()
          : Value(product2Id),
      product3Id: product3Id == null && nullToAbsent
          ? const Value.absent()
          : Value(product3Id),
      product4Id: product4Id == null && nullToAbsent
          ? const Value.absent()
          : Value(product4Id),
      product5Id: product5Id == null && nullToAbsent
          ? const Value.absent()
          : Value(product5Id),
      authorId: Value(authorId),
      capturedAt: Value(capturedAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Point.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Point(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      refNumber: serializer.fromJson<int?>(json['refNumber']),
      projectCode: serializer.fromJson<String?>(json['projectCode']),
      projectName: serializer.fromJson<String?>(json['projectName']),
      purchaseOrder: serializer.fromJson<String?>(json['purchaseOrder']),
      building: serializer.fromJson<String?>(json['building']),
      floorLevel: serializer.fromJson<int?>(json['floorLevel']),
      room: serializer.fromJson<String?>(json['room']),
      description: serializer.fromJson<String?>(json['description']),
      configurationId: serializer.fromJson<String?>(json['configurationId']),
      configurationDetailId:
          serializer.fromJson<String?>(json['configurationDetailId']),
      eiLevelId: serializer.fromJson<String?>(json['eiLevelId']),
      supplierId: serializer.fromJson<String?>(json['supplierId']),
      productTypeId: serializer.fromJson<String?>(json['productTypeId']),
      product1Id: serializer.fromJson<String?>(json['product1Id']),
      product2Id: serializer.fromJson<String?>(json['product2Id']),
      product3Id: serializer.fromJson<String?>(json['product3Id']),
      product4Id: serializer.fromJson<String?>(json['product4Id']),
      product5Id: serializer.fromJson<String?>(json['product5Id']),
      authorId: serializer.fromJson<String>(json['authorId']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'refNumber': serializer.toJson<int?>(refNumber),
      'projectCode': serializer.toJson<String?>(projectCode),
      'projectName': serializer.toJson<String?>(projectName),
      'purchaseOrder': serializer.toJson<String?>(purchaseOrder),
      'building': serializer.toJson<String?>(building),
      'floorLevel': serializer.toJson<int?>(floorLevel),
      'room': serializer.toJson<String?>(room),
      'description': serializer.toJson<String?>(description),
      'configurationId': serializer.toJson<String?>(configurationId),
      'configurationDetailId':
          serializer.toJson<String?>(configurationDetailId),
      'eiLevelId': serializer.toJson<String?>(eiLevelId),
      'supplierId': serializer.toJson<String?>(supplierId),
      'productTypeId': serializer.toJson<String?>(productTypeId),
      'product1Id': serializer.toJson<String?>(product1Id),
      'product2Id': serializer.toJson<String?>(product2Id),
      'product3Id': serializer.toJson<String?>(product3Id),
      'product4Id': serializer.toJson<String?>(product4Id),
      'product5Id': serializer.toJson<String?>(product5Id),
      'authorId': serializer.toJson<String>(authorId),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Point copyWith(
          {String? id,
          String? projectId,
          Value<int?> refNumber = const Value.absent(),
          Value<String?> projectCode = const Value.absent(),
          Value<String?> projectName = const Value.absent(),
          Value<String?> purchaseOrder = const Value.absent(),
          Value<String?> building = const Value.absent(),
          Value<int?> floorLevel = const Value.absent(),
          Value<String?> room = const Value.absent(),
          Value<String?> description = const Value.absent(),
          Value<String?> configurationId = const Value.absent(),
          Value<String?> configurationDetailId = const Value.absent(),
          Value<String?> eiLevelId = const Value.absent(),
          Value<String?> supplierId = const Value.absent(),
          Value<String?> productTypeId = const Value.absent(),
          Value<String?> product1Id = const Value.absent(),
          Value<String?> product2Id = const Value.absent(),
          Value<String?> product3Id = const Value.absent(),
          Value<String?> product4Id = const Value.absent(),
          Value<String?> product5Id = const Value.absent(),
          String? authorId,
          DateTime? capturedAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Point(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        refNumber: refNumber.present ? refNumber.value : this.refNumber,
        projectCode: projectCode.present ? projectCode.value : this.projectCode,
        projectName: projectName.present ? projectName.value : this.projectName,
        purchaseOrder:
            purchaseOrder.present ? purchaseOrder.value : this.purchaseOrder,
        building: building.present ? building.value : this.building,
        floorLevel: floorLevel.present ? floorLevel.value : this.floorLevel,
        room: room.present ? room.value : this.room,
        description: description.present ? description.value : this.description,
        configurationId: configurationId.present
            ? configurationId.value
            : this.configurationId,
        configurationDetailId: configurationDetailId.present
            ? configurationDetailId.value
            : this.configurationDetailId,
        eiLevelId: eiLevelId.present ? eiLevelId.value : this.eiLevelId,
        supplierId: supplierId.present ? supplierId.value : this.supplierId,
        productTypeId:
            productTypeId.present ? productTypeId.value : this.productTypeId,
        product1Id: product1Id.present ? product1Id.value : this.product1Id,
        product2Id: product2Id.present ? product2Id.value : this.product2Id,
        product3Id: product3Id.present ? product3Id.value : this.product3Id,
        product4Id: product4Id.present ? product4Id.value : this.product4Id,
        product5Id: product5Id.present ? product5Id.value : this.product5Id,
        authorId: authorId ?? this.authorId,
        capturedAt: capturedAt ?? this.capturedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Point copyWithCompanion(PointsCompanion data) {
    return Point(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      refNumber: data.refNumber.present ? data.refNumber.value : this.refNumber,
      projectCode:
          data.projectCode.present ? data.projectCode.value : this.projectCode,
      projectName:
          data.projectName.present ? data.projectName.value : this.projectName,
      purchaseOrder: data.purchaseOrder.present
          ? data.purchaseOrder.value
          : this.purchaseOrder,
      building: data.building.present ? data.building.value : this.building,
      floorLevel:
          data.floorLevel.present ? data.floorLevel.value : this.floorLevel,
      room: data.room.present ? data.room.value : this.room,
      description:
          data.description.present ? data.description.value : this.description,
      configurationId: data.configurationId.present
          ? data.configurationId.value
          : this.configurationId,
      configurationDetailId: data.configurationDetailId.present
          ? data.configurationDetailId.value
          : this.configurationDetailId,
      eiLevelId: data.eiLevelId.present ? data.eiLevelId.value : this.eiLevelId,
      supplierId:
          data.supplierId.present ? data.supplierId.value : this.supplierId,
      productTypeId: data.productTypeId.present
          ? data.productTypeId.value
          : this.productTypeId,
      product1Id:
          data.product1Id.present ? data.product1Id.value : this.product1Id,
      product2Id:
          data.product2Id.present ? data.product2Id.value : this.product2Id,
      product3Id:
          data.product3Id.present ? data.product3Id.value : this.product3Id,
      product4Id:
          data.product4Id.present ? data.product4Id.value : this.product4Id,
      product5Id:
          data.product5Id.present ? data.product5Id.value : this.product5Id,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      capturedAt:
          data.capturedAt.present ? data.capturedAt.value : this.capturedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Point(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('refNumber: $refNumber, ')
          ..write('projectCode: $projectCode, ')
          ..write('projectName: $projectName, ')
          ..write('purchaseOrder: $purchaseOrder, ')
          ..write('building: $building, ')
          ..write('floorLevel: $floorLevel, ')
          ..write('room: $room, ')
          ..write('description: $description, ')
          ..write('configurationId: $configurationId, ')
          ..write('configurationDetailId: $configurationDetailId, ')
          ..write('eiLevelId: $eiLevelId, ')
          ..write('supplierId: $supplierId, ')
          ..write('productTypeId: $productTypeId, ')
          ..write('product1Id: $product1Id, ')
          ..write('product2Id: $product2Id, ')
          ..write('product3Id: $product3Id, ')
          ..write('product4Id: $product4Id, ')
          ..write('product5Id: $product5Id, ')
          ..write('authorId: $authorId, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        projectId,
        refNumber,
        projectCode,
        projectName,
        purchaseOrder,
        building,
        floorLevel,
        room,
        description,
        configurationId,
        configurationDetailId,
        eiLevelId,
        supplierId,
        productTypeId,
        product1Id,
        product2Id,
        product3Id,
        product4Id,
        product5Id,
        authorId,
        capturedAt,
        updatedAt,
        deletedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Point &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.refNumber == this.refNumber &&
          other.projectCode == this.projectCode &&
          other.projectName == this.projectName &&
          other.purchaseOrder == this.purchaseOrder &&
          other.building == this.building &&
          other.floorLevel == this.floorLevel &&
          other.room == this.room &&
          other.description == this.description &&
          other.configurationId == this.configurationId &&
          other.configurationDetailId == this.configurationDetailId &&
          other.eiLevelId == this.eiLevelId &&
          other.supplierId == this.supplierId &&
          other.productTypeId == this.productTypeId &&
          other.product1Id == this.product1Id &&
          other.product2Id == this.product2Id &&
          other.product3Id == this.product3Id &&
          other.product4Id == this.product4Id &&
          other.product5Id == this.product5Id &&
          other.authorId == this.authorId &&
          other.capturedAt == this.capturedAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PointsCompanion extends UpdateCompanion<Point> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<int?> refNumber;
  final Value<String?> projectCode;
  final Value<String?> projectName;
  final Value<String?> purchaseOrder;
  final Value<String?> building;
  final Value<int?> floorLevel;
  final Value<String?> room;
  final Value<String?> description;
  final Value<String?> configurationId;
  final Value<String?> configurationDetailId;
  final Value<String?> eiLevelId;
  final Value<String?> supplierId;
  final Value<String?> productTypeId;
  final Value<String?> product1Id;
  final Value<String?> product2Id;
  final Value<String?> product3Id;
  final Value<String?> product4Id;
  final Value<String?> product5Id;
  final Value<String> authorId;
  final Value<DateTime> capturedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PointsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.refNumber = const Value.absent(),
    this.projectCode = const Value.absent(),
    this.projectName = const Value.absent(),
    this.purchaseOrder = const Value.absent(),
    this.building = const Value.absent(),
    this.floorLevel = const Value.absent(),
    this.room = const Value.absent(),
    this.description = const Value.absent(),
    this.configurationId = const Value.absent(),
    this.configurationDetailId = const Value.absent(),
    this.eiLevelId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.productTypeId = const Value.absent(),
    this.product1Id = const Value.absent(),
    this.product2Id = const Value.absent(),
    this.product3Id = const Value.absent(),
    this.product4Id = const Value.absent(),
    this.product5Id = const Value.absent(),
    this.authorId = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PointsCompanion.insert({
    required String id,
    required String projectId,
    this.refNumber = const Value.absent(),
    this.projectCode = const Value.absent(),
    this.projectName = const Value.absent(),
    this.purchaseOrder = const Value.absent(),
    this.building = const Value.absent(),
    this.floorLevel = const Value.absent(),
    this.room = const Value.absent(),
    this.description = const Value.absent(),
    this.configurationId = const Value.absent(),
    this.configurationDetailId = const Value.absent(),
    this.eiLevelId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.productTypeId = const Value.absent(),
    this.product1Id = const Value.absent(),
    this.product2Id = const Value.absent(),
    this.product3Id = const Value.absent(),
    this.product4Id = const Value.absent(),
    this.product5Id = const Value.absent(),
    required String authorId,
    required DateTime capturedAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        authorId = Value(authorId),
        capturedAt = Value(capturedAt),
        updatedAt = Value(updatedAt);
  static Insertable<Point> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<int>? refNumber,
    Expression<String>? projectCode,
    Expression<String>? projectName,
    Expression<String>? purchaseOrder,
    Expression<String>? building,
    Expression<int>? floorLevel,
    Expression<String>? room,
    Expression<String>? description,
    Expression<String>? configurationId,
    Expression<String>? configurationDetailId,
    Expression<String>? eiLevelId,
    Expression<String>? supplierId,
    Expression<String>? productTypeId,
    Expression<String>? product1Id,
    Expression<String>? product2Id,
    Expression<String>? product3Id,
    Expression<String>? product4Id,
    Expression<String>? product5Id,
    Expression<String>? authorId,
    Expression<DateTime>? capturedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (refNumber != null) 'ref_number': refNumber,
      if (projectCode != null) 'project_code': projectCode,
      if (projectName != null) 'project_name': projectName,
      if (purchaseOrder != null) 'purchase_order': purchaseOrder,
      if (building != null) 'building': building,
      if (floorLevel != null) 'floor_level': floorLevel,
      if (room != null) 'room': room,
      if (description != null) 'description': description,
      if (configurationId != null) 'configuration_id': configurationId,
      if (configurationDetailId != null)
        'configuration_detail_id': configurationDetailId,
      if (eiLevelId != null) 'ei_level_id': eiLevelId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (productTypeId != null) 'product_type_id': productTypeId,
      if (product1Id != null) 'product1_id': product1Id,
      if (product2Id != null) 'product2_id': product2Id,
      if (product3Id != null) 'product3_id': product3Id,
      if (product4Id != null) 'product4_id': product4Id,
      if (product5Id != null) 'product5_id': product5Id,
      if (authorId != null) 'author_id': authorId,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PointsCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<int?>? refNumber,
      Value<String?>? projectCode,
      Value<String?>? projectName,
      Value<String?>? purchaseOrder,
      Value<String?>? building,
      Value<int?>? floorLevel,
      Value<String?>? room,
      Value<String?>? description,
      Value<String?>? configurationId,
      Value<String?>? configurationDetailId,
      Value<String?>? eiLevelId,
      Value<String?>? supplierId,
      Value<String?>? productTypeId,
      Value<String?>? product1Id,
      Value<String?>? product2Id,
      Value<String?>? product3Id,
      Value<String?>? product4Id,
      Value<String?>? product5Id,
      Value<String>? authorId,
      Value<DateTime>? capturedAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return PointsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      refNumber: refNumber ?? this.refNumber,
      projectCode: projectCode ?? this.projectCode,
      projectName: projectName ?? this.projectName,
      purchaseOrder: purchaseOrder ?? this.purchaseOrder,
      building: building ?? this.building,
      floorLevel: floorLevel ?? this.floorLevel,
      room: room ?? this.room,
      description: description ?? this.description,
      configurationId: configurationId ?? this.configurationId,
      configurationDetailId:
          configurationDetailId ?? this.configurationDetailId,
      eiLevelId: eiLevelId ?? this.eiLevelId,
      supplierId: supplierId ?? this.supplierId,
      productTypeId: productTypeId ?? this.productTypeId,
      product1Id: product1Id ?? this.product1Id,
      product2Id: product2Id ?? this.product2Id,
      product3Id: product3Id ?? this.product3Id,
      product4Id: product4Id ?? this.product4Id,
      product5Id: product5Id ?? this.product5Id,
      authorId: authorId ?? this.authorId,
      capturedAt: capturedAt ?? this.capturedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (refNumber.present) {
      map['ref_number'] = Variable<int>(refNumber.value);
    }
    if (projectCode.present) {
      map['project_code'] = Variable<String>(projectCode.value);
    }
    if (projectName.present) {
      map['project_name'] = Variable<String>(projectName.value);
    }
    if (purchaseOrder.present) {
      map['purchase_order'] = Variable<String>(purchaseOrder.value);
    }
    if (building.present) {
      map['building'] = Variable<String>(building.value);
    }
    if (floorLevel.present) {
      map['floor_level'] = Variable<int>(floorLevel.value);
    }
    if (room.present) {
      map['room'] = Variable<String>(room.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (configurationId.present) {
      map['configuration_id'] = Variable<String>(configurationId.value);
    }
    if (configurationDetailId.present) {
      map['configuration_detail_id'] =
          Variable<String>(configurationDetailId.value);
    }
    if (eiLevelId.present) {
      map['ei_level_id'] = Variable<String>(eiLevelId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (productTypeId.present) {
      map['product_type_id'] = Variable<String>(productTypeId.value);
    }
    if (product1Id.present) {
      map['product1_id'] = Variable<String>(product1Id.value);
    }
    if (product2Id.present) {
      map['product2_id'] = Variable<String>(product2Id.value);
    }
    if (product3Id.present) {
      map['product3_id'] = Variable<String>(product3Id.value);
    }
    if (product4Id.present) {
      map['product4_id'] = Variable<String>(product4Id.value);
    }
    if (product5Id.present) {
      map['product5_id'] = Variable<String>(product5Id.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('refNumber: $refNumber, ')
          ..write('projectCode: $projectCode, ')
          ..write('projectName: $projectName, ')
          ..write('purchaseOrder: $purchaseOrder, ')
          ..write('building: $building, ')
          ..write('floorLevel: $floorLevel, ')
          ..write('room: $room, ')
          ..write('description: $description, ')
          ..write('configurationId: $configurationId, ')
          ..write('configurationDetailId: $configurationDetailId, ')
          ..write('eiLevelId: $eiLevelId, ')
          ..write('supplierId: $supplierId, ')
          ..write('productTypeId: $productTypeId, ')
          ..write('product1Id: $product1Id, ')
          ..write('product2Id: $product2Id, ')
          ..write('product3Id: $product3Id, ')
          ..write('product4Id: $product4Id, ')
          ..write('product5Id: $product5Id, ')
          ..write('authorId: $authorId, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, Photo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pointIdMeta =
      const VerificationMeta('pointId');
  @override
  late final GeneratedColumn<String> pointId = GeneratedColumn<String>(
      'point_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES points(id)');
  @override
  late final GeneratedColumnWithTypeConverter<PhotoKind, String> kind =
      GeneratedColumn<String>('kind', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<PhotoKind>($PhotosTable.$converterkind);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _remotePathMeta =
      const VerificationMeta('remotePath');
  @override
  late final GeneratedColumn<String> remotePath = GeneratedColumn<String>(
      'remote_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
      'width', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
      'height', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
      'bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
      'sha256', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _takenAtMeta =
      const VerificationMeta('takenAt');
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
      'taken_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<PhotoUploadState, String>
      uploadState = GeneratedColumn<String>('upload_state', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<PhotoUploadState>($PhotosTable.$converteruploadState);
  static const VerificationMeta _uploadAttemptsMeta =
      const VerificationMeta('uploadAttempts');
  @override
  late final GeneratedColumn<int> uploadAttempts = GeneratedColumn<int>(
      'upload_attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextUploadAtMeta =
      const VerificationMeta('nextUploadAt');
  @override
  late final GeneratedColumn<DateTime> nextUploadAt = GeneratedColumn<DateTime>(
      'next_upload_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        pointId,
        kind,
        localPath,
        remotePath,
        width,
        height,
        bytes,
        sha256,
        sortOrder,
        takenAt,
        uploadState,
        uploadAttempts,
        nextUploadAt,
        lastError,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(Insertable<Photo> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('point_id')) {
      context.handle(_pointIdMeta,
          pointId.isAcceptableOrUnknown(data['point_id']!, _pointIdMeta));
    } else if (isInserting) {
      context.missing(_pointIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('remote_path')) {
      context.handle(
          _remotePathMeta,
          remotePath.isAcceptableOrUnknown(
              data['remote_path']!, _remotePathMeta));
    }
    if (data.containsKey('width')) {
      context.handle(
          _widthMeta, width.isAcceptableOrUnknown(data['width']!, _widthMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('bytes')) {
      context.handle(
          _bytesMeta, bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta));
    }
    if (data.containsKey('sha256')) {
      context.handle(_sha256Meta,
          sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('taken_at')) {
      context.handle(_takenAtMeta,
          takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta));
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    if (data.containsKey('upload_attempts')) {
      context.handle(
          _uploadAttemptsMeta,
          uploadAttempts.isAcceptableOrUnknown(
              data['upload_attempts']!, _uploadAttemptsMeta));
    }
    if (data.containsKey('next_upload_at')) {
      context.handle(
          _nextUploadAtMeta,
          nextUploadAt.isAcceptableOrUnknown(
              data['next_upload_at']!, _nextUploadAtMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Photo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Photo(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      pointId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}point_id'])!,
      kind: $PhotosTable.$converterkind.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!),
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      remotePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_path']),
      width: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}width']),
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height']),
      bytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bytes']),
      sha256: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      takenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}taken_at'])!,
      uploadState: $PhotosTable.$converteruploadState.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}upload_state'])!),
      uploadAttempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}upload_attempts'])!,
      nextUploadAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_upload_at']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PhotoKind, String, String> $converterkind =
      const EnumNameConverter<PhotoKind>(PhotoKind.values);
  static JsonTypeConverter2<PhotoUploadState, String, String>
      $converteruploadState =
      const EnumNameConverter<PhotoUploadState>(PhotoUploadState.values);
}

class Photo extends DataClass implements Insertable<Photo> {
  final String id;
  final String pointId;
  final PhotoKind kind;

  /// Chemin absolu du fichier compressé dans le répertoire de l'app.
  /// Reste renseigné après l'upload : il sert de cache d'affichage.
  final String? localPath;

  /// Chemin dans le bucket distant. `null` ⇒ binaire pas encore transféré.
  final String? remotePath;
  final int? width;
  final int? height;
  final int? bytes;

  /// Empreinte du fichier compressé : déduplication et détection de corruption.
  final String? sha256;
  final int sortOrder;
  final DateTime takenAt;
  final PhotoUploadState uploadState;
  final int uploadAttempts;
  final DateTime? nextUploadAt;
  final String? lastError;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Photo(
      {required this.id,
      required this.pointId,
      required this.kind,
      this.localPath,
      this.remotePath,
      this.width,
      this.height,
      this.bytes,
      this.sha256,
      required this.sortOrder,
      required this.takenAt,
      required this.uploadState,
      required this.uploadAttempts,
      this.nextUploadAt,
      this.lastError,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['point_id'] = Variable<String>(pointId);
    {
      map['kind'] = Variable<String>($PhotosTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || remotePath != null) {
      map['remote_path'] = Variable<String>(remotePath);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<int>(bytes);
    }
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['taken_at'] = Variable<DateTime>(takenAt);
    {
      map['upload_state'] = Variable<String>(
          $PhotosTable.$converteruploadState.toSql(uploadState));
    }
    map['upload_attempts'] = Variable<int>(uploadAttempts);
    if (!nullToAbsent || nextUploadAt != null) {
      map['next_upload_at'] = Variable<DateTime>(nextUploadAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      id: Value(id),
      pointId: Value(pointId),
      kind: Value(kind),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      remotePath: remotePath == null && nullToAbsent
          ? const Value.absent()
          : Value(remotePath),
      width:
          width == null && nullToAbsent ? const Value.absent() : Value(width),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      bytes:
          bytes == null && nullToAbsent ? const Value.absent() : Value(bytes),
      sha256:
          sha256 == null && nullToAbsent ? const Value.absent() : Value(sha256),
      sortOrder: Value(sortOrder),
      takenAt: Value(takenAt),
      uploadState: Value(uploadState),
      uploadAttempts: Value(uploadAttempts),
      nextUploadAt: nextUploadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextUploadAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Photo.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Photo(
      id: serializer.fromJson<String>(json['id']),
      pointId: serializer.fromJson<String>(json['pointId']),
      kind: $PhotosTable.$converterkind
          .fromJson(serializer.fromJson<String>(json['kind'])),
      localPath: serializer.fromJson<String?>(json['localPath']),
      remotePath: serializer.fromJson<String?>(json['remotePath']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      bytes: serializer.fromJson<int?>(json['bytes']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      takenAt: serializer.fromJson<DateTime>(json['takenAt']),
      uploadState: $PhotosTable.$converteruploadState
          .fromJson(serializer.fromJson<String>(json['uploadState'])),
      uploadAttempts: serializer.fromJson<int>(json['uploadAttempts']),
      nextUploadAt: serializer.fromJson<DateTime?>(json['nextUploadAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pointId': serializer.toJson<String>(pointId),
      'kind':
          serializer.toJson<String>($PhotosTable.$converterkind.toJson(kind)),
      'localPath': serializer.toJson<String?>(localPath),
      'remotePath': serializer.toJson<String?>(remotePath),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'bytes': serializer.toJson<int?>(bytes),
      'sha256': serializer.toJson<String?>(sha256),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'takenAt': serializer.toJson<DateTime>(takenAt),
      'uploadState': serializer.toJson<String>(
          $PhotosTable.$converteruploadState.toJson(uploadState)),
      'uploadAttempts': serializer.toJson<int>(uploadAttempts),
      'nextUploadAt': serializer.toJson<DateTime?>(nextUploadAt),
      'lastError': serializer.toJson<String?>(lastError),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Photo copyWith(
          {String? id,
          String? pointId,
          PhotoKind? kind,
          Value<String?> localPath = const Value.absent(),
          Value<String?> remotePath = const Value.absent(),
          Value<int?> width = const Value.absent(),
          Value<int?> height = const Value.absent(),
          Value<int?> bytes = const Value.absent(),
          Value<String?> sha256 = const Value.absent(),
          int? sortOrder,
          DateTime? takenAt,
          PhotoUploadState? uploadState,
          int? uploadAttempts,
          Value<DateTime?> nextUploadAt = const Value.absent(),
          Value<String?> lastError = const Value.absent(),
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Photo(
        id: id ?? this.id,
        pointId: pointId ?? this.pointId,
        kind: kind ?? this.kind,
        localPath: localPath.present ? localPath.value : this.localPath,
        remotePath: remotePath.present ? remotePath.value : this.remotePath,
        width: width.present ? width.value : this.width,
        height: height.present ? height.value : this.height,
        bytes: bytes.present ? bytes.value : this.bytes,
        sha256: sha256.present ? sha256.value : this.sha256,
        sortOrder: sortOrder ?? this.sortOrder,
        takenAt: takenAt ?? this.takenAt,
        uploadState: uploadState ?? this.uploadState,
        uploadAttempts: uploadAttempts ?? this.uploadAttempts,
        nextUploadAt:
            nextUploadAt.present ? nextUploadAt.value : this.nextUploadAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Photo copyWithCompanion(PhotosCompanion data) {
    return Photo(
      id: data.id.present ? data.id.value : this.id,
      pointId: data.pointId.present ? data.pointId.value : this.pointId,
      kind: data.kind.present ? data.kind.value : this.kind,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remotePath:
          data.remotePath.present ? data.remotePath.value : this.remotePath,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      uploadState:
          data.uploadState.present ? data.uploadState.value : this.uploadState,
      uploadAttempts: data.uploadAttempts.present
          ? data.uploadAttempts.value
          : this.uploadAttempts,
      nextUploadAt: data.nextUploadAt.present
          ? data.nextUploadAt.value
          : this.nextUploadAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Photo(')
          ..write('id: $id, ')
          ..write('pointId: $pointId, ')
          ..write('kind: $kind, ')
          ..write('localPath: $localPath, ')
          ..write('remotePath: $remotePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('bytes: $bytes, ')
          ..write('sha256: $sha256, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('takenAt: $takenAt, ')
          ..write('uploadState: $uploadState, ')
          ..write('uploadAttempts: $uploadAttempts, ')
          ..write('nextUploadAt: $nextUploadAt, ')
          ..write('lastError: $lastError, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      pointId,
      kind,
      localPath,
      remotePath,
      width,
      height,
      bytes,
      sha256,
      sortOrder,
      takenAt,
      uploadState,
      uploadAttempts,
      nextUploadAt,
      lastError,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Photo &&
          other.id == this.id &&
          other.pointId == this.pointId &&
          other.kind == this.kind &&
          other.localPath == this.localPath &&
          other.remotePath == this.remotePath &&
          other.width == this.width &&
          other.height == this.height &&
          other.bytes == this.bytes &&
          other.sha256 == this.sha256 &&
          other.sortOrder == this.sortOrder &&
          other.takenAt == this.takenAt &&
          other.uploadState == this.uploadState &&
          other.uploadAttempts == this.uploadAttempts &&
          other.nextUploadAt == this.nextUploadAt &&
          other.lastError == this.lastError &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PhotosCompanion extends UpdateCompanion<Photo> {
  final Value<String> id;
  final Value<String> pointId;
  final Value<PhotoKind> kind;
  final Value<String?> localPath;
  final Value<String?> remotePath;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> bytes;
  final Value<String?> sha256;
  final Value<int> sortOrder;
  final Value<DateTime> takenAt;
  final Value<PhotoUploadState> uploadState;
  final Value<int> uploadAttempts;
  final Value<DateTime?> nextUploadAt;
  final Value<String?> lastError;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PhotosCompanion({
    this.id = const Value.absent(),
    this.pointId = const Value.absent(),
    this.kind = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.bytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.uploadAttempts = const Value.absent(),
    this.nextUploadAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotosCompanion.insert({
    required String id,
    required String pointId,
    required PhotoKind kind,
    this.localPath = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.bytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime takenAt,
    required PhotoUploadState uploadState,
    this.uploadAttempts = const Value.absent(),
    this.nextUploadAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pointId = Value(pointId),
        kind = Value(kind),
        takenAt = Value(takenAt),
        uploadState = Value(uploadState),
        updatedAt = Value(updatedAt);
  static Insertable<Photo> custom({
    Expression<String>? id,
    Expression<String>? pointId,
    Expression<String>? kind,
    Expression<String>? localPath,
    Expression<String>? remotePath,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? bytes,
    Expression<String>? sha256,
    Expression<int>? sortOrder,
    Expression<DateTime>? takenAt,
    Expression<String>? uploadState,
    Expression<int>? uploadAttempts,
    Expression<DateTime>? nextUploadAt,
    Expression<String>? lastError,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pointId != null) 'point_id': pointId,
      if (kind != null) 'kind': kind,
      if (localPath != null) 'local_path': localPath,
      if (remotePath != null) 'remote_path': remotePath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (bytes != null) 'bytes': bytes,
      if (sha256 != null) 'sha256': sha256,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (takenAt != null) 'taken_at': takenAt,
      if (uploadState != null) 'upload_state': uploadState,
      if (uploadAttempts != null) 'upload_attempts': uploadAttempts,
      if (nextUploadAt != null) 'next_upload_at': nextUploadAt,
      if (lastError != null) 'last_error': lastError,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotosCompanion copyWith(
      {Value<String>? id,
      Value<String>? pointId,
      Value<PhotoKind>? kind,
      Value<String?>? localPath,
      Value<String?>? remotePath,
      Value<int?>? width,
      Value<int?>? height,
      Value<int?>? bytes,
      Value<String?>? sha256,
      Value<int>? sortOrder,
      Value<DateTime>? takenAt,
      Value<PhotoUploadState>? uploadState,
      Value<int>? uploadAttempts,
      Value<DateTime?>? nextUploadAt,
      Value<String?>? lastError,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return PhotosCompanion(
      id: id ?? this.id,
      pointId: pointId ?? this.pointId,
      kind: kind ?? this.kind,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
      sha256: sha256 ?? this.sha256,
      sortOrder: sortOrder ?? this.sortOrder,
      takenAt: takenAt ?? this.takenAt,
      uploadState: uploadState ?? this.uploadState,
      uploadAttempts: uploadAttempts ?? this.uploadAttempts,
      nextUploadAt: nextUploadAt ?? this.nextUploadAt,
      lastError: lastError ?? this.lastError,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pointId.present) {
      map['point_id'] = Variable<String>(pointId.value);
    }
    if (kind.present) {
      map['kind'] =
          Variable<String>($PhotosTable.$converterkind.toSql(kind.value));
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remotePath.present) {
      map['remote_path'] = Variable<String>(remotePath.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(
          $PhotosTable.$converteruploadState.toSql(uploadState.value));
    }
    if (uploadAttempts.present) {
      map['upload_attempts'] = Variable<int>(uploadAttempts.value);
    }
    if (nextUploadAt.present) {
      map['next_upload_at'] = Variable<DateTime>(nextUploadAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('id: $id, ')
          ..write('pointId: $pointId, ')
          ..write('kind: $kind, ')
          ..write('localPath: $localPath, ')
          ..write('remotePath: $remotePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('bytes: $bytes, ')
          ..write('sha256: $sha256, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('takenAt: $takenAt, ')
          ..write('uploadState: $uploadState, ')
          ..write('uploadAttempts: $uploadAttempts, ')
          ..write('nextUploadAt: $nextUploadAt, ')
          ..write('lastError: $lastError, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEntriesTable extends OutboxEntries
    with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<OutboxEntity, String> entityType =
      GeneratedColumn<String>('entity_type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<OutboxEntity>(
              $OutboxEntriesTable.$converterentityType);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<OutboxStatus, String> status =
      GeneratedColumn<String>('status', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('pending'))
          .withConverter<OutboxStatus>($OutboxEntriesTable.$converterstatus);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>('next_attempt_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityType,
        entityId,
        payload,
        createdAt,
        status,
        attempts,
        nextAttemptAt,
        lastError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entityType: $OutboxEntriesTable.$converterentityType.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}entity_type'])!),
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: $OutboxEntriesTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!),
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_attempt_at'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxEntity, String, String> $converterentityType =
      const EnumNameConverter<OutboxEntity>(OutboxEntity.values);
  static JsonTypeConverter2<OutboxStatus, String, String> $converterstatus =
      const EnumNameConverter<OutboxStatus>(OutboxStatus.values);
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final String id;
  final OutboxEntity entityType;
  final String entityId;

  /// Instantané JSON de la ligne, au format attendu par la table distante.
  final String payload;

  /// Ordonne le drain, et **porte l'ordre des dépendances** : un projet est
  /// forcément créé avant ses points, donc inséré avant dans l'outbox. Le
  /// fusionnement d'entrées (coalescing) préserve délibérément cette date.
  final DateTime createdAt;
  final OutboxStatus status;
  final int attempts;
  final DateTime nextAttemptAt;
  final String? lastError;
  const OutboxEntry(
      {required this.id,
      required this.entityType,
      required this.entityId,
      required this.payload,
      required this.createdAt,
      required this.status,
      required this.attempts,
      required this.nextAttemptAt,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['entity_type'] = Variable<String>(
          $OutboxEntriesTable.$converterentityType.toSql(entityType));
    }
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['status'] =
          Variable<String>($OutboxEntriesTable.$converterstatus.toSql(status));
    }
    map['attempts'] = Variable<int>(attempts);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      payload: Value(payload),
      createdAt: Value(createdAt),
      status: Value(status),
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<String>(json['id']),
      entityType: $OutboxEntriesTable.$converterentityType
          .fromJson(serializer.fromJson<String>(json['entityType'])),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: $OutboxEntriesTable.$converterstatus
          .fromJson(serializer.fromJson<String>(json['status'])),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(
          $OutboxEntriesTable.$converterentityType.toJson(entityType)),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer
          .toJson<String>($OutboxEntriesTable.$converterstatus.toJson(status)),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxEntry copyWith(
          {String? id,
          OutboxEntity? entityType,
          String? entityId,
          String? payload,
          DateTime? createdAt,
          OutboxStatus? status,
          int? attempts,
          DateTime? nextAttemptAt,
          Value<String?> lastError = const Value.absent()}) =>
      OutboxEntry(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityType, entityId, payload, createdAt,
      status, attempts, nextAttemptAt, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<String> id;
  final Value<OutboxEntity> entityType;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<OutboxStatus> status;
  final Value<int> attempts;
  final Value<DateTime> nextAttemptAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const OutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    required String id,
    required OutboxEntity entityType,
    required String entityId,
    required String payload,
    required DateTime createdAt,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    required DateTime nextAttemptAt,
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entityType = Value(entityType),
        entityId = Value(entityId),
        payload = Value(payload),
        createdAt = Value(createdAt),
        nextAttemptAt = Value(nextAttemptAt);
  static Insertable<OutboxEntry> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxEntriesCompanion copyWith(
      {Value<String>? id,
      Value<OutboxEntity>? entityType,
      Value<String>? entityId,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<OutboxStatus>? status,
      Value<int>? attempts,
      Value<DateTime>? nextAttemptAt,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return OutboxEntriesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(
          $OutboxEntriesTable.$converterentityType.toSql(entityType.value));
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
          $OutboxEntriesTable.$converterstatus.toSql(status.value));
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
      'entity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [entity, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(Insertable<SyncCursor> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(_entityMeta,
          entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      entity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String entity;
  final DateTime syncedAt;
  const SyncCursor({required this.entity, required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      entity: Value(entity),
      syncedAt: Value(syncedAt),
    );
  }

  factory SyncCursor.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      entity: serializer.fromJson<String>(json['entity']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  SyncCursor copyWith({String? entity, DateTime? syncedAt}) => SyncCursor(
        entity: entity ?? this.entity,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      entity: data.entity.present ? data.entity.value : this.entity,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('entity: $entity, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.entity == this.entity &&
          other.syncedAt == this.syncedAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> entity;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.entity = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String entity,
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  })  : entity = Value(entity),
        syncedAt = Value(syncedAt);
  static Insertable<SyncCursor> custom({
    Expression<String>? entity,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith(
      {Value<String>? entity, Value<DateTime>? syncedAt, Value<int>? rowid}) {
    return SyncCursorsCompanion(
      entity: entity ?? this.entity,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('entity: $entity, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) => AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $ClientsTable clients = $ClientsTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $ProjectMembersTable projectMembers = $ProjectMembersTable(this);
  late final $SettingOptionsTable settingOptions = $SettingOptionsTable(this);
  late final $PointsTable points = $PointsTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final ProjectDao projectDao = ProjectDao(this as AppDatabase);
  late final PointDao pointDao = PointDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        profiles,
        clients,
        projects,
        projectMembers,
        settingOptions,
        points,
        photos,
        outboxEntries,
        syncCursors,
        appSettings
      ];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String fullName,
  required String email,
  required UserRole role,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> fullName,
  Value<String> email,
  Value<UserRole> role,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $ProfilesTable, Profile> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProjectMembersTable, List<ProjectMember>>
      _projectMembersRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.projectMembers,
              aliasName: $_aliasNameGenerator(
                  db.profiles.id, db.projectMembers.userId));

  $$ProjectMembersTableProcessedTableManager get projectMembersRefs {
    final manager = $$ProjectMembersTableTableManager($_db, $_db.projectMembers)
        .filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectMembersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PointsTable, List<Point>> _pointsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.points,
          aliasName: $_aliasNameGenerator(db.profiles.id, db.points.authorId));

  $$PointsTableProcessedTableManager get pointsRefs {
    final manager = $$PointsTableTableManager($_db, $_db.points)
        .filter((f) => f.authorId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pointsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fullName => $composableBuilder(
      column: $table.fullName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<UserRole, UserRole, String> get role =>
      $composableBuilder(
          column: $table.role,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> projectMembersRefs(
      Expression<bool> Function($$ProjectMembersTableFilterComposer f) f) {
    final $$ProjectMembersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.projectMembers,
        getReferencedColumn: (t) => t.userId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectMembersTableFilterComposer(
              $db: $db,
              $table: $db.projectMembers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> pointsRefs(
      Expression<bool> Function($$PointsTableFilterComposer f) f) {
    final $$PointsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.points,
        getReferencedColumn: (t) => t.authorId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PointsTableFilterComposer(
              $db: $db,
              $table: $db.points,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fullName => $composableBuilder(
      column: $table.fullName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumnWithTypeConverter<UserRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> projectMembersRefs<T extends Object>(
      Expression<T> Function($$ProjectMembersTableAnnotationComposer a) f) {
    final $$ProjectMembersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.projectMembers,
        getReferencedColumn: (t) => t.userId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectMembersTableAnnotationComposer(
              $db: $db,
              $table: $db.projectMembers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> pointsRefs<T extends Object>(
      Expression<T> Function($$PointsTableAnnotationComposer a) f) {
    final $$PointsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.points,
        getReferencedColumn: (t) => t.authorId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PointsTableAnnotationComposer(
              $db: $db,
              $table: $db.points,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProfilesTable,
    Profile,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (Profile, $$ProfilesTableReferences),
    Profile,
    PrefetchHooks Function({bool projectMembersRefs, bool pointsRefs})> {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> fullName = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<UserRole> role = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            fullName: fullName,
            email: email,
            role: role,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String fullName,
            required String email,
            required UserRole role,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion.insert(
            id: id,
            fullName: fullName,
            email: email,
            role: role,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ProfilesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {projectMembersRefs = false, pointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (projectMembersRefs) db.projectMembers,
                if (pointsRefs) db.points
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (projectMembersRefs)
                    await $_getPrefetchedData<Profile, $ProfilesTable,
                            ProjectMember>(
                        currentTable: table,
                        referencedTable: $$ProfilesTableReferences
                            ._projectMembersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .projectMembersRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.userId == item.id),
                        typedResults: items),
                  if (pointsRefs)
                    await $_getPrefetchedData<Profile, $ProfilesTable, Point>(
                        currentTable: table,
                        referencedTable:
                            $$ProfilesTableReferences._pointsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0).pointsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.authorId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProfilesTable,
    Profile,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (Profile, $$ProfilesTableReferences),
    Profile,
    PrefetchHooks Function({bool projectMembersRefs, bool pointsRefs})>;
typedef $$ClientsTableCreateCompanionBuilder = ClientsCompanion Function({
  required String id,
  required String name,
  Value<String?> contactName,
  Value<String?> contactEmail,
  Value<String?> contactPhone,
  required String address,
  required String logoPath,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$ClientsTableUpdateCompanionBuilder = ClientsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> contactName,
  Value<String?> contactEmail,
  Value<String?> contactPhone,
  Value<String> address,
  Value<String> logoPath,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$ClientsTableReferences
    extends BaseReferences<_$AppDatabase, $ClientsTable, Client> {
  $$ClientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.projects,
          aliasName: $_aliasNameGenerator(db.clients.id, db.projects.clientId));

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.clientId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ClientsTableFilterComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactName => $composableBuilder(
      column: $table.contactName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactEmail => $composableBuilder(
      column: $table.contactEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactPhone => $composableBuilder(
      column: $table.contactPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get logoPath => $composableBuilder(
      column: $table.logoPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> projectsRefs(
      Expression<bool> Function($$ProjectsTableFilterComposer f) f) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.clientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ClientsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactName => $composableBuilder(
      column: $table.contactName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactEmail => $composableBuilder(
      column: $table.contactEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactPhone => $composableBuilder(
      column: $table.contactPhone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get logoPath => $composableBuilder(
      column: $table.logoPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$ClientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get contactName => $composableBuilder(
      column: $table.contactName, builder: (column) => column);

  GeneratedColumn<String> get contactEmail => $composableBuilder(
      column: $table.contactEmail, builder: (column) => column);

  GeneratedColumn<String> get contactPhone => $composableBuilder(
      column: $table.contactPhone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get logoPath =>
      $composableBuilder(column: $table.logoPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> projectsRefs<T extends Object>(
      Expression<T> Function($$ProjectsTableAnnotationComposer a) f) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.clientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ClientsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ClientsTable,
    Client,
    $$ClientsTableFilterComposer,
    $$ClientsTableOrderingComposer,
    $$ClientsTableAnnotationComposer,
    $$ClientsTableCreateCompanionBuilder,
    $$ClientsTableUpdateCompanionBuilder,
    (Client, $$ClientsTableReferences),
    Client,
    PrefetchHooks Function({bool projectsRefs})> {
  $$ClientsTableTableManager(_$AppDatabase db, $ClientsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> contactName = const Value.absent(),
            Value<String?> contactEmail = const Value.absent(),
            Value<String?> contactPhone = const Value.absent(),
            Value<String> address = const Value.absent(),
            Value<String> logoPath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClientsCompanion(
            id: id,
            name: name,
            contactName: contactName,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            address: address,
            logoPath: logoPath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> contactName = const Value.absent(),
            Value<String?> contactEmail = const Value.absent(),
            Value<String?> contactPhone = const Value.absent(),
            required String address,
            required String logoPath,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClientsCompanion.insert(
            id: id,
            name: name,
            contactName: contactName,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            address: address,
            logoPath: logoPath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ClientsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({projectsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (projectsRefs) db.projects],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (projectsRefs)
                    await $_getPrefetchedData<Client, $ClientsTable, Project>(
                        currentTable: table,
                        referencedTable:
                            $$ClientsTableReferences._projectsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ClientsTableReferences(db, table, p0)
                                .projectsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.clientId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ClientsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ClientsTable,
    Client,
    $$ClientsTableFilterComposer,
    $$ClientsTableOrderingComposer,
    $$ClientsTableAnnotationComposer,
    $$ClientsTableCreateCompanionBuilder,
    $$ClientsTableUpdateCompanionBuilder,
    (Client, $$ClientsTableReferences),
    Client,
    PrefetchHooks Function({bool projectsRefs})>;
typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required String clientId,
  Value<String?> code,
  Value<String?> purchaseOrder,
  Value<String?> building,
  required String name,
  Value<String?> description,
  Value<DateTime?> startedOn,
  Value<DateTime?> endedOn,
  Value<ProjectStatus> status,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String> clientId,
  Value<String?> code,
  Value<String?> purchaseOrder,
  Value<String?> building,
  Value<String> name,
  Value<String?> description,
  Value<DateTime?> startedOn,
  Value<DateTime?> endedOn,
  Value<ProjectStatus> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientsTable _clientIdTable(_$AppDatabase db) => db.clients
      .createAlias($_aliasNameGenerator(db.projects.clientId, db.clients.id));

  $$ClientsTableProcessedTableManager get clientId {
    final $_column = $_itemColumn<String>('client_id')!;

    final manager = $$ClientsTableTableManager($_db, $_db.clients)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$ProjectMembersTable, List<ProjectMember>>
      _projectMembersRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.projectMembers,
              aliasName: $_aliasNameGenerator(
                  db.projects.id, db.projectMembers.projectId));

  $$ProjectMembersTableProcessedTableManager get projectMembersRefs {
    final manager = $$ProjectMembersTableTableManager($_db, $_db.projectMembers)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectMembersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PointsTable, List<Point>> _pointsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.points,
          aliasName: $_aliasNameGenerator(db.projects.id, db.points.projectId));

  $$PointsTableProcessedTableManager get pointsRefs {
    final manager = $$PointsTableTableManager($_db, $_db.points)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pointsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get purchaseOrder => $composableBuilder(
      column: $table.purchaseOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get building => $composableBuilder(
      column: $table.building, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedOn => $composableBuilder(
      column: $table.startedOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedOn => $composableBuilder(
      column: $table.endedOn, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ProjectStatus, ProjectStatus, String>
      get status => $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$ClientsTableFilterComposer get clientId {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clientId,
        referencedTable: $db.clients,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientsTableFilterComposer(
              $db: $db,
              $table: $db.clients,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> projectMembersRefs(
      Expression<bool> Function($$ProjectMembersTableFilterComposer f) f) {
    final $$ProjectMembersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.projectMembers,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectMembersTableFilterComposer(
              $db: $db,
              $table: $db.projectMembers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> pointsRefs(
      Expression<bool> Function($$PointsTableFilterComposer f) f) {
    final $$PointsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.points,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PointsTableFilterComposer(
              $db: $db,
              $table: $db.points,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get purchaseOrder => $composableBuilder(
      column: $table.purchaseOrder,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get building => $composableBuilder(
      column: $table.building, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedOn => $composableBuilder(
      column: $table.startedOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedOn => $composableBuilder(
      column: $table.endedOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$ClientsTableOrderingComposer get clientId {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clientId,
        referencedTable: $db.clients,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientsTableOrderingComposer(
              $db: $db,
              $table: $db.clients,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get purchaseOrder => $composableBuilder(
      column: $table.purchaseOrder, builder: (column) => column);

  GeneratedColumn<String> get building =>
      $composableBuilder(column: $table.building, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get startedOn =>
      $composableBuilder(column: $table.startedOn, builder: (column) => column);

  GeneratedColumn<DateTime> get endedOn =>
      $composableBuilder(column: $table.endedOn, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProjectStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ClientsTableAnnotationComposer get clientId {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clientId,
        referencedTable: $db.clients,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientsTableAnnotationComposer(
              $db: $db,
              $table: $db.clients,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> projectMembersRefs<T extends Object>(
      Expression<T> Function($$ProjectMembersTableAnnotationComposer a) f) {
    final $$ProjectMembersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.projectMembers,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectMembersTableAnnotationComposer(
              $db: $db,
              $table: $db.projectMembers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> pointsRefs<T extends Object>(
      Expression<T> Function($$PointsTableAnnotationComposer a) f) {
    final $$PointsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.points,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PointsTableAnnotationComposer(
              $db: $db,
              $table: $db.points,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, $$ProjectsTableReferences),
    Project,
    PrefetchHooks Function(
        {bool clientId, bool projectMembersRefs, bool pointsRefs})> {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> clientId = const Value.absent(),
            Value<String?> code = const Value.absent(),
            Value<String?> purchaseOrder = const Value.absent(),
            Value<String?> building = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime?> startedOn = const Value.absent(),
            Value<DateTime?> endedOn = const Value.absent(),
            Value<ProjectStatus> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion(
            id: id,
            clientId: clientId,
            code: code,
            purchaseOrder: purchaseOrder,
            building: building,
            name: name,
            description: description,
            startedOn: startedOn,
            endedOn: endedOn,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String clientId,
            Value<String?> code = const Value.absent(),
            Value<String?> purchaseOrder = const Value.absent(),
            Value<String?> building = const Value.absent(),
            required String name,
            Value<String?> description = const Value.absent(),
            Value<DateTime?> startedOn = const Value.absent(),
            Value<DateTime?> endedOn = const Value.absent(),
            Value<ProjectStatus> status = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion.insert(
            id: id,
            clientId: clientId,
            code: code,
            purchaseOrder: purchaseOrder,
            building: building,
            name: name,
            description: description,
            startedOn: startedOn,
            endedOn: endedOn,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ProjectsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {clientId = false,
              projectMembersRefs = false,
              pointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (projectMembersRefs) db.projectMembers,
                if (pointsRefs) db.points
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (clientId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.clientId,
                    referencedTable:
                        $$ProjectsTableReferences._clientIdTable(db),
                    referencedColumn:
                        $$ProjectsTableReferences._clientIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (projectMembersRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable,
                            ProjectMember>(
                        currentTable: table,
                        referencedTable: $$ProjectsTableReferences
                            ._projectMembersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0)
                                .projectMembersRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (pointsRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable, Point>(
                        currentTable: table,
                        referencedTable:
                            $$ProjectsTableReferences._pointsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0).pointsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProjectsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, $$ProjectsTableReferences),
    Project,
    PrefetchHooks Function(
        {bool clientId, bool projectMembersRefs, bool pointsRefs})>;
typedef $$ProjectMembersTableCreateCompanionBuilder = ProjectMembersCompanion
    Function({
  required String projectId,
  required String userId,
  required DateTime addedAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$ProjectMembersTableUpdateCompanionBuilder = ProjectMembersCompanion
    Function({
  Value<String> projectId,
  Value<String> userId,
  Value<DateTime> addedAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$ProjectMembersTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectMembersTable, ProjectMember> {
  $$ProjectMembersTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
          $_aliasNameGenerator(db.projectMembers.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProfilesTable _userIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
          $_aliasNameGenerator(db.projectMembers.userId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ProjectMembersTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectMembersTable> {
  $$ProjectMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableFilterComposer get userId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProjectMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectMembersTable> {
  $$ProjectMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableOrderingComposer get userId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProjectMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectMembersTable> {
  $$ProjectMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableAnnotationComposer get userId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProjectMembersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectMembersTable,
    ProjectMember,
    $$ProjectMembersTableFilterComposer,
    $$ProjectMembersTableOrderingComposer,
    $$ProjectMembersTableAnnotationComposer,
    $$ProjectMembersTableCreateCompanionBuilder,
    $$ProjectMembersTableUpdateCompanionBuilder,
    (ProjectMember, $$ProjectMembersTableReferences),
    ProjectMember,
    PrefetchHooks Function({bool projectId, bool userId})> {
  $$ProjectMembersTableTableManager(
      _$AppDatabase db, $ProjectMembersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> projectId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectMembersCompanion(
            projectId: projectId,
            userId: userId,
            addedAt: addedAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String projectId,
            required String userId,
            required DateTime addedAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectMembersCompanion.insert(
            projectId: projectId,
            userId: userId,
            addedAt: addedAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ProjectMembersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false, userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$ProjectMembersTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$ProjectMembersTableReferences._projectIdTable(db).id,
                  ) as T;
                }
                if (userId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.userId,
                    referencedTable:
                        $$ProjectMembersTableReferences._userIdTable(db),
                    referencedColumn:
                        $$ProjectMembersTableReferences._userIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ProjectMembersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectMembersTable,
    ProjectMember,
    $$ProjectMembersTableFilterComposer,
    $$ProjectMembersTableOrderingComposer,
    $$ProjectMembersTableAnnotationComposer,
    $$ProjectMembersTableCreateCompanionBuilder,
    $$ProjectMembersTableUpdateCompanionBuilder,
    (ProjectMember, $$ProjectMembersTableReferences),
    ProjectMember,
    PrefetchHooks Function({bool projectId, bool userId})>;
typedef $$SettingOptionsTableCreateCompanionBuilder = SettingOptionsCompanion
    Function({
  required String id,
  required SettingKind kind,
  required String label,
  Value<int> sortOrder,
  Value<String?> parentId,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$SettingOptionsTableUpdateCompanionBuilder = SettingOptionsCompanion
    Function({
  Value<String> id,
  Value<SettingKind> kind,
  Value<String> label,
  Value<int> sortOrder,
  Value<String?> parentId,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$SettingOptionsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingOptionsTable> {
  $$SettingOptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SettingKind, SettingKind, String> get kind =>
      $composableBuilder(
          column: $table.kind,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$SettingOptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingOptionsTable> {
  $$SettingOptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$SettingOptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingOptionsTable> {
  $$SettingOptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SettingKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SettingOptionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingOptionsTable,
    SettingOption,
    $$SettingOptionsTableFilterComposer,
    $$SettingOptionsTableOrderingComposer,
    $$SettingOptionsTableAnnotationComposer,
    $$SettingOptionsTableCreateCompanionBuilder,
    $$SettingOptionsTableUpdateCompanionBuilder,
    (
      SettingOption,
      BaseReferences<_$AppDatabase, $SettingOptionsTable, SettingOption>
    ),
    SettingOption,
    PrefetchHooks Function()> {
  $$SettingOptionsTableTableManager(
      _$AppDatabase db, $SettingOptionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingOptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingOptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingOptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<SettingKind> kind = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingOptionsCompanion(
            id: id,
            kind: kind,
            label: label,
            sortOrder: sortOrder,
            parentId: parentId,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required SettingKind kind,
            required String label,
            Value<int> sortOrder = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingOptionsCompanion.insert(
            id: id,
            kind: kind,
            label: label,
            sortOrder: sortOrder,
            parentId: parentId,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingOptionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingOptionsTable,
    SettingOption,
    $$SettingOptionsTableFilterComposer,
    $$SettingOptionsTableOrderingComposer,
    $$SettingOptionsTableAnnotationComposer,
    $$SettingOptionsTableCreateCompanionBuilder,
    $$SettingOptionsTableUpdateCompanionBuilder,
    (
      SettingOption,
      BaseReferences<_$AppDatabase, $SettingOptionsTable, SettingOption>
    ),
    SettingOption,
    PrefetchHooks Function()>;
typedef $$PointsTableCreateCompanionBuilder = PointsCompanion Function({
  required String id,
  required String projectId,
  Value<int?> refNumber,
  Value<String?> projectCode,
  Value<String?> projectName,
  Value<String?> purchaseOrder,
  Value<String?> building,
  Value<int?> floorLevel,
  Value<String?> room,
  Value<String?> description,
  Value<String?> configurationId,
  Value<String?> configurationDetailId,
  Value<String?> eiLevelId,
  Value<String?> supplierId,
  Value<String?> productTypeId,
  Value<String?> product1Id,
  Value<String?> product2Id,
  Value<String?> product3Id,
  Value<String?> product4Id,
  Value<String?> product5Id,
  required String authorId,
  required DateTime capturedAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$PointsTableUpdateCompanionBuilder = PointsCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<int?> refNumber,
  Value<String?> projectCode,
  Value<String?> projectName,
  Value<String?> purchaseOrder,
  Value<String?> building,
  Value<int?> floorLevel,
  Value<String?> room,
  Value<String?> description,
  Value<String?> configurationId,
  Value<String?> configurationDetailId,
  Value<String?> eiLevelId,
  Value<String?> supplierId,
  Value<String?> productTypeId,
  Value<String?> product1Id,
  Value<String?> product2Id,
  Value<String?> product3Id,
  Value<String?> product4Id,
  Value<String?> product5Id,
  Value<String> authorId,
  Value<DateTime> capturedAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$PointsTableReferences
    extends BaseReferences<_$AppDatabase, $PointsTable, Point> {
  $$PointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.points.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _configurationIdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias($_aliasNameGenerator(
          db.points.configurationId, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get configurationId {
    final $_column = $_itemColumn<String>('configuration_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_configurationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _configurationDetailIdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias($_aliasNameGenerator(
          db.points.configurationDetailId, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get configurationDetailId {
    final $_column = $_itemColumn<String>('configuration_detail_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item =
        $_typedResult.readTableOrNull(_configurationDetailIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _eiLevelIdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias(
          $_aliasNameGenerator(db.points.eiLevelId, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get eiLevelId {
    final $_column = $_itemColumn<String>('ei_level_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eiLevelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _supplierIdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias(
          $_aliasNameGenerator(db.points.supplierId, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get supplierId {
    final $_column = $_itemColumn<String>('supplier_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplierIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _productTypeIdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias(
          $_aliasNameGenerator(db.points.productTypeId, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get productTypeId {
    final $_column = $_itemColumn<String>('product_type_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productTypeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _product1IdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias(
          $_aliasNameGenerator(db.points.product1Id, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get product1Id {
    final $_column = $_itemColumn<String>('product1_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_product1IdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _product2IdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias(
          $_aliasNameGenerator(db.points.product2Id, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get product2Id {
    final $_column = $_itemColumn<String>('product2_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_product2IdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _product3IdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias(
          $_aliasNameGenerator(db.points.product3Id, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get product3Id {
    final $_column = $_itemColumn<String>('product3_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_product3IdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _product4IdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias(
          $_aliasNameGenerator(db.points.product4Id, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get product4Id {
    final $_column = $_itemColumn<String>('product4_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_product4IdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SettingOptionsTable _product5IdTable(_$AppDatabase db) =>
      db.settingOptions.createAlias(
          $_aliasNameGenerator(db.points.product5Id, db.settingOptions.id));

  $$SettingOptionsTableProcessedTableManager? get product5Id {
    final $_column = $_itemColumn<String>('product5_id');
    if ($_column == null) return null;
    final manager = $$SettingOptionsTableTableManager($_db, $_db.settingOptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_product5IdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProfilesTable _authorIdTable(_$AppDatabase db) => db.profiles
      .createAlias($_aliasNameGenerator(db.points.authorId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get authorId {
    final $_column = $_itemColumn<String>('author_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_authorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$PhotosTable, List<Photo>> _photosRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.photos,
          aliasName: $_aliasNameGenerator(db.points.id, db.photos.pointId));

  $$PhotosTableProcessedTableManager get photosRefs {
    final manager = $$PhotosTableTableManager($_db, $_db.photos)
        .filter((f) => f.pointId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_photosRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PointsTableFilterComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get refNumber => $composableBuilder(
      column: $table.refNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectCode => $composableBuilder(
      column: $table.projectCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectName => $composableBuilder(
      column: $table.projectName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get purchaseOrder => $composableBuilder(
      column: $table.purchaseOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get building => $composableBuilder(
      column: $table.building, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get floorLevel => $composableBuilder(
      column: $table.floorLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get room => $composableBuilder(
      column: $table.room, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get configurationId {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.configurationId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get configurationDetailId {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.configurationDetailId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get eiLevelId {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.eiLevelId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get supplierId {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get productTypeId {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productTypeId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get product1Id {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product1Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get product2Id {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product2Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get product3Id {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product3Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get product4Id {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product4Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableFilterComposer get product5Id {
    final $$SettingOptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product5Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableFilterComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableFilterComposer get authorId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.authorId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> photosRefs(
      Expression<bool> Function($$PhotosTableFilterComposer f) f) {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.photos,
        getReferencedColumn: (t) => t.pointId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PhotosTableFilterComposer(
              $db: $db,
              $table: $db.photos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PointsTableOrderingComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get refNumber => $composableBuilder(
      column: $table.refNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectCode => $composableBuilder(
      column: $table.projectCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectName => $composableBuilder(
      column: $table.projectName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get purchaseOrder => $composableBuilder(
      column: $table.purchaseOrder,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get building => $composableBuilder(
      column: $table.building, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get floorLevel => $composableBuilder(
      column: $table.floorLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get room => $composableBuilder(
      column: $table.room, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get configurationId {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.configurationId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get configurationDetailId {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.configurationDetailId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get eiLevelId {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.eiLevelId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get supplierId {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get productTypeId {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productTypeId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get product1Id {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product1Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get product2Id {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product2Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get product3Id {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product3Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get product4Id {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product4Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableOrderingComposer get product5Id {
    final $$SettingOptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product5Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableOrderingComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableOrderingComposer get authorId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.authorId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get refNumber =>
      $composableBuilder(column: $table.refNumber, builder: (column) => column);

  GeneratedColumn<String> get projectCode => $composableBuilder(
      column: $table.projectCode, builder: (column) => column);

  GeneratedColumn<String> get projectName => $composableBuilder(
      column: $table.projectName, builder: (column) => column);

  GeneratedColumn<String> get purchaseOrder => $composableBuilder(
      column: $table.purchaseOrder, builder: (column) => column);

  GeneratedColumn<String> get building =>
      $composableBuilder(column: $table.building, builder: (column) => column);

  GeneratedColumn<int> get floorLevel => $composableBuilder(
      column: $table.floorLevel, builder: (column) => column);

  GeneratedColumn<String> get room =>
      $composableBuilder(column: $table.room, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get configurationId {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.configurationId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get configurationDetailId {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.configurationDetailId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get eiLevelId {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.eiLevelId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get supplierId {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get productTypeId {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productTypeId,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get product1Id {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product1Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get product2Id {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product2Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get product3Id {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product3Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get product4Id {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product4Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SettingOptionsTableAnnotationComposer get product5Id {
    final $$SettingOptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.product5Id,
        referencedTable: $db.settingOptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SettingOptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.settingOptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableAnnotationComposer get authorId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.authorId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> photosRefs<T extends Object>(
      Expression<T> Function($$PhotosTableAnnotationComposer a) f) {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.photos,
        getReferencedColumn: (t) => t.pointId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PhotosTableAnnotationComposer(
              $db: $db,
              $table: $db.photos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PointsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PointsTable,
    Point,
    $$PointsTableFilterComposer,
    $$PointsTableOrderingComposer,
    $$PointsTableAnnotationComposer,
    $$PointsTableCreateCompanionBuilder,
    $$PointsTableUpdateCompanionBuilder,
    (Point, $$PointsTableReferences),
    Point,
    PrefetchHooks Function(
        {bool projectId,
        bool configurationId,
        bool configurationDetailId,
        bool eiLevelId,
        bool supplierId,
        bool productTypeId,
        bool product1Id,
        bool product2Id,
        bool product3Id,
        bool product4Id,
        bool product5Id,
        bool authorId,
        bool photosRefs})> {
  $$PointsTableTableManager(_$AppDatabase db, $PointsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<int?> refNumber = const Value.absent(),
            Value<String?> projectCode = const Value.absent(),
            Value<String?> projectName = const Value.absent(),
            Value<String?> purchaseOrder = const Value.absent(),
            Value<String?> building = const Value.absent(),
            Value<int?> floorLevel = const Value.absent(),
            Value<String?> room = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> configurationId = const Value.absent(),
            Value<String?> configurationDetailId = const Value.absent(),
            Value<String?> eiLevelId = const Value.absent(),
            Value<String?> supplierId = const Value.absent(),
            Value<String?> productTypeId = const Value.absent(),
            Value<String?> product1Id = const Value.absent(),
            Value<String?> product2Id = const Value.absent(),
            Value<String?> product3Id = const Value.absent(),
            Value<String?> product4Id = const Value.absent(),
            Value<String?> product5Id = const Value.absent(),
            Value<String> authorId = const Value.absent(),
            Value<DateTime> capturedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PointsCompanion(
            id: id,
            projectId: projectId,
            refNumber: refNumber,
            projectCode: projectCode,
            projectName: projectName,
            purchaseOrder: purchaseOrder,
            building: building,
            floorLevel: floorLevel,
            room: room,
            description: description,
            configurationId: configurationId,
            configurationDetailId: configurationDetailId,
            eiLevelId: eiLevelId,
            supplierId: supplierId,
            productTypeId: productTypeId,
            product1Id: product1Id,
            product2Id: product2Id,
            product3Id: product3Id,
            product4Id: product4Id,
            product5Id: product5Id,
            authorId: authorId,
            capturedAt: capturedAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            Value<int?> refNumber = const Value.absent(),
            Value<String?> projectCode = const Value.absent(),
            Value<String?> projectName = const Value.absent(),
            Value<String?> purchaseOrder = const Value.absent(),
            Value<String?> building = const Value.absent(),
            Value<int?> floorLevel = const Value.absent(),
            Value<String?> room = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> configurationId = const Value.absent(),
            Value<String?> configurationDetailId = const Value.absent(),
            Value<String?> eiLevelId = const Value.absent(),
            Value<String?> supplierId = const Value.absent(),
            Value<String?> productTypeId = const Value.absent(),
            Value<String?> product1Id = const Value.absent(),
            Value<String?> product2Id = const Value.absent(),
            Value<String?> product3Id = const Value.absent(),
            Value<String?> product4Id = const Value.absent(),
            Value<String?> product5Id = const Value.absent(),
            required String authorId,
            required DateTime capturedAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PointsCompanion.insert(
            id: id,
            projectId: projectId,
            refNumber: refNumber,
            projectCode: projectCode,
            projectName: projectName,
            purchaseOrder: purchaseOrder,
            building: building,
            floorLevel: floorLevel,
            room: room,
            description: description,
            configurationId: configurationId,
            configurationDetailId: configurationDetailId,
            eiLevelId: eiLevelId,
            supplierId: supplierId,
            productTypeId: productTypeId,
            product1Id: product1Id,
            product2Id: product2Id,
            product3Id: product3Id,
            product4Id: product4Id,
            product5Id: product5Id,
            authorId: authorId,
            capturedAt: capturedAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PointsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {projectId = false,
              configurationId = false,
              configurationDetailId = false,
              eiLevelId = false,
              supplierId = false,
              productTypeId = false,
              product1Id = false,
              product2Id = false,
              product3Id = false,
              product4Id = false,
              product5Id = false,
              authorId = false,
              photosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (photosRefs) db.photos],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$PointsTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._projectIdTable(db).id,
                  ) as T;
                }
                if (configurationId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.configurationId,
                    referencedTable:
                        $$PointsTableReferences._configurationIdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._configurationIdTable(db).id,
                  ) as T;
                }
                if (configurationDetailId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.configurationDetailId,
                    referencedTable:
                        $$PointsTableReferences._configurationDetailIdTable(db),
                    referencedColumn: $$PointsTableReferences
                        ._configurationDetailIdTable(db)
                        .id,
                  ) as T;
                }
                if (eiLevelId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.eiLevelId,
                    referencedTable:
                        $$PointsTableReferences._eiLevelIdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._eiLevelIdTable(db).id,
                  ) as T;
                }
                if (supplierId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.supplierId,
                    referencedTable:
                        $$PointsTableReferences._supplierIdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._supplierIdTable(db).id,
                  ) as T;
                }
                if (productTypeId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productTypeId,
                    referencedTable:
                        $$PointsTableReferences._productTypeIdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._productTypeIdTable(db).id,
                  ) as T;
                }
                if (product1Id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.product1Id,
                    referencedTable:
                        $$PointsTableReferences._product1IdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._product1IdTable(db).id,
                  ) as T;
                }
                if (product2Id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.product2Id,
                    referencedTable:
                        $$PointsTableReferences._product2IdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._product2IdTable(db).id,
                  ) as T;
                }
                if (product3Id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.product3Id,
                    referencedTable:
                        $$PointsTableReferences._product3IdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._product3IdTable(db).id,
                  ) as T;
                }
                if (product4Id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.product4Id,
                    referencedTable:
                        $$PointsTableReferences._product4IdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._product4IdTable(db).id,
                  ) as T;
                }
                if (product5Id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.product5Id,
                    referencedTable:
                        $$PointsTableReferences._product5IdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._product5IdTable(db).id,
                  ) as T;
                }
                if (authorId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.authorId,
                    referencedTable: $$PointsTableReferences._authorIdTable(db),
                    referencedColumn:
                        $$PointsTableReferences._authorIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (photosRefs)
                    await $_getPrefetchedData<Point, $PointsTable, Photo>(
                        currentTable: table,
                        referencedTable:
                            $$PointsTableReferences._photosRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PointsTableReferences(db, table, p0).photosRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pointId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PointsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PointsTable,
    Point,
    $$PointsTableFilterComposer,
    $$PointsTableOrderingComposer,
    $$PointsTableAnnotationComposer,
    $$PointsTableCreateCompanionBuilder,
    $$PointsTableUpdateCompanionBuilder,
    (Point, $$PointsTableReferences),
    Point,
    PrefetchHooks Function(
        {bool projectId,
        bool configurationId,
        bool configurationDetailId,
        bool eiLevelId,
        bool supplierId,
        bool productTypeId,
        bool product1Id,
        bool product2Id,
        bool product3Id,
        bool product4Id,
        bool product5Id,
        bool authorId,
        bool photosRefs})>;
typedef $$PhotosTableCreateCompanionBuilder = PhotosCompanion Function({
  required String id,
  required String pointId,
  required PhotoKind kind,
  Value<String?> localPath,
  Value<String?> remotePath,
  Value<int?> width,
  Value<int?> height,
  Value<int?> bytes,
  Value<String?> sha256,
  Value<int> sortOrder,
  required DateTime takenAt,
  required PhotoUploadState uploadState,
  Value<int> uploadAttempts,
  Value<DateTime?> nextUploadAt,
  Value<String?> lastError,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$PhotosTableUpdateCompanionBuilder = PhotosCompanion Function({
  Value<String> id,
  Value<String> pointId,
  Value<PhotoKind> kind,
  Value<String?> localPath,
  Value<String?> remotePath,
  Value<int?> width,
  Value<int?> height,
  Value<int?> bytes,
  Value<String?> sha256,
  Value<int> sortOrder,
  Value<DateTime> takenAt,
  Value<PhotoUploadState> uploadState,
  Value<int> uploadAttempts,
  Value<DateTime?> nextUploadAt,
  Value<String?> lastError,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$PhotosTableReferences
    extends BaseReferences<_$AppDatabase, $PhotosTable, Photo> {
  $$PhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PointsTable _pointIdTable(_$AppDatabase db) => db.points
      .createAlias($_aliasNameGenerator(db.photos.pointId, db.points.id));

  $$PointsTableProcessedTableManager get pointId {
    final $_column = $_itemColumn<String>('point_id')!;

    final manager = $$PointsTableTableManager($_db, $_db.points)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pointIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<PhotoKind, PhotoKind, String> get kind =>
      $composableBuilder(
          column: $table.kind,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
      column: $table.takenAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<PhotoUploadState, PhotoUploadState, String>
      get uploadState => $composableBuilder(
          column: $table.uploadState,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get uploadAttempts => $composableBuilder(
      column: $table.uploadAttempts,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextUploadAt => $composableBuilder(
      column: $table.nextUploadAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$PointsTableFilterComposer get pointId {
    final $$PointsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pointId,
        referencedTable: $db.points,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PointsTableFilterComposer(
              $db: $db,
              $table: $db.points,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
      column: $table.takenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uploadState => $composableBuilder(
      column: $table.uploadState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get uploadAttempts => $composableBuilder(
      column: $table.uploadAttempts,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextUploadAt => $composableBuilder(
      column: $table.nextUploadAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$PointsTableOrderingComposer get pointId {
    final $$PointsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pointId,
        referencedTable: $db.points,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PointsTableOrderingComposer(
              $db: $db,
              $table: $db.points,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PhotoKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PhotoUploadState, String> get uploadState =>
      $composableBuilder(
          column: $table.uploadState, builder: (column) => column);

  GeneratedColumn<int> get uploadAttempts => $composableBuilder(
      column: $table.uploadAttempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextUploadAt => $composableBuilder(
      column: $table.nextUploadAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PointsTableAnnotationComposer get pointId {
    final $$PointsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pointId,
        referencedTable: $db.points,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PointsTableAnnotationComposer(
              $db: $db,
              $table: $db.points,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PhotosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PhotosTable,
    Photo,
    $$PhotosTableFilterComposer,
    $$PhotosTableOrderingComposer,
    $$PhotosTableAnnotationComposer,
    $$PhotosTableCreateCompanionBuilder,
    $$PhotosTableUpdateCompanionBuilder,
    (Photo, $$PhotosTableReferences),
    Photo,
    PrefetchHooks Function({bool pointId})> {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> pointId = const Value.absent(),
            Value<PhotoKind> kind = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> remotePath = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<int?> bytes = const Value.absent(),
            Value<String?> sha256 = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> takenAt = const Value.absent(),
            Value<PhotoUploadState> uploadState = const Value.absent(),
            Value<int> uploadAttempts = const Value.absent(),
            Value<DateTime?> nextUploadAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PhotosCompanion(
            id: id,
            pointId: pointId,
            kind: kind,
            localPath: localPath,
            remotePath: remotePath,
            width: width,
            height: height,
            bytes: bytes,
            sha256: sha256,
            sortOrder: sortOrder,
            takenAt: takenAt,
            uploadState: uploadState,
            uploadAttempts: uploadAttempts,
            nextUploadAt: nextUploadAt,
            lastError: lastError,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String pointId,
            required PhotoKind kind,
            Value<String?> localPath = const Value.absent(),
            Value<String?> remotePath = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<int?> bytes = const Value.absent(),
            Value<String?> sha256 = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            required DateTime takenAt,
            required PhotoUploadState uploadState,
            Value<int> uploadAttempts = const Value.absent(),
            Value<DateTime?> nextUploadAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PhotosCompanion.insert(
            id: id,
            pointId: pointId,
            kind: kind,
            localPath: localPath,
            remotePath: remotePath,
            width: width,
            height: height,
            bytes: bytes,
            sha256: sha256,
            sortOrder: sortOrder,
            takenAt: takenAt,
            uploadState: uploadState,
            uploadAttempts: uploadAttempts,
            nextUploadAt: nextUploadAt,
            lastError: lastError,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PhotosTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({pointId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pointId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pointId,
                    referencedTable: $$PhotosTableReferences._pointIdTable(db),
                    referencedColumn:
                        $$PhotosTableReferences._pointIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PhotosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PhotosTable,
    Photo,
    $$PhotosTableFilterComposer,
    $$PhotosTableOrderingComposer,
    $$PhotosTableAnnotationComposer,
    $$PhotosTableCreateCompanionBuilder,
    $$PhotosTableUpdateCompanionBuilder,
    (Photo, $$PhotosTableReferences),
    Photo,
    PrefetchHooks Function({bool pointId})>;
typedef $$OutboxEntriesTableCreateCompanionBuilder = OutboxEntriesCompanion
    Function({
  required String id,
  required OutboxEntity entityType,
  required String entityId,
  required String payload,
  required DateTime createdAt,
  Value<OutboxStatus> status,
  Value<int> attempts,
  required DateTime nextAttemptAt,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$OutboxEntriesTableUpdateCompanionBuilder = OutboxEntriesCompanion
    Function({
  Value<String> id,
  Value<OutboxEntity> entityType,
  Value<String> entityId,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<OutboxStatus> status,
  Value<int> attempts,
  Value<DateTime> nextAttemptAt,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$OutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<OutboxEntity, OutboxEntity, String>
      get entityType => $composableBuilder(
          column: $table.entityType,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<OutboxStatus, OutboxStatus, String>
      get status => $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$OutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$OutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxEntity, String> get entityType =>
      $composableBuilder(
          column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxEntriesTable,
    OutboxEntry,
    $$OutboxEntriesTableFilterComposer,
    $$OutboxEntriesTableOrderingComposer,
    $$OutboxEntriesTableAnnotationComposer,
    $$OutboxEntriesTableCreateCompanionBuilder,
    $$OutboxEntriesTableUpdateCompanionBuilder,
    (
      OutboxEntry,
      BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>
    ),
    OutboxEntry,
    PrefetchHooks Function()> {
  $$OutboxEntriesTableTableManager(_$AppDatabase db, $OutboxEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<OutboxEntity> entityType = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<OutboxStatus> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<DateTime> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxEntriesCompanion(
            id: id,
            entityType: entityType,
            entityId: entityId,
            payload: payload,
            createdAt: createdAt,
            status: status,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required OutboxEntity entityType,
            required String entityId,
            required String payload,
            required DateTime createdAt,
            Value<OutboxStatus> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            required DateTime nextAttemptAt,
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxEntriesCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            payload: payload,
            createdAt: createdAt,
            status: status,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxEntriesTable,
    OutboxEntry,
    $$OutboxEntriesTableFilterComposer,
    $$OutboxEntriesTableOrderingComposer,
    $$OutboxEntriesTableAnnotationComposer,
    $$OutboxEntriesTableCreateCompanionBuilder,
    $$OutboxEntriesTableUpdateCompanionBuilder,
    (
      OutboxEntry,
      BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>
    ),
    OutboxEntry,
    PrefetchHooks Function()>;
typedef $$SyncCursorsTableCreateCompanionBuilder = SyncCursorsCompanion
    Function({
  required String entity,
  required DateTime syncedAt,
  Value<int> rowid,
});
typedef $$SyncCursorsTableUpdateCompanionBuilder = SyncCursorsCompanion
    Function({
  Value<String> entity,
  Value<DateTime> syncedAt,
  Value<int> rowid,
});

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
      column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
      column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SyncCursorsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncCursorsTable,
    SyncCursor,
    $$SyncCursorsTableFilterComposer,
    $$SyncCursorsTableOrderingComposer,
    $$SyncCursorsTableAnnotationComposer,
    $$SyncCursorsTableCreateCompanionBuilder,
    $$SyncCursorsTableUpdateCompanionBuilder,
    (SyncCursor, BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>),
    SyncCursor,
    PrefetchHooks Function()> {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> entity = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncCursorsCompanion(
            entity: entity,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String entity,
            required DateTime syncedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncCursorsCompanion.insert(
            entity: entity,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncCursorsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncCursorsTable,
    SyncCursor,
    $$SyncCursorsTableFilterComposer,
    $$SyncCursorsTableOrderingComposer,
    $$SyncCursorsTableAnnotationComposer,
    $$SyncCursorsTableCreateCompanionBuilder,
    $$SyncCursorsTableUpdateCompanionBuilder,
    (SyncCursor, BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>),
    SyncCursor,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db, _db.clients);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$ProjectMembersTableTableManager get projectMembers =>
      $$ProjectMembersTableTableManager(_db, _db.projectMembers);
  $$SettingOptionsTableTableManager get settingOptions =>
      $$SettingOptionsTableTableManager(_db, _db.settingOptions);
  $$PointsTableTableManager get points =>
      $$PointsTableTableManager(_db, _db.points);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
