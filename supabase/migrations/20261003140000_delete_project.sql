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
