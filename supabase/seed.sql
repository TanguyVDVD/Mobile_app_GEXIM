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
