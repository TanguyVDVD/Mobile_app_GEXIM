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
