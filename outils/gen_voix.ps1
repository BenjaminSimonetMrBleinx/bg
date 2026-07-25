<#
.SYNOPSIS
    Fabrique un fichier audio par replique de dialogues.json.

.DESCRIPTION
    Lit game\donnees\dialogues.json et game\donnees\voix.json, synthetise
    chaque replique avec la voix de Windows, la transpose selon le profil du
    personnage, et ecrit game\assets\voix\<qui>_<empreinte>.wav.

    Le nom du fichier contient l empreinte MD5 du texte. Consequences utiles :
    changer une replique ne regenere QUE celle-la, et le jeu retrouve le bon
    fichier sans index a maintenir. Godot calcule la meme empreinte avec
    md5_text().

    Tout se passe hors ligne. Aucun compte, aucune cle, rien a installer :
    la synthese vocale est fournie avec Windows.
#>
[CmdletBinding()]
param(
    [string]$Racine = (Split-Path $PSScriptRoot -Parent),
    # Regenere meme ce qui existe deja.
    [switch]$Refaire,
    # Affiche les voix installees et sort.
    [switch]$Voix,
    # Ecrit le script d enregistrement pour un comedien, et sort.
    [switch]$Script,
    # Integre les fichiers deposes dans assets\voix\, et sort.
    [switch]$Integrer
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech

if ($Voix) {
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    Write-Host "`nVoix installees sur cette machine :" -ForegroundColor Cyan
    $s.GetInstalledVoices() | ForEach-Object {
        $i = $_.VoiceInfo
        Write-Host ("  {0,-30} {1,-8} {2}" -f $i.Name, $i.Gender, $i.Culture)
    }
    Write-Host "`nPour en ajouter : Parametres > Heure et langue > Voix." -ForegroundColor Gray
    $s.Dispose()
    exit 0
}

$Dialogues = Join-Path $Racine 'game\donnees\dialogues.json'
$Profils   = Join-Path $Racine 'game\donnees\voix.json'
$Sortie    = Join-Path $Racine 'game\assets\voix'

foreach ($f in @($Dialogues, $Profils)) {
    if (-not (Test-Path $f)) { throw "introuvable : $f" }
}
New-Item -ItemType Directory -Force -Path $Sortie | Out-Null

$FFmpeg = Get-Item "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_*\*\bin\ffmpeg.exe" -ErrorAction SilentlyContinue |
          Select-Object -First 1
if (-not $FFmpeg) {
    $c = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($c) { $FFmpeg = Get-Item $c.Source }
}
if (-not $FFmpeg) { throw "ffmpeg introuvable. winget install --id Gyan.FFmpeg -e" }

$d = Get-Content $Dialogues -Raw -Encoding UTF8 | ConvertFrom-Json
$p = Get-Content $Profils -Raw -Encoding UTF8 | ConvertFrom-Json

# Meme empreinte que String.md5_text() cote Godot : MD5 de l UTF-8, en
# hexadecimal minuscule. Sans cette identite, le jeu chercherait des noms de
# fichiers qui n existent pas, en silence.
function Empreinte([string]$texte) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $octets = [System.Text.Encoding]::UTF8.GetBytes($texte)
    -join ($md5.ComputeHash($octets) | ForEach-Object { $_.ToString('x2') })
}

# Le nom de fichier doit survivre a un systeme de fichiers : pas d accent,
# pas d espace.
function Simplifier([string]$nom) {
    $plat = [System.Text.Encoding]::ASCII.GetString(
        [System.Text.Encoding]::GetEncoding('ISO-8859-8',
            [System.Text.EncoderFallback]::ReplacementFallback,
            [System.Text.DecoderFallback]::ReplacementFallback
        ).GetBytes($nom.Normalize([System.Text.NormalizationForm]::FormD)))
    ($plat -replace '[^A-Za-z0-9]', '').ToLower()
}

# On rassemble d abord toutes les repliques : un personnage peut parler dans
# la conversation de quelqu un d autre.
$repliques = @()
foreach ($cle in $d.PSObject.Properties.Name) {
    if ($cle -like '_*') { continue }
    $fiche = $d.$cle
    foreach ($conv in $fiche.conversations) {
        foreach ($r in $conv) {
            $repliques += [pscustomobject]@{ Qui = $r.qui; Texte = $r.texte }
        }
    }
}

Write-Host "`n$($repliques.Count) replique(s) dans dialogues.json" -ForegroundColor Cyan

# --------------------------------------------------- script d enregistrement
#
# Personne ne doit calculer une empreinte MD5 a la main. Le comedien recoit
# des NUMEROS et enregistre 001.wav, 002.wav... C est ainsi que se fait un
# vrai enregistrement, et c est la seule convention qu on puisse suivre a
# l oreille sans se tromper.
$Depot = Join-Path $Racine 'assets\voix'
$Index = Join-Path $Depot 'index.json'

function Ecrire-Script {
    New-Item -ItemType Directory -Force -Path $Depot | Out-Null
    $lignes = @()
    $table = @()
    $n = 0
    foreach ($r in $repliques) {
        $n++
        $num = '{0:d3}' -f $n
        $cible = "{0}_{1}.wav" -f (Simplifier $r.Qui), (Empreinte $r.Texte).Substring(0, 10)
        $table += [pscustomobject]@{ numero = $num; qui = $r.Qui; texte = $r.Texte; cible = $cible }
        $lignes += "| $num | **$($r.Qui)** | $($r.Texte) |"
    }
    $table | ConvertTo-Json -Depth 4 | Set-Content $Index -Encoding UTF8

    $doc = Join-Path $Racine 'docs\08-script-voix.md'
    $entete = @"
# Script d'enregistrement des voix

**Genere par ``.\bg.ps1 voix -Script``. Ne pas modifier a la main** — il est
reecrit a chaque fois que les dialogues changent.

## Comment enregistrer

1. Enregistre **un fichier par ligne**, dans l'ordre ou dans le desordre.
2. Nomme-le avec son **numero** : ``001.wav``, ``002.wav``, ``017.wav``.
   Le reste du nom est libre : ``012_jesse_yo.wav`` marche aussi.
3. Depose-les dans **``assets\voix\``** a la racine du depot.
4. Lance ``.\livrer.ps1`` — ils sont convertis, renommes et ranges tout seuls.

Tu n'as **rien d'autre a faire**. Pas de format impose, pas de dossier a
creer : n'importe quel WAV, MP3 ou OGG convient, il sera converti en 22 kHz
mono, la definition d'une PS2.

Une ligne sans enregistrement garde la voix de synthese. On peut donc en
livrer trois aujourd'hui et le reste plus tard, sans rien casser.

## Les repliques

| N° | Qui | Texte |
|---|---|---|
"@
    Set-Content $doc ($entete + ($lignes -join "`n") + "`n") -Encoding UTF8
    Write-Host "`nScript ecrit : $doc" -ForegroundColor Green
    Write-Host "Depot des enregistrements : $Depot" -ForegroundColor Gray
}

# ------------------------------------------------------------- integration
#
# Prend ce que le comedien a depose et le met la ou le jeu le cherche.
function Integrer-Depot {
    if (-not (Test-Path $Index)) {
        Write-Host "`nAucun index. Lance d abord : .\bg.ps1 voix -Script" -ForegroundColor Yellow
        return 0
    }
    $table = Get-Content $Index -Raw -Encoding UTF8 | ConvertFrom-Json
    $fichiers = @(Get-ChildItem $Depot -File -Include *.wav, *.mp3, *.ogg, *.flac `
                  -Recurse -ErrorAction SilentlyContinue)
    if ($fichiers.Count -eq 0) { return 0 }

    $n = 0
    foreach ($f in $fichiers) {
        # Le numero est la premiere suite de chiffres du nom. Tout le reste
        # est libre : le comedien nomme comme il veut autour.
        if ($f.BaseName -notmatch '^(\d{1,3})') {
            Write-Host "  ? $($f.Name) : aucun numero en debut de nom, ignore" -ForegroundColor Yellow
            continue
        }
        $num = '{0:d3}' -f [int]$Matches[1]
        $ligne = $table | Where-Object { $_.numero -eq $num } | Select-Object -First 1
        if (-not $ligne) {
            Write-Host "  ? $($f.Name) : le numero $num n existe pas dans le script" -ForegroundColor Yellow
            continue
        }

        $cible = Join-Path $Sortie $ligne.cible
        & $FFmpeg -y -hide_banner -loglevel error -i $f.FullName `
            -af "highpass=f=70,lowpass=f=8000,acompressor=threshold=-18dB:ratio=3,loudnorm=I=-18:TP=-2" `
            -ac 1 -ar 22050 -c:a pcm_s16le $cible
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ! $($f.Name) : ffmpeg a refuse ce fichier" -ForegroundColor Red
            continue
        }
        Write-Host ("  {0}  {1,-9} {2}" -f $num, $ligne.qui, $ligne.texte) -ForegroundColor Gray
        Remove-Item $f.FullName -Force
        $n++
    }
    return $n
}

if ($Script) { Ecrire-Script; exit 0 }

if ($Integrer) {
    $n = Integrer-Depot
    Write-Host ""
    if ($n -eq 0) {
        Write-Host "Aucun enregistrement a integrer." -ForegroundColor Gray
    } else {
        Write-Host "$n enregistrement(s) integres. Ils remplacent la synthese." -ForegroundColor Green
    }
    exit 0
}

$synthes = @{}
$faits = 0
$sautes = 0
$temp = Join-Path $env:TEMP "bg_voix.wav"

foreach ($r in $repliques) {
    $profil = if ($p.voix.PSObject.Properties.Name -contains $r.Qui) {
        $p.voix.($r.Qui)
    } else {
        Write-Host "  ! aucun profil pour '$($r.Qui)', voix par defaut" -ForegroundColor Yellow
        $p.defaut
    }

    $nom = "{0}_{1}.wav" -f (Simplifier $r.Qui), (Empreinte $r.Texte).Substring(0, 10)
    $cible = Join-Path $Sortie $nom

    if ((Test-Path $cible) -and -not $Refaire) { $sautes++; continue }

    # Un synthetiseur par voix, garde d une replique a l autre : en creer un
    # par ligne coute plus cher que la synthese elle-meme.
    if (-not $synthes.ContainsKey($profil.moteur)) {
        $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $s.SelectVoice($profil.moteur)
        $synthes[$profil.moteur] = $s
    }
    $s = $synthes[$profil.moteur]
    $s.Rate = [int]$profil.debit
    $s.SetOutputToWaveFile($temp)
    $s.Speak($r.Texte)
    $s.SetOutputToNull()

    # asetrate descend la hauteur ET les formants ; atempo retablit le debit.
    # Le compresseur egalise le niveau d une replique a l autre — une phrase
    # deux fois plus forte que la suivante s entend immediatement.
    $h = [double]$profil.hauteur
    $tempo = [math]::Round(1.0 / $h, 4)
    $filtre = "asetrate=22050*$h,aresample=22050,atempo=$tempo," +
              "highpass=f=$($profil.grave),lowpass=f=$($profil.aigu)," +
              "acompressor=threshold=-18dB:ratio=3,volume=2.2"

    # 22 kHz mono : ce que sortait une PS2. Ce n est pas de la coquetterie,
    # ca masque une bonne partie des artefacts de la synthese.
    & $FFmpeg -y -hide_banner -loglevel error -i $temp -af $filtre `
        -ac 1 -ar 22050 -c:a pcm_s16le $cible
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg a echoue sur : $($r.Texte)" }

    $faits++
    Write-Host ("  {0,-9} {1}" -f $r.Qui, $r.Texte) -ForegroundColor Gray
}

foreach ($s in $synthes.Values) { $s.Dispose() }
Remove-Item $temp -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "$faits fichier(s) ecrits, $sautes deja a jour" -ForegroundColor Green
Write-Host "-> $Sortie" -ForegroundColor Gray
