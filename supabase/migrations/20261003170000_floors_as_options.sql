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
