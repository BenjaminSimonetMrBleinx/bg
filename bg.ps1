<#
.SYNOPSIS
    Lanceur du projet BG. Evite d avoir a retenir les chemins.

.EXAMPLE
    .\bg.ps1 jouer          lance le jeu
    .\bg.ps1 editeur        ouvre l editeur Godot sur le projet
    .\bg.ps1 generer        regenere tout : textures, ville, vehicule,
                            personnages, maisons, objets
    .\bg.ps1 capture        rend une image hors ecran dans .tmp/
    .\bg.ps1 verif          verifie que le projet charge (headless)
    .\bg.ps1 exporter       fabrique build\BG.exe, jouable sans rien installer
    .\bg.ps1 nettoyer       vide .tmp et build (tout y est regenerable)
    .\bg.ps1 outils         affiche l etat de la chaine d outils

.NOTES
    Les chemins sont resolus automatiquement. Si un outil manque, le script
    le dit au lieu d echouer avec un message cryptique.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('jouer', 'editeur', 'generer', 'capture', 'verif', 'test', 'son', 'sons', 'reparer', 'exporter', 'nettoyer', 'outils')]
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
# Godot garde une copie convertie de chaque fichier 3D, image et son dans
# .godot\, qui n est PAS suivi par git. Un fichier arrive par git pull sans
# cette copie ne se charge pas du tout :
#
#   ERROR: Cannot open file 'res://.godot/imported/arme.glb-....scn'
#
# Le jeu se lance quand meme, sans les maisons ni les objets. Une version
# anterieure de ce script n important qu au tout premier lancement, un
# equipier qui recuperait du travail se retrouvait exactement la.
#
# Meme chose pour les scripts : les noms declares par class_name vivent dans
# un cache du meme dossier. Sans lui, ils sont introuvables a l execution.
#
# On date donc le dernier import et on le refait des que quoi que ce soit a
# bouge. Quand rien n a change, on ne paie rien.
function Initialize-Projet {
    if (-not $GodotConsole) { return }

    $marque = Join-Path $Projet '.godot\.bg-import'
    $besoin = $true
    if (Test-Path $marque) {
        $date = (Get-Item $marque).LastWriteTime
        $recent = Get-ChildItem $Projet -Recurse -File -Force -ErrorAction SilentlyContinue |
                  Where-Object { $_.FullName -notlike "*\.godot\*" } |
                  Where-Object { $_.LastWriteTime -gt $date } |
                  Select-Object -First 1
        $besoin = $null -ne $recent
    }
    if (-not $besoin) { return }

    Write-Host "  Import des fichiers nouveaux ou modifies..." -ForegroundColor Gray
    # Godot ecrit ses avertissements sur la sortie d erreur : avec
    # ErrorActionPreference a Stop, le moindre message tuerait le script.
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $GodotConsole --headless --path $Projet --import 2>&1 | Out-Null }
    finally { $ErrorActionPreference = $ancien }

    New-Item -ItemType Directory -Force -Path (Split-Path $marque) | Out-Null
    Set-Content -Path $marque -Value (Get-Date -Format 'o') -Encoding ASCII
}

switch ($Commande) {

    'outils' {
        # Pas d'operateur ?? ici : il n'existe qu'a partir de PowerShell 7,
        # et Windows livre encore la 5.1 par defaut.
        function Get-OuAbsent($v) { if ($v) { $v } else { 'ABSENT' } }
        [pscustomobject]@{ Outil = 'Godot';   Chemin = Get-OuAbsent $Godot }
        [pscustomobject]@{ Outil = 'Blender'; Chemin = Get-OuAbsent $Blender }
        [pscustomobject]@{ Outil = 'Python';  Chemin = Get-OuAbsent $Python }
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
            Write-Host "`n--- personnages ---" -ForegroundColor Cyan
            & $Blender -b -P 'outils/gen_personnage.py' -- --nom tous
            Write-Host "`n--- maisons ---" -ForegroundColor Cyan
            & $Blender -b -P 'outils/gen_maison.py' -- --nom toutes
            Write-Host "`n--- objets ---" -ForegroundColor Cyan
            & $Blender -b -P 'outils/gen_objets.py' -- --nom tous
            # Sans reimport, Godot continue de servir l ancienne version depuis
            # son cache et on corrige a l aveugle en croyant que rien ne change.
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

    'nettoyer' {
        # Ne touche QUE a ce que le projet sait refabriquer : les captures et
        # fichiers de travail de .tmp, et l executable de build. Jamais aux
        # assets, qui contiennent le travail livre par Guillaume, ni au cache
        # .godot, dont la reconstruction coute dix secondes a chacun.
        $total = 0
        foreach ($cible in @($Tmp, (Join-Path $Racine 'build'))) {
            if (-not (Test-Path $cible)) { continue }
            $mo = [math]::Round((Get-ChildItem $cible -Recurse -File -ErrorAction SilentlyContinue |
                   Measure-Object Length -Sum).Sum / 1MB, 1)
            Remove-Item $cible -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  $cible  ($mo Mo)" -ForegroundColor Gray
            $total += $mo
        }
        if ($total -eq 0) {
            Write-Host "`nDeja propre." -ForegroundColor Green
        } else {
            Write-Host "`n$total Mo liberes. Tout est regenerable :" -ForegroundColor Green
            Write-Host "  .\bg.ps1 capture   pour les images" -ForegroundColor Gray
            Write-Host "  .\bg.ps1 exporter  pour l executable" -ForegroundColor Gray
        }
    }

    'exporter' {
        Exiger $GodotConsole 'Godot (console)'
        Initialize-Projet

        # Les modeles d export sont un telechargement a part, absent de
        # l installation de Godot. Sans eux l export echoue avec un message
        # qui ne dit pas quoi faire, alors on le fait.
        $version = '4.7.1.stable'
        $modeles = Join-Path $env:APPDATA "Godot\export_templates\$version"
        if (-not (Test-Path (Join-Path $modeles 'windows_release_x86_64.exe'))) {
            Write-Host "`nLes modeles d export manquent (environ 1,2 Go)." -ForegroundColor Yellow
            Write-Host "Telechargement, une seule fois..." -ForegroundColor Gray
            $tpz = Join-Path $Tmp 'templates.tpz'
            $sortieTpl = Join-Path $Tmp 'tpl'
            New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
            $url = "https://github.com/godotengine/godot/releases/download/" +
                   "4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz"
            $ancien = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                Invoke-WebRequest -Uri $url -OutFile $tpz -MaximumRedirection 5
            } finally { $ProgressPreference = $ancien }
            Remove-Item -Recurse -Force $sortieTpl -ErrorAction SilentlyContinue
            Expand-Archive -Path $tpz -DestinationPath $sortieTpl -Force
            New-Item -ItemType Directory -Force -Path $modeles | Out-Null
            Copy-Item (Join-Path $sortieTpl 'templates\*') -Destination $modeles -Recurse -Force
            Remove-Item $tpz -Force -ErrorAction SilentlyContinue
            Write-Host "Modeles installes." -ForegroundColor Green
        }

        $dossier = Join-Path $Racine 'build'
        New-Item -ItemType Directory -Force -Path $dossier | Out-Null
        Write-Host "`n--- export Windows ---" -ForegroundColor Cyan
        & $GodotConsole --headless --path $Projet --export-release 'Windows' | Out-Null
        $exe = Join-Path $dossier 'BG.exe'
        if (Test-Path $exe) {
            $mo = [math]::Round((Get-Item $exe).Length / 1MB, 1)
            Write-Host "`nOK  $exe  ($mo Mo)" -ForegroundColor Green
            Write-Host "Il se lance seul, sans Godot ni rien d autre." -ForegroundColor Gray
        } else {
            Write-Host "`nL export n a rien produit." -ForegroundColor Red
            exit 1
        }
    }

    'son' {
        # Le jeu muet ne donne aucune piste : ce diagnostic repond d un coup
        # sur le fichier, l import, les bus, le peripherique et le volume.
        Exiger $GodotConsole 'Godot (console)'
        Initialize-Projet
        & $GodotConsole --path $Projet --script 'res://outils/diag_son.gd'
        exit $LASTEXITCODE
    }

    'sons' {
        # Godot n importe que du WAV en PCM non compresse. Les stations audio
        # exportent volontiers autre chose sous une extension .wav, et le
        # message d erreur de Godot ne dit pas quoi faire.
        Exiger $Python 'Python'
        Push-Location $Racine
        try {
            if ($Corriger) { & $Python 'outils/normaliser_sons.py' --corriger }
            else            { & $Python 'outils/normaliser_sons.py' }
        } finally { Pop-Location }
    }

    'reparer' {
        # Godot garde un cache d import dans .godot/. Si un fichier est
        # arrive casse - typiquement un pointeur Git LFS importe comme s il
        # etait un vrai fichier - le cache reste fausse et le reimport normal
        # ne suffit pas. On le supprime pour forcer une reconstruction.
        Exiger $GodotConsole 'Godot (console)'
        $cache = Join-Path $Projet '.godot'
        if (Test-Path $cache) {
            Write-Host "  Suppression du cache d import..." -ForegroundColor Gray
            Remove-Item -Recurse -Force $cache
        }
        Write-Host "  Reimport complet, patiente..." -ForegroundColor Gray
        $ancien = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { & $GodotConsole --headless --path $Projet --import 2>&1 | Out-Null }
        finally { $ErrorActionPreference = $ancien }
        Write-Host "  Termine. Relance le jeu." -ForegroundColor Green
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
            @{ nom = 'franchissement de bordure'; script = 'res://outils/test_trottoir.gd' },
            @{ nom = 'audio'; script = 'res://outils/test_audio.gd' },
            @{ nom = 'son du moteur'; script = 'res://outils/test_moteur.gd' },
            @{ nom = 'entrer dans les maisons'; script = 'res://outils/test_maison.gd' },
            @{ nom = 'habitants et dialogue'; script = 'res://outils/test_dialogue.gd' },
            @{ nom = 'roue des outils'; script = 'res://outils/test_outils.gd' }
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
