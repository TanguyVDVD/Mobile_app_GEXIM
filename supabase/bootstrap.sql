-- =============================================================================
-- FireStop Tracker -- installation initiale, en un seul bloc
-- =============================================================================
--
-- FICHIER GENERE. Ne pas modifier : la source de verite reste
-- supabase/migrations/ et supabase/seed.sql.
--
-- A coller tel quel dans le SQL Editor de Supabase, pour un projet VIERGE.
-- Toute evolution ulterieure passe par une nouvelle migration, jamais par ce
-- fichier -- le rejouer sur une base existante echouerait sur les types et
-- policies deja crees.
-- =============================================================================



-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090000_initial_schema.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — schéma initial
-- =============================================================================
--
-- Miroir distant de la base locale Drift (`lib/database/tables/tables.dart`).
-- Les noms de colonnes doivent correspondre exactement à ceux produits par
-- `lib/sync/payloads.dart` : c'est le contrat de synchronisation.
--
-- Conventions reprises du client :
--   * `id` en uuid, généré **côté client** (v7). Le serveur n'en fabrique
--     jamais : un opérateur crée un point sans réseau.
--   * `updated_at` porte la résolution de conflit (last-write-wins).
--   * `deleted_at` : suppression logique. Aucun DELETE physique.
-- =============================================================================

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Types
-- -----------------------------------------------------------------------------

create type public.user_role as enum ('admin', 'operator');
create type public.project_status as enum ('draft', 'in_progress', 'completed');
create type public.photo_kind as enum ('before', 'after', 'extra');

-- -----------------------------------------------------------------------------
-- Profils
-- -----------------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text        not null default '',
  email       text        not null default '',
  role        public.user_role not null default 'operator',
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Rôle applicatif. Pilote l''intégralité des policies RLS.';

-- Un compte créé par l'admin dans le tableau de bord Supabase n'aurait aucun
-- profil, donc aucun rôle, donc aucun accès — et l'échec serait muet côté app.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Clients
-- -----------------------------------------------------------------------------

create table public.report_templates (
  id         uuid primary key,
  name       text        not null,
  config     jsonb       not null default '{}'::jsonb,
  is_default boolean     not null default false,
  updated_at timestamptz not null default now()
);

comment on column public.report_templates.config is
  'Mise en page du rapport PDF : marque, page de garde, disposition des photos.';

create table public.clients (
  id            uuid primary key,
  name          text not null check (length(name) between 1 and 200),
  contact_name  text,
  contact_email text,
  contact_phone text,
  address       text,
  logo_path     text,
  template_id   uuid references public.report_templates (id),
  created_at    timestamptz not null,
  updated_at    timestamptz not null,
  deleted_at    timestamptz
);

-- -----------------------------------------------------------------------------
-- Chantiers
-- -----------------------------------------------------------------------------

create table public.projects (
  id          uuid primary key,
  client_id   uuid not null references public.clients (id),
  name        text not null check (length(name) between 1 and 200),
  description text,
  started_on  timestamptz,
  ended_on    timestamptz,
  status      public.project_status not null default 'draft',
  created_at  timestamptz not null,
  updated_at  timestamptz not null,
  deleted_at  timestamptz
);

create index projects_client_idx on public.projects (client_id)
  where deleted_at is null;

-- Affectation des opérateurs. Table serveur uniquement : le client n'en a pas
-- besoin, RLS filtrant déjà ce qu'il peut lire.
create table public.project_members (
  project_id uuid not null references public.projects (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  added_at   timestamptz not null default now(),
  primary key (project_id, user_id)
);

create index project_members_user_idx on public.project_members (user_id);

-- -----------------------------------------------------------------------------
-- Points (traversées)
-- -----------------------------------------------------------------------------

create table public.points (
  id          uuid primary key,
  project_id  uuid not null references public.projects (id),
  ref_number  integer,
  floor       text,
  room        text,
  description text,
  author_id   uuid not null references public.profiles (id),
  captured_at timestamptz not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null,
  deleted_at  timestamptz,

  -- Filet de sécurité du trigger de numérotation ci-dessous.
  unique (project_id, ref_number)
);

create index points_project_idx on public.points (project_id)
  where deleted_at is null;

-- Attribution du numéro définitif.
--
-- Le client n'envoie jamais `ref_number` : deux opérateurs hors-ligne
-- créeraient tous deux le « point 47 » sans pouvoir trancher. Le numéro est
-- donc attribué ici, à l'arrivée, dans l'ordre réel de synchronisation.
create or replace function public.assign_point_ref_number()
returns trigger
language plpgsql
-- `security definer` est indispensable : la fonction lit `points`, table
-- protégée par RLS. Exécutée avec les droits de l'appelant, son `max()` ne
-- verrait que les lignes visibles de cet utilisateur. Un opérateur qui n'aurait
-- pas encore reçu tous les points du chantier repartirait alors d'un numéro
-- déjà pris — collision rattrapée par la contrainte d'unicité, mais sous forme
-- d'échec de synchronisation incompréhensible sur le terrain.
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    -- Un upsert rejoué (accusé de réception perdu) repasse par ici. Renuméroter
    -- changerait un identifiant déjà imprimé sur un rapport de conformité.
    new.ref_number := old.ref_number;
    return new;
  end if;

  -- Sérialise les insertions du même chantier le temps de la transaction.
  -- Sans ce verrou, deux tablettes synchronisant en même temps liraient le même
  -- `max()` et se disputeraient le numéro.
  perform pg_advisory_xact_lock(hashtext(new.project_id::text));

  select coalesce(max(ref_number), 0) + 1
    into new.ref_number
    from public.points
   where project_id = new.project_id;

  return new;
end;
$$;

create trigger points_assign_ref_number
  before insert or update on public.points
  for each row execute function public.assign_point_ref_number();

-- -----------------------------------------------------------------------------
-- Matériaux
-- -----------------------------------------------------------------------------

create table public.materials (
  id           uuid primary key,
  label        text not null,
  manufacturer text,
  reference    text,
  client_id    uuid references public.clients (id),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

comment on column public.materials.client_id is
  'NULL = catalogue global. Renseigné = produit imposé par ce client.';

create table public.point_materials (
  point_id    uuid not null references public.points (id),
  material_id uuid not null references public.materials (id),
  quantity    double precision,
  updated_at  timestamptz not null,
  deleted_at  timestamptz,
  primary key (point_id, material_id)
);

-- -----------------------------------------------------------------------------
-- Photos
-- -----------------------------------------------------------------------------

create table public.photos (
  id           uuid primary key,
  point_id     uuid not null references public.points (id),
  kind         public.photo_kind not null,
  storage_path text not null,
  width        integer,
  height       integer,
  bytes        integer,
  sha256       text,
  sort_order   integer not null default 0,
  taken_at     timestamptz not null,
  updated_at   timestamptz not null,
  deleted_at   timestamptz
);

create index photos_point_idx on public.photos (point_id)
  where deleted_at is null;

comment on column public.photos.storage_path is
  'Chemin dans le bucket point-photos : {project_id}/{point_id}/{photo_id}.jpg';

-- -----------------------------------------------------------------------------
-- Rapports générés
-- -----------------------------------------------------------------------------

create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  project_id   uuid not null references public.projects (id),
  storage_path text not null,
  generated_at timestamptz not null default now(),
  generated_by uuid references public.profiles (id)
);

-- -----------------------------------------------------------------------------
-- Last-write-wins : rejet des écritures périmées
-- -----------------------------------------------------------------------------

-- Une tentative rejouée après temporisation peut arriver *après* une écriture
-- plus récente venue d'une autre tablette. Sans ce garde-fou, le retardataire
-- écraserait la version à jour.
--
-- Le trigger rend NULL, ce qui annule silencieusement la mise à jour : l'upsert
-- réussit du point de vue du client, son entrée d'outbox se vide, et la donnée
-- la plus récente reste en place. Renvoyer une erreur ferait au contraire
-- boucler indéfiniment le rejeu.
create or replace function public.reject_stale_write()
returns trigger
language plpgsql
as $$
begin
  if old.updated_at > new.updated_at then
    return null;
  end if;
  return new;
end;
$$;

create trigger clients_reject_stale before update on public.clients
  for each row execute function public.reject_stale_write();
create trigger projects_reject_stale before update on public.projects
  for each row execute function public.reject_stale_write();
create trigger points_reject_stale before update on public.points
  for each row execute function public.reject_stale_write();
create trigger point_materials_reject_stale before update on public.point_materials
  for each row execute function public.reject_stale_write();
create trigger photos_reject_stale before update on public.photos
  for each row execute function public.reject_stale_write();


-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090100_rls.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — sécurité au niveau ligne (RLS)
-- =============================================================================
--
-- C'est **ici** que vit le RBAC, pas dans l'application. L'app masque les
-- chantiers clôturés aux opérateurs, mais ce n'est qu'un confort d'interface :
-- une tablette dont l'horloge dérive, un cache périmé ou un APK modifié
-- contourneraient cette couche. Les policies ci-dessous, non.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fonctions d'aide
-- -----------------------------------------------------------------------------
--
-- Toutes en `security definer`, et ce n'est pas optionnel.
--
-- `is_admin()` lit `profiles`, table elle-même protégée par RLS. Évaluée avec
-- les droits de l'appelant, elle déclencherait la policy de `profiles`, qui
-- appelle `is_admin()`, qui... Postgres coupe avec « infinite recursion
-- detected in policy ». C'est le piège RLS le plus courant sur Supabase.
--
-- `search_path` est figé : sans cela, un rôle capable de créer un schéma
-- pourrait détourner la résolution des noms dans une fonction privilégiée.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_project_member(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.project_members
     where project_id = p_project and user_id = auth.uid()
  );
$$;

create or replace function public.project_is_open(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.projects
     where id = p_project
       and status <> 'completed'
       and deleted_at is null
  );
$$;

-- Remonte au chantier depuis un point : les photos et les matériaux n'ont pas
-- de `project_id` propre.
create or replace function public.point_project(p_point uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select project_id from public.points where id = p_point;
$$;

-- Droit d'écriture d'un opérateur sur le contenu d'un chantier.
create or replace function public.can_write_project(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or (public.is_project_member(p_project)
          and public.project_is_open(p_project));
$$;

-- -----------------------------------------------------------------------------
-- Activation
-- -----------------------------------------------------------------------------

alter table public.profiles         enable row level security;
alter table public.report_templates enable row level security;
alter table public.clients          enable row level security;
alter table public.projects         enable row level security;
alter table public.project_members  enable row level security;
alter table public.points           enable row level security;
alter table public.materials        enable row level security;
alter table public.point_materials  enable row level security;
alter table public.photos           enable row level security;
alter table public.reports          enable row level security;

-- -----------------------------------------------------------------------------
-- Profils
-- -----------------------------------------------------------------------------

-- Lecture ouverte à tous les authentifiés : le rapport PDF nomme l'auteur de
-- chaque relevé, et la liste des points l'affiche.
create policy profiles_select on public.profiles
  for select to authenticated
  using (true);

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy profiles_insert_admin on public.profiles
  for insert to authenticated
  with check (public.is_admin());

-- Verrou d'escalade de privilèges.
--
-- RLS travaille à la **ligne**, jamais à la colonne. `profiles_update_self`
-- autorise donc légitimement un utilisateur à modifier sa propre ligne — nom,
-- courriel... et `role`. Un opérateur n'avait qu'à s'attribuer `admin` pour
-- accéder à tous les chantiers de l'entreprise et rouvrir un rapport clos.
-- Aucune erreur, aucune trace : l'UPDATE réussissait.
--
-- Le contrôle de colonne se fait donc par trigger. On lève une exception plutôt
-- que de rétablir silencieusement l'ancienne valeur : c'est une tentative
-- d'élévation de privilèges, elle doit être bruyante. Aucun client légitime
-- n'écrit ce champ — l'app ne synchronise pas `profiles`.
-- `security invoker` (le défaut), et c'est délibéré : le contrôle porte sur le
-- rôle réel de l'appelant. Dans une fonction `security definer`, `current_user`
-- désigne le propriétaire de la fonction et non l'appelant — la condition
-- serait toujours fausse, et le verrou inopérant.
--
-- Restreindre à `authenticated` laisse passer les migrations (rôle `postgres`)
-- et le worker de rapports (`service_role`), qui doivent pouvoir attribuer des
-- rôles sans détenir eux-mêmes de profil.
create or replace function public.guard_profile_role()
returns trigger
language plpgsql
as $$
begin
  if current_user = 'authenticated'
     and new.role is distinct from old.role
     and not public.is_admin()
  then
    raise exception 'Seul un administrateur peut modifier un role'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger profiles_guard_role
  before update on public.profiles
  for each row execute function public.guard_profile_role();

-- -----------------------------------------------------------------------------
-- Référentiels : templates, clients, matériaux
-- -----------------------------------------------------------------------------

create policy report_templates_select on public.report_templates
  for select to authenticated using (true);
create policy report_templates_write on public.report_templates
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy clients_select on public.clients
  for select to authenticated using (true);
create policy clients_write on public.clients
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy materials_select on public.materials
  for select to authenticated using (true);
create policy materials_write on public.materials
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- Chantiers
-- -----------------------------------------------------------------------------

-- Un opérateur ne voit que ses affectations. C'est aussi ce qui borne le volume
-- descendu sur la tablette : sans cela, chaque appareil dupliquerait localement
-- l'intégralité des chantiers de l'entreprise.
create policy projects_select on public.projects
  for select to authenticated
  using (public.is_admin() or public.is_project_member(id));

-- Création, dates, clôture : prérogatives de l'admin.
create policy projects_write on public.projects
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy project_members_select on public.project_members
  for select to authenticated
  using (public.is_admin() or user_id = auth.uid());

create policy project_members_write on public.project_members
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- Points
-- -----------------------------------------------------------------------------

create policy points_select on public.points
  for select to authenticated
  using (public.is_admin() or public.is_project_member(project_id));

create policy points_insert on public.points
  for insert to authenticated
  with check (public.can_write_project(project_id));

-- `using` autorise la ligne d'origine, `with check` la ligne résultante. Les
-- deux sont nécessaires : sans `with check`, un opérateur pourrait déplacer un
-- point vers un chantier auquel il n'a pas accès.
create policy points_update on public.points
  for update to authenticated
  using (public.can_write_project(project_id))
  with check (public.can_write_project(project_id));

-- Aucune policy DELETE, nulle part et volontairement : la suppression est
-- logique (`deleted_at`), donc un UPDATE. Un DELETE physique serait de toute
-- façon annulé par la prochaine synchro d'un appareil resté hors-ligne.

-- -----------------------------------------------------------------------------
-- Matériaux posés
-- -----------------------------------------------------------------------------

create policy point_materials_select on public.point_materials
  for select to authenticated
  using (
    public.is_admin()
    or public.is_project_member(public.point_project(point_id))
  );

create policy point_materials_insert on public.point_materials
  for insert to authenticated
  with check (public.can_write_project(public.point_project(point_id)));

create policy point_materials_update on public.point_materials
  for update to authenticated
  using (public.can_write_project(public.point_project(point_id)))
  with check (public.can_write_project(public.point_project(point_id)));

-- -----------------------------------------------------------------------------
-- Photos
-- -----------------------------------------------------------------------------

create policy photos_select on public.photos
  for select to authenticated
  using (
    public.is_admin()
    or public.is_project_member(public.point_project(point_id))
  );

create policy photos_insert on public.photos
  for insert to authenticated
  with check (public.can_write_project(public.point_project(point_id)));

create policy photos_update on public.photos
  for update to authenticated
  using (public.can_write_project(public.point_project(point_id)))
  with check (public.can_write_project(public.point_project(point_id)));

-- -----------------------------------------------------------------------------
-- Rapports
-- -----------------------------------------------------------------------------

create policy reports_select on public.reports
  for select to authenticated
  using (public.is_admin() or public.is_project_member(project_id));

-- Produits par le worker Docker, qui se présente en `service_role` et n'est pas
-- soumis à RLS. Un admin peut aussi en déposer un manuellement.
create policy reports_insert on public.reports
  for insert to authenticated
  with check (public.is_admin());


-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090200_storage.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — buckets et policies de stockage
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Buckets
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Photos de traversées. Privé : un rapport de conformité incendie identifie
  -- des vulnérabilités structurelles d'un bâtiment réel.
  --
  -- Plafond à 5 Mo alors qu'un cliché compressé pèse ~400 Ko : ce n'est pas une
  -- marge, c'est un disjoncteur. Si une régression court-circuitait
  -- `ImageCompressor`, les originaux de 4 Mo passeraient inaperçus jusqu'à la
  -- facture. À 5 Mo, ils passent encore — mais l'écart devient visible dans les
  -- métriques du bucket avant d'être coûteux.
  ('point-photos', 'point-photos', false, 5242880, array['image/jpeg']),

  -- Logos clients, injectés dans l'en-tête des rapports.
  ('client-logos', 'client-logos', false, 2097152,
   array['image/png', 'image/jpeg', 'image/svg+xml']),

  -- Rapports PDF générés à la clôture.
  ('reports', 'reports', false, 104857600, array['application/pdf'])
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- point-photos
-- -----------------------------------------------------------------------------
--
-- Chemin : {project_id}/{point_id}/{photo_id}.jpg
-- Le premier segment porte donc le droit d'accès.
--
-- Le transfert utilise `upsert: true` pour rester idempotent après une coupure
-- réseau. Côté Supabase Storage cela se traduit par un UPDATE quand l'objet
-- existe déjà : sans la policy UPDATE ci-dessous, toute **reprise** de
-- transfert échouerait en 403 — précisément le cas que l'idempotence est censée
-- couvrir, et seulement sur réseau instable. Le genre de bug qui ne se
-- manifeste jamais au bureau.

create policy point_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'point-photos'
    and (
      public.is_admin()
      or public.is_project_member(((storage.foldername(name))[1])::uuid)
    )
  );

create policy point_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'point-photos'
    and public.can_write_project(((storage.foldername(name))[1])::uuid)
  );

create policy point_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'point-photos'
    and public.can_write_project(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = 'point-photos'
    and public.can_write_project(((storage.foldername(name))[1])::uuid)
  );

-- Aucune policy DELETE : une photo versée est une pièce justificative. La
-- retirer du rapport se fait en marquant la ligne `photos.deleted_at`, ce qui
-- laisse la preuve en place.

-- -----------------------------------------------------------------------------
-- client-logos
-- -----------------------------------------------------------------------------

create policy client_logos_select on storage.objects
  for select to authenticated
  using (bucket_id = 'client-logos');

create policy client_logos_write on storage.objects
  for all to authenticated
  using (bucket_id = 'client-logos' and public.is_admin())
  with check (bucket_id = 'client-logos' and public.is_admin());

-- -----------------------------------------------------------------------------
-- reports
-- -----------------------------------------------------------------------------
--
-- Chemin : {project_id}/{report_id}.pdf
-- Écriture réservée au worker Docker, qui se présente en `service_role` et
-- échappe donc à RLS. Aucune policy d'écriture pour `authenticated`.

create policy reports_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'reports'
    and (
      public.is_admin()
      or public.is_project_member(((storage.foldername(name))[1])::uuid)
    )
  );


-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090300_sync_cursor.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — curseur de réplication descendante
-- =============================================================================
--
-- `updated_at` ne peut PAS servir de curseur de pull, alors que c'est le
-- réflexe naturel.
--
-- Il est écrit **par le client** : c'est son rôle, il porte la résolution de
-- conflit (last-write-wins) et doit donc refléter l'instant de la saisie, pas
-- celui de l'arrivée. Or une tablette de chantier a l'horloge qu'elle a. Une
-- seule dont la date part en 2027 suffit : son `updated_at` devient le maximum
-- vu par tous les autres appareils, leur curseur saute un an dans le futur, et
-- **plus aucune modification ne redescend jamais**. Panne totale, silencieuse,
-- déclenchée par un appareil tiers.
--
-- `synced_at` est écrit par le serveur, jamais transmis par le client, et sert
-- uniquement de curseur. Deux colonnes parce que ce sont deux responsabilités :
--   * `updated_at` = quand la donnée a changé      (autorité : le client)
--   * `synced_at`  = quand le serveur l'a acceptée (autorité : le serveur)
-- =============================================================================

create or replace function public.touch_synced_at()
returns trigger
language plpgsql
as $$
begin
  -- `clock_timestamp()` et non `now()` : `now()` renvoie l'heure de début de
  -- transaction, identique pour toutes les lignes d'un même lot. L'horloge
  -- murale donne un ordre plus fin à l'intérieur d'un gros envoi.
  new.synced_at := clock_timestamp();
  return new;
end;
$$;

do $$
declare
  t text;
  tables text[] := array[
    'profiles', 'report_templates', 'clients', 'projects',
    'points', 'materials', 'point_materials', 'photos'
  ];
begin
  foreach t in array tables loop
    execute format(
      'alter table public.%I add column if not exists synced_at timestamptz not null default clock_timestamp()',
      t
    );

    -- Le pull interroge exclusivement `synced_at > curseur`. Sans index, chaque
    -- réveil d'une tablette provoquerait un parcours complet de la table.
    execute format(
      'create index if not exists %I on public.%I (synced_at)',
      t || '_synced_at_idx', t
    );

    -- Nom en `_touch_synced` : les triggers se déclenchent par ordre
    -- alphabétique, et celui-ci doit passer APRÈS `_reject_stale`. Une écriture
    -- périmée annulée ne doit pas faire avancer le curseur des autres
    -- appareils, sans quoi ils croiraient avoir reçu une mise à jour.
    execute format(
      'create trigger %I before insert or update on public.%I '
      'for each row execute function public.touch_synced_at()',
      t || '_touch_synced', t
    );
  end loop;
end
$$;

comment on function public.touch_synced_at() is
  'Horodatage serveur servant de curseur au pull. Ne jamais exposer en écriture.';


-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090400_project_members_sync.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — affectations synchronisables, et correction de révocation
-- =============================================================================
--
-- `project_members` était une table purement serveur : personne ne l'écrivait
-- depuis l'application. La console d'administration change cela — un admin doit
-- pouvoir affecter un opérateur à un chantier depuis sa tablette, y compris
-- hors ligne. La table rejoint donc le régime commun : `updated_at` pour
-- l'arbitrage, `deleted_at` pour la suppression logique, `synced_at` pour le
-- curseur de descente.
-- =============================================================================

alter table public.project_members
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz,
  add column if not exists synced_at  timestamptz not null default clock_timestamp();

create index if not exists project_members_synced_at_idx
  on public.project_members (synced_at);

create trigger project_members_reject_stale
  before update on public.project_members
  for each row execute function public.reject_stale_write();

create trigger project_members_touch_synced
  before insert or update on public.project_members
  for each row execute function public.touch_synced_at();

-- -----------------------------------------------------------------------------
-- Correction de sécurité : une affectation retirée doit réellement l'être
-- -----------------------------------------------------------------------------
--
-- `is_project_member()` testait la simple existence de la ligne. Or la
-- suppression est désormais logique : retirer un opérateur d'un chantier laisse
-- sa ligne en place avec `deleted_at` renseigné.
--
-- Sans le filtre ci-dessous, la révocation ne révoquerait rien. Un opérateur
-- écarté d'un chantier — parce qu'il a changé d'équipe, ou quitté
-- l'entreprise — conserverait accès en lecture **et en écriture** à l'ensemble
-- de ses traversées. L'admin le verrait disparaître de la liste des affectés et
-- croirait le problème réglé.
create or replace function public.is_project_member(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.project_members
     where project_id = p_project
       and user_id = auth.uid()
       and deleted_at is null
  );
$$;


-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090500_report_storage.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — dépôt des rapports par un administrateur
-- =============================================================================
--
-- Le bucket `reports` n'acceptait que `service_role`, en prévision d'un worker
-- serveur. Le rapport étant pour l'instant produit dans l'application, l'admin
-- doit pouvoir l'y déposer.
--
-- Réservé aux admins, jamais aux opérateurs : un rapport de conformité est le
-- document remis au client, il n'a qu'un seul auteur légitime.
-- =============================================================================

create policy reports_insert_admin on storage.objects
  for insert to authenticated
  with check (bucket_id = 'reports' and public.is_admin());

-- Regénérer un rapport écrase le précédent au même chemin : le PDF est une
-- donnée **dérivée**, reconstructible à tout moment depuis les traversées. On
-- ne cherche donc pas à en conserver l'historique ici — c'est la table
-- `reports` qui date chaque génération.
create policy reports_update_admin on storage.objects
  for update to authenticated
  using (bucket_id = 'reports' and public.is_admin())
  with check (bucket_id = 'reports' and public.is_admin());


-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090600_tighten_reads.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — resserrage des lectures après ouverture de l'inscription
-- =============================================================================
--
-- **Correction de sécurité.** Les policies de lecture sur `clients` et
-- `profiles` étaient en `using (true)` : tout compte authentifié pouvait les
-- lire intégralement.
--
-- C'était défendable tant que les comptes étaient créés un par un par un
-- administrateur dans le tableau de bord Supabase. L'inscription libre a changé
-- le modèle de menace sans que ces policies ne soient revues : n'importe qui
-- pouvait désormais créer un compte et repartir avec
--
--   * le fichier clients complet — raisons sociales, adresses, noms et
--     coordonnées des contacts, c'est-à-dire le patrimoine commercial ;
--   * l'annuaire du personnel — noms, adresses e-mail et rôles, soit une liste
--     de cibles d'hameçonnage prête à l'emploi, avec les administrateurs
--     désignés.
--
-- Aucune trace n'en serait restée : ce sont des lectures parfaitement légitimes
-- du point de vue du serveur.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fonctions d'aide
-- -----------------------------------------------------------------------------
--
-- `security definer`, comme les autres : elles lisent des tables elles-mêmes
-- protégées par RLS, et seraient sinon prises dans une récursion de policies.

create or replace function public.can_see_client(p_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or exists (
           select 1
             from public.projects p
             join public.project_members m on m.project_id = p.id
            where p.client_id = p_client
              and m.user_id = auth.uid()
              and m.deleted_at is null
         );
$$;

-- Un profil reste visible dans quatre cas, et pas un de plus.
--
-- Le dernier — « a relevé une traversée que je peux voir » — n'est pas du
-- confort : `points.author_id` référence `profiles` **aussi dans la base
-- locale**. Sans lui, la descente d'un point relevé par un administrateur, ou
-- par un collègue depuis retiré du chantier, violerait la clé étrangère et
-- bloquerait la synchronisation de la tablette.
create or replace function public.can_see_profile(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or p_profile = auth.uid()
      -- Les administrateurs sont les interlocuteurs déclarés : leur identité
      -- n'a pas à être cachée aux techniciens.
      or exists (
           select 1 from public.profiles
            where id = p_profile and role = 'admin'
         )
      -- Collègue sur un chantier commun.
      or exists (
           select 1
             from public.project_members mine
             join public.project_members theirs
               on theirs.project_id = mine.project_id
            where mine.user_id = auth.uid()   and mine.deleted_at is null
              and theirs.user_id = p_profile  and theirs.deleted_at is null
         )
      -- Auteur d'une traversée visible.
      or exists (
           select 1
             from public.points pt
             join public.project_members m on m.project_id = pt.project_id
            where pt.author_id = p_profile
              and m.user_id = auth.uid()
              and m.deleted_at is null
         );
$$;

-- -----------------------------------------------------------------------------
-- Application
-- -----------------------------------------------------------------------------

drop policy if exists clients_select on public.clients;
create policy clients_select on public.clients
  for select to authenticated
  using (public.can_see_client(id));

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (public.can_see_profile(id));

-- `materials` et `report_templates` restent lisibles par tout compte
-- authentifié, délibérément : un catalogue de produits coupe-feu et une mise en
-- page de rapport ne sont pas des secrets commerciaux, et `point_materials`
-- comme `clients` les référencent par clé étrangère jusque dans la base locale.


-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090700_materials_scope.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — cloisonnement du catalogue propre à un client
-- =============================================================================
--
-- Durcissement, **pas** une correction de fuite active. À appliquer sans
-- urgence particulière.
--
-- `materials` restait en `using (true)` après le resserrage de `090600`, au
-- motif qu'un catalogue de produits coupe-feu n'est pas un secret. C'est vrai
-- du catalogue **global**, dont tout le monde a besoin. Ça l'est moins des
-- entrées portant un `client_id` : celles-là nomment les produits qu'un client
-- précis impose dans son cahier des charges, ce qui relève de sa relation
-- commerciale.
--
-- Le catalogue global (`client_id is null`) reste évidemment lisible par tous :
-- `point_materials` le référence par clé étrangère jusque dans la base locale
-- des tablettes, et le restreindre casserait la synchronisation.
-- =============================================================================

drop policy if exists materials_select on public.materials;

create policy materials_select on public.materials
  for select to authenticated
  using (
    client_id is null
    or public.can_see_client(client_id)
  );

-- `report_templates` reste délibérément ouvert : une mise en page de rapport ne
-- révèle rien, et `clients.template_id` la référence par clé étrangère.


-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260904090800_letterhead.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — papier à en-tête des rapports
-- =============================================================================
--
-- Un gabarit peut désormais porter le document type de l'entreprise ou de son
-- client : le rapport se compose par-dessus.
--
-- Rattaché au **gabarit** et non au client : c'est une caractéristique de mise
-- en page, au même titre que la couleur d'accentuation. Deux clients partageant
-- le même gabarit partagent le même papier, et un client qui change de charte
-- change de gabarit.
-- =============================================================================

alter table public.report_templates
  add column if not exists letterhead_cover_path text,
  add column if not exists letterhead_body_path  text;

comment on column public.report_templates.letterhead_cover_path is
  'PDF ou image, fond de la page de garde. Chemin dans le bucket letterheads.';
comment on column public.report_templates.letterhead_body_path is
  'Fond des pages suivantes. NULL = la page de garde est réutilisée.';

-- -----------------------------------------------------------------------------
-- Bucket
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'letterheads', 'letterheads', false, 10485760,
  array['application/pdf', 'image/png', 'image/jpeg']
)
on conflict (id) do nothing;

-- Lecture ouverte à tout compte authentifié : un papier à en-tête est le
-- document que l'entreprise imprime et diffuse, et le technicien qui consulte
-- un rapport doit pouvoir l'afficher. Restreindre imposerait de croiser
-- gabarit → client → affectation pour un gain nul.
create policy letterheads_select on storage.objects
  for select to authenticated
  using (bucket_id = 'letterheads');

-- Écriture réservée aux administrateurs : le papier à en-tête engage l'identité
-- visuelle de l'entreprise sur un document contractuel.
create policy letterheads_write on storage.objects
  for all to authenticated
  using (bucket_id = 'letterheads' and public.is_admin())
  with check (bucket_id = 'letterheads' and public.is_admin());

-- -----------------------------------------------------------------------------
-- Logos clients : autoriser aussi le remplacement
-- -----------------------------------------------------------------------------
--
-- `client_logos_write` couvrait déjà `for all`, mais l'envoi depuis
-- l'application utilise `upsert: true` pour rester idempotent après une coupure
-- réseau. Supabase Storage traduit cela en UPDATE quand l'objet existe déjà :
-- sans policy UPDATE explicite, seule la **reprise** d'un envoi échouait — et
-- uniquement sur réseau instable, donc jamais au bureau.
--
-- `for all` inclut bien UPDATE ; ce commentaire existe pour que personne ne la
-- restreigne en `for insert` en croyant durcir quelque chose.


-- >>>>>>>>>>>>>>>>>>>>  supabase/seed.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Données de départ
-- =============================================================================
--
--   supabase db reset          (applique les migrations puis ce fichier)
--
-- Idempotent : rejouable sans effet de bord.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Template PDF par défaut
-- -----------------------------------------------------------------------------
--
-- Contrat lu par le package `firestop_report`. Un client sans `template_id`
-- retombe sur celui-ci.
--
-- `version` n'est pas décoratif : le jour où la structure change, le moteur de
-- rendu doit pouvoir distinguer un template ancien d'un nouveau. Sans lui, un
-- rapport régénéré des années plus tard — ce qu'un dossier de conformité
-- incendie impose de pouvoir faire — sortirait avec une mise en page qui n'est
-- pas celle remise au client à l'époque.

insert into public.report_templates (id, name, config, is_default) values (
  '00000000-0000-4000-8000-000000000001',
  'Standard GEXIM',
  '{
    "version": 1,
    "brand": {
      "accentColor": "#C8102E",
      "showLogo": true
    },
    "cover": {
      "enabled": true,
      "showSummary": true,
      "subtitle": "Rapport de conformité - calfeutrement de traversées"
    },
    "pointCard": {
      "layout": "twoUp",
      "fields": ["ref", "location", "materials", "description", "author", "date"],
      "pageBreak": "perPoint"
    },
    "header": {
      "left": "{{client.name}}",
      "right": "{{project.name}}"
    },
    "footer": {
      "text": "Page {{page}}/{{pages}} - généré le {{date}}"
    }
  }'::jsonb,
  true
)
on conflict (id) do update set
  config     = excluded.config,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- Catalogue global des matériaux
-- -----------------------------------------------------------------------------
--
-- `client_id` nul = disponible sur tous les chantiers. Les produits imposés par
-- le cahier des charges d'un client précis s'ajoutent avec son identifiant.
--
-- Ce catalogue est administré côté serveur et descendu sur les tablettes : le
-- client ne le synchronise jamais en écriture (aucune entrée correspondante
-- dans `OutboxEntity`). Un opérateur choisit dans la liste, il ne l'étend pas —
-- une référence saisie librement sur le terrain ne serait pas traçable en
-- audit.

insert into public.materials (id, label, manufacturer, reference) values
  ('00000000-0000-4000-8000-000000000101', 'Mousse coupe-feu PU',        null, null),
  ('00000000-0000-4000-8000-000000000102', 'Mastic acrylique coupe-feu', null, null),
  ('00000000-0000-4000-8000-000000000103', 'Mastic silicone coupe-feu',  null, null),
  ('00000000-0000-4000-8000-000000000104', 'Collier intumescent',        null, null),
  ('00000000-0000-4000-8000-000000000105', 'Bandage intumescent',        null, null),
  ('00000000-0000-4000-8000-000000000106', 'Coussin coupe-feu',          null, null),
  ('00000000-0000-4000-8000-000000000107', 'Panneau laine de roche enduit', null, null),
  ('00000000-0000-4000-8000-000000000108', 'Plâtre coupe-feu',           null, null),
  ('00000000-0000-4000-8000-000000000109', 'Manchon coupe-feu',          null, null),
  ('00000000-0000-4000-8000-000000000110', 'Enduit projeté coupe-feu',   null, null)
on conflict (id) do update set
  label      = excluded.label,
  updated_at = now();
