# Régénère le logo de l'application et toutes ses déclinaisons.
#
#   pip install pillow
#   python tools/logo.py
#
# Le dessin : la plaque d'identification coupe-feu — celle du thème, voir
# `lib/app/theme.dart` — rivetée aux quatre coins, et au centre une traversée
# vue en coupe : le tube, puis le collier coupe-feu qui le serre. Le rouge y
# tient le rôle qu'il a partout dans l'application : il désigne ce qui classe.
#
# `assets/branding/logo.svg` est le même dessin en vectoriel, pour tout usage
# hors de l'application. Les deux doivent rester d'accord : les cotes
# ci-dessous sont celles du SVG, sur un carré de 1024.
#
# Ce script écrit :
#   assets/branding/logo.png                    1024 px
#   android/.../mipmap-*/ic_launcher.png        icône classique (Android 7)
#   android/.../mipmap-*/ic_launcher_foreground.png   icône adaptative
#   web/favicon.png, web/icons/Icon-*.png       version navigateur
from pathlib import Path

from PIL import Image, ImageDraw

RACINE = Path(__file__).resolve().parent.parent

# Les couleurs de `Fs`, et aucune autre.
ENCRE = (0x14, 0x18, 0x1C, 255)
ENCRE_ATTENUEE = (0x62, 0x6D, 0x78, 255)
FILET = (0xD9, 0xDD, 0xE1, 255)
PLAQUE = (0xFF, 0xFF, 0xFF, 255)
SIGNAL = (0xC8, 0x10, 0x2E, 255)
VIDE = (0, 0, 0, 0)

BASE = 1024
SUR = 4  # suréchantillonnage : dessiné quatre fois trop grand, puis réduit


def _disque(d, cx, cy, r, couleur):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=couleur)


def _traversee(d, echelle=1.0, fond=ENCRE):
    """Le tube et son collier, centrés. `echelle` les réduit pour l'icône
    adaptative, dont Android rogne les bords."""
    c = BASE * SUR / 2
    k = SUR * echelle
    _disque(d, c, c, 300 * k, SIGNAL)  # collier coupe-feu
    _disque(d, c, c, 205 * k, fond)    # jeu entre collier et tube
    _disque(d, c, c, 150 * k, PLAQUE)  # paroi du tube
    _disque(d, c, c, 78 * k, fond)     # intérieur du tube


def plaque():
    """Le logo complet : plaque, filet, rivets, traversée."""
    image = Image.new('RGBA', (BASE * SUR, BASE * SUR), VIDE)
    d = ImageDraw.Draw(image)
    s = SUR

    # Angles presque droits : la plaque est un objet rigide.
    d.rounded_rectangle([0, 0, BASE * s - 1, BASE * s - 1], radius=72 * s, fill=ENCRE)
    d.rounded_rectangle(
        [60 * s, 60 * s, (BASE - 60) * s, (BASE - 60) * s],
        radius=28 * s,
        outline=ENCRE_ATTENUEE,
        width=8 * s,
    )
    for x in (140, BASE - 140):
        for y in (140, BASE - 140):
            _disque(d, x * s, y * s, 24 * s, FILET)

    _traversee(d)
    return image.resize((BASE, BASE), Image.LANCZOS)


def premier_plan():
    """Premier plan de l'icône adaptative : la traversée seule, sur fond
    transparent. Android fournit la forme et le fond (`ic_launcher_background`),
    et rogne tout ce qui sort du cercle central — les rivets n'y survivraient
    pas."""
    image = Image.new('RGBA', (BASE * SUR, BASE * SUR), VIDE)
    # 0,72 : le collier tient dans la zone qu'aucun masque ne rogne (66/108).
    _traversee(ImageDraw.Draw(image), echelle=0.72)
    return image.resize((BASE, BASE), Image.LANCZOS)


def main():
    logo = plaque()
    avant = premier_plan()

    marque = RACINE / 'assets' / 'branding'
    marque.mkdir(parents=True, exist_ok=True)
    logo.save(marque / 'logo.png')

    res = RACINE / 'android' / 'app' / 'src' / 'main' / 'res'
    # densité : (icône classique 48 dp, premier plan adaptatif 108 dp)
    for densite, (classique, adaptatif) in {
        'mdpi': (48, 108),
        'hdpi': (72, 162),
        'xhdpi': (96, 216),
        'xxhdpi': (144, 324),
        'xxxhdpi': (192, 432),
    }.items():
        dossier = res / f'mipmap-{densite}'
        dossier.mkdir(parents=True, exist_ok=True)
        logo.resize((classique, classique), Image.LANCZOS).save(
            dossier / 'ic_launcher.png'
        )
        avant.resize((adaptatif, adaptatif), Image.LANCZOS).save(
            dossier / 'ic_launcher_foreground.png'
        )

    # Version navigateur : l'onglet, l'écran d'accueil, et les variantes
    # « masquables » que le système rogne à sa forme — même raisonnement que
    # l'icône adaptative d'Android, d'où le premier plan sur fond d'encre.
    web = RACINE / 'web'
    logo.resize((32, 32), Image.LANCZOS).save(web / 'favicon.png')
    masquable = Image.new('RGBA', (BASE, BASE), ENCRE)
    masquable.alpha_composite(avant)
    for cote in (192, 512):
        logo.resize((cote, cote), Image.LANCZOS).save(
            web / 'icons' / f'Icon-{cote}.png'
        )
        masquable.resize((cote, cote), Image.LANCZOS).save(
            web / 'icons' / f'Icon-maskable-{cote}.png'
        )
    print('logo régénéré')


if __name__ == '__main__':
    main()
