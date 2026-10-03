-- =============================================================================
-- Le numéro d'un point est un texte
-- =============================================================================
--
-- Le repérage d'un chantier n'est pas toujours une suite d'entiers : le modèle
-- Excel du bureau nomme ses fiches « 1.40 », « 1.167 ». Un entier ne sait pas
-- porter cela — « 1.40 » y deviendrait 1, ou serait refusé.
--
-- Les numéros déjà saisis sont conservés tels quels : 12 devient « 12 ».
--
-- Sans conséquence sur les règles d'accès : aucune policy, aucun trigger ne
-- lit cette colonne depuis que le serveur ne l'attribue plus.

alter table public.points
  alter column ref_number type text using ref_number::text;

-- Un numéro vide n'est pas un numéro : il se confondrait avec « pas de
-- numéro » tout en échappant au test `is null`.
alter table public.points
  add constraint points_ref_number_not_blank
  check (ref_number is null or length(btrim(ref_number)) > 0);

comment on column public.points.ref_number is
  'Numéro de la traversée, saisi par le technicien, en texte libre (« 12 », '
  '« 1.40 »). Ni attribué ni garanti unique par le serveur.';
