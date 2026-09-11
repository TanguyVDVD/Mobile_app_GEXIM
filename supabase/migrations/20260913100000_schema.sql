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
