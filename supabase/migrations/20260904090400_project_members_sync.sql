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
