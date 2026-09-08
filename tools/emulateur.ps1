# ATTENTION : ce fichier DOIT rester encode en UTF-8 avec BOM.
#
# PowerShell 5.1 lit sans BOM en ANSI. Les caracteres accentues et le tiret
# cadratin se decomposent alors en sequences dont certaines contiennent un
# guillemet double : la chaine se ferme en plein milieu, et l'erreur signalee
# pointe des dizaines de lignes plus bas que la vraie cause. Le corps du script
# s'en tient donc a l'ASCII, BOM ou pas.

# Demarre l'emulateur Android et ramene sa fenetre dans l'ecran.
#
# CE QUI SE PASSE REELLEMENT (mesure sur cette machine, emulateur 36.6.11)
#
# Ecran 1536x960, zone de travail 1536x912 (barre des taches). L'emulateur
# ouvre sa fenetre en 442x935 a la position (186, -1036) : 935 px de haut pour
# 912 disponibles, et entierement au-dessus de l'ecran. Elle apparait dans la
# barre des taches, cliquer dessus ne fait rien, et aucun message n'est emis.
#
# DEUX FAUSSES PISTES, ECARTEES PAR LA MESURE
#
#   * `-scale 0.3` ne sert a RIEN. L'option est declaree obsolete depuis
#     l'emulateur 2.0 et ignoree ("the '-scale <scale>' option is obsolete as
#     of Emulator 2.0 and will be ignored", cf. `emulator -help-scale`). La
#     fenetre mesure 442x935 avec ou sans elle : ces 935 px viennent de la mise
#     a l'echelle AUTOMATIQUE de l'emulateur, qui vise la hauteur de l'ecran
#     (960) sans retrancher la barre des taches. D'ou le debordement.
#
#   * `emulator-user.ini` est sain : `window.x = 100`, `window.y = 100`.
#     Inutile d'y toucher.
#
# CE QUI MARCHE
#
# La fenetre Qt est REDIMENSIONNABLE par `SetWindowPos`. C'est la moitie qui
# manquait : la deplacer sans la retailler ne pouvait pas tenir, puisqu'elle ne
# rentrait pas. Retaillee a 892 px de haut, elle se pose a (10,10) et n'en
# bouge plus.
#
# Corollaire : plus besoin de redemarrer pour changer la taille. Une echelle ne
# s'appliquait qu'a la creation du processus ; un redimensionnement, non.
#
# LA BARRE D'OUTILS SUIT TOUTE SEULE. L'emulateur ouvre bien deux fenetres
# (l'appareil, et sa barre laterale marche/arret-volume-rotation), mais la
# seconde est arrimee a la premiere : deplacer l'appareil l'emmene avec lui.
# Elle n'est repositionnee ici qu'en dernier recours, si elle reste dehors.
#
# Usage :
#   .\tools\emulateur.ps1                    # demarre si besoin, puis replace
#   .\tools\emulateur.ps1 -Relancer          # redemarrage propre
#   .\tools\emulateur.ps1 -Avd Pixel_5_API_30 -Marge 40

param(
    [string]$Avd = 'Pixel_7_Pro_API_34',
    [int]$Marge = 10,
    [switch]$Relancer
)

$ErrorActionPreference = 'Stop'

$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$emulateur = Join-Path $sdk 'emulator\emulator.exe'
$adb = Join-Path $sdk 'platform-tools\adb.exe'

if (-not (Test-Path $emulateur)) {
    Write-Host "emulator.exe introuvable dans $sdk" -ForegroundColor Red
    exit 1
}

# --- Win32 -----------------------------------------------------------------

$signature = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class FenetreEmulateur {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr apres, int x, int y, int l, int ht, uint f);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool EnumWindows(Rappel r, IntPtr p);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  public delegate bool Rappel(IntPtr h, IntPtr p);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue

# Fenetres de premier niveau, visibles et non degenerees, d'un processus donne.
#
# `MainWindowHandle` ne rend que la premiere : elle suffirait a placer
# l'appareil, jamais sa barre d'outils si celle-ci se detachait.
function Get-FenetresDe {
    param([int]$Proprietaire)

    $trouvees = New-Object System.Collections.ArrayList
    $rappel = [FenetreEmulateur+Rappel] {
        param($h, $p)
        $cible = 0
        [FenetreEmulateur]::GetWindowThreadProcessId($h, [ref]$cible) | Out-Null
        if ($cible -eq $Proprietaire -and [FenetreEmulateur]::IsWindowVisible($h)) {
            $zone = New-Object FenetreEmulateur+RECT
            [FenetreEmulateur]::GetWindowRect($h, [ref]$zone) | Out-Null
            $l = $zone.Right - $zone.Left
            $ht = $zone.Bottom - $zone.Top
            if ($l -gt 20 -and $ht -gt 20) {
                $n = [FenetreEmulateur]::GetWindowTextLength($h)
                $titre = New-Object System.Text.StringBuilder ($n + 1)
                [FenetreEmulateur]::GetWindowText($h, $titre, $titre.Capacity) | Out-Null
                $trouvees.Add([pscustomobject]@{
                    Handle  = $h
                    Titre   = $titre.ToString()
                    Largeur = $l
                    Hauteur = $ht
                    X       = $zone.Left
                    Y       = $zone.Top
                }) | Out-Null
            }
        }
        return $true
    }
    [FenetreEmulateur]::EnumWindows($rappel, [IntPtr]::Zero) | Out-Null
    return $trouvees
}

function Get-Emulateur {
    return Get-Process -Name qemu-system-x86_64* -ErrorAction SilentlyContinue |
           Select-Object -First 1
}

function Get-Geometrie {
    param($Fenetre)
    $zone = New-Object FenetreEmulateur+RECT
    [FenetreEmulateur]::GetWindowRect($Fenetre.Handle, [ref]$zone) | Out-Null
    return [pscustomobject]@{
        X       = $zone.Left
        Y       = $zone.Top
        Largeur = $zone.Right - $zone.Left
        Hauteur = $zone.Bottom - $zone.Top
    }
}

# --- Demarrage -------------------------------------------------------------
#
# `flutter emulators --launch` est volontairement evite : ce wrapper echoue sur
# cette machine (« exited with code 1 ») alors que l'executable direct demarre
# sans probleme.
#
# Aucune option d'echelle n'est passee : il n'en existe plus de fiable.
# `-scale` est ignore, et `-lcd-scaling-factor` est marque experimental et
# changerait la densite percue par l'application - ce n'est pas ce qu'on veut
# tester.

$enCours = & $adb devices | Select-String 'emulator-\d+\s+device'

# Un redemarrage impose un demarrage A FROID, et ce n'est pas une precaution
# de principe : `adb emu kill` interrompt l'emulateur sans lui laisser ecrire
# un instantane propre. Au lancement suivant il recharge cet instantane a
# moitie ecrit et reste bloque sur `offline` - `adb devices` le voit, il ne
# repond a rien, et aucun delai d'attente n'y change quoi que ce soit. Mesure
# faite : 4 minutes d'attente vaine, puis un cold boot qui aboutit en 40 s.
$aFroid = $false

if ($enCours -and $Relancer) {
    Write-Host "Arret de l'emulateur en cours..." -ForegroundColor DarkGray
    & $adb emu kill | Out-Null
    $limite = (Get-Date).AddSeconds(30)
    while ((Get-Emulateur) -and (Get-Date) -lt $limite) { Start-Sleep -Milliseconds 500 }

    # Ce qui survit a `emu kill` doit etre acheve a la main, sinon le port 5554
    # reste pris et le demarrage suivant echoue sans expliquer pourquoi.
    Get-Process -Name qemu-system-x86_64*, emulator* -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    $aFroid = $true
    $enCours = $null
}

if ($enCours) {
    Write-Host "Emulateur deja en cours." -ForegroundColor DarkGray
} else {
    $arguments = @('-avd', $Avd)
    if ($aFroid) { $arguments += '-no-snapshot-load' }

    $mention = if ($aFroid) { ' (a froid)' } else { '' }
    Write-Host ("Demarrage de {0}{1}..." -f $Avd, $mention)
    Start-Process $emulateur -ArgumentList $arguments

    Write-Host -NoNewline "Attente du demarrage"
    $limite = (Get-Date).AddSeconds(240)
    do {
        Start-Sleep -Seconds 3
        Write-Host -NoNewline '.'
        $sortie = & $adb devices
        $pret = $sortie | Select-String 'emulator-\d+\s+device'
        $bloque = $sortie | Select-String 'emulator-\d+\s+offline'
    } while (-not $pret -and (Get-Date) -lt $limite)
    Write-Host ''

    if (-not $pret) {
        Write-Host "L'emulateur n'a pas repondu dans les temps." -ForegroundColor Red
        if ($bloque) {
            Write-Host ''
            Write-Host "Il est vu par adb mais reste 'offline' : instantane corrompu." -ForegroundColor Yellow
            Write-Host "Un demarrage a froid le repare :" -ForegroundColor Yellow
            Write-Host "  .	ools\emulateur.ps1 -Relancer" -ForegroundColor Yellow
        }
        exit 1
    }
}

# --- Fenetres --------------------------------------------------------------
#
# Elles n'existent pas encore quand adb signale l'appareil : adb rend la main
# des que le systeme Android repond, avant que Qt n'ait dessine quoi que ce
# soit. C'est le handle Qt qu'il faut attendre, pas `adb devices`.

$limite = (Get-Date).AddSeconds(60)
do {
    Start-Sleep -Seconds 2
    $processus = Get-Emulateur
    $fenetres = if ($processus) { @(Get-FenetresDe -Proprietaire $processus.Id) } else { @() }
    $appareil = $fenetres | Where-Object { $_.Titre -like '*Android Emulator*' } | Select-Object -First 1
} while (-not $appareil -and (Get-Date) -lt $limite)

if (-not $appareil) {
    Write-Host "Emulateur pret, mais aucune fenetre d'appareil detectee." -ForegroundColor Yellow
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
$ecran = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

# Retailler AVANT de placer : une fenetre plus haute que la zone de travail ne
# peut pas y tenir, et Windows la repousse aussitot hors champ. C'est ce qui
# faisait croire que le repositionnement « ne tenait pas ».
$hauteurCible = $ecran.Height - (2 * $Marge)
$largeurCible = [int][Math]::Round($appareil.Largeur * $hauteurCible / $appareil.Hauteur)

if ($appareil.Hauteur -le ($ecran.Height - $Marge) -and $appareil.Y -ge 0) {
    # Deja dans l'ecran : ne pas la retailler pour rien, l'utilisateur a
    # peut-etre choisi sa taille.
    $hauteurCible = $appareil.Hauteur
    $largeurCible = $appareil.Largeur
}

$x = [Math]::Max(0, [Math]::Min($Marge, $ecran.Width - $largeurCible))
$y = [Math]::Max(0, [Math]::Min($Marge, $ecran.Height - $hauteurCible))

# SWP_NOZORDER | SWP_NOACTIVATE : ne pas voler le premier plan a l'editeur.
[FenetreEmulateur]::ShowWindow($appareil.Handle, 9) | Out-Null   # SW_RESTORE
[FenetreEmulateur]::SetWindowPos(
    $appareil.Handle, [IntPtr]::Zero, $x, $y, $largeurCible, $hauteurCible,
    0x0004 -bor 0x0010) | Out-Null

# La barre d'outils est arrimee a l'appareil et le suit d'elle-meme. On lui
# laisse le temps de se recoller, et on ne la force que si elle est restee
# dehors - la deplacer alors qu'elle allait revenir la ferait sauter.
Start-Sleep -Milliseconds 800

$reel = Get-Geometrie $appareil

foreach ($f in @(Get-FenetresDe -Proprietaire $processus.Id)) {
    if ($f.Handle -eq $appareil.Handle) { continue }
    $g = Get-Geometrie $f
    $dehors = $g.Y -lt 0 -or $g.X -lt 0 -or
              ($g.Y + $g.Hauteur) -gt $ecran.Height -or
              ($g.X + $g.Largeur) -gt $ecran.Width
    if ($dehors) {
        $bx = [Math]::Max(0, [Math]::Min($reel.X + $reel.Largeur + 4, $ecran.Width - $g.Largeur))
        $by = [Math]::Max(0, [Math]::Min($reel.Y, $ecran.Height - $g.Hauteur))
        [FenetreEmulateur]::SetWindowPos($f.Handle, [IntPtr]::Zero, $bx, $by, 0, 0,
            0x0001 -bor 0x0004 -bor 0x0010) | Out-Null
    }
}

[FenetreEmulateur]::SetForegroundWindow($appareil.Handle) | Out-Null

# Relire la position reelle plutot que d'annoncer celle demandee : si Qt la
# refuse, c'est precisement ce qu'il faut voir.
Start-Sleep -Milliseconds 400

Write-Host ''
Write-Host ("Zone de travail : {0}x{1}" -f $ecran.Width, $ecran.Height) -ForegroundColor DarkGray

$deborde = $false
foreach ($f in @(Get-FenetresDe -Proprietaire $processus.Id)) {
    $g = Get-Geometrie $f
    $nom = if ($f.Titre -like '*Android Emulator*') { 'appareil' } else { 'barre outils' }
    $dedans = $g.Y -ge 0 -and $g.X -ge 0 -and
              ($g.Y + $g.Hauteur) -le $ecran.Height -and
              ($g.X + $g.Largeur) -le $ecran.Width
    if (-not $dedans) { $deborde = $true }
    $etat = if ($dedans) { 'OK' } else { 'DEBORDE' }
    $couleur = if ($dedans) { 'Green' } else { 'Yellow' }
    Write-Host ("{0,-13} {1,4}x{2,-4} en ({3},{4})  {5}" -f $nom, $g.Largeur, $g.Hauteur, $g.X, $g.Y, $etat) -ForegroundColor $couleur
}

if ($deborde) {
    Write-Host ''
    Write-Host "Une fenetre deborde encore. Reessayez avec une marge plus grande :" -ForegroundColor Yellow
    Write-Host "  .\tools\emulateur.ps1 -Marge 60" -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Lancez maintenant :' -ForegroundColor DarkGray
Write-Host '  flutter run -d emulator-5554 --dart-define-from-file=env.json'
