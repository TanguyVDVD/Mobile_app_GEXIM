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

insert into public.clients (id, name, created_at, updated_at) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Client Test', now(), now());

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
-- 7. Numéros attribués par le serveur, stables au rejeu
-- -----------------------------------------------------------------------------

begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222"}', true);
set local role authenticated;

do $$
declare
  p1 uuid := gen_random_uuid();
  p2 uuid := gen_random_uuid();
  numeros integer[];
  apres integer;
begin
  insert into public.points
    (id, project_id, author_id, captured_at, updated_at)
  values
    (p1, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '22222222-2222-4222-8222-222222222222', now(), now()),
    (p2, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '22222222-2222-4222-8222-222222222222', now(), now());

  select array_agg(ref_number order by ref_number)
    into numeros from public.points where id in (p1, p2);

  assert numeros = array[1, 2],
    format('REGRESSION: numeros attribues = %s', numeros);

  -- Rejeu d'un upsert dont l'accuse de reception s'est perdu.
  insert into public.points
    (id, project_id, author_id, description, captured_at, updated_at)
  values
    (p1, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
     '22222222-2222-4222-8222-222222222222',
     'Description corrigee', now(), now() + interval '1 minute')
  on conflict (id) do update set
    description = excluded.description,
    updated_at  = excluded.updated_at;

  select ref_number into apres from public.points where id = p1;
  assert apres = 1,
    format('REGRESSION: le rejeu a renumerote le point (%s au lieu de 1)', apres);

  raise notice 'OK   numeros sequentiels, stables au rejeu';
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
\echo '=== Catalogue materiaux ==='

-- -----------------------------------------------------------------------------
-- 14. Catalogue global lisible par tous, catalogue client cloisonne
-- -----------------------------------------------------------------------------

begin;

insert into public.materials (id, label, client_id) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'Produit impose ErnestCorp',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');

select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333"}', true);
set local role authenticated;

do $$
declare vus integer;
begin
  select count(*) into vus from public.materials
   where client_id is not null;
  assert vus = 0,
    format('FUITE: %s materiau(x) client visible(s) par un inscrit non affecte',
           vus);
  raise notice 'OK   catalogue client invisible hors affectation';
end
$$;
rollback;

\echo ''
\echo 'Tous les tests sont passes.'
