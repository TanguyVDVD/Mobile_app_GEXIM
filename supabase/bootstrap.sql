-- =============================================================================
-- FireStop Tracker -- installation initiale, en un seul bloc
-- =============================================================================
--
-- FICHIER GENERE par tools/bootstrap.dart. Ne pas modifier : la source de
-- verite reste supabase/migrations/.
--
-- A coller tel quel dans le SQL Editor de Supabase, pour un projet VIERGE.
-- Toute evolution ulterieure passe par une nouvelle migration, jamais par ce
-- fichier -- le rejouer sur une base existante echouerait sur les types et
-- policies deja crees.
-- =============================================================================

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260913100000_schema.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — schéma
-- =============================================================================
--
-- Miroir distant de la base locale Drift (`lib/database/tables/tables.dart`).
-- Les noms de colonnes doivent correspondre exactement à ceux produits par
-- `lib/sync/payloads.dart` : c'est le contrat de synchronisation.
--
-- Conventions, les mêmes qu'en local :
--   * `id` en uuid, généré **côté client** (v7). Le serveur n'en fabrique
--     jamais : un technicien crée une traversée sans réseau.
--   * `updated_at` porte la résolution de conflit (last-write-wins). Écrit par
--     le client, il date la saisie.
--   * `synced_at` est le curseur de descente. Écrit par le serveur, jamais
--     transmis par le client.
--   * `deleted_at` : suppression logique. Aucun DELETE physique — un appareil
--     resté hors ligne ressusciterait la ligne à sa prochaine synchronisation.
--
-- Les droits d'accès sont dans `20260913100100_rls.sql`, le stockage des
-- fichiers dans `20260913100200_storage.sql`.
-- =============================================================================

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Types
-- -----------------------------------------------------------------------------

create type public.user_role as enum ('admin', 'operator');

create type public.project_status as enum ('in_progress', 'completed');

-- `before` et `after` sont les deux cases imprimées de la fiche — « Photo 1 » et
-- « Photo 2 » à l'écran. `extra` : les clichés complémentaires, en page de
-- suite du rapport.
create type public.photo_kind as enum ('before', 'after', 'extra');

-- Les six listes déroulantes de la fiche de traversée. Les *valeurs* de ces
-- listes sont des données (`setting_options`) ; seule leur *nature* est figée
-- ici, parce que chacune correspond à une colonne de `points` et à une ligne du
-- formulaire imprimé.
create type public.setting_kind as enum (
  'configuration',
  'configuration_detail',
  'ei_level',
  'supplier',
  'product_type',
  'product'
);

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text        not null default '',
  email       text        not null default '',
  role        public.user_role not null default 'operator',
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default clock_timestamp()
);

comment on table public.profiles is
  'Rôle applicatif. Pilote l''intégralité des policies RLS.';
comment on column public.profiles.role is
  'Jamais transmis par le client : tout compte naît operator, et seul un '
  'administrateur le fait évoluer (voir guard_profile_role).';

create table public.clients (
  id            uuid primary key,
  name          text not null check (length(name) between 1 and 200),
  contact_name  text,
  contact_email text,
  contact_phone text,
  address       text not null check (length(address) > 0),
  logo_path     text not null check (length(logo_path) > 0),
  created_at    timestamptz not null,
  updated_at    timestamptz not null,
  deleted_at    timestamptz,
  synced_at     timestamptz not null default clock_timestamp()
);

comment on column public.clients.address is
  'Reportée dans la case « adresse client » de chaque fiche du rapport.';
comment on column public.clients.logo_path is
  'Chemin dans le bucket client-logos. Posé dans la case « logo client » de '
  'chaque fiche.';

create table public.projects (
  id          uuid primary key,
  client_id   uuid not null references public.clients (id),
  code        text,
  name        text not null check (length(name) between 1 and 200),
  description text,
  started_on  timestamptz,
  ended_on    timestamptz,
  status      public.project_status not null default 'in_progress',
  created_at  timestamptz not null,
  updated_at  timestamptz not null,
  deleted_at  timestamptz,
  synced_at   timestamptz not null default clock_timestamp()
);

comment on column public.projects.code is
  'Numéro de chantier du donneur d''ordre, reporté sur chaque fiche du rapport.';
comment on column public.projects.status is
  'completed gèle le relevé : plus aucune écriture de technicien n''est '
  'acceptée (voir can_write_project).';

-- La **seule** relation utilisateur ↔ chantier. Toutes les policies d'accès au
-- contenu d'un chantier l'interrogent (`is_project_member`).
create table public.project_members (
  project_id uuid not null references public.projects (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  added_at   timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  synced_at  timestamptz not null default clock_timestamp(),
  primary key (project_id, user_id)
);

create table public.setting_options (
  id         uuid primary key,
  kind       public.setting_kind not null,
  label      text not null check (length(label) between 1 and 120),
  sort_order integer not null default 0,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at  timestamptz not null default clock_timestamp()
);

comment on table public.setting_options is
  'Valeurs des listes déroulantes de la fiche de traversée. Administrées, '
  'jamais saisies librement : deux orthographes du même produit deviendraient '
  'deux produits en audit de conformité.';
comment on column public.setting_options.sort_order is
  'Rang d''affichage. Explicite et non alphabétique : EI120 passerait avant '
  'EI30.';

create table public.points (
  id                      uuid primary key,
  project_id              uuid not null references public.projects (id),
  -- Attribué par `assign_point_ref_number`, jamais par le client.
  ref_number              integer,
  purchase_order          text,
  building                text,
  floor_level             integer,
  room                    text,
  description             text,
  configuration_id        uuid references public.setting_options (id),
  configuration_detail_id uuid references public.setting_options (id),
  ei_level_id             uuid references public.setting_options (id),
  supplier_id             uuid references public.setting_options (id),
  product_type_id         uuid references public.setting_options (id),
  product1_id             uuid references public.setting_options (id),
  product2_id             uuid references public.setting_options (id),
  product3_id             uuid references public.setting_options (id),
  product4_id             uuid references public.setting_options (id),
  product5_id             uuid references public.setting_options (id),
  author_id               uuid not null references public.profiles (id),
  captured_at             timestamptz not null,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null,
  deleted_at              timestamptz,
  synced_at               timestamptz not null default clock_timestamp(),

  -- Filet de sécurité du trigger de numérotation.
  unique (project_id, ref_number),

  -- La même borne que la liste déroulante (`floorRange`, côté Dart).
  constraint points_floor_level_range
    check (floor_level is null or floor_level between -3 and 5)
);

comment on column public.points.purchase_order is
  'Bon de commande du client. Terme anglais conservé : c''est celui des pièces '
  'contractuelles.';
comment on column public.points.floor_level is
  'Étage, -3 à 5. Entier et non texte : c''est un axe ordonné.';
comment on column public.points.product_type_id is
  'Nature du produit posé (manchon, mortier…). La référence commerciale, elle, '
  'occupe les cinq colonnes product1_id à product5_id.';
comment on column public.points.product1_id is
  'Cinq colonnes et non une table d''association : l''arité est fixe et la '
  'position signifiante — « Produit utilisé (3) » reste le troisième même si '
  'le deuxième est vide.';

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
  deleted_at   timestamptz,
  synced_at    timestamptz not null default clock_timestamp()
);

comment on column public.photos.storage_path is
  'Chemin dans le bucket point-photos : {project_id}/{point_id}/{photo_id}.jpg '
  '(imposé par guard_photo_path).';

-- Rapports déposés. Le PDF est une donnée dérivée, régénérable à tout moment :
-- cette table date chaque dépôt, rien de plus.
create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  project_id   uuid not null references public.projects (id),
  storage_path text not null,
  generated_at timestamptz not null default now(),
  generated_by uuid references public.profiles (id) default auth.uid()
);

-- -----------------------------------------------------------------------------
-- Index
-- -----------------------------------------------------------------------------

create index projects_client_idx on public.projects (client_id)
  where deleted_at is null;
create index project_members_user_idx on public.project_members (user_id);
create index points_project_idx on public.points (project_id)
  where deleted_at is null;
create index photos_point_idx on public.photos (point_id)
  where deleted_at is null;
create index setting_options_kind_idx on public.setting_options (kind, sort_order)
  where deleted_at is null;

-- La descente interroge exclusivement `synced_at > curseur`. Sans index, chaque
-- réveil d'une tablette provoquerait un parcours complet de la table.
create index profiles_synced_at_idx        on public.profiles        (synced_at);
create index clients_synced_at_idx         on public.clients         (synced_at);
create index projects_synced_at_idx        on public.projects        (synced_at);
create index project_members_synced_at_idx on public.project_members (synced_at);
create index setting_options_synced_at_idx on public.setting_options (synced_at);
create index points_synced_at_idx          on public.points          (synced_at);
create index photos_synced_at_idx          on public.photos          (synced_at);

-- -----------------------------------------------------------------------------
-- Profil créé à l'inscription
-- -----------------------------------------------------------------------------
--
-- Un compte sans profil n'aurait aucun rôle, donc aucun accès — et l'échec
-- serait muet côté application.

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
-- Numéro définitif d'une traversée
-- -----------------------------------------------------------------------------
--
-- Le client n'envoie jamais `ref_number` : deux techniciens hors ligne
-- créeraient tous deux le « point 47 » sans pouvoir trancher. Le numéro est
-- attribué ici, à l'arrivée, dans l'ordre réel de synchronisation.

create or replace function public.assign_point_ref_number()
returns trigger
language plpgsql
-- `security definer` : la fonction lit `points`, table protégée par RLS.
-- Exécutée avec les droits de l'appelant, son `max()` ne verrait que les
-- lignes visibles de cet utilisateur, et repartirait d'un numéro déjà pris.
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

  -- Sérialise les insertions du même chantier le temps de la transaction :
  -- sans ce verrou, deux tablettes synchronisant ensemble liraient le même
  -- `max()`.
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
-- Réplication : last-write-wins et curseur serveur
-- -----------------------------------------------------------------------------
--
-- Une écriture rejouée après temporisation peut arriver *après* une écriture
-- plus récente venue d'une autre tablette. Le trigger rend alors NULL, ce qui
-- annule silencieusement la mise à jour : l'upsert réussit du point de vue du
-- client, son entrée d'outbox se vide, et la donnée la plus récente reste en
-- place. Lever une erreur ferait boucler le rejeu indéfiniment.
--
-- C'est la même règle que le `WHERE` du `ON CONFLICT` de `PullEngine._upsert`,
-- côté client : les deux extrémités arbitrent à l'identique.

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

-- `updated_at` ne peut PAS servir de curseur : il vient des tablettes, et une
-- seule horloge déréglée propulserait le curseur de tous les autres appareils
-- dans le futur. `synced_at` est posé ici, et seulement ici.
--
-- `clock_timestamp()` et non `now()` : `now()` rend l'heure de début de
-- transaction, identique pour toutes les lignes d'un même lot.
create or replace function public.touch_synced_at()
returns trigger
language plpgsql
as $$
begin
  new.synced_at := clock_timestamp();
  return new;
end;
$$;

comment on function public.touch_synced_at() is
  'Horodatage serveur servant de curseur à la descente. Jamais transmis par '
  'le client.';

-- Les triggers d'une table se déclenchent par ordre alphabétique de nom :
-- `_reject_stale` passe donc AVANT `_touch_synced`. Une écriture périmée annulée
-- ne doit pas faire avancer le curseur des autres appareils, sans quoi ils
-- croiraient avoir reçu une mise à jour.

create trigger clients_reject_stale before update on public.clients
  for each row execute function public.reject_stale_write();
create trigger projects_reject_stale before update on public.projects
  for each row execute function public.reject_stale_write();
create trigger project_members_reject_stale before update on public.project_members
  for each row execute function public.reject_stale_write();
create trigger setting_options_reject_stale before update on public.setting_options
  for each row execute function public.reject_stale_write();
create trigger points_reject_stale before update on public.points
  for each row execute function public.reject_stale_write();
create trigger photos_reject_stale before update on public.photos
  for each row execute function public.reject_stale_write();

create trigger profiles_touch_synced before insert or update on public.profiles
  for each row execute function public.touch_synced_at();
create trigger clients_touch_synced before insert or update on public.clients
  for each row execute function public.touch_synced_at();
create trigger projects_touch_synced before insert or update on public.projects
  for each row execute function public.touch_synced_at();
create trigger project_members_touch_synced
  before insert or update on public.project_members
  for each row execute function public.touch_synced_at();
create trigger setting_options_touch_synced
  before insert or update on public.setting_options
  for each row execute function public.touch_synced_at();
create trigger points_touch_synced before insert or update on public.points
  for each row execute function public.touch_synced_at();
create trigger photos_touch_synced before insert or update on public.photos
  for each row execute function public.touch_synced_at();

-- -----------------------------------------------------------------------------
-- Une affectation rend son chantier téléchargeable
-- -----------------------------------------------------------------------------
--
-- La descente est incrémentale : une tablette demande les lignes dont
-- `synced_at` dépasse son curseur. Or affecter quelqu'un ne modifie pas le
-- chantier — cela change ce que RLS laisse voir. Le chantier, créé la semaine
-- d'avant, garde un `synced_at` antérieur au curseur d'un technicien qui
-- travaillait déjà ailleurs : **la ligne devient visible et n'est jamais
-- envoyée**.
--
-- `synced_at` ne dit donc pas « quand la donnée a changé », mais « quand le
-- serveur a décidé qu'elle devait partir ». Une ligne qui devient visible doit
-- être réestampillée exactement comme une ligne modifiée.
--
-- Seulement à l'octroi : une révocation n'ouvre rien, c'est le tombstone de
-- l'affectation qui redescend et ferme la porte. Réestampiller là ferait
-- re-descendre le chantier entier chez tous les autres membres, pour rien.

create or replace function public.refresh_project_visibility()
returns trigger
language plpgsql
-- Réestampille des lignes que l'appelant n'a pas forcément le droit de
-- modifier. En pratique seul un admin écrit `project_members`, mais adosser la
-- correction à une policy la rendrait fragile.
security definer
set search_path = public
as $$
declare
  v_client uuid;
begin
  if new.deleted_at is not null then
    return null;
  end if;

  -- Sur UPDATE, seule la résurrection d'une affectation retirée ouvre un accès.
  if tg_op = 'UPDATE' and old.deleted_at is null then
    return null;
  end if;

  select client_id into v_client
    from public.projects where id = new.project_id;

  update public.clients  set synced_at = clock_timestamp() where id = v_client;
  update public.projects set synced_at = clock_timestamp()
   where id = new.project_id;
  update public.points   set synced_at = clock_timestamp()
   where project_id = new.project_id;
  update public.photos   set synced_at = clock_timestamp()
   where point_id in (
     select id from public.points where project_id = new.project_id
   );

  -- Les auteurs des traversées deviennent visibles avec elles
  -- (`can_see_profile`) : sans cela, `points.author_id` pointerait vers un
  -- profil absent de la base locale — une violation de clé étrangère.
  update public.profiles set synced_at = clock_timestamp()
   where id in (
     select distinct author_id from public.points
      where project_id = new.project_id
   );

  return null;
end;
$$;

create trigger project_members_refresh_visibility
  after insert or update on public.project_members
  for each row execute function public.refresh_project_visibility();

-- -----------------------------------------------------------------------------
-- Valeurs initiales des listes de la fiche
-- -----------------------------------------------------------------------------
--
-- Ici et non dans des données de démonstration : sans elles, la fiche de
-- traversée n'a rien à proposer. Un administrateur les complète ensuite depuis
-- l'écran Paramètres.
--
-- `not exists` sur (kind, label) : ce bloc peut être rejoué seul pour compléter
-- un catalogue sans créer de doublon.

insert into public.setting_options (id, kind, label, sort_order, updated_at)
select gen_random_uuid(), v.kind::public.setting_kind, v.label, v.ord, now()
  from (values
    ('configuration', 'Traversée de paroi verticale',   0),
    ('configuration', 'Traversée de paroi horizontale', 1),
    ('configuration', 'Percement de paroi verticale',   2),
    ('configuration', 'Percement de paroi horizontale', 3),
    ('configuration', 'Ouverture linéaire verticale',   4),
    ('configuration', 'Ouverture linéaire horizontale', 5),

    ('configuration_detail', 'Conduite synthétique',            0),
    ('configuration_detail', 'Conduite métallique',             1),
    ('configuration_detail', 'Chemin de câbles',                2),
    ('configuration_detail', 'Câbles sans support',             3),
    ('configuration_detail', 'Fissure/Retrait entre matériaux', 4),
    ('configuration_detail', 'Trou',                            5),

    -- Ordre croissant explicite : l'alphabet placerait EI120 en tête.
    ('ei_level', 'EI30',  0),
    ('ei_level', 'EI60',  1),
    ('ei_level', 'EI90',  2),
    ('ei_level', 'EI120', 3),

    ('supplier', 'Promat', 0),

    ('product_type', 'Combinaison de produits', 0),
    ('product_type', 'Manchon',                 1),
    ('product_type', 'Panneau LR enduit',       2),
    ('product_type', 'Produit liquide',         3),
    ('product_type', 'Produit pâteux (joint)',  4),
    ('product_type', 'Mortier',                 5),
    ('product_type', 'Mousse 1 comp',           6),
    ('product_type', 'Mousse 2 comp',           7),
    ('product_type', 'Brique foisonnante',      8),
    ('product_type', 'Sachet foisonnant',       9),

    ('product', 'Promastop-FC',         0),
    ('product', 'Promastop-UCE',        1),
    ('product', 'Promastop-FC MD',      2),
    ('product', 'Promastop-W',          3),
    ('product', 'Promastop-CC liquide', 4),
    ('product', 'Promastop-B',          5),
    ('product', 'Promastop-P',          6),
    ('product', 'Promastop-M',          7),
    ('product', 'Promastop-IM Cbox',    8),
    ('product', 'Promaseal-AG',         9),
    ('product', 'Promastop-CC panneau', 10),
    ('product', 'Promaseal-A',          11),
    ('product', 'Promafoam-C',          12),
    ('product', 'Promastop-CC',         13),
    ('product', 'Promaseal-S',          14),
    ('product', 'Alsijoint',            15),
    ('product', 'Promaseal-A Spray',    16)
  ) as v (kind, label, ord)
 where not exists (
   select 1 from public.setting_options s
    where s.kind = v.kind::public.setting_kind
      and s.label = v.label
 );

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260913100100_rls.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — droits d'accès
-- =============================================================================
--
-- C'est **ici** que vit le RBAC, pas dans l'application. L'app masque ce
-- qu'un technicien ne doit pas voir, mais ce n'est qu'un confort d'interface :
-- un APK modifié, une tablette à l'heure fausse ou un appel direct à l'API se
-- heurtent aux règles qui suivent, et à elles seules.
--
-- Deux étages :
--   * les **policies RLS** décident, ligne par ligne, qui lit et qui écrit ;
--   * des **triggers de garde** protègent les colonnes qu'une policy ne sait
--     pas protéger — RLS travaille à la ligne, jamais à la colonne.
--
-- Une policy trop permissive ne produit aucune erreur : elle laisse passer. Les
-- refus sont donc prouvés par `docker/rls_tests.sql`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fonctions d'aide
-- -----------------------------------------------------------------------------
--
-- Toutes en `security definer`, et ce n'est pas optionnel : elles lisent des
-- tables elles-mêmes protégées par RLS. Évaluées avec les droits de l'appelant,
-- la policy de `profiles` appellerait `is_admin()`, qui lirait `profiles`, qui…
-- Postgres coupe avec « infinite recursion detected in policy ».
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

-- Une affectation retirée l'est **logiquement** : sa ligne reste, avec
-- `deleted_at`. Sans ce filtre, la révocation ne révoquerait rien — le
-- technicien écarté garderait lecture et écriture sur tout le chantier.
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

-- Remonte au chantier depuis une traversée : les clichés n'ont pas de
-- `project_id` propre.
create or replace function public.point_project(p_point uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select project_id from public.points where id = p_point;
$$;

-- Droit d'écriture sur le contenu d'un chantier : l'admin toujours, le
-- technicien s'il y est affecté et que le chantier n'est pas clôturé.
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

-- L'inscription étant ouverte à tous, ce qu'un compte peut **lire** est une
-- surface publique. Un client n'est visible que de l'admin et des techniciens
-- affectés à l'un de ses chantiers — sans quoi n'importe qui repartirait avec
-- le fichier clients complet.
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

-- Un profil reste visible dans quatre cas, et pas un de plus — sans quoi
-- l'annuaire du personnel, administrateurs désignés compris, serait une liste
-- de cibles d'hameçonnage prête à l'emploi.
--
-- Le dernier cas — « a relevé une traversée que je peux voir » — n'est pas du
-- confort : `points.author_id` référence `profiles` **aussi dans la base
-- locale**. Sans lui, la descente d'une traversée relevée par un collègue
-- depuis retiré du chantier violerait la clé étrangère et bloquerait la
-- synchronisation.
create or replace function public.can_see_profile(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or p_profile = auth.uid()
      -- Les administrateurs sont les interlocuteurs déclarés.
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
-- Activation
-- -----------------------------------------------------------------------------

alter table public.profiles        enable row level security;
alter table public.clients         enable row level security;
alter table public.projects        enable row level security;
alter table public.project_members enable row level security;
alter table public.setting_options enable row level security;
alter table public.points          enable row level security;
alter table public.photos          enable row level security;
alter table public.reports         enable row level security;

-- Aucune policy DELETE, nulle part et volontairement : la suppression est
-- logique (`deleted_at`), donc un UPDATE.

-- -----------------------------------------------------------------------------
-- Profils
-- -----------------------------------------------------------------------------

create policy profiles_select on public.profiles
  for select to authenticated
  using (public.can_see_profile(id));

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy profiles_insert_admin on public.profiles
  for insert to authenticated
  with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- Clients et chantiers
-- -----------------------------------------------------------------------------

create policy clients_select on public.clients
  for select to authenticated
  using (public.can_see_client(id));
create policy clients_write on public.clients
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Un technicien ne voit que ses affectations. C'est aussi ce qui borne le
-- volume descendu sur chaque tablette.
create policy projects_select on public.projects
  for select to authenticated
  using (public.is_admin() or public.is_project_member(id));
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
-- Listes de la fiche
-- -----------------------------------------------------------------------------
--
-- Lecture ouverte à tout compte authentifié, et il faut qu'elle le reste :
-- `points` référence ces lignes par clé étrangère **jusque dans la base locale
-- des tablettes**. Une option invisible ferait échouer la descente de la
-- traversée qui la désigne. Le contenu ne justifie de toute façon aucun
-- secret : ce sont des noms de produits au catalogue du fabricant.

create policy setting_options_select on public.setting_options
  for select to authenticated
  using (true);
create policy setting_options_write on public.setting_options
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- Traversées et clichés
-- -----------------------------------------------------------------------------
--
-- `using` autorise la ligne d'origine, `with check` la ligne résultante. Les
-- deux sont nécessaires : sans `with check`, un technicien pourrait déplacer
-- une traversée vers un chantier auquel il n'a pas accès.

create policy points_select on public.points
  for select to authenticated
  using (public.is_admin() or public.is_project_member(project_id));
create policy points_insert on public.points
  for insert to authenticated
  with check (public.can_write_project(project_id));
create policy points_update on public.points
  for update to authenticated
  using (public.can_write_project(project_id))
  with check (public.can_write_project(project_id));

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
--
-- Un rapport de conformité est le document remis au client : il n'a qu'un
-- auteur légitime, l'administrateur.

create policy reports_select on public.reports
  for select to authenticated
  using (public.is_admin() or public.is_project_member(project_id));
create policy reports_insert on public.reports
  for insert to authenticated
  with check (public.is_admin());

-- =============================================================================
-- Gardes de colonne
-- =============================================================================
--
-- Des triggers `security invoker` — le défaut — et c'est délibéré : ils testent
-- `current_user`, qui désignerait le propriétaire de la fonction dans une
-- fonction `security definer`. La condition serait toujours fausse, et le
-- verrou inopérant tout en paraissant correct.
--
-- Restreints à `authenticated`, ils laissent passer les migrations et
-- `service_role`. Ils lèvent plutôt que de corriger en silence : l'application
-- n'écrit jamais ces valeurs autrement, un écart est donc une tentative.

-- -----------------------------------------------------------------------------
-- Rôle d'un profil
-- -----------------------------------------------------------------------------
--
-- `profiles_update_self` autorise légitimement un utilisateur à modifier sa
-- propre ligne — nom, courriel… et `role`. Sans ce trigger, un technicien
-- n'avait qu'à s'attribuer `admin`.

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
-- Auteur d'une traversée
-- -----------------------------------------------------------------------------
--
-- À la création, l'auteur est l'appelant ; ensuite il ne bouge plus. Un
-- collègue qui complète la fiche la modifie, il n'en devient pas l'auteur. Sur
-- un dossier de conformité incendie, « qui a posé ce calfeutrement » n'est pas
-- une métadonnée anodine. L'administrateur est exempté : il peut avoir à
-- reprendre un relevé au nom de quelqu'un.
--
-- **Le piège de l'upsert.** Toutes les écritures de l'application sont des
-- `INSERT ... ON CONFLICT DO UPDATE`, et Postgres déclenche `BEFORE INSERT` sur
-- la ligne proposée **avant** de constater le conflit. La requête d'un collègue
-- arrive donc en insertion, avec l'`author_id` d'origine : d'où le test
-- d'existence. Il passe par RLS, et c'est voulu — une ligne invisible pour
-- l'appelant est traitée comme neuve, donc refusée si elle prétend à un autre
-- auteur.

create or replace function public.guard_point_author()
returns trigger
language plpgsql
as $$
begin
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT'
     and new.author_id is distinct from auth.uid()
     and not exists (select 1 from public.points where id = new.id)
  then
    raise exception 'Une traversee ne se cree qu''au nom de son auteur'
      using errcode = 'insufficient_privilege';
  end if;

  if tg_op = 'UPDATE' and new.author_id is distinct from old.author_id then
    raise exception 'L''auteur d''une traversee ne se modifie pas'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

create trigger points_guard_author
  before insert or update on public.points
  for each row execute function public.guard_point_author();

-- -----------------------------------------------------------------------------
-- Chemin d'un cliché
-- -----------------------------------------------------------------------------
--
-- Le chemin est déterministe : `{project_id}/{point_id}/{photo_id}.jpg`, tel
-- que `PhotoUploader` le construit. Sans cette garde, une ligne pouvait
-- désigner l'objet d'un autre chantier du bucket : le technicien ne l'aurait
-- pas lu, mais l'administrateur, si — et la photo d'un autre bâtiment serait
-- sortie sur le rapport. Une mise à jour qui ne touche pas au chemin n'est pas
-- re-contrôlée.

create or replace function public.guard_photo_path()
returns trigger
language plpgsql
as $$
declare
  attendu text;
begin
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  if tg_op = 'UPDATE' and new.storage_path is not distinct from old.storage_path
  then
    return new;
  end if;

  attendu := public.point_project(new.point_id)::text
          || '/' || new.point_id::text
          || '/' || new.id::text || '.jpg';

  if new.storage_path is distinct from attendu then
    raise exception 'Chemin de cliche incoherent avec sa traversee : %',
      new.storage_path
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

create trigger photos_guard_path
  before insert or update on public.photos
  for each row execute function public.guard_photo_path();

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20260913100200_storage.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- FireStop Tracker — stockage des fichiers
-- =============================================================================
--
-- Trois buckets, tous privés. Le premier segment d'un chemin porte le droit
-- d'accès : c'est l'identifiant du chantier (clichés, rapports) ou du client
-- (logos).
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Clichés de traversée. Privé : un rapport de conformité incendie identifie
  -- des vulnérabilités structurelles d'un bâtiment réel.
  --
  -- Plafond à 5 Mo alors qu'un cliché compressé pèse quelques centaines de
  -- kilo-octets : ce n'est pas une marge, c'est un disjoncteur. Si une
  -- régression court-circuitait la compression, les originaux passeraient
  -- encore — mais l'écart deviendrait visible avant d'être coûteux.
  ('point-photos', 'point-photos', false, 5242880, array['image/jpeg']),

  -- Logos clients, posés en tête de chaque fiche. PNG ou JPEG : ce sont les
  -- deux formats que l'écran client propose et que le moteur PDF sait rendre.
  ('client-logos', 'client-logos', false, 2097152,
   array['image/png', 'image/jpeg']),

  -- Rapports PDF déposés par l'administrateur.
  ('reports', 'reports', false, 104857600, array['application/pdf'])
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- point-photos — chemin {project_id}/{point_id}/{photo_id}.jpg
-- -----------------------------------------------------------------------------
--
-- Le dépôt utilise `upsert: true` pour rester idempotent après une coupure, ce
-- que Supabase Storage traduit en UPDATE quand l'objet existe déjà. Sans la
-- policy UPDATE, seule la **reprise** d'un transfert échouerait — et seulement
-- sur réseau instable, donc jamais au bureau.
--
-- Aucune policy DELETE : un cliché versé est une pièce justificative. Le
-- retirer du rapport, c'est marquer `photos.deleted_at`.

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

-- -----------------------------------------------------------------------------
-- client-logos — chemin {client_id}/{uuid}.{png|jpg}
-- -----------------------------------------------------------------------------
--
-- Lecture ouverte à tout compte authentifié : un technicien peut générer le
-- rapport de son chantier, et le logo y figure. Écriture réservée à
-- l'administrateur — `for all`, qui couvre l'UPDATE de l'upsert.

create policy client_logos_select on storage.objects
  for select to authenticated
  using (bucket_id = 'client-logos');

create policy client_logos_write on storage.objects
  for all to authenticated
  using (bucket_id = 'client-logos' and public.is_admin())
  with check (bucket_id = 'client-logos' and public.is_admin());

-- -----------------------------------------------------------------------------
-- reports — chemin {project_id}/rapport.pdf
-- -----------------------------------------------------------------------------
--
-- Regénérer un rapport écrase le précédent au même chemin : le PDF est une
-- donnée dérivée, et c'est la table `reports` qui date chaque dépôt.

create policy reports_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'reports'
    and (
      public.is_admin()
      or public.is_project_member(((storage.foldername(name))[1])::uuid)
    )
  );

create policy reports_insert_admin on storage.objects
  for insert to authenticated
  with check (bucket_id = 'reports' and public.is_admin());

create policy reports_update_admin on storage.objects
  for update to authenticated
  using (bucket_id = 'reports' and public.is_admin())
  with check (bucket_id = 'reports' and public.is_admin());

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20261003100000_product_supplier.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Un produit appartient à un fournisseur
-- =============================================================================
--
-- Jusqu'ici « fournisseur » et « produit » étaient deux listes indépendantes :
-- la fiche laissait choisir Promat puis un produit d'un autre fabricant. Le
-- produit désigne désormais son fournisseur, et la fiche ne propose que les
-- produits du fournisseur choisi.
--
-- Une colonne sur `setting_options` et non une table d'association : un
-- produit n'a qu'un fabricant, et la relation suit ainsi le même chemin de
-- synchronisation, les mêmes policies et le même last-write-wins que la ligne
-- qui la porte.
--
-- Fichier séparé, contrairement aux trois précédents : le schéma est déjà
-- installé sur le projet en ligne, il faut pouvoir le faire évoluer.

alter table public.setting_options
  add column parent_id uuid references public.setting_options (id);

alter table public.setting_options
  add constraint setting_options_parent_only_product
  check (parent_id is null or kind = 'product');

comment on column public.setting_options.parent_id is
  'Fournisseur d''un produit. Nul pour toute autre liste. Un produit sans '
  'fournisseur n''est proposé sur aucune fiche : l''écran Paramètres le '
  'signale et permet de le rattacher.';

create index setting_options_parent_idx
  on public.setting_options (parent_id, sort_order)
  where deleted_at is null;

-- La contrainte CHECK ne voit que la ligne ; que le parent soit bien un
-- fournisseur demande une lecture, donc un trigger.
--
-- `security invoker`, par défaut : la lecture de `setting_options` est ouverte
-- à tout compte authentifié, il n'y a rien à contourner.
create or replace function public.guard_option_parent()
returns trigger
language plpgsql
as $$
begin
  if new.parent_id is not null and not exists (
    select 1 from public.setting_options s
     where s.id = new.parent_id
       and s.kind = 'supplier'
  ) then
    raise exception 'Le parent d''un produit doit être un fournisseur'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger setting_options_guard_parent
  before insert or update on public.setting_options
  for each row execute function public.guard_option_parent();

-- Rattachement de l'existant. Tant qu'il n'existe qu'un fournisseur, tout
-- produit est forcément le sien — c'est le cas du catalogue initial, tout
-- entier chez Promat. Avec plusieurs fournisseurs, rien ne permet de deviner :
-- les produits restent sans parent, et l'administrateur les rattache depuis
-- l'écran Paramètres.
--
-- `updated_at = now()` : sans lui `reject_stale_write` laisserait passer, mais
-- le last-write-wins des tablettes écarterait la ligne redescendue. Le trigger
-- `_touch_synced` réestampille `synced_at`, donc les produits redescendent.
update public.setting_options p
   set parent_id  = s.id,
       updated_at = now()
  from public.setting_options s
 where p.kind = 'product'
   and p.parent_id is null
   and s.kind = 'supplier'
   and s.deleted_at is null
   and (select count(*) from public.setting_options
         where kind = 'supplier' and deleted_at is null) = 1;

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20261003110000_project_fields_point_number.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Bon de commande et bâtiment au chantier ; numéro de point saisi
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Deux champs de la fiche remontent à la définition du chantier
-- -----------------------------------------------------------------------------
--
-- Le bon de commande est celui du chantier : saisi une fois, repris sur chaque
-- fiche, comme le numéro de projet. `points.purchase_order` reste en place
-- pour les relevés antérieurs, que le rapport relit à défaut.
--
-- Le bâtiment du chantier n'est qu'une **valeur de départ** : chaque nouvelle
-- traversée le reçoit dans `points.building`, où il reste modifiable — un
-- chantier couvre parfois plusieurs bâtiments.

alter table public.projects
  add column purchase_order text,
  add column building       text;

comment on column public.projects.purchase_order is
  'Bon de commande du client, reporté sur chaque fiche du rapport.';
comment on column public.projects.building is
  'Bâtiment proposé par défaut à chaque nouvelle traversée, qui peut le '
  'modifier (points.building).';

-- -----------------------------------------------------------------------------
-- 2. Le numéro d'une traversée est saisi par le technicien
-- -----------------------------------------------------------------------------
--
-- Il était attribué ici, dans l'ordre d'arrivée des synchronisations. Il suit
-- désormais le repérage du chantier — plans, étiquettes posées sur place — et
-- seul le technicien le connaît. Le client l'envoie comme n'importe quel champ.
--
-- La contrainte d'unicité tombe avec le trigger, et c'est délibéré. Deux
-- techniciens hors ligne peuvent saisir le même numéro ; avec la contrainte,
-- le second relevé serait **refusé** à la synchronisation et resterait bloqué
-- sur sa tablette. Un doublon se voit et se corrige — l'application le
-- signale sur la fiche — alors qu'un relevé refusé ne figure dans aucun
-- rapport.

drop trigger points_assign_ref_number on public.points;
drop function public.assign_point_ref_number();

alter table public.points
  drop constraint points_project_id_ref_number_key;

comment on column public.points.ref_number is
  'Numéro de la traversée, saisi par le technicien. Ni attribué ni garanti '
  'unique par le serveur : voir la migration qui a retiré le trigger.';

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20261003120000_revoke_anon_helpers.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Les fonctions d'aide des policies ne sont pas une API publique
-- =============================================================================
--
-- `is_admin`, `point_project`, `project_is_open`… sont en `security definer` :
-- elles lisent des tables protégées avec les droits de leur propriétaire, pour
-- que les policies RLS puissent s'en servir sans récursion.
--
-- Or PostgREST expose toute fonction du schéma `public` sous `/rpc/`, et
-- Supabase en accorde l'exécution au rôle `anon` par défaut. Constaté le
-- 3 octobre 2026 sur le projet en ligne : `POST /rpc/point_project` répondait
-- **sans session**, avec la seule clé publique embarquée dans l'APK. Qui
-- connaît l'identifiant d'une traversée obtenait celui de son chantier, et
-- `project_is_open` disait si un chantier existe et s'il est clôturé — en
-- contournant RLS, puisque c'est précisément ce que fait `security definer`.
--
-- Les identifiants sont des UUID, donc non devinables : la fuite est mince.
-- Mais rien ne justifie qu'elle existe. Toutes les policies sont déclarées
-- `to authenticated` : un visiteur anonyme n'en évalue aucune, et n'a aucun
-- besoin de ces fonctions.
--
-- `from public` en plus de `from anon` : Postgres accorde aussi l'exécution à
-- tout le monde par défaut, et retirer l'un sans l'autre ne retire rien.

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.is_admin()',
    'public.is_project_member(uuid)',
    'public.project_is_open(uuid)',
    'public.point_project(uuid)',
    'public.can_write_project(uuid)',
    'public.can_see_client(uuid)',
    'public.can_see_profile(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end
$$;

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20261003130000_point_project_overrides.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Une traversée peut s'écarter de ce que dit son chantier
-- =============================================================================
--
-- Numéro de projet, intitulé et Purchase Order se saisissent sur le chantier
-- et se reportent sur chaque fiche. Ils doivent rester **modifiables fiche par
-- fiche**, au cas où : un point rattaché à un autre bon de commande, un
-- intitulé à préciser pour une zone.
--
-- Trois colonnes d'écart sur `points`, toutes nullables :
--
--   nul        ⇒ la fiche suit le chantier, y compris s'il est corrigé après ;
--   renseigné  ⇒ la fiche porte cette valeur, quoi que dise le chantier.
--
-- Un écart et non une copie, à la différence du bâtiment (`points.building`,
-- recopié à la création) : corriger une faute de frappe dans le numéro de
-- projet doit atteindre toutes les fiches qui ne s'en sont pas écartées
-- volontairement, sans les rouvrir une à une.
--
-- `purchase_order` existait déjà : il portait la saisie d'avant le passage du
-- champ au chantier, et prend désormais ce rôle d'écart.

alter table public.points
  add column project_code text,
  add column project_name text;

comment on column public.points.project_code is
  'Écart au numéro de projet du chantier. Nul : la fiche suit projects.code.';
comment on column public.points.project_name is
  'Écart à l''intitulé du chantier. Nul : la fiche suit projects.name.';
comment on column public.points.purchase_order is
  'Écart au Purchase Order du chantier. Nul : la fiche suit '
  'projects.purchase_order.';

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20261003140000_delete_project.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Supprimer un chantier l'efface pour de bon
-- =============================================================================
--
-- Partout ailleurs la suppression est logique (`deleted_at`). Pas ici, à la
-- demande du bureau : supprimer un chantier retire **définitivement** le
-- chantier, ses affectations, ses traversées et leurs clichés.
--
-- Un DELETE physique a deux conséquences que `deleted_at` évitait, et cette
-- migration les traite toutes les deux :
--
--  1. Une ligne effacée ne redescend plus. Les autres appareils, qui tirent
--     par `synced_at`, ne sauraient jamais que le chantier a disparu et le
--     garderaient affiché. D'où `deleted_projects`, la **trace** de chaque
--     suppression : elle descend comme une entité ordinaire, et l'appareil
--     qui la reçoit efface le chantier de sa base locale.
--
--  2. Un appareil resté hors ligne repousserait sa copie, et le chantier
--     ressusciterait. La même trace l'interdit : un chantier ou une traversée
--     qui la désigne est écarté à l'arrivée, sans erreur.

create table public.deleted_projects (
  id         uuid primary key,
  deleted_at timestamptz not null default now(),
  synced_at  timestamptz not null default clock_timestamp()
);

comment on table public.deleted_projects is
  'Trace des chantiers supprimés définitivement. Descend vers les appareils, '
  'qui purgent alors leur copie ; interdit aussi le retour du chantier.';

create index deleted_projects_synced_at_idx
  on public.deleted_projects (synced_at);

alter table public.deleted_projects enable row level security;

-- Lisible par tout compte connecté : la ligne ne porte qu'un identifiant, et
-- un technicien doit l'obtenir pour un chantier dont il vient d'être écarté
-- par la suppression même. Aucune policy d'écriture : seule `delete_project`,
-- en `security definer`, y inscrit quelque chose.
create policy deleted_projects_select on public.deleted_projects
  for select to authenticated
  using (true);

-- -----------------------------------------------------------------------------
-- La suppression
-- -----------------------------------------------------------------------------
--
-- Une fonction et non des DELETE envoyés par le client : cinq tables à vider
-- dans l'ordre des clés étrangères, en **une** transaction. Interrompue au
-- milieu, une suite de requêtes laisserait un chantier à moitié effacé.
--
-- `security definer` parce qu'aucune policy DELETE n'existe, et qu'il n'en
-- faut pas : effacer reste impossible par toute autre voie. Le contrôle du
-- rôle est donc fait ici, à la main.
--
-- Les fichiers des clichés ne sont pas des lignes : le client les retire du
-- bucket **avant** d'appeler cette fonction, tant que `photos` dit encore
-- lesquels ils sont.

create or replace function public.delete_project(p_project uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Seul un administrateur peut supprimer un chantier'
      using errcode = 'insufficient_privilege';
  end if;

  -- La trace d'abord : dès cet instant, rien ne peut plus réinscrire le
  -- chantier ni ses traversées.
  insert into public.deleted_projects (id) values (p_project)
  on conflict (id) do nothing;

  delete from public.photos
   where point_id in (select id from public.points where project_id = p_project);
  delete from public.points          where project_id = p_project;
  delete from public.project_members where project_id = p_project;
  delete from public.reports         where project_id = p_project;
  delete from public.projects        where id = p_project;
end;
$$;

-- Voir la migration `revoke_anon_helpers` : une fonction `security definer`
-- de `public` est une route `/rpc/` ouverte à `anon` par défaut.
revoke execute on function public.delete_project(uuid) from public, anon;
grant  execute on function public.delete_project(uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Pas de retour d'un chantier supprimé
-- -----------------------------------------------------------------------------
--
-- `return null` et non une exception : l'écriture est écartée en silence,
-- comme une écriture périmée (`reject_stale_write`). L'appareil qui la
-- poussait la tient pour envoyée, sa file avance, et la trace qu'il reçoit à
-- la descente suivante efface le reste. Une exception laisserait l'envoi en
-- échec définitif sur la tablette, à réclamer une intervention pour un relevé
-- qui n'a plus lieu d'être.

create or replace function public.drop_if_project_deleted()
returns trigger
language plpgsql
-- `security invoker` : la lecture de `deleted_projects` est ouverte à tout
-- compte connecté.
as $$
declare
  -- Par le JSON de la ligne et non `new.project_id` : PL/pgSQL résout chaque
  -- champ nommé à l'exécution, y compris dans la branche non prise, et
  -- `projects` n'a pas de colonne `project_id`. Le banc d'essai l'a montré.
  chantier uuid := (to_jsonb(new) ->> case tg_table_name
                                        when 'projects' then 'id'
                                        else 'project_id'
                                      end)::uuid;
begin
  if exists (select 1 from public.deleted_projects where id = chantier) then
    return null;
  end if;
  return new;
end;
$$;

-- Noms choisis pour passer **avant** les autres triggers de la table, qui se
-- déclenchent par ordre alphabétique : inutile de vérifier l'auteur d'une
-- traversée qu'on va écarter.
create trigger projects_drop_if_deleted
  before insert on public.projects
  for each row execute function public.drop_if_project_deleted();
create trigger points_drop_if_project_deleted
  before insert on public.points
  for each row execute function public.drop_if_project_deleted();
create trigger project_members_drop_if_project_deleted
  before insert on public.project_members
  for each row execute function public.drop_if_project_deleted();

-- -----------------------------------------------------------------------------
-- Les fichiers
-- -----------------------------------------------------------------------------
--
-- Aucune policy DELETE n'existait sur le stockage : les fichiers ne
-- s'effaçaient jamais. Un administrateur peut désormais retirer les clichés
-- et l'ancien rapport PDF d'un chantier — et lui seul.

create policy point_photos_delete_admin on storage.objects
  for delete to authenticated
  using (bucket_id = 'point-photos' and public.is_admin());

create policy reports_delete_admin on storage.objects
  for delete to authenticated
  using (bucket_id = 'reports' and public.is_admin());

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20261003150000_ref_number_text.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Le numéro d'un point est un texte
-- =============================================================================
--
-- Le repérage d'un chantier n'est pas toujours une suite d'entiers : le modèle
-- Excel du bureau nomme ses fiches « 1.40 », « 1.167 ». Un entier ne sait pas
-- porter cela — « 1.40 » y deviendrait 1, ou serait refusé.
--
-- Les numéros déjà saisis sont conservés tels quels : 12 devient « 12 ».
--
-- Sans conséquence sur les règles d'accès : aucune policy, aucun trigger ne
-- lit cette colonne depuis que le serveur ne l'attribue plus.

alter table public.points
  alter column ref_number type text using ref_number::text;

-- Un numéro vide n'est pas un numéro : il se confondrait avec « pas de
-- numéro » tout en échappant au test `is null`.
alter table public.points
  add constraint points_ref_number_not_blank
  check (ref_number is null or length(btrim(ref_number)) > 0);

comment on column public.points.ref_number is
  'Numéro de la traversée, saisi par le technicien, en texte libre (« 12 », '
  '« 1.40 »). Ni attribué ni garanti unique par le serveur.';

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20261003160000_delete_point.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Supprimer un point l'efface pour de bon
-- =============================================================================
--
-- Même demande que pour les chantiers, et même mécanique (voir la migration
-- `delete_project`) : la ligne est réellement effacée, une **trace** dit aux
-- autres appareils de purger leur copie, et un trigger empêche le retour.
--
-- Une différence, et elle compte : supprimer un point reste possible **hors
-- ligne**. Un technicien efface une fiche créée par erreur devant le mur, sans
-- réseau. La tablette ne change donc rien à son geste — elle marque la ligne
-- (`deleted_at`) et l'envoie par la file d'attente, comme avant. C'est le
-- serveur qui, en la recevant, fait de cette marque un effacement.

create table public.deleted_points (
  id         uuid primary key,
  project_id uuid not null,
  deleted_at timestamptz not null default now(),
  synced_at  timestamptz not null default clock_timestamp()
);

comment on table public.deleted_points is
  'Trace des traversées supprimées définitivement. Descend vers les '
  'appareils, qui purgent alors leur copie ; interdit aussi leur retour.';
comment on column public.deleted_points.project_id is
  'Sans clé étrangère : le chantier peut avoir été supprimé à son tour. Sert '
  'à retrouver le dossier des clichés dans le stockage.';

create index deleted_points_synced_at_idx
  on public.deleted_points (synced_at);

alter table public.deleted_points enable row level security;

-- Lisible par tout compte connecté, comme `deleted_projects` : la ligne ne
-- porte que des identifiants. Aucune policy d'écriture — seul le trigger
-- ci-dessous, en `security definer`, y inscrit quelque chose.
create policy deleted_points_select on public.deleted_points
  for select to authenticated
  using (true);

-- -----------------------------------------------------------------------------
-- La marque devient un effacement
-- -----------------------------------------------------------------------------
--
-- Après l'écriture, et non avant : la ligne marquée a alors passé les policies
-- — seul qui peut écrire sur le chantier peut y supprimer un point — et
-- l'arbitrage du plus récent (`reject_stale_write`).
--
-- `security definer` : il n'existe aucune policy DELETE, et il n'en faut pas.

create or replace function public.erase_deleted_point()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.deleted_points (id, project_id)
  values (new.id, new.project_id)
  on conflict (id) do nothing;

  delete from public.photos where point_id = new.id;
  delete from public.points where id = new.id;
  return null;
end;
$$;

create trigger points_erase_deleted
  after insert or update on public.points
  for each row
  when (new.deleted_at is not null)
  execute function public.erase_deleted_point();

-- Une fonction de trigger ne s'appelle pas par `/rpc/`, mais autant ne rien
-- laisser d'ouvert par défaut. Voir la migration `revoke_anon_helpers`.
revoke execute on function public.erase_deleted_point() from public, anon;

-- -----------------------------------------------------------------------------
-- Pas de retour d'un point supprimé
-- -----------------------------------------------------------------------------
--
-- Un appareil resté hors ligne repousse sa copie du point, ou un cliché pris
-- pour lui : écartés en silence, pour la même raison que
-- `drop_if_project_deleted` — la file de la tablette avance, et la trace
-- qu'elle reçoit ensuite efface le reste.

create or replace function public.drop_if_point_deleted()
returns trigger
language plpgsql
as $$
declare
  -- Par le JSON de la ligne : `photos` n'a pas de colonne `id` de point, et
  -- PL/pgSQL résout chaque champ nommé même dans la branche non prise.
  point uuid := (to_jsonb(new) ->> case tg_table_name
                                     when 'points' then 'id'
                                     else 'point_id'
                                   end)::uuid;
begin
  if exists (select 1 from public.deleted_points where id = point) then
    return null;
  end if;
  return new;
end;
$$;

-- `a_…` : avant les autres triggers de la table, qui se déclenchent par ordre
-- alphabétique. Inutile de vérifier l'auteur d'une traversée, ou le chemin
-- d'un cliché, qu'on va écarter.
create trigger a_points_drop_if_deleted
  before insert on public.points
  for each row execute function public.drop_if_point_deleted();
create trigger a_photos_drop_if_point_deleted
  before insert on public.photos
  for each row execute function public.drop_if_point_deleted();

-- -----------------------------------------------------------------------------
-- Les fichiers
-- -----------------------------------------------------------------------------
--
-- Les clichés d'un point supprimé sont retirés du stockage par l'appareil qui
-- reçoit la trace. Un technicien doit donc pouvoir retirer un fichier de
-- **son** chantier — et seulement de là ; l'administrateur le pouvait déjà.

create policy point_photos_delete_member on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'point-photos'
    and public.can_write_project(((storage.foldername(name))[1])::uuid)
  );

-- -----------------------------------------------------------------------------
-- L'existant
-- -----------------------------------------------------------------------------
--
-- Les points déjà supprimés logiquement le deviennent pour de bon : même
-- traitement que ceux qui le seront désormais.

insert into public.deleted_points (id, project_id)
select id, project_id from public.points where deleted_at is not null
on conflict (id) do nothing;

delete from public.photos
 where point_id in (select id from public.deleted_points);
delete from public.points
 where id in (select id from public.deleted_points);

-- >>>>>>>>>>>>>>>>>>>>  supabase/migrations/20261003170000_floors_as_options.sql  <<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- Les étages deviennent une liste administrée
-- =============================================================================
--
-- L'étage était un entier borné de -3 à 5, la borne écrite dans le schéma. Le
-- bureau veut l'administrer comme les autres listes de la fiche : ajouter un
-- « Niveau 6 », une « Toiture », un « Entresol ». Il rejoint donc
-- `setting_options`, sous une septième nature de liste.

-- -----------------------------------------------------------------------------
-- 1. Une septième nature de liste
-- -----------------------------------------------------------------------------
--
-- Pas `alter type … add value` : l'étiquette ajoutée serait inutilisable
-- **dans sa propre transaction**, et cette migration doit l'employer aussitôt
-- pour créer les étages. Or `bootstrap.sql` et l'éditeur Supabase jouent tout
-- d'un bloc. Le type est donc refait, et la colonne basculée dessus — ce qui,
-- lui, tient dans une transaction.

-- La contrainte compare `kind` à une étiquette de l'ancien type : elle ne
-- survivrait pas au changement. Retirée, puis reposée à l'identique.
alter table public.setting_options
  drop constraint setting_options_parent_only_product;

create type public.setting_kind_v2 as enum (
  'configuration',
  'configuration_detail',
  'ei_level',
  'supplier',
  'product_type',
  'product',
  'floor'
);

alter table public.setting_options
  alter column kind type public.setting_kind_v2
  using kind::text::public.setting_kind_v2;

drop type public.setting_kind;
alter type public.setting_kind_v2 rename to setting_kind;

alter table public.setting_options
  add constraint setting_options_parent_only_product
  check (parent_id is null or kind = 'product');

-- -----------------------------------------------------------------------------
-- 2. Le point désigne son étage, comme ses autres caractéristiques
-- -----------------------------------------------------------------------------

alter table public.points
  add column floor_id uuid references public.setting_options (id);

comment on column public.points.floor_id is
  'Étage, choisi dans la liste administrée (setting_options, nature floor).';

-- -----------------------------------------------------------------------------
-- 3. Les étages d'origine, et les traversées déjà relevées
-- -----------------------------------------------------------------------------
--
-- Libellés « Niveau -3 » à « Niveau 5 » : ceux de la liste « Étages » du
-- classeur Excel, pour qu'une fiche exportée retrouve sa valeur dans le menu
-- déroulant. Le rang suit l'ordre des niveaux, du plus bas au plus haut.

insert into public.setting_options (id, kind, label, sort_order, updated_at)
select gen_random_uuid(), 'floor', 'Niveau ' || n, n + 3, now()
  from generate_series(-3, 5) as n
 where not exists (
   select 1 from public.setting_options s
    where s.kind = 'floor' and s.label = 'Niveau ' || n
 );

-- `updated_at = now()` : la ligne doit l'emporter sur la copie des tablettes
-- à la descente, qui arbitre au plus récent. `synced_at` est réestampillé par
-- son trigger, donc chaque traversée concernée redescend.
update public.points p
   set floor_id   = s.id,
       updated_at = now()
  from public.setting_options s
 where p.floor_level is not null
   and s.kind = 'floor'
   and s.label = 'Niveau ' || p.floor_level;

-- -----------------------------------------------------------------------------
-- 4. L'ancienne colonne s'en va, sa borne avec
-- -----------------------------------------------------------------------------

alter table public.points drop constraint points_floor_level_range;
alter table public.points drop column floor_level;
