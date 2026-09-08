-- =============================================================================
-- Émulation minimale de Supabase sur un Postgres nu
-- =============================================================================
--
-- Uniquement destiné au banc d'essai local (`docker/docker-compose.yml`). Ce
-- fichier n'est jamais appliqué sur l'environnement Supabase, qui fournit déjà
-- tout ce qui suit.
--
-- Objectif : faire tourner **les migrations réelles, inchangées**, pour vérifier
-- les policies RLS avant de les pousser. Une policy trop permissive ne provoque
-- aucune erreur — elle laisse simplement passer. Sans banc d'essai, on ne
-- l'apprend qu'après.
-- =============================================================================

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Rôles
-- -----------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

grant anon, authenticated, service_role to postgres;

-- -----------------------------------------------------------------------------
-- Schéma auth
-- -----------------------------------------------------------------------------

create schema if not exists auth;

create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at         timestamptz not null default now()
);

-- Reprise fidèle de l'implémentation Supabase : l'identité vient du JWT, pas
-- d'une variable de session maison. Les tests peuvent ainsi endosser une
-- identité exactement comme le fait PostgREST en production.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(
    current_setting('request.jwt.claims', true)::jsonb ->> 'sub',
    ''
  )::uuid;
$$;

grant usage on schema auth to authenticated, anon, service_role;

-- -----------------------------------------------------------------------------
-- Schéma storage
-- -----------------------------------------------------------------------------

create schema if not exists storage;

create table if not exists storage.buckets (
  id                 text primary key,
  name               text not null,
  public             boolean not null default false,
  file_size_limit    bigint,
  allowed_mime_types text[],
  created_at         timestamptz not null default now()
);

create table if not exists storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text not null references storage.buckets (id),
  name       text not null,
  owner      uuid,
  created_at timestamptz not null default now(),
  unique (bucket_id, name)
);

alter table storage.objects enable row level security;

-- Tout sauf le dernier segment du chemin : « a/b/c.jpg » donne {a, b}.
create or replace function storage.foldername(name text)
returns text[]
language plpgsql
immutable
as $$
declare
  parts text[];
begin
  parts := string_to_array(name, '/');
  return parts[1 : array_length(parts, 1) - 1];
end;
$$;

grant usage on schema storage to authenticated, anon, service_role;
grant select, insert, update on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
