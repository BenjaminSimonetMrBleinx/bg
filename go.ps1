<#
.SYNOPSIS
    La seule commande a retenir.

.DESCRIPTION
    Fait tout, dans l ordre :
      1. installe ce qui manque, s il manque quelque chose
      2. recupere le travail des autres
      3. envoie le tien, s il y en a
      4. lance le jeu

    Chaque etape est sautee si elle n a rien a faire. Rien n est envoye
    sans confirmation.

.EXAMPLE
    .\go.ps1
    Le parcours complet.

.EXAMPLE
    .\go.ps1 "sons de portieres"
    Pareil, avec ta description pour l envoi.

.EXAMPLE
    .\go.ps1 -SansJeu
    Tout sauf le lancement du jeu.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message = "",

    # Ne pas lancer le jeu a la fin.
    [switch]$SansJeu,

    # Ne rien demander, tout accepter.
    [switch]$Oui
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Titre($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Info($t)  { Write-Host "  $t" -ForegroundColor Gray }
function Bien($t)  { Write-Host "  $t" -ForegroundColor Green }

Write-Host @"

  BG
  ==
  Installation, mise a jour, envoi de ton travail, lancement du jeu.
  Les etapes inutiles sont sautees.
"@ -ForegroundColor Cyan

# --------------------------------------------------- 1. installer si besoin

# On ne lance l installateur que si quelque chose manque reellement : sinon
# il defile pour rien a chaque fois, et on finit par ne plus le lire.
function Present($nom, $motifs) {
    foreach ($m in $motifs) {
        if (Get-Item $m -ErrorAction SilentlyContinue) { return $true }
    }
    return [bool](Get-Command $nom -ErrorAction SilentlyContinue)
}

$manque = @()
if (-not (Present 'git' @("$env:ProgramFiles\Git\cmd\git.exe"))) { $manque += 'Git' }
if (-not (Present 'blender' @("$env:ProgramFiles\Blender Foundation\Blender *\blender.exe"))) { $manque += 'Blender' }
if (-not (Present 'godot' @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v*_win64.exe"))) { $manque += 'Godot' }
if (-not (Present 'python' @("$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe"))) { $manque += 'Python' }

if ($manque.Count -gt 0) {
    Titre "1. Installation"
    Info "Il manque : $($manque -join ', ')"
    & "$PSScriptRoot\installer.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Titre "1. Installation"
    Bien "Tout est deja installe"
}

# ---------------------------------------- 2 et 3. mise a jour puis envoi

# livrer.ps1 recupere d abord le travail des autres, puis envoie le tien.
# Les deux etapes sont donc couvertes par un seul appel, et s il n y a rien
# a envoyer il s arrete tout seul apres la mise a jour.
Titre "2. Mise a jour et envoi"

$args_livrer = @()
if ($Message) { $args_livrer += $Message }
if ($Oui)     { $args_livrer += '-Oui' }
& "$PSScriptRoot\livrer.ps1" @args_livrer
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n  L envoi s est arrete. Le jeu n a pas ete lance.`n" -ForegroundColor Yellow
    exit $LASTEXITCODE
}

# ------------------------------------------------------------ 4. jouer

if ($SansJeu) {
    Write-Host "`n  Termine.`n" -ForegroundColor Green
    exit 0
}

Titre "3. Le jeu"

if (-not $Oui) {
    $rep = Read-Host "  Lancer le jeu ? [O/n]"
    if ($rep -and $rep -notmatch '^[oOyY]') {
        Write-Host "`n  Termine. Pour jouer plus tard : .\bg.ps1 jouer`n" -ForegroundColor Green
        exit 0
    }
}

Info "W A S D pour marcher et conduire, F devant la voiture, Espace au frein a main."
& "$PSScriptRoot\bg.ps1" jouer
