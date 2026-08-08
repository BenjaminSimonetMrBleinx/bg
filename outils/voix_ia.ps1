# Range les voix generees au format du jeu, sous le nom que Godot cherche.
#
#     .\outils\voix_ia.ps1 -Travail .tmp\voix-ia\lot.json
#
# CE FICHIER EST EN ASCII STRICT. PowerShell 5.1 lit un .ps1 en CP-1252 quand
# il n'a pas de marque d'octets, et un seul caractere accentue casse tout le
# fichier a partir de la, sur une ligne jamais touchee.
#
# CE QUE CE SCRIPT NE FAIT PAS : generer. La generation passe par le MCP
# Magnific (audio_tts), qui demande une session OAuth et n'est donc pas
# scriptable : l'API REST n'expose aucun endpoint audio, dix chemins sondes le
# 08/08/2026, tous en 404. Ce script prend le RESULTAT et l'integre.
#
# LE FICHIER DE TRAVAIL est une liste d'objets :
#
#     [ { "qui": "Jesse", "vo": "Yo, you look like hell.", "url": "https://..." } ]
#
# 'qui' et 'vo' donnent le nom du fichier ; ils doivent etre copies mot pour mot
# de dialogues.json, sans quoi le jeu cherchera un nom qui n'existe pas et
# restera muet SANS LA MOINDRE ERREUR. C'est le seul point de contact entre les
# deux cotes.
#
# LES URL EXPIRENT. Elles sont signees et valables quelques heures : ce script
# se lance dans la foulee de la generation, pas le lendemain.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Travail,
    # Ecrase un fichier deja present. Sans ca, une voix deja rangee est gardee.
    [switch]$Refaire
)

$ErrorActionPreference = 'Stop'
$Racine = Split-Path -Parent $PSScriptRoot
$Sortie = Join-Path $Racine 'game\assets\voix'
New-Item -ItemType Directory -Force -Path $Sortie | Out-Null

$FFmpeg = Get-Item "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_*\*\bin\ffmpeg.exe" -ErrorAction SilentlyContinue |
          Select-Object -First 1
if (-not $FFmpeg) {
    $c = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($c) { $FFmpeg = Get-Item $c.Source }
}
if (-not $FFmpeg) { throw "ffmpeg introuvable. winget install --id Gyan.FFmpeg -e" }
$FFprobe = Join-Path (Split-Path $FFmpeg -Parent) 'ffprobe.exe'

# Meme empreinte que String.md5_text() cote Godot : MD5 de l'UTF-8, en
# hexadecimal minuscule. Sans cette identite, tout le monde reste muet.
function Empreinte([string]$texte) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $octets = [System.Text.Encoding]::UTF8.GetBytes($texte)
    -join ($md5.ComputeHash($octets) | ForEach-Object { $_.ToString('x2') })
}

# Doit produire exactement le meme nom que Dialogue._simplifier() cote Godot.
function Simplifier([string]$nom) {
    ($nom.ToLower() -replace '[^a-z0-9]', '')
}

# ConvertFrom-Json rend un tableau comme UN SEUL objet dans le pipeline : un
# @() autour n'en fait pas une liste de n elements, mais une liste de UN qui
# contient tout. Les trois premieres voix sont ainsi sorties fusionnees, sous
# le nom "Jesse Walter Tuco", sans la moindre erreur. Le += aplatit, lui.
$lot = @()
$lot += (Get-Content $Travail -Raw -Encoding UTF8 | ConvertFrom-Json)
Write-Host ""
Write-Host "$($lot.Count) voix a ranger" -ForegroundColor Cyan

# Le sas : les mp3 d'origine sont hors de git, comme tout original genere.
$sas = Join-Path $Racine 'livraisons\ia\voix'
New-Item -ItemType Directory -Force -Path $sas | Out-Null

$faits = 0
$sautes = 0
$rates = 0

foreach ($v in $lot) {
    $nom = "{0}_{1}.wav" -f (Simplifier $v.qui), (Empreinte $v.vo).Substring(0, 10)
    $cible = Join-Path $Sortie $nom

    if ((Test-Path $cible) -and -not $Refaire) { $sautes++; continue }

    $brut = Join-Path $sas ([IO.Path]::GetFileNameWithoutExtension($nom) + '.mp3')
    try {
        Invoke-WebRequest -Uri $v.url -OutFile $brut -UseBasicParsing
    } catch {
        Write-Host "  ! $($v.qui) : telechargement refuse (URL expiree ?)" -ForegroundColor Red
        $rates++
        continue
    }

    # MEME TRAITEMENT QUE LES VRAIES PRISES de gen_voix.ps1 -Integrer. Une voix
    # generee et une voix enregistree doivent sortir au meme niveau et a la meme
    # definition : deux qualites melangees s'entendent d'une replique a l'autre,
    # et c'est plus genant qu'une voix moyenne partout.
    #
    # 22 kHz mono : ce que sortait une PS2.
    & $FFmpeg -y -hide_banner -loglevel error -i $brut `
        -af "highpass=f=70,lowpass=f=8000,acompressor=threshold=-18dB:ratio=3,loudnorm=I=-18:TP=-2" `
        -ac 1 -ar 22050 -c:a pcm_s16le $cible
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ! $($v.qui) : ffmpeg a refuse $brut" -ForegroundColor Red
        $rates++
        continue
    }

    # ON MESURE LE FICHIER PRODUIT, jamais l'intention. Un ffmpeg qui sort en
    # code 0 sur une entree tronquee ecrit un WAV valide de zero seconde : le
    # jeu le chargerait sans erreur et le personnage serait muet, ce qui se
    # confondrait avec une voix manquante. On relit donc la duree.
    $duree = 0.0
    try {
        $duree = [double](& $FFprobe -v error -show_entries format=duration -of csv=p=0 $cible)
    } catch { $duree = 0.0 }
    if ($duree -lt 0.25) {
        Write-Host ("  ! {0} : {1:n2} s ecrit, c'est vide -> jete" -f $v.qui, $duree) -ForegroundColor Red
        Remove-Item $cible -Force -ErrorAction SilentlyContinue
        $rates++
        continue
    }

    Write-Host ("  {0,-9} {1,5:n1}s  {2}" -f $v.qui, $duree, $v.vo) -ForegroundColor Gray
    $faits++
}

Write-Host ""
Write-Host "$faits rangee(s), $sautes deja presente(s)" -ForegroundColor Green
if ($rates -gt 0) {
    Write-Host "$rates en echec : relancer apres avoir regenere" -ForegroundColor Yellow
}
Write-Host "-> $Sortie" -ForegroundColor Gray
if ($rates -gt 0) { exit 1 }
