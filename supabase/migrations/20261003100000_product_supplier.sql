-- =============================================================================
-- Un produit appartient à un fournisseur
-- =============================================================================
--
-- Jusqu'ici « fournisseur » et « produit » étaient deux listes indépendantes :
-- la fiche laissait choisir Promat puis un produit d'un autre fabricant. Le
-- produit désigne désormais son fournisseur, et la fiche ne propose que les
-- produits du fournisseur choisi.
--
-- Une colonne sur `setting_options` et non une table d'association : un
-- produit n'a qu'un fabricant, et la relation suit ainsi le même chemin de
-- synchronisation, les mêmes policies et le même last-write-wins que la ligne
-- qui la porte.
--
-- Fichier séparé, contrairement aux trois précédents : le schéma est déjà
-- installé sur le projet en ligne, il faut pouvoir le faire évoluer.

alter table public.setting_options
  add column parent_id uuid references public.setting_options (id);

alter table public.setting_options
  add constraint setting_options_parent_only_product
  check (parent_id is null or kind = 'product');

comment on column public.setting_options.parent_id is
  'Fournisseur d''un produit. Nul pour toute autre liste. Un produit sans '
  'fournisseur n''est proposé sur aucune fiche : l''écran Paramètres le '
  'signale et permet de le rattacher.';

create index setting_options_parent_idx
  on public.setting_options (parent_id, sort_order)
  where deleted_at is null;

-- La contrainte CHECK ne voit que la ligne ; que le parent soit bien un
-- fournisseur demande une lecture, donc un trigger.
--
-- `security invoker`, par défaut : la lecture de `setting_options` est ouverte
-- à tout compte authentifié, il n'y a rien à contourner.
create or replace function public.guard_option_parent()
returns trigger
language plpgsql
as $$
begin
  if new.parent_id is not null and not exists (
    select 1 from public.setting_options s
     where s.id = new.parent_id
       and s.kind = 'supplier'
  ) then
    raise exception 'Le parent d''un produit doit être un fournisseur'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger setting_options_guard_parent
  before insert or update on public.setting_options
  for each row execute function public.guard_option_parent();

-- Rattachement de l'existant. Tant qu'il n'existe qu'un fournisseur, tout
-- produit est forcément le sien — c'est le cas du catalogue initial, tout
-- entier chez Promat. Avec plusieurs fournisseurs, rien ne permet de deviner :
-- les produits restent sans parent, et l'administrateur les rattache depuis
-- l'écran Paramètres.
--
-- `updated_at = now()` : sans lui `reject_stale_write` laisserait passer, mais
-- le last-write-wins des tablettes écarterait la ligne redescendue. Le trigger
-- `_touch_synced` réestampille `synced_at`, donc les produits redescendent.
update public.setting_options p
   set parent_id  = s.id,
       updated_at = now()
  from public.setting_options s
 where p.kind = 'product'
   and p.parent_id is null
   and s.kind = 'supplier'
   and s.deleted_at is null
   and (select count(*) from public.setting_options
         where kind = 'supplier' and deleted_at is null) = 1;
