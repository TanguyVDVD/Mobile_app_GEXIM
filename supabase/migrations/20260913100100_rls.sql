-- =============================================================================
-- FireStop Tracker — droits d'accès
-- =============================================================================
--
-- C'est **ici** que vit le RBAC, pas dans l'application. L'app masque ce
-- qu'un technicien ne doit pas voir, mais ce n'est qu'un confort d'interface :
-- un APK modifié, une tablette à l'heure fausse ou un appel direct à l'API se
-- heurtent aux règles qui suivent, et à elles seules.
--
-- Deux étages :
--   * les **policies RLS** décident, ligne par ligne, qui lit et qui écrit ;
--   * des **triggers de garde** protègent les colonnes qu'une policy ne sait
--     pas protéger — RLS travaille à la ligne, jamais à la colonne.
--
-- Une policy trop permissive ne produit aucune erreur : elle laisse passer. Les
-- refus sont donc prouvés par `docker/rls_tests.sql`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fonctions d'aide
-- -----------------------------------------------------------------------------
--
-- Toutes en `security definer`, et ce n'est pas optionnel : elles lisent des
-- tables elles-mêmes protégées par RLS. Évaluées avec les droits de l'appelant,
-- la policy de `profiles` appellerait `is_admin()`, qui lirait `profiles`, qui…
-- Postgres coupe avec « infinite recursion detected in policy ».
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

-- Une affectation retirée l'est **logiquement** : sa ligne reste, avec
-- `deleted_at`. Sans ce filtre, la révocation ne révoquerait rien — le
-- technicien écarté garderait lecture et écriture sur tout le chantier.
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

-- Remonte au chantier depuis une traversée : les clichés n'ont pas de
-- `project_id` propre.
create or replace function public.point_project(p_point uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select project_id from public.points where id = p_point;
$$;

-- Droit d'écriture sur le contenu d'un chantier : l'admin toujours, le
-- technicien s'il y est affecté et que le chantier n'est pas clôturé.
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

-- L'inscription étant ouverte à tous, ce qu'un compte peut **lire** est une
-- surface publique. Un client n'est visible que de l'admin et des techniciens
-- affectés à l'un de ses chantiers — sans quoi n'importe qui repartirait avec
-- le fichier clients complet.
create or replace function public.can_see_client(p_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or exists (
           select 1
             from public.projects p
             join public.project_members m on m.project_id = p.id
            where p.client_id = p_client
              and m.user_id = auth.uid()
              and m.deleted_at is null
         );
$$;

-- Un profil reste visible dans quatre cas, et pas un de plus — sans quoi
-- l'annuaire du personnel, administrateurs désignés compris, serait une liste
-- de cibles d'hameçonnage prête à l'emploi.
--
-- Le dernier cas — « a relevé une traversée que je peux voir » — n'est pas du
-- confort : `points.author_id` référence `profiles` **aussi dans la base
-- locale**. Sans lui, la descente d'une traversée relevée par un collègue
-- depuis retiré du chantier violerait la clé étrangère et bloquerait la
-- synchronisation.
create or replace function public.can_see_profile(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or p_profile = auth.uid()
      -- Les administrateurs sont les interlocuteurs déclarés.
      or exists (
           select 1 from public.profiles
            where id = p_profile and role = 'admin'
         )
      -- Collègue sur un chantier commun.
      or exists (
           select 1
             from public.project_members mine
             join public.project_members theirs
               on theirs.project_id = mine.project_id
            where mine.user_id = auth.uid()   and mine.deleted_at is null
              and theirs.user_id = p_profile  and theirs.deleted_at is null
         )
      -- Auteur d'une traversée visible.
      or exists (
           select 1
             from public.points pt
             join public.project_members m on m.project_id = pt.project_id
            where pt.author_id = p_profile
              and m.user_id = auth.uid()
              and m.deleted_at is null
         );
$$;

-- -----------------------------------------------------------------------------
-- Activation
-- -----------------------------------------------------------------------------

alter table public.profiles        enable row level security;
alter table public.clients         enable row level security;
alter table public.projects        enable row level security;
alter table public.project_members enable row level security;
alter table public.setting_options enable row level security;
alter table public.points          enable row level security;
alter table public.photos          enable row level security;
alter table public.reports         enable row level security;

-- Aucune policy DELETE, nulle part et volontairement : la suppression est
-- logique (`deleted_at`), donc un UPDATE.

-- -----------------------------------------------------------------------------
-- Profils
-- -----------------------------------------------------------------------------

create policy profiles_select on public.profiles
  for select to authenticated
  using (public.can_see_profile(id));

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy profiles_insert_admin on public.profiles
  for insert to authenticated
  with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- Clients et chantiers
-- -----------------------------------------------------------------------------

create policy clients_select on public.clients
  for select to authenticated
  using (public.can_see_client(id));
create policy clients_write on public.clients
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Un technicien ne voit que ses affectations. C'est aussi ce qui borne le
-- volume descendu sur chaque tablette.
create policy projects_select on public.projects
  for select to authenticated
  using (public.is_admin() or public.is_project_member(id));
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
-- Listes de la fiche
-- -----------------------------------------------------------------------------
--
-- Lecture ouverte à tout compte authentifié, et il faut qu'elle le reste :
-- `points` référence ces lignes par clé étrangère **jusque dans la base locale
-- des tablettes**. Une option invisible ferait échouer la descente de la
-- traversée qui la désigne. Le contenu ne justifie de toute façon aucun
-- secret : ce sont des noms de produits au catalogue du fabricant.

create policy setting_options_select on public.setting_options
  for select to authenticated
  using (true);
create policy setting_options_write on public.setting_options
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- Traversées et clichés
-- -----------------------------------------------------------------------------
--
-- `using` autorise la ligne d'origine, `with check` la ligne résultante. Les
-- deux sont nécessaires : sans `with check`, un technicien pourrait déplacer
-- une traversée vers un chantier auquel il n'a pas accès.

create policy points_select on public.points
  for select to authenticated
  using (public.is_admin() or public.is_project_member(project_id));
create policy points_insert on public.points
  for insert to authenticated
  with check (public.can_write_project(project_id));
create policy points_update on public.points
  for update to authenticated
  using (public.can_write_project(project_id))
  with check (public.can_write_project(project_id));

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
--
-- Un rapport de conformité est le document remis au client : il n'a qu'un
-- auteur légitime, l'administrateur.

create policy reports_select on public.reports
  for select to authenticated
  using (public.is_admin() or public.is_project_member(project_id));
create policy reports_insert on public.reports
  for insert to authenticated
  with check (public.is_admin());

-- =============================================================================
-- Gardes de colonne
-- =============================================================================
--
-- Des triggers `security invoker` — le défaut — et c'est délibéré : ils testent
-- `current_user`, qui désignerait le propriétaire de la fonction dans une
-- fonction `security definer`. La condition serait toujours fausse, et le
-- verrou inopérant tout en paraissant correct.
--
-- Restreints à `authenticated`, ils laissent passer les migrations et
-- `service_role`. Ils lèvent plutôt que de corriger en silence : l'application
-- n'écrit jamais ces valeurs autrement, un écart est donc une tentative.

-- -----------------------------------------------------------------------------
-- Rôle d'un profil
-- -----------------------------------------------------------------------------
--
-- `profiles_update_self` autorise légitimement un utilisateur à modifier sa
-- propre ligne — nom, courriel… et `role`. Sans ce trigger, un technicien
-- n'avait qu'à s'attribuer `admin`.

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
-- Auteur d'une traversée
-- -----------------------------------------------------------------------------
--
-- À la création, l'auteur est l'appelant ; ensuite il ne bouge plus. Un
-- collègue qui complète la fiche la modifie, il n'en devient pas l'auteur. Sur
-- un dossier de conformité incendie, « qui a posé ce calfeutrement » n'est pas
-- une métadonnée anodine. L'administrateur est exempté : il peut avoir à
-- reprendre un relevé au nom de quelqu'un.
--
-- **Le piège de l'upsert.** Toutes les écritures de l'application sont des
-- `INSERT ... ON CONFLICT DO UPDATE`, et Postgres déclenche `BEFORE INSERT` sur
-- la ligne proposée **avant** de constater le conflit. La requête d'un collègue
-- arrive donc en insertion, avec l'`author_id` d'origine : d'où le test
-- d'existence. Il passe par RLS, et c'est voulu — une ligne invisible pour
-- l'appelant est traitée comme neuve, donc refusée si elle prétend à un autre
-- auteur.

create or replace function public.guard_point_author()
returns trigger
language plpgsql
as $$
begin
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT'
     and new.author_id is distinct from auth.uid()
     and not exists (select 1 from public.points where id = new.id)
  then
    raise exception 'Une traversee ne se cree qu''au nom de son auteur'
      using errcode = 'insufficient_privilege';
  end if;

  if tg_op = 'UPDATE' and new.author_id is distinct from old.author_id then
    raise exception 'L''auteur d''une traversee ne se modifie pas'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

create trigger points_guard_author
  before insert or update on public.points
  for each row execute function public.guard_point_author();

-- -----------------------------------------------------------------------------
-- Chemin d'un cliché
-- -----------------------------------------------------------------------------
--
-- Le chemin est déterministe : `{project_id}/{point_id}/{photo_id}.jpg`, tel
-- que `PhotoUploader` le construit. Sans cette garde, une ligne pouvait
-- désigner l'objet d'un autre chantier du bucket : le technicien ne l'aurait
-- pas lu, mais l'administrateur, si — et la photo d'un autre bâtiment serait
-- sortie sur le rapport. Une mise à jour qui ne touche pas au chemin n'est pas
-- re-contrôlée.

create or replace function public.guard_photo_path()
returns trigger
language plpgsql
as $$
declare
  attendu text;
begin
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  if tg_op = 'UPDATE' and new.storage_path is not distinct from old.storage_path
  then
    return new;
  end if;

  attendu := public.point_project(new.point_id)::text
          || '/' || new.point_id::text
          || '/' || new.id::text || '.jpg';

  if new.storage_path is distinct from attendu then
    raise exception 'Chemin de cliche incoherent avec sa traversee : %',
      new.storage_path
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

create trigger photos_guard_path
  before insert or update on public.photos
  for each row execute function public.guard_photo_path();
