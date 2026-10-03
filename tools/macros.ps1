# Reinscrit la macro "Nouveau point" dans le modele Excel.
#
#   powershell -ExecutionPolicy Bypass -File tools\macros.ps1
#
# NE METTRE AUCUN CARACTERE ACCENTUE DANS CE FICHIER : PowerShell 5.1 relit un
# script sans BOM en ANSI (voir CLAUDE.md). Le code VBA, lui, est accentue ;
# il vit dans tools\macros\Module1.bas, lu ici en UTF-8.
#
# Le projet VBA d'un classeur est un binaire que seul Excel sait ecrire. Le
# script ouvre donc une COPIE du modele dans Excel, y remplace le code de
# Module1, l'enregistre, puis ne reprend de cette copie que xl/vbaProject.bin.
# Le reste du modele n'est pas touche : un classeur reenregistre par Excel a
# ses styles renumerotes, et les emplacements releves par firestop_excel ne
# vaudraient plus rien.
#
# Excel n'ouvre son projet VBA a l'automatisation que si le reglage "Acces
# approuve au modele d'objet du projet VBA" est actif. Le script l'active le
# temps de son travail et le remet dans l'etat ou il l'a trouve.
#
# La premiere execution garde le modele d'origine dans tools\macros\.
$ErrorActionPreference = 'Stop'

$racine  = Split-Path -Parent $PSScriptRoot
$modele  = Join-Path $racine 'AS_BUILT_Resserages_RF_model_vierge.xlsm'
$source  = Join-Path $PSScriptRoot 'macros\Module1.bas'
$origine = Join-Path $PSScriptRoot 'macros\modele_origine.xlsm'
$travail = Join-Path $env:TEMP ('modele_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $travail | Out-Null
$copie  = Join-Path $travail 'copie.xlsm'
$sortie = Join-Path $travail 'sortie.xlsm'

if (-not (Test-Path $origine)) { Copy-Item $modele $origine }
Copy-Item $modele $copie

$code = Get-Content -Path $source -Raw -Encoding UTF8

$cle = 'HKCU:\Software\Microsoft\Office\16.0\Excel\Security'
if (-not (Test-Path $cle)) { New-Item -Path $cle -Force | Out-Null }
$avant = (Get-ItemProperty -Path $cle -Name AccessVBOM -ErrorAction SilentlyContinue).AccessVBOM
Set-ItemProperty -Path $cle -Name AccessVBOM -Value 1 -Type DWord

$xl = New-Object -ComObject Excel.Application
try {
  $xl.Visible = $false
  $xl.DisplayAlerts = $false
  $xl.AutomationSecurity = 3   # aucune macro ne s'execute pendant l'operation
  $wb = $xl.Workbooks.Open($copie)
  $module = $wb.VBProject.VBComponents.Item('Module1').CodeModule
  $module.DeleteLines(1, $module.CountOfLines)
  $module.AddFromString($code)
  $wb.SaveAs($sortie, 52)
  $wb.Close($false)
} finally {
  $xl.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
  [GC]::Collect(); [GC]::WaitForPendingFinalizers()
  # Excel reecrit ses reglages de securite en se fermant, donc APRES Quit() :
  # remis trop tot, le reglage reviendrait a 1 une seconde plus tard. On
  # attend que le processus ait rendu la main, puis on verifie.
  Start-Sleep -Seconds 4
  for ($essai = 0; $essai -lt 5; $essai++) {
    if ($null -eq $avant) {
      Remove-ItemProperty -Path $cle -Name AccessVBOM -ErrorAction SilentlyContinue
    } else {
      Set-ItemProperty -Path $cle -Name AccessVBOM -Value $avant -Type DWord
    }
    Start-Sleep -Seconds 1
    $apres = (Get-ItemProperty -Path $cle -Name AccessVBOM -ErrorAction SilentlyContinue).AccessVBOM
    if ($apres -eq $avant) { break }
  }
  if ($apres -ne $avant) {
    Write-Warning 'Le reglage AccessVBOM n''a pas pu etre remis dans son etat initial.'
  }
}

# Seul le projet VBA passe de la copie au modele.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$lu = [IO.Compression.ZipFile]::OpenRead($sortie)
try {
  $flux = $lu.GetEntry('xl/vbaProject.bin').Open()
  $memoire = New-Object IO.MemoryStream
  $flux.CopyTo($memoire)
  $flux.Dispose()
} finally { $lu.Dispose() }

$zip = [IO.Compression.ZipFile]::Open($modele, 'Update')
try {
  $zip.GetEntry('xl/vbaProject.bin').Delete()
  $entree = $zip.CreateEntry('xl/vbaProject.bin')
  $ecrit = $entree.Open()
  $octets = $memoire.ToArray()
  $ecrit.Write($octets, 0, $octets.Length)
  $ecrit.Dispose()
} finally { $zip.Dispose() }

Remove-Item -Recurse -Force $travail
Write-Output ('Macro reinscrite dans le modele : ' + $octets.Length + ' octets de projet VBA.')
