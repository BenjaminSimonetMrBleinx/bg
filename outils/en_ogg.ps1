# Convertit un son long en Ogg Vorbis.
#
#     .\outils\en_ogg.ps1 -Fichier livraisons\ia\musique\x.wav `
#                         -Sortie game\assets\sons\musique\x.ogg
#
# CE FICHIER EST EN ASCII STRICT. PowerShell 5.1 lit un .ps1 en CP-1252 quand
# il n'a pas de marque d'octets : un tiret cadratin y devient trois caracteres
# dont un guillemet, qui casse tout le fichier a partir de la.
#
# POURQUOI CET OUTIL EXISTE. La charte veut de l'Ogg pour la musique et les
# ambiances longues, du WAV pour les bruitages courts. Un theme de trente
# secondes pese six megaoctets en WAV et cinq cents kilo-octets en Ogg — douze
# fois moins, et le depot passe par Git LFS, donc ca se paie a chaque clone et
# a chaque build de release.
#
# CE QUI A ETE ESSAYE AVANT. Blender embarque un encodeur Vorbis et il est deja
# installe : bpy.ops.sound.mixdown() aurait evite une dependance de plus. Il ne
# marche pas en mode -b — Blender n'y initialise pas son systeme audio, et
# l'operateur retourne sans ecrire un octet, sans erreur. C'est le garde-fou
# « on relit le fichier ecrit » qui l'a dit ; sans lui on aurait eu un .ogg de
# zero octet que Godot aurait charge sans un mot pour ne jamais rien jouer.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Fichier,
    [Parameter(Mandatory = $true)][string]$Sortie,
    # 5 sur 10. Au-dessus, le poids double sans que ca s'entende dans un jeu
    # dont le rendu est deja volontairement grossier.
    [int]$Qualite = 5
)

$ErrorActionPreference = 'Stop'
$Racine = Split-Path -Parent $PSScriptRoot
Set-Location $Racine

# Le lien de winget n'est pas dans le PATH de la session courante juste apres
# l'installation : on cherche aussi dans le dossier des paquets.
$FFmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $FFmpeg) {
    $FFmpeg = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe" `
        -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
}
if (-not $FFmpeg) {
    Write-Host "ffmpeg introuvable. Installer :" -ForegroundColor Red
    Write-Host "  winget install --id Gyan.FFmpeg" -ForegroundColor Gray
    exit 1
}

if (-not (Test-Path $Fichier)) { Write-Host "introuvable : $Fichier" -ForegroundColor Red; exit 1 }
New-Item -ItemType Directory -Force (Split-Path $Sortie) | Out-Null

# -loglevel error, ET SURTOUT PAS DE REDIRECTION 2>&1.
#
# ffmpeg ecrit sa banniere de version et toute sa progression sur la sortie
# d'ERREUR, meme quand tout se passe bien. PowerShell traite la moindre ligne
# de stderr d'un binaire natif comme une erreur : le script echouait sur
# « ffmpeg version 9.0-full_build » alors que le fichier etait correctement
# ecrit. C'est le piege du projet, repaye une troisieme fois.
& $FFmpeg -y -loglevel error -i $Fichier -c:a libvorbis -q:a $Qualite $Sortie

# ON RELIT LE FICHIER ECRIT. Un encodeur qui echoue laisse un fichier vide, et
# rien en aval ne s'en plaint : Godot charge un .ogg de zero octet sans un mot.
if (-not (Test-Path $Sortie)) {
    Write-Host "ECHEC : rien n'a ete ecrit" -ForegroundColor Red
    exit 1
}
$avant = (Get-Item $Fichier).Length
$apres = (Get-Item $Sortie).Length
if ($apres -eq 0) {
    Write-Host "ECHEC : $Sortie fait zero octet" -ForegroundColor Red
    exit 1
}
Write-Host ("ogg       {0:N2} Mo -> {1:N2} Mo  ({2:N0} % du poids)" -f `
    ($avant / 1MB), ($apres / 1MB), (100.0 * $apres / $avant)) -ForegroundColor Green
Write-Host "sortie    $Sortie"
