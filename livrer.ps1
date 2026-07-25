<#
.SYNOPSIS
    Envoie ton travail sur GitHub. Une seule commande.

.DESCRIPTION
    Verifie que tout est en ordre, recupere le travail des autres, liste ce
    que tu t appretes a envoyer, puis envoie. A chaque etape, si quelque
    chose cloche, le script dit quoi faire au lieu d echouer.

.EXAMPLE
    .\livrer.ps1
    Fait tout, avec une demande de confirmation.

.EXAMPLE
    .\livrer.ps1 "sons moteur et portieres"
    Pareil, avec ta propre description.

.EXAMPLE
    .\livrer.ps1 -Quoi
    Montre seulement ce qui partirait, sans rien envoyer.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message = "",

    # N envoie rien, montre seulement.
    [switch]$Quoi,

    # Ne demande pas confirmation.
    [switch]$Oui
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Titre($t) { Write-Host "`n$t" -ForegroundColor Cyan }
function Bien($t)  { Write-Host "  $t" -ForegroundColor Green }
function Info($t)  { Write-Host "  $t" -ForegroundColor Gray }
function Souci($t) { Write-Host "  $t" -ForegroundColor Yellow }
function Stop-Net($t) {
    Write-Host "`n$t`n" -ForegroundColor Red
    exit 1
}

# git ecrit sa progression sur la sortie d ERREUR, meme quand tout se passe
# bien : "To https://github.com/...", le decompte des objets, tout y passe.
# Avec ErrorActionPreference a Stop, PowerShell 5.1 transforme ces lignes en
# erreur bloquante - le script annoncait donc un echec sur un envoi
# parfaitement reussi. On isole les appels natifs et on ne juge que le code
# de sortie, seul indicateur fiable.
function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lignes = & git @Arguments 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Code = $LASTEXITCODE; Lignes = $lignes }
    } finally {
        $ErrorActionPreference = $ancien
    }
}

# git est bavard : compteurs de progression repetes ligne apres ligne,
# avertissements de fins de ligne Windows. Noyer l information utile
# la-dedans revient a ne rien afficher du tout.
function Select-Utile($lignes) {
    $bruit = 'Updating files:|Receiving objects|Resolving deltas|remote: (Counting|Compressing|Total)|LF will be replaced|Created autostash|^\s*$'
    return @($lignes | Where-Object { $_ -notmatch $bruit })
}

# --------------------------------------------------------------- 1. controles

Titre "1. Verification de ton installation"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Stop-Net "Git n est pas installe.`nTelecharge-le sur https://git-scm.com puis relance."
}
Bien "Git est la"

# Git LFS : la cause numero un des problemes sur ce depot. Sans lui, les
# fichiers binaires ne sont que des pointeurs texte de 130 octets, les images
# ne s ouvrent pas et les envois echouent avec un message incomprehensible.
$r_lfs = Invoke-Git lfs version
$lfs = $r_lfs.Lignes -join ' '
if ($r_lfs.Code -ne 0) {
    Stop-Net @"
Git LFS n est pas installe. C est indispensable ici : le depot stocke les
images, les sons et les .blend a travers lui.

  1. Telecharge-le sur https://git-lfs.com
  2. Puis, dans ce dossier :
       git lfs install
       git lfs pull
  3. Relance ce script.
"@
}
Bien "Git LFS est la ($($lfs -replace 'git-lfs/([\d.]+).*', '$1'))"

$nom = (& git config user.name)
$mail = (& git config user.email)
if (-not $nom -or -not $mail) {
    Stop-Net @"
Git ne sait pas qui tu es. Une seule fois, colle ces deux lignes en
remplacant par tes infos :

  git config --global user.name "Guillaume"
  git config --global user.email "gui.s@live.fr"

Puis relance ce script.
"@
}
Bien "Tu es identifie comme $nom <$mail>"

# Un clone fait sans LFS laisse des pointeurs a la place des images.
$temoin = "game/assets/textures/route.png"
if (Test-Path $temoin) {
    $taille = (Get-Item $temoin).Length
    if ($taille -lt 1000) {
        Souci "Tes images sont des pointeurs, pas de vraies images."
        Info  "Reparation : git lfs install puis git lfs pull"
        Stop-Net "Repare d abord, sinon tu risques d envoyer des fichiers casses."
    }
}
Bien "Les fichiers binaires sont bien telecharges"

# ------------------------------------------------- 2. recuperer le travail des autres

Titre "2. Recuperation du travail des autres"

$r_pull = Invoke-Git pull --rebase --autostash
Select-Utile $r_pull.Lignes | ForEach-Object { Info $_ }
if ($r_pull.Code -ne 0) {
    Invoke-Git rebase --abort | Out-Null
    Stop-Net @"
La recuperation a echoue : quelqu un a modifie les memes fichiers que toi.

Rien n est perdu et rien n a ete envoye. Envoie une copie d ecran de ce
message a Benjamin, il demelera en deux minutes.
"@
}
Bien "A jour avec GitHub"

# ------------------------------------------------------- 3. ce que tu vas envoyer

Titre "3. Ce que tu t appretes a envoyer"

$etat = & git status --porcelain
if (-not $etat) {
    Write-Host "`n  Rien de nouveau. Tout ton travail est deja sur GitHub.`n" -ForegroundColor Green
    exit 0
}

$fichiers = @()
foreach ($ligne in $etat) {
    $code = $ligne.Substring(0, 2).Trim()
    $chemin = $ligne.Substring(3).Trim('"')
    $verbe = switch -Regex ($code) {
        '^\?\?' { 'nouveau'  }
        '^D'    { 'supprime' }
        default { 'modifie'  }
    }
    $fichiers += [pscustomobject]@{ Etat = $verbe; Fichier = $chemin }
}

$fichiers | Sort-Object Etat, Fichier | Format-Table -AutoSize | Out-String |
    ForEach-Object { Write-Host $_ -ForegroundColor Gray }

$sons = @($fichiers | Where-Object { $_.Fichier -match '\.(wav|ogg|mp3)$' }).Count
$trois_d = @($fichiers | Where-Object { $_.Fichier -match '\.(blend|glb|fbx|obj)$' }).Count
$images = @($fichiers | Where-Object { $_.Fichier -match '\.(png|jpg|tga|psd)$' }).Count

# Un MP3 livre comme master ne peut plus etre remonte : autant le dire ici.
$mp3 = @($fichiers | Where-Object { $_.Fichier -match '\.mp3$' })
if ($mp3) {
    Souci "Des fichiers MP3 sont sur le point de partir :"
    $mp3 | ForEach-Object { Info "  $($_.Fichier)" }
    Info "Le projet attend du WAV 48 kHz 16 bits. Voir docs/04-brief-son.md"
}

# Chacun sa voie : assets/ et docs/ pour les livraisons, game/ et outils/
# pour le code et ce qui en est genere. Rien n est bloque - il arrive tout a
# fait qu on doive toucher a l autre moitie - mais un binaire ne se fusionne
# pas : si deux personnes regenerent le meme .glb, l un des deux travaux est
# perdu au moment de resoudre le conflit. Autant le voir avant d envoyer.
$hors_voie = @($fichiers | Where-Object {
    $_.Fichier -notmatch '^(assets|docs)/' -and $_.Fichier -notmatch '^[^/]+$'
})
$generes = @($hors_voie | Where-Object {
    $_.Fichier -match '\.(glb|import|uid)$' -or $_.Fichier -match '^game/assets/'
})
if ($generes.Count -gt 4) {
    Souci "$($generes.Count) fichiers generes par Godot ou Blender vont partir."
    Info  "C est normal apres un premier import, ou si tu as lance bg.ps1 generer."
    Info  "Si tu n as fait ni l un ni l autre, signale-le a Benjamin avant d envoyer."
}

# Les gros fichiers passent par LFS, mais autant savoir ce qu on envoie.
foreach ($f in $fichiers) {
    if ((Test-Path $f.Fichier) -and (Get-Item $f.Fichier).Length -gt 50MB) {
        $mo = [math]::Round((Get-Item $f.Fichier).Length / 1MB)
        Souci "$($f.Fichier) pese $mo Mo. C est gros, verifie que c est voulu."
    }
}

if ($Quoi) {
    Write-Host "`n  Mode apercu : rien n a ete envoye.`n" -ForegroundColor Cyan
    exit 0
}

# ------------------------------------------------------------------ 4. envoi

if (-not $Message) {
    $morceaux = @()
    if ($sons)    { $morceaux += "$sons son(s)" }
    if ($trois_d) { $morceaux += "$trois_d modele(s) 3D" }
    if ($images)  { $morceaux += "$images image(s)" }
    $Message = if ($morceaux) { $morceaux -join ", " }
               else { "$($fichiers.Count) fichier(s)" }
}

Titre "4. Envoi"
Info "Description : $Message"

if (-not $Oui) {
    $rep = Read-Host "`n  Envoyer ces $($fichiers.Count) fichier(s) ? [O/n]"
    if ($rep -and $rep -notmatch '^[oOyY]') {
        Write-Host "`n  Annule. Rien n a ete envoye.`n" -ForegroundColor Yellow
        exit 0
    }
}

if ((Invoke-Git add -A).Code -ne 0) { Stop-Net "Impossible de preparer les fichiers." }

if ((Invoke-Git commit -q -m $Message).Code -ne 0) {
    Stop-Net "Impossible d enregistrer les modifications."
}
Bien "Modifications enregistrees"

$r_push = Invoke-Git push
Select-Utile $r_push.Lignes | ForEach-Object { Info $_ }
if ($r_push.Code -ne 0) {
    Stop-Net @"
L envoi a echoue.

Ton travail est enregistre en local, rien n est perdu. Causes courantes :

  - GitHub te demande un mot de passe : il n en accepte plus depuis 2021.
    Installe Git Credential Manager (fourni avec Git pour Windows) ou
    relance simplement, une fenetre de connexion devrait s ouvrir.
  - Pas de connexion internet.

Si ca persiste, envoie ce message a Benjamin.
"@
}

Write-Host "`n  Envoye. $($fichiers.Count) fichier(s) sont sur GitHub.`n" -ForegroundColor Green
