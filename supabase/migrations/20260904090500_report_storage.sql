-- =============================================================================
-- FireStop Tracker — dépôt des rapports par un administrateur
-- =============================================================================
--
-- Le bucket `reports` n'acceptait que `service_role`, en prévision d'un worker
-- serveur. Le rapport étant pour l'instant produit dans l'application, l'admin
-- doit pouvoir l'y déposer.
--
-- Réservé aux admins, jamais aux opérateurs : un rapport de conformité est le
-- document remis au client, il n'a qu'un seul auteur légitime.
-- =============================================================================

create policy reports_insert_admin on storage.objects
  for insert to authenticated
  with check (bucket_id = 'reports' and public.is_admin());

-- Regénérer un rapport écrase le précédent au même chemin : le PDF est une
-- donnée **dérivée**, reconstructible à tout moment depuis les traversées. On
-- ne cherche donc pas à en conserver l'historique ici — c'est la table
-- `reports` qui date chaque génération.
create policy reports_update_admin on storage.objects
  for update to authenticated
  using (bucket_id = 'reports' and public.is_admin())
  with check (bucket_id = 'reports' and public.is_admin());
