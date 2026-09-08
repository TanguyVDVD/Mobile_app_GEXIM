-- =============================================================================
-- FireStop Tracker — papier à en-tête des rapports
-- =============================================================================
--
-- Un gabarit peut désormais porter le document type de l'entreprise ou de son
-- client : le rapport se compose par-dessus.
--
-- Rattaché au **gabarit** et non au client : c'est une caractéristique de mise
-- en page, au même titre que la couleur d'accentuation. Deux clients partageant
-- le même gabarit partagent le même papier, et un client qui change de charte
-- change de gabarit.
-- =============================================================================

alter table public.report_templates
  add column if not exists letterhead_cover_path text,
  add column if not exists letterhead_body_path  text;

comment on column public.report_templates.letterhead_cover_path is
  'PDF ou image, fond de la page de garde. Chemin dans le bucket letterheads.';
comment on column public.report_templates.letterhead_body_path is
  'Fond des pages suivantes. NULL = la page de garde est réutilisée.';

-- -----------------------------------------------------------------------------
-- Bucket
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'letterheads', 'letterheads', false, 10485760,
  array['application/pdf', 'image/png', 'image/jpeg']
)
on conflict (id) do nothing;

-- Lecture ouverte à tout compte authentifié : un papier à en-tête est le
-- document que l'entreprise imprime et diffuse, et le technicien qui consulte
-- un rapport doit pouvoir l'afficher. Restreindre imposerait de croiser
-- gabarit → client → affectation pour un gain nul.
create policy letterheads_select on storage.objects
  for select to authenticated
  using (bucket_id = 'letterheads');

-- Écriture réservée aux administrateurs : le papier à en-tête engage l'identité
-- visuelle de l'entreprise sur un document contractuel.
create policy letterheads_write on storage.objects
  for all to authenticated
  using (bucket_id = 'letterheads' and public.is_admin())
  with check (bucket_id = 'letterheads' and public.is_admin());

-- -----------------------------------------------------------------------------
-- Logos clients : autoriser aussi le remplacement
-- -----------------------------------------------------------------------------
--
-- `client_logos_write` couvrait déjà `for all`, mais l'envoi depuis
-- l'application utilise `upsert: true` pour rester idempotent après une coupure
-- réseau. Supabase Storage traduit cela en UPDATE quand l'objet existe déjà :
-- sans policy UPDATE explicite, seule la **reprise** d'un envoi échouait — et
-- uniquement sur réseau instable, donc jamais au bureau.
--
-- `for all` inclut bien UPDATE ; ce commentaire existe pour que personne ne la
-- restreigne en `for insert` en croyant durcir quelque chose.
