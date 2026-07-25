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

# --------------------------------------------------------------- 1. controles

Titre "1. Verification de ton installation"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Stop-Net "Git n est pas installe.`nTelecharge-le sur https://git-scm.com puis relance."
}
Bien "Git est la"

# Git LFS : la cause numero un des problemes sur ce depot. Sans lui, les
# fichiers binaires ne sont que des pointeurs texte de 130 octets, les images
# ne s ouvrent pas et les envois echouent avec un message incomprehensible.
$lfs = & git lfs version 2>&1
if ($LASTEXITCODE -ne 0) {
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

$sale = (& git status --porcelain)
& git pull --rebase --autostash 2>&1 | ForEach-Object { Info $_ }
if ($LASTEXITCODE -ne 0) {
    & git rebase --abort 2>&1 | Out-Null
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

& git add -A
if ($LASTEXITCODE -ne 0) { Stop-Net "Impossible de preparer les fichiers." }

& git commit -q -m $Message
if ($LASTEXITCODE -ne 0) { Stop-Net "Impossible d enregistrer les modifications." }
Bien "Modifications enregistrees"

& git push 2>&1 | ForEach-Object { Info $_ }
if ($LASTEXITCODE -ne 0) {
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
