-- =============================================================================
-- FireStop Tracker — sécurité au niveau ligne (RLS)
-- =============================================================================
--
-- C'est **ici** que vit le RBAC, pas dans l'application. L'app masque les
-- chantiers clôturés aux opérateurs, mais ce n'est qu'un confort d'interface :
-- une tablette dont l'horloge dérive, un cache périmé ou un APK modifié
-- contourneraient cette couche. Les policies ci-dessous, non.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fonctions d'aide
-- -----------------------------------------------------------------------------
--
-- Toutes en `security definer`, et ce n'est pas optionnel.
--
-- `is_admin()` lit `profiles`, table elle-même protégée par RLS. Évaluée avec
-- les droits de l'appelant, elle déclencherait la policy de `profiles`, qui
-- appelle `is_admin()`, qui... Postgres coupe avec « infinite recursion
-- detected in policy ». C'est le piège RLS le plus courant sur Supabase.
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

create or replace function public.is_project_member(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.project_members
     where project_id = p_project and user_id = auth.uid()
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

-- Remonte au chantier depuis un point : les photos et les matériaux n'ont pas
-- de `project_id` propre.
create or replace function public.point_project(p_point uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select project_id from public.points where id = p_point;
$$;

-- Droit d'écriture d'un opérateur sur le contenu d'un chantier.
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

-- -----------------------------------------------------------------------------
-- Activation
-- -----------------------------------------------------------------------------

alter table public.profiles         enable row level security;
alter table public.report_templates enable row level security;
alter table public.clients          enable row level security;
alter table public.projects         enable row level security;
alter table public.project_members  enable row level security;
alter table public.points           enable row level security;
alter table public.materials        enable row level security;
alter table public.point_materials  enable row level security;
alter table public.photos           enable row level security;
alter table public.reports          enable row level security;

-- -----------------------------------------------------------------------------
-- Profils
-- -----------------------------------------------------------------------------

-- Lecture ouverte à tous les authentifiés : le rapport PDF nomme l'auteur de
-- chaque relevé, et la liste des points l'affiche.
create policy profiles_select on public.profiles
  for select to authenticated
  using (true);

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy profiles_insert_admin on public.profiles
  for insert to authenticated
  with check (public.is_admin());

-- Verrou d'escalade de privilèges.
--
-- RLS travaille à la **ligne**, jamais à la colonne. `profiles_update_self`
-- autorise donc légitimement un utilisateur à modifier sa propre ligne — nom,
-- courriel... et `role`. Un opérateur n'avait qu'à s'attribuer `admin` pour
-- accéder à tous les chantiers de l'entreprise et rouvrir un rapport clos.
-- Aucune erreur, aucune trace : l'UPDATE réussissait.
--
-- Le contrôle de colonne se fait donc par trigger. On lève une exception plutôt
-- que de rétablir silencieusement l'ancienne valeur : c'est une tentative
-- d'élévation de privilèges, elle doit être bruyante. Aucun client légitime
-- n'écrit ce champ — l'app ne synchronise pas `profiles`.
-- `security invoker` (le défaut), et c'est délibéré : le contrôle porte sur le
-- rôle réel de l'appelant. Dans une fonction `security definer`, `current_user`
-- désigne le propriétaire de la fonction et non l'appelant — la condition
-- serait toujours fausse, et le verrou inopérant.
--
-- Restreindre à `authenticated` laisse passer les migrations (rôle `postgres`)
-- et le worker de rapports (`service_role`), qui doivent pouvoir attribuer des
-- rôles sans détenir eux-mêmes de profil.
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
-- Référentiels : templates, clients, matériaux
-- -----------------------------------------------------------------------------

create policy report_templates_select on public.report_templates
  for select to authenticated using (true);
create policy report_templates_write on public.report_templates
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy clients_select on public.clients
  for select to authenticated using (true);
create policy clients_write on public.clients
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy materials_select on public.materials
  for select to authenticated using (true);
create policy materials_write on public.materials
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- Chantiers
-- -----------------------------------------------------------------------------

-- Un opérateur ne voit que ses affectations. C'est aussi ce qui borne le volume
-- descendu sur la tablette : sans cela, chaque appareil dupliquerait localement
-- l'intégralité des chantiers de l'entreprise.
create policy projects_select on public.projects
  for select to authenticated
  using (public.is_admin() or public.is_project_member(id));

-- Création, dates, clôture : prérogatives de l'admin.
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
-- Points
-- -----------------------------------------------------------------------------

create policy points_select on public.points
  for select to authenticated
  using (public.is_admin() or public.is_project_member(project_id));

create policy points_insert on public.points
  for insert to authenticated
  with check (public.can_write_project(project_id));

-- `using` autorise la ligne d'origine, `with check` la ligne résultante. Les
-- deux sont nécessaires : sans `with check`, un opérateur pourrait déplacer un
-- point vers un chantier auquel il n'a pas accès.
create policy points_update on public.points
  for update to authenticated
  using (public.can_write_project(project_id))
  with check (public.can_write_project(project_id));

-- Aucune policy DELETE, nulle part et volontairement : la suppression est
-- logique (`deleted_at`), donc un UPDATE. Un DELETE physique serait de toute
-- façon annulé par la prochaine synchro d'un appareil resté hors-ligne.

-- -----------------------------------------------------------------------------
-- Matériaux posés
-- -----------------------------------------------------------------------------

create policy point_materials_select on public.point_materials
  for select to authenticated
  using (
    public.is_admin()
    or public.is_project_member(public.point_project(point_id))
  );

create policy point_materials_insert on public.point_materials
  for insert to authenticated
  with check (public.can_write_project(public.point_project(point_id)));

create policy point_materials_update on public.point_materials
  for update to authenticated
  using (public.can_write_project(public.point_project(point_id)))
  with check (public.can_write_project(public.point_project(point_id)));

-- -----------------------------------------------------------------------------
-- Photos
-- -----------------------------------------------------------------------------

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

create policy reports_select on public.reports
  for select to authenticated
  using (public.is_admin() or public.is_project_member(project_id));

-- Produits par le worker Docker, qui se présente en `service_role` et n'est pas
-- soumis à RLS. Un admin peut aussi en déposer un manuellement.
create policy reports_insert on public.reports
  for insert to authenticated
  with check (public.is_admin());
