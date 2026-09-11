-- =============================================================================
-- FireStop Tracker — stockage des fichiers
-- =============================================================================
--
-- Trois buckets, tous privés. Le premier segment d'un chemin porte le droit
-- d'accès : c'est l'identifiant du chantier (clichés, rapports) ou du client
-- (logos).
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Clichés de traversée. Privé : un rapport de conformité incendie identifie
  -- des vulnérabilités structurelles d'un bâtiment réel.
  --
  -- Plafond à 5 Mo alors qu'un cliché compressé pèse quelques centaines de
  -- kilo-octets : ce n'est pas une marge, c'est un disjoncteur. Si une
  -- régression court-circuitait la compression, les originaux passeraient
  -- encore — mais l'écart deviendrait visible avant d'être coûteux.
  ('point-photos', 'point-photos', false, 5242880, array['image/jpeg']),

  -- Logos clients, posés en tête de chaque fiche. PNG ou JPEG : ce sont les
  -- deux formats que l'écran client propose et que le moteur PDF sait rendre.
  ('client-logos', 'client-logos', false, 2097152,
   array['image/png', 'image/jpeg']),

  -- Rapports PDF déposés par l'administrateur.
  ('reports', 'reports', false, 104857600, array['application/pdf'])
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- point-photos — chemin {project_id}/{point_id}/{photo_id}.jpg
-- -----------------------------------------------------------------------------
--
-- Le dépôt utilise `upsert: true` pour rester idempotent après une coupure, ce
-- que Supabase Storage traduit en UPDATE quand l'objet existe déjà. Sans la
-- policy UPDATE, seule la **reprise** d'un transfert échouerait — et seulement
-- sur réseau instable, donc jamais au bureau.
--
-- Aucune policy DELETE : un cliché versé est une pièce justificative. Le
-- retirer du rapport, c'est marquer `photos.deleted_at`.

create policy point_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'point-photos'
    and (
      public.is_admin()
      or public.is_project_member(((storage.foldername(name))[1])::uuid)
    )
  );

create policy point_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'point-photos'
    and public.can_write_project(((storage.foldername(name))[1])::uuid)
  );

create policy point_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'point-photos'
    and public.can_write_project(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = 'point-photos'
    and public.can_write_project(((storage.foldername(name))[1])::uuid)
  );

-- -----------------------------------------------------------------------------
-- client-logos — chemin {client_id}/{uuid}.{png|jpg}
-- -----------------------------------------------------------------------------
--
-- Lecture ouverte à tout compte authentifié : un technicien peut générer le
-- rapport de son chantier, et le logo y figure. Écriture réservée à
-- l'administrateur — `for all`, qui couvre l'UPDATE de l'upsert.

create policy client_logos_select on storage.objects
  for select to authenticated
  using (bucket_id = 'client-logos');

create policy client_logos_write on storage.objects
  for all to authenticated
  using (bucket_id = 'client-logos' and public.is_admin())
  with check (bucket_id = 'client-logos' and public.is_admin());

-- -----------------------------------------------------------------------------
-- reports — chemin {project_id}/rapport.pdf
-- -----------------------------------------------------------------------------
--
-- Regénérer un rapport écrase le précédent au même chemin : le PDF est une
-- donnée dérivée, et c'est la table `reports` qui date chaque dépôt.

create policy reports_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'reports'
    and (
      public.is_admin()
      or public.is_project_member(((storage.foldername(name))[1])::uuid)
    )
  );

create policy reports_insert_admin on storage.objects
  for insert to authenticated
  with check (bucket_id = 'reports' and public.is_admin());

create policy reports_update_admin on storage.objects
  for update to authenticated
  using (bucket_id = 'reports' and public.is_admin())
  with check (bucket_id = 'reports' and public.is_admin());
