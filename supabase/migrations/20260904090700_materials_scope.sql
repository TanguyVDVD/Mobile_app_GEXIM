-- =============================================================================
-- FireStop Tracker — cloisonnement du catalogue propre à un client
-- =============================================================================
--
-- Durcissement, **pas** une correction de fuite active. À appliquer sans
-- urgence particulière.
--
-- `materials` restait en `using (true)` après le resserrage de `090600`, au
-- motif qu'un catalogue de produits coupe-feu n'est pas un secret. C'est vrai
-- du catalogue **global**, dont tout le monde a besoin. Ça l'est moins des
-- entrées portant un `client_id` : celles-là nomment les produits qu'un client
-- précis impose dans son cahier des charges, ce qui relève de sa relation
-- commerciale.
--
-- Le catalogue global (`client_id is null`) reste évidemment lisible par tous :
-- `point_materials` le référence par clé étrangère jusque dans la base locale
-- des tablettes, et le restreindre casserait la synchronisation.
-- =============================================================================

drop policy if exists materials_select on public.materials;

create policy materials_select on public.materials
  for select to authenticated
  using (
    client_id is null
    or public.can_see_client(client_id)
  );

-- `report_templates` reste délibérément ouvert : une mise en page de rapport ne
-- révèle rien, et `clients.template_id` la référence par clé étrangère.
