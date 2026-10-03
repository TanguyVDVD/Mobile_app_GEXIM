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
