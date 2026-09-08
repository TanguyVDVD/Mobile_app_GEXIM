import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Surface bordée, angles francs — l'unité de base de l'interface.
///
/// Reprend la plaque d'identification coupe-feu rivetée près de chaque
/// traversée : une bordure nette qui délimite un fait, là où une ombre portée
/// suggérerait un objet flottant et interchangeable.
class Plate extends StatelessWidget {
  const Plate({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Fs.lg),
    this.accent = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Trait rouge sur le bord gauche : réservé à ce qui appelle une action.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Fs.plate,
      borderRadius: Fs.radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: Fs.radius,
        // Le liseré est posé en `Stack` plutôt qu'en enfant de `Row` étiré.
        //
        // `CrossAxisAlignment.stretch` demanderait à la rangée de dicter sa
        // hauteur à ses enfants — impossible dans une `ListView`, où la hauteur
        // est non bornée : Flutter lève « BoxConstraints forces an infinite
        // height » et abandonne la mise en page de **toute la liste**. Un
        // `Positioned` contraint par `top` et `bottom` prend la hauteur du
        // contenu sans jamais la réclamer.
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: Fs.radius,
                border: Border.all(color: Fs.hairline),
              ),
              child: Padding(padding: padding, child: child),
            ),
            if (accent)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Fs.signal,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Numéro de traversée, dans un cartouche carré.
///
/// Carré et non rond : un rond évoque un avatar, un carré bordé évoque
/// l'étiquette de repérage. Le numéro provisoire est marqué d'un tiret plutôt
/// que déguisé en définitif — il figurera dans un rapport de conformité.
class ReferenceTag extends StatelessWidget {
  const ReferenceTag({
    required this.label,
    this.isProvisional = false,
    super.key,
  });

  final String label;
  final bool isProvisional;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isProvisional ? Fs.ground : Fs.ink,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        border: isProvisional ? Border.all(color: Fs.hairline) : null,
      ),
      child: Text(
        label,
        style: Fs.reference.copyWith(
          color: isProvisional ? Fs.inkMuted : Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// État des deux clichés réglementaires, en deux segments.
///
/// Se lit d'un coup d'œil sans lire de texte : plein = présent, creux =
/// manquant. C'est l'information que l'opérateur balaie des dizaines de fois
/// avant de quitter le chantier.
class SealRule extends StatelessWidget {
  const SealRule({required this.before, required this.after, super.key});

  final bool before;
  final bool after;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segment(before),
        const SizedBox(width: 3),
        _segment(after),
        const SizedBox(width: Fs.sm),
        Text(
          switch ((before, after)) {
            (true, true) => 'Complet',
            (false, false) => 'Aucun cliché',
            (true, false) => 'Après manquant',
            (false, true) => 'Avant manquant',
          },
          style: TextStyle(
            fontSize: 14,
            color: before && after ? Fs.inkMuted : Fs.signal,
            fontWeight: before && after ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _segment(bool filled) {
    return Container(
      width: 20,
      height: 5,
      decoration: BoxDecoration(
        color: filled ? Fs.ink : Colors.transparent,
        border: filled ? null : Border.all(color: Fs.signal, width: 1),
        borderRadius: const BorderRadius.all(Radius.circular(1)),
      ),
    );
  }
}

/// Borne la largeur du contenu et le centre.
///
/// Sur une tablette de chantier — l'appareil visé — une liste pleine largeur
/// pose le titre à un bout et son chevron à l'autre, avec un mètre de blanc
/// entre les deux. L'œil doit traverser l'écran pour relier deux informations
/// qui vont ensemble, et la ligne devient plus difficile à suivre qu'un
/// téléphone.
///
/// 720 px : au-delà, une ligne de texte dépasse la longueur confortable, et
/// les plaques perdent leur densité.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({required this.child, this.maxWidth = 720, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Intitulé de section. Casse normale, jamais de capitales espacées.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Fs.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Écran vide : une invitation à agir, jamais un simple constat.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.body,
    this.icon,
    super.key,
  });

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Fs.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 32, color: Fs.inkMuted),
                const SizedBox(height: Fs.lg),
              ],
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Fs.sm),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
