-- =============================================================================
-- Droits de table (banc d'essai local uniquement)
-- =============================================================================
--
-- Supabase applique ces GRANT automatiquement à chaque nouvelle table. Sur un
-- Postgres nu il faut les poser à la main, faute de quoi tout échoue en
-- « permission denied for table » — et l'on croirait à tort que ce sont les
-- policies RLS qui refusent.
--
-- Rappel : GRANT et RLS sont deux étages distincts. Le GRANT ouvre la table au
-- rôle ; RLS décide ensuite ligne par ligne. Un GRANT large n'affaiblit donc
-- pas la sécurité tant que RLS est actif — c'est le modèle de Supabase.
-- =============================================================================

grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update on all tables in schema public
  to authenticated;

grant execute on all functions in schema public
  to anon, authenticated, service_role;

grant usage, select on all sequences in schema public
  to authenticated, service_role;

-- Le worker de rapports contourne RLS : il doit lire tous les chantiers pour
-- produire le PDF de n'importe lequel.
grant all on all tables in schema public to service_role;
