-- =============================================================================
-- FireStop Tracker — resserrage des lectures après ouverture de l'inscription
-- =============================================================================
--
-- **Correction de sécurité.** Les policies de lecture sur `clients` et
-- `profiles` étaient en `using (true)` : tout compte authentifié pouvait les
-- lire intégralement.
--
-- C'était défendable tant que les comptes étaient créés un par un par un
-- administrateur dans le tableau de bord Supabase. L'inscription libre a changé
-- le modèle de menace sans que ces policies ne soient revues : n'importe qui
-- pouvait désormais créer un compte et repartir avec
--
--   * le fichier clients complet — raisons sociales, adresses, noms et
--     coordonnées des contacts, c'est-à-dire le patrimoine commercial ;
--   * l'annuaire du personnel — noms, adresses e-mail et rôles, soit une liste
--     de cibles d'hameçonnage prête à l'emploi, avec les administrateurs
--     désignés.
--
-- Aucune trace n'en serait restée : ce sont des lectures parfaitement légitimes
-- du point de vue du serveur.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fonctions d'aide
-- -----------------------------------------------------------------------------
--
-- `security definer`, comme les autres : elles lisent des tables elles-mêmes
-- protégées par RLS, et seraient sinon prises dans une récursion de policies.

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

-- Un profil reste visible dans quatre cas, et pas un de plus.
--
-- Le dernier — « a relevé une traversée que je peux voir » — n'est pas du
-- confort : `points.author_id` référence `profiles` **aussi dans la base
-- locale**. Sans lui, la descente d'un point relevé par un administrateur, ou
-- par un collègue depuis retiré du chantier, violerait la clé étrangère et
-- bloquerait la synchronisation de la tablette.
create or replace function public.can_see_profile(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or p_profile = auth.uid()
      -- Les administrateurs sont les interlocuteurs déclarés : leur identité
      -- n'a pas à être cachée aux techniciens.
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
-- Application
-- -----------------------------------------------------------------------------

drop policy if exists clients_select on public.clients;
create policy clients_select on public.clients
  for select to authenticated
  using (public.can_see_client(id));

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (public.can_see_profile(id));

-- `materials` et `report_templates` restent lisibles par tout compte
-- authentifié, délibérément : un catalogue de produits coupe-feu et une mise en
-- page de rapport ne sont pas des secrets commerciaux, et `point_materials`
-- comme `clients` les référencent par clé étrangère jusque dans la base locale.
