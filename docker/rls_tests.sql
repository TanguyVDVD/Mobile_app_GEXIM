-- =============================================================================
-- Banc d'essai des policies RLS
-- =============================================================================
--
--   docker compose -f docker/docker-compose.yml up -d
--   docker compose -f docker/docker-compose.yml exec -T db \
--     psql -v ON_ERROR_STOP=1 -U postgres -d firestop < docker/rls_tests.sql
--
-- Pourquoi ce fichier existe : une policy RLS trop permissive ne produit
-- **aucune erreur**. Elle laisse simplement passer une écriture qui aurait dû
-- être refusée. Aucun test applicatif ne la verra, aucun log ne la signalera —
-- on l'apprend le jour où un opérateur modifie un chantier déjà remis au
-- client. Les refus doivent donc être prouvés, pas supposés.
--
-- Chaque test s'exécute dans sa propre transaction annulée : le jeu de données
-- reste identique d'un cas à l'autre.
-- =============================================================================

\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- Jeu de données
-- -----------------------------------------------------------------------------

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-4111-8111-111111111111', 'admin@gexim.be',
   '{"full_name": "Admin"}'),
  ('22222222-2222-4222-8222-222222222222', 'operateur@gexim.be',
   '{"full_name": "Operateur"}'),
  ('33333333-3333-4333-8333-333333333333', 'externe@gexim.be',
   '{"full_name": "Externe"}');

-- Le trigger a créé les profils avec le rôle par défaut ; on promeut l'admin.
update public.profiles set role = 'admin'
 where id = '11111111-1111-4111-8111-111111111111';

insert into public.clients
  (id, name, address, logo_path, created_at, updated_at) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Client Test',
   'Rue de l''Industrie 12, 4000 Liege',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/logo.png', now(), now());

insert into public.projects
  (id, client_id, name, status, created_at, updated_at) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'Chantier ouvert', 'in_progress', now(), now()),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'Chantier cloture', 'completed', now(), now()),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'Chantier d''une autre equipe', 'in_progress', now(), now());

-- L'opérateur est affecté aux deux premiers, pas au troisième.
insert into public.project_members (project_id, user_id) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '22222222-2222-4222-8222-222222222222'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   '22222222-2222-4222-8222-222222222222');

commit;

\echo ''
\echo '=== Policies RLS ==='

-- -----------------------------------------------------------------------------
-- 1. Un opérateur écrit sur un chantier ouvert auquel il est affecté
-- -----------------------------------------------------------------------------

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

insert into public.points
  (id, project_id, author_id, description, captured_at, updated_at)
values
  (gen_random_uuid(), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '22222222-2222-4222-8222-222222222222',
   'Traversee cable etage 2', now(), now());

\echo 'OK   chantier ouvert + affecte : ecriture acceptee'
rollback;

-- -----------------------------------------------------------------------------
-- 2. Le même opérateur, sur un chantier CLÔTURÉ
-- -----------------------------------------------------------------------------
--
-- Le cas qui compte : le rapport de conformité est déjà remis au client. Toute
-- écriture postérieure invaliderait le document sans laisser de trace.

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare refuse boolean := false;
begin
  begin
    insert into public.points
      (id, project_id, author_id, captured_at, updated_at)
    values
      (gen_random_uuid(), 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
       '22222222-2222-4222-8222-222222222222', now(), now());
  exception when others then
    refuse := true;
  end;

  assert refuse,
    'REGRESSION: un operateur a pu ecrire sur un chantier cloture';
  raise notice 'OK   chantier cloture : ecriture refusee';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 3. Un opérateur non affecté
-- -----------------------------------------------------------------------------

begin;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333"}', true);
set local role authenticated;

do $$
declare refuse boolean := false;
        visibles integer;
begin
  begin
    insert into public.points
      (id, project_id, author_id, captured_at, updated_at)
    values
      (gen_random_uuid(), 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
       '33333333-3333-4333-8333-333333333333', now(), now());
  exception when others then
    refuse := true;
  end;

  assert refuse,
    'REGRESSION: ecriture possible sur un chantier non affecte';

  select count(*) into visibles from public.projects;
  assert visibles = 0,
    format('REGRESSION: %s chantier(s) visible(s) sans affectation', visibles);

  raise notice 'OK   non affecte : ni lecture ni ecriture';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 4. Cloisonnement en lecture
-- -----------------------------------------------------------------------------

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare visibles integer;
begin
  select count(*) into visibles from public.projects;
  assert visibles = 2,
    format('REGRESSION: %s chantiers visibles au lieu de 2', visibles);
  raise notice 'OK   lecture bornee aux affectations (2 chantiers)';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 5. Un opérateur ne peut pas se promouvoir admin
-- -----------------------------------------------------------------------------

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare apres public.user_role;
begin
  -- `profiles_update_self` autorise bien l'UPDATE de sa propre ligne : la
  -- requete ne leve donc aucune erreur. C'est precisement le genre de faille
  -- qu'un test de refus par exception manquerait — il faut relire la valeur.
  begin
    update public.profiles set role = 'admin'
     where id = '22222222-2222-4222-8222-222222222222';
  exception when others then
    null;
  end;

  select role into apres from public.profiles
   where id = '22222222-2222-4222-8222-222222222222';

  assert apres = 'operator',
    'FAILLE: un operateur s''est promu admin';
  raise notice 'OK   auto-promotion impossible';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 6. L'admin n'est borné par rien
-- -----------------------------------------------------------------------------

begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111"}', true);
set local role authenticated;

do $$
declare visibles integer;
begin
  select count(*) into visibles from public.projects;
  assert visibles = 3,
    format('REGRESSION: l''admin ne voit que %s chantiers sur 3', visibles);

  insert into public.points
    (id, project_id, author_id, captured_at, updated_at)
  values
    (gen_random_uuid(), 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
     '11111111-1111-4111-8111-111111111111', now(), now());

  raise notice 'OK   admin : lecture complete + ecriture sur chantier cloture';
end
$$;
rollback;

\echo ''
\echo '=== Numerotation des points ==='

-- -----------------------------------------------------------------------------
-- 7. Le numéro de point est celui que le technicien a saisi
-- -----------------------------------------------------------------------------
--
-- Il etait attribue ici par un trigger. S'il en restait un, le numero saisi
-- sur la tablette serait ecrase a l'arrivee, sans erreur : la fiche et le
-- rapport ne porteraient plus le reperage du chantier.
--
-- Et un doublon doit **passer**. Deux techniciens hors ligne peuvent saisir le
-- meme numero ; une contrainte d'unicite ferait refuser le second releve, qui
-- resterait bloque sur sa tablette. L'application signale le doublon.

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare
  p1 uuid := gen_random_uuid();
  p2 uuid := gen_random_uuid();
  p3 uuid := gen_random_uuid();
  lu text;
begin
  insert into public.points
    (id, project_id, ref_number, author_id, captured_at, updated_at)
  values
    (p1, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '1.40',
     '22222222-2222-4222-8222-222222222222', now(), now()),
    (p2, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', null,
     '22222222-2222-4222-8222-222222222222', now(), now());

  select ref_number into lu from public.points where id = p1;
  -- « 1.40 » et non 1.4 : le numero est un texte, il se garde tel quel.
  assert lu = '1.40',
    format('REGRESSION: numero saisi 1.40, enregistre %s', lu);

  select ref_number into lu from public.points where id = p2;
  assert lu is null,
    format('REGRESSION: une fiche sans numero en a recu un (%s)', lu);

  -- La correction du technicien arrive par upsert, comme tout le reste.
  insert into public.points
    (id, project_id, ref_number, author_id, captured_at, updated_at)
  values
    (p1, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '12',
     '22222222-2222-4222-8222-222222222222', now(),
     now() + interval '1 minute')
  on conflict (id) do update set
    ref_number = excluded.ref_number,
    updated_at = excluded.updated_at;

  select ref_number into lu from public.points where id = p1;
  assert lu = '12',
    format('REGRESSION: numero corrige en 12, enregistre %s', lu);

  -- Le doublon passe.
  insert into public.points
    (id, project_id, ref_number, author_id, captured_at, updated_at)
  values
    (p3, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '12',
     '22222222-2222-4222-8222-222222222222', now(), now());

  -- Un numero vide n'est pas un numero.
  declare refuse boolean := false;
  begin
    begin
      update public.points set ref_number = '  ' where id = p2;
    exception when check_violation then
      refuse := true;
    end;
    assert refuse, 'REGRESSION: un numero de point vide a ete accepte';
  end;

  raise notice 'OK   numero de point : texte libre, corrigeable, doublon accepte';
end
$$;
rollback;

\echo ''
\echo '=== Last-write-wins ==='

-- -----------------------------------------------------------------------------
-- 8. Une écriture périmée n'écrase pas une version plus récente
-- -----------------------------------------------------------------------------

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare
  p uuid := gen_random_uuid();
  t0 timestamptz := now();
  final text;
begin
  insert into public.points
    (id, project_id, author_id, description, captured_at, updated_at)
  values
    (p, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '22222222-2222-4222-8222-222222222222', 'v1', t0, t0);

  -- Tablette B, plus recente.
  update public.points
     set description = 'v2', updated_at = t0 + interval '10 minutes'
   where id = p;

  -- Tablette A rejoue enfin sa version, vieille de dix minutes.
  update public.points
     set description = 'v1-retardataire', updated_at = t0 + interval '1 minute'
   where id = p;

  select description into final from public.points where id = p;
  assert final = 'v2',
    format('REGRESSION: le retardataire a ecrase la version recente (%s)', final);

  raise notice 'OK   ecriture perimee ignoree sans erreur';
end
$$;
rollback;

\echo ''
\echo '=== Curseur de replication ==='

-- -----------------------------------------------------------------------------
-- 9. `synced_at` est inforgeable depuis un client
-- -----------------------------------------------------------------------------
--
-- Le scenario redoute : une tablette a l'horloge deraillee ecrit une date en
-- 2027. Si cette valeur atteignait la colonne, elle deviendrait le maximum vu
-- par tous les autres appareils, leur curseur sauterait un an, et plus rien ne
-- redescendrait jamais. Panne totale et silencieuse, provoquee par un tiers.

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare
  p uuid := gen_random_uuid();
  stocke timestamptz;
begin
  insert into public.points
    (id, project_id, author_id, captured_at, updated_at, synced_at)
  values
    (p, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '22222222-2222-4222-8222-222222222222',
     now(), now(), '2027-01-01T00:00:00Z');

  select synced_at into stocke from public.points where id = p;

  assert stocke < now() + interval '1 minute',
    format('FAILLE: un client a impose synced_at = %s', stocke);
  raise notice 'OK   synced_at impose par le serveur, horloge client ignoree';
end
$$;
rollback;

\echo ''
\echo '=== Revocation d''affectation ==='

-- -----------------------------------------------------------------------------
-- 10. Retirer un operateur d'un chantier lui coupe reellement l'acces
-- -----------------------------------------------------------------------------
--
-- La suppression etant logique, la ligne d'affectation reste en base avec
-- `deleted_at` renseigne. Si `is_project_member()` se contentait de tester
-- l'existence de la ligne, un operateur ecarte — change d'equipe, ou parti de
-- l'entreprise — garderait acces en lecture ET en ecriture. L'admin le verrait
-- disparaitre de la liste et croirait le probleme regle.

begin;

update public.project_members
   set deleted_at = now(), updated_at = now()
 where project_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
   and user_id = '22222222-2222-4222-8222-222222222222';

select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare
  visible integer;
  refuse boolean := false;
begin
  select count(*) into visible from public.projects
   where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  assert visible = 0,
    'FAILLE: un operateur revoque voit encore le chantier';

  begin
    insert into public.points
      (id, project_id, author_id, captured_at, updated_at)
    values
      (gen_random_uuid(), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
       '22222222-2222-4222-8222-222222222222', now(), now());
  exception when others then
    refuse := true;
  end;

  assert refuse, 'FAILLE: un operateur revoque ecrit encore sur le chantier';
  raise notice 'OK   affectation retiree : acces coupe en lecture et ecriture';
end
$$;
rollback;

\echo ''
\echo '=== Cloisonnement des lectures (inscription libre) ==='

-- -----------------------------------------------------------------------------
-- 11. Un compte fraichement inscrit ne repart avec rien
-- -----------------------------------------------------------------------------
--
-- L'inscription etant ouverte a tous, n'importe qui peut obtenir un compte
-- authentifie. Ce que ce compte peut LIRE devient donc une surface publique.
-- Sans cloisonnement, il repartait avec le fichier clients complet et
-- l'annuaire du personnel — deux lectures parfaitement legitimes du point de
-- vue du serveur, donc indetectables.

begin;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333"}', true);
set local role authenticated;

do $$
declare
  clients_vus  integer;
  profils_vus  integer;
begin
  select count(*) into clients_vus from public.clients;
  assert clients_vus = 0,
    format('FUITE: %s client(s) lisibles par un inscrit sans affectation',
           clients_vus);

  -- Il se voit lui-meme, et voit l'administrateur — interlocuteur declare.
  -- Il ne doit PAS voir l'autre technicien.
  select count(*) into profils_vus from public.profiles;
  assert profils_vus = 2,
    format('FUITE: %s profils lisibles au lieu de 2 (soi + admin)',
           profils_vus);

  assert not exists (
    select 1 from public.profiles
     where id = '22222222-2222-4222-8222-222222222222'
  ), 'FUITE: annuaire du personnel lisible par un inscrit sans affectation';

  raise notice 'OK   inscrit non affecte : ni clients ni annuaire';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 12. Un technicien affecte voit ce dont il a besoin, et rien de plus
-- -----------------------------------------------------------------------------
--
-- Le cloisonnement ne doit pas casser l'integrite referentielle : `projects`
-- reference `clients`, et `points` reference `profiles`, jusque dans la base
-- locale de la tablette. Un client invisible ferait echouer la descente sur une
-- violation de cle etrangere.

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare
  manquants integer;
begin
  -- Tout chantier visible a son client visible.
  select count(*) into manquants
    from public.projects p
   where not exists (select 1 from public.clients c where c.id = p.client_id);

  assert manquants = 0,
    format('REGRESSION: %s chantier(s) dont le client est invisible — la '
           'descente violerait la cle etrangere', manquants);

  assert exists (select 1 from public.clients),
    'REGRESSION: un technicien affecte ne voit pas le client de son chantier';

  raise notice 'OK   technicien affecte : client visible, integrite preservee';
end
$$;
rollback;

\echo ''
\echo '=== UPDATE filtre : 200 sans erreur ==='

-- -----------------------------------------------------------------------------
-- 13. Un UPDATE ecarte par RLS ne leve AUCUNE erreur
-- -----------------------------------------------------------------------------
--
-- Piege verifie en conditions reelles sur le projet de production : un UPDATE
-- dont la clause `using` ne matche aucune ligne n'echoue pas. PostgREST repond
-- HTTP 200 avec zero ligne. Un appelant qui ne compte pas les lignes touchees
-- croit son ecriture passee.
--
-- L'INSERT, lui, leve bien 42501 — d'ou l'asymetrie a connaitre : cote client,
-- `upsert` signale son refus, `update` non.

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare touchees integer;
begin
  -- Le chantier cccc est cloture : l'operateur n'a pas le droit d'y ecrire.
  update public.points
     set description = 'TENTATIVE'
   where project_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  get diagnostics touchees = row_count;

  assert touchees = 0,
    format('REGRESSION: %s ligne(s) modifiee(s) sur un chantier cloture',
           touchees);

  raise notice 'OK   update ecarte silencieusement : 0 ligne, aucune erreur';
end
$$;
rollback;

\echo ''
\echo '=== Listes de parametres ==='

-- -----------------------------------------------------------------------------
-- 14. Un operateur ne peut pas modifier les listes de la fiche
-- -----------------------------------------------------------------------------
--
-- Ces listes decident du vocabulaire de tous les rapports de l'entreprise. Un
-- technicien qui pourrait y ajouter « Promastop-FX » d'un doigt maladroit
-- polluerait le catalogue de tout le monde, et l'entree se retrouverait sur le
-- document d'un autre chantier.
--
-- Comme partout ici, le refus se prouve en comptant les lignes : `insert`
-- ecarte par `with check` leve bien, mais un `update` ecarte par `using` rend
-- 200 avec zero ligne. On verifie donc l'effet, pas l'exception.

begin;

insert into public.setting_options (id, kind, label, sort_order, updated_at)
values ('f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1', 'product', 'Reference Test',
        0, now());

select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare libelle text; ajoutees integer;
begin
  begin
    update public.setting_options set label = 'DETOURNE'
     where id = 'f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1';
  exception when others then
    null;
  end;

  select label into libelle from public.setting_options
   where id = 'f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1';
  assert libelle = 'Reference Test',
    'FAILLE: un operateur a renomme une entree de catalogue';

  begin
    insert into public.setting_options (id, kind, label, sort_order, updated_at)
    values ('f2f2f2f2-f2f2-4f2f-8f2f-f2f2f2f2f2f2', 'product', 'INTRUS',
            1, now());
  exception when others then
    null;
  end;

  select count(*) into ajoutees from public.setting_options
   where label = 'INTRUS';
  assert ajoutees = 0,
    'FAILLE: un operateur a ajoute une entree de catalogue';

  raise notice 'OK   listes de parametres en lecture seule pour un operateur';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 15. ... mais il doit pouvoir les LIRE
-- -----------------------------------------------------------------------------
--
-- Le pendant du test precedent, et il compte tout autant. `points` reference
-- ces lignes par cle etrangere **jusque dans la base locale des tablettes** :
-- une option invisible ferait echouer la descente du point qui la designe, et
-- le technicien verrait simplement une traversee ne jamais arriver. C'est le
-- piege que `can_see_client` et `can_see_profile` evitent pour `clients` et
-- `profiles`.

begin;

insert into public.setting_options (id, kind, label, sort_order, updated_at)
values ('f3f3f3f3-f3f3-4f3f-8f3f-f3f3f3f3f3f3', 'ei_level', 'EI240', 9, now());

select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333"}', true);
set local role authenticated;

do $$
declare vues integer;
begin
  select count(*) into vues from public.setting_options
   where id = 'f3f3f3f3-f3f3-4f3f-8f3f-f3f3f3f3f3f3';
  assert vues = 1,
    'REGRESSION: les listes de parametres ne sont plus lisibles, la descente '
    'des points qui les referencent echouera';
  raise notice 'OK   listes lisibles par tout compte authentifie';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 16. `synced_at` est pose par le serveur sur setting_options aussi
-- -----------------------------------------------------------------------------
--
-- Chaque table repliquee doit porter son trigger `_touch_synced`. L'oubli serait
-- silencieux : le curseur de descente n'avancerait jamais pour cette entite, et
-- les nouvelles options n'arriveraient sur aucune tablette.

begin;

do $$
declare pose timestamptz;
begin
  insert into public.setting_options (id, kind, label, sort_order, updated_at)
  values ('f4f4f4f4-f4f4-4f4f-8f4f-f4f4f4f4f4f4', 'supplier', 'Fabricant Test',
          0, '2020-01-01'::timestamptz);

  select synced_at into pose from public.setting_options
   where id = 'f4f4f4f4-f4f4-4f4f-8f4f-f4f4f4f4f4f4';

  assert pose > now() - interval '1 minute',
    format('REGRESSION: synced_at vaut %s, le trigger ne tourne pas', pose);
  raise notice 'OK   synced_at pose par le serveur sur setting_options';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 17. Les etages sont une liste administree, deja garnie
-- -----------------------------------------------------------------------------
--
-- L'etage etait un entier borne de -3 a 5 ; il est desormais une option de
-- `setting_options`. Deux choses a prouver : les neuf niveaux d'origine
-- existent — sans eux la fiche n'aurait rien a proposer —, et un point ne
-- peut designer qu'une option qui existe.

begin;

do $$
declare
  niveaux integer;
  rdc uuid;
  refuse boolean := false;
begin
  select count(*) into niveaux from public.setting_options
   where kind = 'floor' and deleted_at is null;
  assert niveaux = 9,
    format('REGRESSION: %s etages d''origine au lieu de 9', niveaux);

  select id into rdc from public.setting_options
   where kind = 'floor' and label = 'Niveau 0';
  insert into public.points
    (id, project_id, author_id, floor_id, captured_at, updated_at)
  values
    (gen_random_uuid(), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '22222222-2222-4222-8222-222222222222', rdc, now(), now());

  begin
    insert into public.points
      (id, project_id, author_id, floor_id, captured_at, updated_at)
    values
      (gen_random_uuid(), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
       '22222222-2222-4222-8222-222222222222', gen_random_uuid(), now(), now());
  exception when foreign_key_violation then
    refuse := true;
  end;
  assert refuse,
    'REGRESSION: un point a pu designer un etage qui n''existe pas';

  raise notice 'OK   etages : liste administree, garnie de ses neuf niveaux';
end
$$;
rollback;

\echo ''
\echo '=== Affectation et descente incrementale ==='

-- -----------------------------------------------------------------------------
-- 18. Affecter quelqu'un rend son chantier telechargeable
-- -----------------------------------------------------------------------------
--
-- La panne observee sur tablette. Une affectation ne modifie pas le chantier,
-- seulement ce que RLS laisse voir. Sans reestampillage, un chantier plus
-- ancien que le curseur du technicien devenait visible et n'etait jamais
-- envoye : il n'apparaissait pas sur son accueil.
--
-- Le test mesure donc `synced_at`, pas la visibilite : la visibilite, elle,
-- etait deja correcte — c'est precisement ce qui rendait la panne difficile a
-- lire. Un chantier parfaitement visible que personne ne recevait.

begin;

do $$
declare
  avant_projet   timestamptz;
  avant_point    timestamptz;
  avant_client   timestamptz;
  apres_projet   timestamptz;
  apres_point    timestamptz;
  apres_client   timestamptz;
begin
  -- Un chantier « ancien », avec une traversee, auquel l'externe n'est pas
  -- affecte. On force des horodatages serveur anciens.
  insert into public.points
    (id, project_id, author_id, captured_at, updated_at)
  values
    ('caca1111-1111-4111-8111-111111111111',
     'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
     '22222222-2222-4222-8222-222222222222', now(), now());

  update public.projects set synced_at = now() - interval '30 days'
   where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  update public.points   set synced_at = now() - interval '30 days'
   where project_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  update public.clients  set synced_at = now() - interval '30 days'
   where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  select synced_at into avant_projet from public.projects
   where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  select synced_at into avant_point  from public.points
   where id = 'caca1111-1111-4111-8111-111111111111';
  select synced_at into avant_client from public.clients
   where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  -- L'admin affecte l'externe.
  insert into public.project_members (project_id, user_id) values
    ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
     '33333333-3333-4333-8333-333333333333');

  select synced_at into apres_projet from public.projects
   where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  select synced_at into apres_point  from public.points
   where id = 'caca1111-1111-4111-8111-111111111111';
  select synced_at into apres_client from public.clients
   where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  assert apres_projet > avant_projet,
    'REGRESSION: le chantier n''a pas ete reestampille, il n''apparaitra pas '
    'sur l''accueil du technicien';
  assert apres_point > avant_point,
    'REGRESSION: les traversees n''ont pas ete reestampillees, le technicien '
    'verrait un chantier vide';
  assert apres_client > avant_client,
    'REGRESSION: le client n''a pas ete reestampille, la cle etrangere locale '
    'projects.client_id echouerait';

  raise notice 'OK   affectation : chantier, traversees et client reestampilles';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 19. Une revocation ne reestampille rien
-- -----------------------------------------------------------------------------
--
-- Le pendant du test precedent. Retirer quelqu'un n'ouvre aucun acces : c'est
-- le tombstone de `project_members` qui redescend et ferme la porte. Si le
-- trigger reestampillait la, chaque revocation ferait re-telecharger le
-- chantier entier a tous les autres membres, pour rien.

begin;

do $$
declare avant timestamptz; apres timestamptz;
begin
  select synced_at into avant from public.projects
   where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  update public.project_members set deleted_at = now(), updated_at = now()
   where project_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
     and user_id = '22222222-2222-4222-8222-222222222222';

  select synced_at into apres from public.projects
   where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  assert apres = avant,
    'REGRESSION: une revocation reestampille le chantier, ce qui le fait '
    're-descendre sur toutes les tablettes sans raison';
  raise notice 'OK   revocation : aucun reestampillage inutile';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 20. Une reaffectation apres retrait reestampille de nouveau
-- -----------------------------------------------------------------------------
--
-- La resurrection d'une affectation retiree rouvre un acces : le technicien a
-- pu purger sa base entre-temps, et son curseur, lui, n'a pas recule.

begin;

do $$
declare avant timestamptz; apres timestamptz;
begin
  update public.project_members set deleted_at = now(), updated_at = now()
   where project_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
     and user_id = '22222222-2222-4222-8222-222222222222';

  update public.projects set synced_at = now() - interval '30 days'
   where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  select synced_at into avant from public.projects
   where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  update public.project_members set deleted_at = null, updated_at = now()
   where project_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
     and user_id = '22222222-2222-4222-8222-222222222222';

  select synced_at into apres from public.projects
   where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  assert apres > avant,
    'REGRESSION: une reaffectation ne redonne pas acces au chantier';
  raise notice 'OK   reaffectation : chantier reestampille';
end
$$;
rollback;

\echo ''
\echo '=== Integrite des releves ==='

-- -----------------------------------------------------------------------------
-- 21. Un technicien ne cree pas de traversee au nom d'un autre
-- -----------------------------------------------------------------------------
--
-- RLS ne voit que la ligne : l'operateur a le droit d'ecrire sur ce chantier,
-- donc la ligne passait, quel que soit l'auteur qu'elle declarait.

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare refuse boolean := false;
begin
  begin
    insert into public.points
      (id, project_id, author_id, captured_at, updated_at)
    values
      (gen_random_uuid(), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
       '11111111-1111-4111-8111-111111111111', now(), now());
  exception when insufficient_privilege then
    refuse := true;
  end;

  assert refuse,
    'REGRESSION: un technicien a cree une traversee au nom d''un autre';
  raise notice 'OK   traversee creee au nom d''un autre : refusee';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 22. Un collegue complete la fiche d'un autre, par upsert
-- -----------------------------------------------------------------------------
--
-- Le cas qu'une garde naive aurait casse. PostgREST ecrit par
-- INSERT ... ON CONFLICT, et Postgres declenche le trigger BEFORE INSERT
-- **avant** de basculer en mise a jour : la requete du collegue arrive en
-- insertion, avec l'author_id d'origine. Elle doit passer, et l'auteur rester.

begin;
insert into public.points
  (id, project_id, author_id, captured_at, updated_at)
values
  ('cafe2222-2222-4222-8222-222222222222',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '11111111-1111-4111-8111-111111111111', now(), now() - interval '1 hour');

select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

insert into public.points
  (id, project_id, author_id, description, captured_at, updated_at)
values
  ('cafe2222-2222-4222-8222-222222222222',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '11111111-1111-4111-8111-111111111111',
   'Completee par un collegue', now(), now())
on conflict (id) do update
  set description = excluded.description,
      updated_at  = excluded.updated_at;

do $$
begin
  assert (select description from public.points
           where id = 'cafe2222-2222-4222-8222-222222222222')
         = 'Completee par un collegue',
    'REGRESSION: un collegue ne peut plus completer une fiche';
  assert (select author_id from public.points
           where id = 'cafe2222-2222-4222-8222-222222222222')
         = '11111111-1111-4111-8111-111111111111',
    'REGRESSION: completer une fiche en a change l''auteur';
  raise notice 'OK   collegue : fiche completee, auteur d''origine conserve';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 23. L'auteur d'une traversee ne se reattribue pas
-- -----------------------------------------------------------------------------

begin;
insert into public.points
  (id, project_id, author_id, captured_at, updated_at)
values
  ('cafe3333-3333-4333-8333-333333333333',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '22222222-2222-4222-8222-222222222222', now(), now() - interval '1 hour');

select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare refuse boolean := false;
begin
  begin
    update public.points
       set author_id  = '11111111-1111-4111-8111-111111111111',
           updated_at = now()
     where id = 'cafe3333-3333-4333-8333-333333333333';
  exception when insufficient_privilege then
    refuse := true;
  end;

  assert refuse,
    'REGRESSION: un technicien a reattribue une traversee';
  raise notice 'OK   auteur d''une traversee : non modifiable';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 24. L'administrateur peut reprendre un releve au nom d'un technicien
-- -----------------------------------------------------------------------------

begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111"}', true);
set local role authenticated;

insert into public.points
  (id, project_id, author_id, captured_at, updated_at)
values
  (gen_random_uuid(), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '22222222-2222-4222-8222-222222222222', now(), now());

\echo 'OK   admin : releve saisi au nom d''un technicien accepte'
rollback;

-- -----------------------------------------------------------------------------
-- 25. Un cliche ne designe que l'objet de sa traversee
-- -----------------------------------------------------------------------------
--
-- Sans cette garde, une ligne de cliche pouvait pointer vers le bucket d'un
-- autre chantier. Le technicien ne l'aurait pas lue, mais l'administrateur, si
-- — et la photo d'un autre batiment serait sortie sur le rapport.

begin;
insert into public.points
  (id, project_id, author_id, captured_at, updated_at)
values
  ('cafe4444-4444-4444-8444-444444444444',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '22222222-2222-4222-8222-222222222222', now(), now());

select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare refuse boolean := false;
begin
  begin
    insert into public.photos
      (id, point_id, kind, storage_path, taken_at, updated_at)
    values
      ('fade5555-5555-4555-8555-555555555555',
       'cafe4444-4444-4444-8444-444444444444', 'before',
       'dddddddd-dddd-4ddd-8ddd-dddddddddddd/autre/cliche.jpg', now(), now());
  exception when insufficient_privilege then
    refuse := true;
  end;

  assert refuse,
    'REGRESSION: un cliche a pu designer l''objet d''un autre chantier';

  -- Le chemin que l'application construit, lui, passe.
  insert into public.photos
    (id, point_id, kind, storage_path, taken_at, updated_at)
  values
    ('fade5555-5555-4555-8555-555555555555',
     'cafe4444-4444-4444-8444-444444444444', 'before',
     'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/'
     'cafe4444-4444-4444-8444-444444444444/'
     'fade5555-5555-4555-8555-555555555555.jpg',
     now(), now());

  raise notice 'OK   chemin de cliche : borne a sa traversee';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 26. Les logos clients sont en PNG ou en JPEG
-- -----------------------------------------------------------------------------

do $$
begin
  assert not exists (
    select 1 from storage.buckets
     where id = 'client-logos'
       and 'image/svg+xml' = any (allowed_mime_types)
  ),
    'REGRESSION: le bucket des logos accepte encore le SVG';
  raise notice 'OK   logos clients : PNG et JPEG uniquement';
end
$$;

-- -----------------------------------------------------------------------------
-- 27. Le parent d'un produit est un fournisseur, et rien d'autre n'a de parent
-- -----------------------------------------------------------------------------
--
-- La fiche ne propose que les produits du fournisseur choisi. Un produit
-- rattache a un niveau EI, ou un niveau EI rattache a un fournisseur, ne
-- leverait aucune erreur cote application : il ne serait simplement propose
-- nulle part.

begin;

do $$
declare
  fournisseur uuid;
  niveau      uuid;
  refuse      boolean;
begin
  select id into fournisseur from public.setting_options
   where kind = 'supplier' limit 1;
  select id into niveau from public.setting_options
   where kind = 'ei_level' limit 1;

  -- Le cas nominal passe.
  insert into public.setting_options
    (id, kind, label, sort_order, parent_id, updated_at)
  values ('f5f5f5f5-f5f5-4f5f-8f5f-f5f5f5f5f5f5', 'product', 'Produit Test',
          0, fournisseur, now());

  refuse := false;
  begin
    insert into public.setting_options
      (id, kind, label, sort_order, parent_id, updated_at)
    values ('f6f6f6f6-f6f6-4f6f-8f6f-f6f6f6f6f6f6', 'product', 'Mal range',
            0, niveau, now());
  exception when check_violation then
    refuse := true;
  end;
  assert refuse,
    'REGRESSION: un produit a pu designer autre chose qu''un fournisseur';

  refuse := false;
  begin
    insert into public.setting_options
      (id, kind, label, sort_order, parent_id, updated_at)
    values ('f7f7f7f7-f7f7-4f7f-8f7f-f7f7f7f7f7f7', 'ei_level', 'EI45',
            0, fournisseur, now());
  exception when check_violation then
    refuse := true;
  end;
  assert refuse,
    'REGRESSION: une option qui n''est pas un produit a recu un fournisseur';

  raise notice 'OK   produit : son parent est un fournisseur';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 28. Le catalogue initial est rattache a son fournisseur
-- -----------------------------------------------------------------------------
--
-- Un produit sans fournisseur n'est propose sur aucune fiche. Si la migration
-- laissait le catalogue initial orphelin, une installation neuve offrirait
-- cinq listes « Produit utilise » vides, sans le moindre message.

do $$
declare orphelins integer; rattaches integer;
begin
  select count(*) filter (where parent_id is null),
         count(*) filter (where parent_id is not null)
    into orphelins, rattaches
    from public.setting_options
   where kind = 'product';

  assert orphelins = 0 and rattaches > 0,
    format('REGRESSION: %s produits du catalogue initial sans fournisseur '
           '(%s rattaches)', orphelins, rattaches);
  raise notice 'OK   catalogue initial rattache a son fournisseur';
end
$$;

-- -----------------------------------------------------------------------------
-- 29. Un visiteur sans session n'appelle pas les fonctions des policies
-- -----------------------------------------------------------------------------
--
-- Elles sont en `security definer` et exposees sous /rpc/ : sans ce retrait,
-- la seule cle publique de l'APK suffit a demander le chantier d'une
-- traversee, RLS contournee. Un compte connecte, lui, doit garder l'acces :
-- ses policies en dependent, et le refus couperait toute lecture.

begin;
set local role anon;

do $$
declare
  f text;
  refuse boolean;
begin
  foreach f in array array[
    'select public.is_admin()',
    'select public.point_project(''cafe4444-4444-4444-8444-444444444444'')',
    'select public.project_is_open(''bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'')',
    'select public.is_project_member(''bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'')',
    'select public.can_write_project(''bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'')',
    'select public.can_see_client(''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'')',
    'select public.can_see_profile(''11111111-1111-4111-8111-111111111111'')'
  ] loop
    refuse := false;
    begin
      execute f;
    exception when insufficient_privilege then
      refuse := true;
    end;
    assert refuse, format('FAILLE: un visiteur anonyme a execute « %s »', f);
  end loop;
  raise notice 'OK   fonctions des policies : fermees au role anon';
end
$$;
rollback;

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
begin
  assert public.is_project_member('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
    'REGRESSION: un technicien affecte ne peut plus evaluer ses policies';
  raise notice 'OK   fonctions des policies : ouvertes aux comptes connectes';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 30. Supprimer un chantier l'efface pour de bon, et il ne revient pas
-- -----------------------------------------------------------------------------
--
-- Le seul DELETE physique de l'application. Trois choses a prouver : tout est
-- parti, un technicien ne peut pas le declencher, et un appareil reste hors
-- ligne ne ressuscite ni le chantier ni ses traversees.

begin;

insert into public.points
  (id, project_id, author_id, captured_at, updated_at)
values
  ('dead1111-1111-4111-8111-111111111111',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '22222222-2222-4222-8222-222222222222', now(), now());

-- Un technicien affecte : refuse.
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare refuse boolean := false;
begin
  begin
    perform public.delete_project('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  exception when insufficient_privilege then
    refuse := true;
  end;
  assert refuse, 'FAILLE: un technicien a supprime un chantier';
  assert exists (select 1 from public.projects
                  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
    'FAILLE: le chantier a disparu malgre le refus';
  raise notice 'OK   suppression de chantier : refusee a un technicien';
end
$$;

-- L'administrateur : tout part.
reset role;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111"}', true);
set local role authenticated;

do $$
declare restes integer; revenus integer;
begin
  perform public.delete_project('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

  select (select count(*) from public.projects
           where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
       + (select count(*) from public.points
           where project_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
       + (select count(*) from public.project_members
           where project_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
    into restes;
  assert restes = 0,
    format('REGRESSION: %s lignes du chantier subsistent', restes);

  assert exists (select 1 from public.deleted_projects
                  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
    'REGRESSION: aucune trace de la suppression — les autres appareils '
    'garderaient le chantier';

  -- Un appareil reste hors ligne repousse sa copie : ecartee, sans erreur.
  insert into public.projects
    (id, client_id, name, created_at, updated_at)
  values
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Revenant', now(), now())
  on conflict (id) do update set name = excluded.name;
  insert into public.points
    (id, project_id, author_id, captured_at, updated_at)
  values
    ('dead2222-2222-4222-8222-222222222222',
     'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '11111111-1111-4111-8111-111111111111', now(), now())
  on conflict (id) do update set updated_at = excluded.updated_at;

  select (select count(*) from public.projects
           where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
       + (select count(*) from public.points
           where project_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
    into revenus;
  assert revenus = 0,
    'REGRESSION: un chantier supprime est revenu par une ecriture tardive';

  raise notice 'OK   suppression de chantier : definitive, sans retour';
end
$$;
rollback;

-- -----------------------------------------------------------------------------
-- 31. Supprimer un point l'efface pour de bon, et il ne revient pas
-- -----------------------------------------------------------------------------
--
-- La tablette marque la ligne (`deleted_at`) et l'envoie, comme toute autre
-- modification — c'est ce qui garde la suppression possible hors ligne. Le
-- serveur en fait un effacement, garde une trace pour les autres appareils,
-- et ecarte toute ecriture tardive.

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare
  p uuid := 'dead3333-3333-4333-8333-333333333333';
  restes integer;
begin
  insert into public.points
    (id, project_id, ref_number, author_id, captured_at, updated_at)
  values
    (p, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '1.40',
     '22222222-2222-4222-8222-222222222222', now(), now());
  insert into public.photos
    (id, point_id, kind, storage_path, taken_at, updated_at)
  values
    ('fade3333-3333-4333-8333-333333333333', p, 'before',
     'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/' || p || '/'
     || 'fade3333-3333-4333-8333-333333333333.jpg', now(), now());

  -- Le geste de la tablette : un upsert qui porte `deleted_at`.
  insert into public.points
    (id, project_id, author_id, captured_at, updated_at, deleted_at)
  values
    (p, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '22222222-2222-4222-8222-222222222222', now(),
     now() + interval '1 minute', now())
  on conflict (id) do update set
    deleted_at = excluded.deleted_at,
    updated_at = excluded.updated_at;

  select (select count(*) from public.points where id = p)
       + (select count(*) from public.photos where point_id = p)
    into restes;
  assert restes = 0,
    format('REGRESSION: %s lignes du point subsistent', restes);

  assert exists (select 1 from public.deleted_points
                  where id = p
                    and project_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
    'REGRESSION: aucune trace de la suppression — les autres appareils '
    'garderaient le point';

  -- Un appareil reste hors ligne repousse le point, puis un cliche : ecartes
  -- sans erreur.
  insert into public.points
    (id, project_id, author_id, captured_at, updated_at)
  values
    (p, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '22222222-2222-4222-8222-222222222222', now(), now() + interval '1 hour')
  on conflict (id) do update set updated_at = excluded.updated_at;
  insert into public.photos
    (id, point_id, kind, storage_path, taken_at, updated_at)
  values
    ('fade4444-4444-4444-8444-444444444444', p, 'after',
     'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/' || p || '/'
     || 'fade4444-4444-4444-8444-444444444444.jpg', now(), now());

  select (select count(*) from public.points where id = p)
       + (select count(*) from public.photos where point_id = p)
    into restes;
  assert restes = 0,
    'REGRESSION: un point supprime est revenu par une ecriture tardive';

  raise notice 'OK   suppression de point : definitive, sans retour';
end
$$;
rollback;

\echo ''
\echo 'Tous les tests sont passes.'
