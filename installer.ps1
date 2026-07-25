<#
.SYNOPSIS
    Installe tout ce dont le projet a besoin. A lancer une fois.

.DESCRIPTION
    Detecte ce qui manque, l installe via winget, repare le telechargement
    des fichiers binaires, et verifie que le jeu se lance. Ce qui est deja
    present est laisse tranquille - le script peut etre relance sans risque.

    Certaines installations demandent une confirmation Windows : c est normal,
    reponds oui.

.EXAMPLE
    .\installer.ps1
    Installe ce qui manque.

.EXAMPLE
    .\installer.ps1 -Simuler
    Montre ce qui serait installe, sans rien toucher.
#>
[CmdletBinding()]
param(
    # Ne rien installer, seulement dire quoi.
    [switch]$Simuler
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Titre($t) { Write-Host "`n$t" -ForegroundColor Cyan }
function Bien($t)  { Write-Host "  $t" -ForegroundColor Green }
function Info($t)  { Write-Host "  $t" -ForegroundColor Gray }
function Souci($t) { Write-Host "  $t" -ForegroundColor Yellow }

# Recharge le PATH depuis le registre : sans ca, un outil installe a l instant
# reste invisible pour la session en cours, et le script croit avoir echoue.
function Update-Chemin {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User")
}

# git et winget ecrivent leur progression sur la sortie d ERREUR, meme quand
# tout va bien. Avec ErrorActionPreference a Stop, PowerShell 5.1 en fait une
# erreur bloquante et le script s arrete sur un succes. On isole donc les
# appels externes et on ne juge que le code de sortie.
# Pas de bloc param() : un parametre nomme se laisse abreger, et les
# drapeaux courts des outils appeles (-A, -e, -m...) seraient pris pour lui.
function Invoke-Externe {
    $prog = $args[0]
    $reste = @()
    if ($args.Count -gt 1) { $reste = $args[1..($args.Count - 1)] }
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lignes = & $prog @reste 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Code = $LASTEXITCODE; Lignes = $lignes }
    } finally {
        $ErrorActionPreference = $ancien
    }
}

function Trouve($nom, $motifs) {
    foreach ($m in $motifs) {
        $t = Get-Item $m -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($t) { return $t.FullName }
    }
    $c = Get-Command $nom -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

$OUTILS = @(
    @{ nom = 'Git';      cmd = 'git';     paquet = 'Git.Git'
       motifs = @("$env:ProgramFiles\Git\cmd\git.exe")
       pourquoi = 'recuperer et envoyer le travail' }
    @{ nom = 'Blender';  cmd = 'blender'; paquet = 'BlenderFoundation.Blender'
       motifs = @("$env:ProgramFiles\Blender Foundation\Blender *\blender.exe")
       pourquoi = 'modelisation, et les generateurs du projet tournent dedans' }
    @{ nom = 'Godot';    cmd = 'godot';   paquet = 'GodotEngine.GodotEngine'
       motifs = @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v*_win64.exe")
       pourquoi = 'le moteur du jeu' }
    @{ nom = 'Python';   cmd = 'python';  paquet = 'Python.Python.3.12'
       motifs = @("$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe")
       pourquoi = 'generation des textures' }
    @{ nom = 'ffmpeg';   cmd = 'ffmpeg';  paquet = 'Gyan.FFmpeg'
       motifs = @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_*\*\bin\ffmpeg.exe")
       pourquoi = 'convertir les sons que Godot refuse d importer' }
)

Write-Host @"

  BG - installation
  =================
  Le script installe ce qui manque et laisse le reste tranquille.
  Il peut etre relance autant de fois que tu veux.
"@ -ForegroundColor Cyan

# ------------------------------------------------------------------- winget

Titre "1. Gestionnaire d installation"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host @"

  winget est introuvable. C est l installateur fourni avec Windows 10 et 11.

  Ouvre le Microsoft Store, cherche "App Installer" et installe-le, puis
  relance ce script. Sinon, installe les outils a la main :

    Git      https://git-scm.com
    Git LFS  https://git-lfs.com
    Blender  https://www.blender.org/download/
    Godot    https://godotengine.org/download
    Python   https://www.python.org/downloads/

"@ -ForegroundColor Red
    exit 1
}
Bien "winget est disponible"

# ------------------------------------------------------------------- outils

Titre "2. Outils"

$a_installer = @()
foreach ($o in $OUTILS) {
    $chemin = Trouve $o.cmd $o.motifs
    if ($chemin) {
        Bien "$($o.nom) deja installe"
    } else {
        Souci "$($o.nom) manquant : $($o.pourquoi)"
        $a_installer += $o
    }
}

if ($a_installer.Count -eq 0) {
    Info "Rien a installer."
} elseif ($Simuler) {
    Info "Mode simulation : $($a_installer.Count) paquet(s) seraient installes."
} else {
    Write-Host ""
    Souci "Windows demandera peut-etre une confirmation. Reponds oui."
    foreach ($o in $a_installer) {
        Write-Host "`n  Installation de $($o.nom)..." -ForegroundColor Cyan
        $res = Invoke-Externe winget install --id $o.paquet --exact --silent `
            --accept-package-agreements --accept-source-agreements
        $res.Lignes | Select-Object -Last 2 | ForEach-Object { Info $_ }
    }
    Update-Chemin
}

# ------------------------------------------------------------------ git lfs

Titre "3. Git LFS"

Update-Chemin
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Souci "Git vient d etre installe : ferme ce terminal, rouvre-le,"
    Souci "et relance .\installer.ps1 pour terminer."
    exit 0
}

if ((Invoke-Externe git lfs version).Code -ne 0) {
    if ($Simuler) {
        Info "Git LFS serait installe."
    } else {
        Info "Installation de Git LFS..."
        $res = Invoke-Externe winget install --id GitHub.GitLFS --exact --silent `
            --accept-package-agreements --accept-source-agreements
        $res.Lignes | Select-Object -Last 2 | ForEach-Object { Info $_ }
        Update-Chemin
    }
} else {
    Bien "Git LFS est la"
}

if (-not $Simuler) {
    (Invoke-Externe git lfs install).Lignes | ForEach-Object { Info $_ }

    # Toujours reclamer les objets LFS, sans condition. Une premiere version
    # ne le faisait que si une texture temoin etait un pointeur - mais un
    # fichier arrive APRES cette verification pouvait tres bien rester un
    # pointeur sans que rien ne le signale. C'est instantane quand tout est
    # deja la, autant le faire a chaque fois.
    Info "Recuperation des fichiers binaires..."
    (Invoke-Externe git lfs pull).Lignes | ForEach-Object { Info $_ }

    $pointeurs = @(Get-ChildItem game/assets -Recurse -File -Include *.png,*.ogg,*.wav,*.glb -ErrorAction SilentlyContinue |
                   Where-Object { $_.Length -lt 1000 })
    if ($pointeurs.Count -gt 0) {
        Souci "$($pointeurs.Count) fichier(s) sont restes des pointeurs :"
        $pointeurs | Select-Object -First 5 | ForEach-Object { Info "  $($_.Name)" }
        Info "Signale-le a Benjamin, ces fichiers manqueront dans le jeu."
    } else {
        Bien "Les fichiers binaires sont tous la"
    }
}

# ----------------------------------------------------------------- identite

Titre "4. Ton identite git"

$nom = (& git config user.name)
$mail = (& git config user.email)
if ($nom -and $mail) {
    Bien "$nom <$mail>"
} elseif ($Simuler) {
    Souci "Ton identite git serait demandee."
} else {
    Souci "Git ne sait pas encore qui tu es."
    $n = Read-Host "  Ton nom (ex: Guillaume)"
    $m = Read-Host "  Ton email"
    if ($n -and $m) {
        & git config --global user.name $n
        & git config --global user.email $m
        Bien "Enregistre"
    } else {
        Souci "Ignore. A faire plus tard : git config --global user.name ..."
    }
}

# ------------------------------------------------------- politique de scripts

Titre "5. Autorisation des scripts"

$politique = Get-ExecutionPolicy -Scope CurrentUser
if ($politique -in @('Restricted', 'Undefined', 'AllSigned')) {
    if ($Simuler) {
        Souci "La politique d execution serait passee a RemoteSigned."
    } else {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
        Bien "Les scripts du projet peuvent maintenant s executer"
    }
} else {
    Bien "Deja autorise ($politique)"
}

# ------------------------------------------------------------------ controle

Titre "6. Controle final"

if ($Simuler) {
    Info "Mode simulation : rien n a ete installe."
} else {
    Update-Chemin
    & "$PSScriptRoot\bg.ps1" outils
    Write-Host ""
    & "$PSScriptRoot\bg.ps1" verif
}

Write-Host @"

  Termine.

  Pour jouer            .\bg.ps1 jouer
  Pour envoyer ton travail   .\livrer.ps1
  Ce qu il y a a faire       docs\04-brief-son.md

  Si un outil n a pas ete trouve au controle final, ferme ce terminal,
  rouvre-le et relance .\installer.ps1 - Windows a parfois besoin d une
  nouvelle session pour voir ce qui vient d etre installe.

"@ -ForegroundColor Green
