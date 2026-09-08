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
