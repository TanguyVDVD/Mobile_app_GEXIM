-- =============================================================================
-- FireStop Tracker — buckets et policies de stockage
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Buckets
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Photos de traversées. Privé : un rapport de conformité incendie identifie
  -- des vulnérabilités structurelles d'un bâtiment réel.
  --
  -- Plafond à 5 Mo alors qu'un cliché compressé pèse ~400 Ko : ce n'est pas une
  -- marge, c'est un disjoncteur. Si une régression court-circuitait
  -- `ImageCompressor`, les originaux de 4 Mo passeraient inaperçus jusqu'à la
  -- facture. À 5 Mo, ils passent encore — mais l'écart devient visible dans les
  -- métriques du bucket avant d'être coûteux.
  ('point-photos', 'point-photos', false, 5242880, array['image/jpeg']),

  -- Logos clients, injectés dans l'en-tête des rapports.
  ('client-logos', 'client-logos', false, 2097152,
   array['image/png', 'image/jpeg', 'image/svg+xml']),

  -- Rapports PDF générés à la clôture.
  ('reports', 'reports', false, 104857600, array['application/pdf'])
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- point-photos
-- -----------------------------------------------------------------------------
--
-- Chemin : {project_id}/{point_id}/{photo_id}.jpg
-- Le premier segment porte donc le droit d'accès.
--
-- Le transfert utilise `upsert: true` pour rester idempotent après une coupure
-- réseau. Côté Supabase Storage cela se traduit par un UPDATE quand l'objet
-- existe déjà : sans la policy UPDATE ci-dessous, toute **reprise** de
-- transfert échouerait en 403 — précisément le cas que l'idempotence est censée
-- couvrir, et seulement sur réseau instable. Le genre de bug qui ne se
-- manifeste jamais au bureau.

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

-- Aucune policy DELETE : une photo versée est une pièce justificative. La
-- retirer du rapport se fait en marquant la ligne `photos.deleted_at`, ce qui
-- laisse la preuve en place.

-- -----------------------------------------------------------------------------
-- client-logos
-- -----------------------------------------------------------------------------

create policy client_logos_select on storage.objects
  for select to authenticated
  using (bucket_id = 'client-logos');

create policy client_logos_write on storage.objects
  for all to authenticated
  using (bucket_id = 'client-logos' and public.is_admin())
  with check (bucket_id = 'client-logos' and public.is_admin());

-- -----------------------------------------------------------------------------
-- reports
-- -----------------------------------------------------------------------------
--
-- Chemin : {project_id}/{report_id}.pdf
-- Écriture réservée au worker Docker, qui se présente en `service_role` et
-- échappe donc à RLS. Aucune policy d'écriture pour `authenticated`.

create policy reports_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'reports'
    and (
      public.is_admin()
      or public.is_project_member(((storage.foldername(name))[1])::uuid)
    )
  );
