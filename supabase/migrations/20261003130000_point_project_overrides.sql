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
