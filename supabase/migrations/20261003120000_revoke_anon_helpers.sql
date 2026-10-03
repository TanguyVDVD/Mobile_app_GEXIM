-- =============================================================================
-- Les fonctions d'aide des policies ne sont pas une API publique
-- =============================================================================
--
-- `is_admin`, `point_project`, `project_is_open`… sont en `security definer` :
-- elles lisent des tables protégées avec les droits de leur propriétaire, pour
-- que les policies RLS puissent s'en servir sans récursion.
--
-- Or PostgREST expose toute fonction du schéma `public` sous `/rpc/`, et
-- Supabase en accorde l'exécution au rôle `anon` par défaut. Constaté le
-- 3 octobre 2026 sur le projet en ligne : `POST /rpc/point_project` répondait
-- **sans session**, avec la seule clé publique embarquée dans l'APK. Qui
-- connaît l'identifiant d'une traversée obtenait celui de son chantier, et
-- `project_is_open` disait si un chantier existe et s'il est clôturé — en
-- contournant RLS, puisque c'est précisément ce que fait `security definer`.
--
-- Les identifiants sont des UUID, donc non devinables : la fuite est mince.
-- Mais rien ne justifie qu'elle existe. Toutes les policies sont déclarées
-- `to authenticated` : un visiteur anonyme n'en évalue aucune, et n'a aucun
-- besoin de ces fonctions.
--
-- `from public` en plus de `from anon` : Postgres accorde aussi l'exécution à
-- tout le monde par défaut, et retirer l'un sans l'autre ne retire rien.

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.is_admin()',
    'public.is_project_member(uuid)',
    'public.project_is_open(uuid)',
    'public.point_project(uuid)',
    'public.can_write_project(uuid)',
    'public.can_see_client(uuid)',
    'public.can_see_profile(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end
$$;
