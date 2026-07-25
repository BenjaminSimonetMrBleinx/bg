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
    [switch]$Integrer,
    # Decoupe une longue prise en segments parles, et sort.
    [string]$Decouper = '',
    # Seuil de silence du decoupage, en dB. Plus bas = plus tolerant au bruit.
    [double]$Seuil = -40.0,
    # Duree minimale d un silence pour couper, en secondes.
    [double]$Pause = 0.6,
    # Affecte les segments decoupes aux repliques, dans l ordre. A n utiliser
    # qu apres avoir verifie que la prise suit le script sans reprise.
    [switch]$Assigner,
    # Numero de la premiere replique concernee : une prise ne couvre pas
    # forcement le script depuis le debut.
    [int]$Depuis = 1,
    # Ecart entre deux repliques successives de la prise. 2 = une sur deux.
    #
    # C'est le cas normal d'un dialogue : chaque comedien enregistre SA piste
    # de son cote, et ses repliques sont donc alternees dans le script. Sans
    # ce pas, il faudrait renommer dix fichiers a la main a chaque livraison.
    [int]$Pas = 1,
    # Confronte chaque segment au script, par reconnaissance vocale.
    [switch]$Reconnaitre
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
$FFprobe = Join-Path (Split-Path $FFmpeg -Parent) 'ffprobe.exe'

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

function Write-ScriptVoix {
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
function Import-Depot {
    if (-not (Test-Path $Index)) {
        Write-Host "`nAucun index. Lance d abord : .\bg.ps1 voix -Script" -ForegroundColor Yellow
        return 0
    }
    $table = Get-Content $Index -Raw -Encoding UTF8 | ConvertFrom-Json
    # On exclut les archives : sans ca, chaque passage reintegrerait les
    # prises deja traitees, les rearchiverait sous un nom double, et le
    # dossier gonflerait a chaque livraison.
    $fichiers = @(Get-ChildItem $Depot -File -Include *.wav, *.mp3, *.ogg, *.flac `
                  -Recurse -ErrorAction SilentlyContinue |
                  Where-Object { $_.DirectoryName -notlike '*\originaux*' })
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

        # La prise d origine est ARCHIVEE, jamais supprimee.
        #
        # Ce qui part dans le jeu est ecrase, compresse et ramene a 22 kHz :
        # c est une impasse, on ne remonte pas de la. Si quelqu un depose sa
        # seule copie et qu on l efface apres conversion, la prise est perdue
        # et il faut la refaire. Une premiere version faisait exactement ca.
        $archives = Join-Path $Depot 'originaux'
        New-Item -ItemType Directory -Force -Path $archives | Out-Null
        Move-Item $f.FullName (Join-Path $archives ("{0}_{1}" -f $num, $f.Name)) -Force

        # On note que cette replique a une vraie voix, pour que la synthese
        # ne repasse jamais dessus.
        $registre = Join-Path $Depot 'enregistrees.json'
        $deja = @()
        if (Test-Path $registre) {
            $deja = @(Get-Content $registre -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
        if ($deja -notcontains $num) { $deja += $num }
        ($deja | Sort-Object) | ConvertTo-Json -AsArray | Set-Content $registre -Encoding UTF8

        $n++
    }
    return $n
}

# ---------------------------------------------------------- decoupage
#
# Une longue prise contenant plusieurs repliques est le cas NORMAL : c est
# ainsi qu on enregistre, on ne s arrete pas entre chaque phrase. Le
# decoupage se fait donc apres coup, en cherchant les silences.
#
# Rien n est affecte automatiquement a une replique. Le nombre de segments ne
# correspond presque jamais au nombre de lignes — on se reprend, on tousse,
# on enchaine deux phrases d une traite. Deviner produirait un doublage ou
# chacun dit le texte du precedent, et personne ne verrait d ou ca vient.
function Split-Prise([string]$chemin) {
    if (-not (Test-Path $chemin)) { throw "introuvable : $chemin" }
    $sortie = Join-Path $Depot 'decoupe'
    New-Item -ItemType Directory -Force -Path $sortie | Out-Null

    $duree = [double](& $FFprobe -v error -show_entries format=duration -of csv=p=0 $chemin)
    $brut = & $FFmpeg -hide_banner -i $chemin -af "silencedetect=noise=$($Seuil)dB:d=$Pause" -f null NUL 2>&1

    # On reconstruit les segments PARLES a partir des silences detectes :
    # ffmpeg ne rapporte que les trous.
    $debuts = @(0.0)
    $fins = @()
    foreach ($l in $brut) {
        if ($l -match 'silence_start:\s*([0-9.]+)') { $fins += [double]$Matches[1] }
        elseif ($l -match 'silence_end:\s*([0-9.]+)') { $debuts += [double]$Matches[1] }
    }
    $fins += $duree

    $marge = 0.12          # on garde un souffle avant et apres
    $mini = 0.35           # en dessous, c'est un clic ou une respiration
    $n = 0
    $table = @()
    for ($i = 0; $i -lt [math]::Min($debuts.Count, $fins.Count); $i++) {
        $d = [math]::Max(0.0, $debuts[$i] - $marge)
        $f = [math]::Min($duree, $fins[$i] + $marge)
        $len = $f - $d
        if ($len -lt $mini) { continue }
        $n++
        $nom = 'seg_{0:d3}.wav' -f $n
        & $FFmpeg -y -hide_banner -loglevel error -ss $d -to $f -i $chemin `
            -c:a pcm_s16le (Join-Path $sortie $nom)
        $table += [pscustomobject]@{ Segment = $nom; Debut = [math]::Round($d, 2); Duree = [math]::Round($len, 2) }
    }

    Write-Host "`n$n segment(s) parles extraits de $(Split-Path $chemin -Leaf)" -ForegroundColor Green
    $table | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "-> $sortie" -ForegroundColor Gray
    Write-Host @"
Ecoute-les, puis renomme chacun avec le numero de sa replique
(voir docs\08-script-voix.md) et pose-le dans assets\voix\ :

    seg_002.wav  ->  001.wav
    seg_003.wav  ->  002.wav

Les segments non utilises se jettent. Rien n'est devine : le nombre de
segments ne correspond presque jamais au nombre de repliques.
"@ -ForegroundColor Gray
}

if ($Decouper) { Split-Prise $Decouper; exit 0 }

# ------------------------------------------------------------- reconnaissance
#
# Windows sait reconnaitre du francais hors ligne. On ne lui demande pas de
# transcrire librement — on lui donne les vingt phrases du script comme
# GRAMMAIRE FERMEE. Reconnaitre parmi vingt possibilites connues est un
# probleme bien plus facile que transcrire, et le score obtenu dit alors deux
# choses : quelle replique c'est, et si l'enregistrement est exploitable.
#
# Repere mesure sur ce projet : une phrase propre atteint 93 %. En dessous de
# 40 %, soit ce n'est pas une phrase du script, soit la prise est inutilisable.
function Test-Segments {
    $decoupe = Join-Path $Depot 'decoupe'
    $fichiers = @(Get-ChildItem $decoupe -Filter '*.wav' -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($fichiers.Count -eq 0) {
        Write-Host "`nAucun segment. Lance d abord : .\bg.ps1 voix -Decouper <fichier>" -ForegroundColor Yellow
        return
    }

    $moteurs = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers()
    $fr = @($moteurs | Where-Object { $_.Culture.Name -like 'fr*' })
    if ($fr.Count -eq 0) {
        Write-Host "`nAucun moteur de reconnaissance francais installe." -ForegroundColor Yellow
        Write-Host "Parametres > Heure et langue > Francais > Reconnaissance vocale." -ForegroundColor Gray
        return
    }

    $utiles = @()
    $i = 0
    foreach ($r in $repliques) {
        $i++
        if ($r.Texte -match '[a-zA-Z]') {
            $utiles += [pscustomobject]@{ N = $i; Qui = $r.Qui; Texte = $r.Texte }
        }
    }

    $moteur = New-Object System.Speech.Recognition.SpeechRecognitionEngine($fr[0])
    $ch = New-Object System.Speech.Recognition.Choices
    $utiles | ForEach-Object { $ch.Add($_.Texte) }
    $gb = New-Object System.Speech.Recognition.GrammarBuilder
    $gb.Culture = $fr[0].Culture
    $gb.Append($ch)
    $moteur.LoadGrammar((New-Object System.Speech.Recognition.Grammar($gb)))
    try { $moteur.UpdateRecognizerSetting("CFGConfidenceRejectionThreshold", 0) } catch {}

    $tmp = Join-Path $env:TEMP 'bg_reco.wav'
    Write-Host "`nMoteur : $($fr[0].Name) ($($fr[0].Culture))" -ForegroundColor Gray
    Write-Host ""

    foreach ($f in $fichiers) {
        # Le moteur veut du 16 kHz mono. On normalise au passage : une prise
        # trop faible n'est pas reconnue, et ce serait un faux negatif.
        & $FFmpeg -y -hide_banner -loglevel error -i $f.FullName `
            -af "highpass=f=80,loudnorm=I=-16:TP=-1.5" -ac 1 -ar 16000 -c:a pcm_s16le $tmp
        $moteur.SetInputToWaveFile($tmp)
        $res = $moteur.Recognize()
        if ($null -eq $res) {
            Write-Host ("  {0,-14}  --   rien de reconnaissable" -f $f.BaseName) -ForegroundColor Yellow
            continue
        }
        $l = $utiles | Where-Object { $_.Texte -eq $res.Text } | Select-Object -First 1
        $couleur = if ($res.Confidence -ge 0.4) { 'Green' } else { 'Yellow' }
        Write-Host ("  {0,-14} {1,4:P0}  -> {2:d3}  {3}" -f
                $f.BaseName, $res.Confidence, $l.N, $res.Text) -ForegroundColor $couleur
    }
    Remove-Item $tmp -ErrorAction SilentlyContinue
    Write-Host "`nEn vert : sur. En jaune : a verifier a l oreille." -ForegroundColor Gray
}

if ($Reconnaitre) { Test-Segments; exit 0 }

# Affecte les segments aux repliques DANS L ORDRE.
#
# A n utiliser qu apres avoir ecoute et confirme que la prise suit le script
# sans reprise ni oubli. C est le raccourci quand tout s est bien passe ; le
# renommage a la main reste la voie sure quand ce n est pas le cas.
if ($Assigner) {
    $decoupe = Join-Path $Depot 'decoupe'
    $segments = @(Get-ChildItem $decoupe -Filter 'seg_*.wav' -ErrorAction SilentlyContinue |
                  Sort-Object Name)
    if ($segments.Count -eq 0) {
        Write-Host "`nAucun segment. Lance d abord : .\bg.ps1 voix -Decouper <fichier>" -ForegroundColor Yellow
        exit 1
    }
    # Une prise ne couvre pas forcement tout le script : on peut enregistrer
    # les repliques 11 a 19, ou une sur deux. D ou le depart et le pas.
    $dernier = $Depuis + ($segments.Count - 1) * $Pas
    if ($dernier -gt $repliques.Count) {
        Write-Host "`n$($segments.Count) segment(s) au pas de $Pas depuis $Depuis" -ForegroundColor Yellow
        Write-Host "iraient jusqu a la replique $dernier, or il n y en a que $($repliques.Count)." -ForegroundColor Yellow
        Write-Host "Redecoupe avec un autre seuil, ou renomme a la main." -ForegroundColor Gray
        exit 1
    }
    $n = $Depuis
    foreach ($s in $segments) {
        Move-Item $s.FullName (Join-Path $Depot ('{0:d3}.wav' -f $n)) -Force
        $n += $Pas
    }
    $n = $dernier
    Remove-Item $decoupe -Recurse -Force -ErrorAction SilentlyContinue
    # $n est le numero de la DERNIERE replique, pas le nombre de segments :
    # une premiere version affichait "19 segments affectes de 001 a 019" pour
    # neuf fichiers poses de 011 a 019.
    Write-Host ("`n{0} segment(s) affectes aux repliques {1:d3} a {2:d3}." -f
            $segments.Count, $Depuis, $n) -ForegroundColor Green
    Write-Host "Verifie en jouant, puis livre : .\go.ps1" -ForegroundColor Gray
    exit 0
}

if ($Script) { Write-ScriptVoix; exit 0 }

if ($Integrer) {
    $n = Import-Depot
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
$proteges = 0
$temp = Join-Path $env:TEMP "bg_voix.wav"

# Les repliques deja enregistrees pour de vrai.
#
# Sans cette liste, -Refaire ecraserait par de la synthese des prises qui ont
# coute une soiree d enregistrement, et le seul avertissement serait le
# silence de celui qui les avait faites.
#
# La liste est tenue par l INTEGRATION, pas deduite du nom des archives : une
# prise unique peut couvrir les repliques 11 a 19, et son nom de fichier ne
# peut en porter qu un. C'est exactement ce qui s'est produit avec la
# confession de Walter, enregistree d'une traite sous le nom 001.
$Registre = Join-Path $Depot 'enregistrees.json'
$enregistrees = @{}
if (Test-Path $Registre) {
    foreach ($n in (Get-Content $Registre -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        $enregistrees["$n"] = $true
    }
}

$numero = 0
foreach ($r in $repliques) {
    $numero++
    if ($enregistrees.ContainsKey('{0:d3}' -f $numero)) {
        $proteges++
        continue
    }
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
if ($proteges -gt 0) {
    Write-Host "$proteges replique(s) laissees intactes : elles ont un vrai enregistrement" -ForegroundColor Cyan
}
Write-Host "-> $Sortie" -ForegroundColor Gray
