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
