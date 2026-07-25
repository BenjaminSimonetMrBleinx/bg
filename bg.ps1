<#
.SYNOPSIS
    Lanceur du projet BG. Evite d avoir a retenir les chemins.

.EXAMPLE
    .\bg.ps1 jouer          lance le jeu
    .\bg.ps1 editeur        ouvre l editeur Godot sur le projet
    .\bg.ps1 generer        regenere textures, ville et vehicule
    .\bg.ps1 capture        rend une image hors ecran dans .tmp/
    .\bg.ps1 verif          verifie que le projet charge (headless)
    .\bg.ps1 outils         affiche l etat de la chaine d outils

.NOTES
    Les chemins sont resolus automatiquement. Si un outil manque, le script
    le dit au lieu d echouer avec un message cryptique.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('jouer', 'editeur', 'generer', 'capture', 'verif', 'test', 'outils')]
    [string]$Commande = 'jouer',

    [int]$Blocs = 2,
    [int]$Graine = 505,
    [string]$Couleur = 'voiture_aztek'
)

$ErrorActionPreference = 'Stop'
$Racine = $PSScriptRoot
$Projet = Join-Path $Racine 'game'
$Tmp = Join-Path $Racine '.tmp'

function Find-Outil {
    param([string]$Nom, [string[]]$Candidats)
    foreach ($c in $Candidats) {
        $trouve = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($trouve) { return $trouve.FullName }
    }
    $cmd = Get-Command $Nom -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$Godot = Find-Outil 'godot' @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v*_win64.exe",
    "$env:ProgramFiles\Godot\Godot*.exe"
)
$GodotConsole = if ($Godot) { $Godot -replace '_win64\.exe$', '_win64_console.exe' } else { $null }
$Blender = Find-Outil 'blender' @(
    "$env:ProgramFiles\Blender Foundation\Blender *\blender.exe"
)
$Python = Find-Outil 'python' @(
    "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe"
)

function Exiger($chemin, $nom) {
    if (-not $chemin) { throw "$nom introuvable. Installe-le, ou lance : .\bg.ps1 outils" }
}

# Sur un depot fraichement clone, Godot n a jamais importe le projet : le
# registre des classes globales vit dans .godot/, qui est ignore par git.
# Sans cet import, tout script utilisant un class_name refuse de compiler
# avec une "Parse error" qui ne dit pas pourquoi.
function Initialize-Projet {
    if (Test-Path (Join-Path $Projet '.godot')) { return }
    if (-not $GodotConsole) { return }
    Write-Host "  Premier lancement : import du projet par Godot..." -ForegroundColor Gray
    & $GodotConsole --headless --path $Projet --import 2>&1 | Out-Null
}

switch ($Commande) {

    'outils' {
        # Pas d'operateur ?? ici : il n'existe qu'a partir de PowerShell 7,
        # et Windows livre encore la 5.1 par defaut.
        function Ou-Absent($v) { if ($v) { $v } else { 'ABSENT' } }
        [pscustomobject]@{ Outil = 'Godot';   Chemin = Ou-Absent $Godot }
        [pscustomobject]@{ Outil = 'Blender'; Chemin = Ou-Absent $Blender }
        [pscustomobject]@{ Outil = 'Python';  Chemin = Ou-Absent $Python }
        [pscustomobject]@{ Outil = 'Projet';  Chemin = $Projet }
    }

    'jouer' {
        Exiger $Godot 'Godot'
        Initialize-Projet
        & $Godot --path $Projet
    }

    'editeur' {
        Exiger $Godot 'Godot'
        Initialize-Projet
        # -e ouvre l editeur au lieu de lancer le jeu
        & $Godot -e --path $Projet
    }

    'generer' {
        Exiger $Python 'Python'
        Exiger $Blender 'Blender'
        Push-Location $Racine
        try {
            Write-Host "`n--- textures ---" -ForegroundColor Cyan
            & $Python 'outils/gen_textures.py'
            Write-Host "`n--- ville ($Blocs x $Blocs, graine $Graine) ---" -ForegroundColor Cyan
            & $Blender -b -P 'outils/gen_ville.py' -- --blocs $Blocs --seed $Graine
            Write-Host "`n--- vehicule ($Couleur) ---" -ForegroundColor Cyan
            & $Blender -b -P 'outils/gen_voiture.py' -- --couleur $Couleur
            if ($GodotConsole -and (Test-Path $GodotConsole)) {
                Write-Host "`n--- reimport Godot ---" -ForegroundColor Cyan
                & $GodotConsole --headless --path $Projet --import | Out-Null
            }
            Write-Host "`nOK" -ForegroundColor Green
        } finally { Pop-Location }
    }

    'capture' {
        # Variante console obligatoire : le binaire graphique se detache et
        # PowerShell n attend ni sa fin ni son code de sortie.
        Exiger $GodotConsole 'Godot (console)'
        Initialize-Projet
        New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
        $sortie = Join-Path $Tmp 'capture.png'
        & $GodotConsole --path $Projet --script 'res://outils/capture.gd' -- --sortie $sortie --frames 150
        if (Test-Path $sortie) { Write-Host "-> $sortie" -ForegroundColor Green }
    }

    'verif' {
        Exiger $GodotConsole 'Godot (console)'
        Initialize-Projet
        & $GodotConsole --headless --path $Projet --script 'res://outils/verif.gd'
        exit $LASTEXITCODE
    }

    'test' {
        # Tests de comportement : ils ont besoin d un vrai rendu, donc pas de
        # --headless. Et imperativement la variante console : le binaire
        # graphique se detache, PowerShell ne recupere jamais son code de
        # sortie et toutes les suites paraissent echouer.
        Exiger $GodotConsole 'Godot (console)'
        Initialize-Projet
        $suites = @(
            @{ nom = 'sens de conduite'; script = 'res://outils/test_sens.gd' },
            @{ nom = 'montee et descente'; script = 'res://outils/test_montee.gd' },
            @{ nom = 'orientation de marche'; script = 'res://outils/test_marche.gd' },
            @{ nom = 'boucle camera'; script = 'res://outils/test_camera.gd' },
            @{ nom = 'franchissement de bordure'; script = 'res://outils/test_trottoir.gd' }
        )
        $echecs = 0
        foreach ($s in $suites) {
            Write-Host "`n--- $($s.nom) ---" -ForegroundColor Cyan
            & $GodotConsole --path $Projet --script $s.script
            if ($LASTEXITCODE -ne 0) { $echecs++ }
        }
        Write-Host ""
        if ($echecs -gt 0) {
            Write-Host "$echecs suite(s) en echec" -ForegroundColor Red
            exit 1
        }
        Write-Host "$($suites.Count) suites OK" -ForegroundColor Green
    }
}
