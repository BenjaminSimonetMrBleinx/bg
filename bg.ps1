<#
.SYNOPSIS
    Lanceur du projet BG. Evite d avoir a retenir les chemins.

.EXAMPLE
    .\bg.ps1 jouer          lance le jeu
    .\bg.ps1 editeur        ouvre l editeur Godot sur le projet
    .\bg.ps1 generer        regenere tout : textures, ville, vehicule,
                            personnages, maisons, objets, decor
    .\bg.ps1 capture        rend une image hors ecran dans .tmp/
    .\bg.ps1 integrer       met un modele livre aux normes du jeu et le pose
                            dans game\assets. -Fichier, -Vers, -Hauteur
    .\bg.ps1 verif          verifie que le projet charge (headless)
    .\bg.ps1 diag           releve le cout de la ville : FPS, memoire, chargement
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
    [ValidateSet('jouer', 'editeur', 'generer', 'capture', 'integrer', 'verif', 'test', 'diag', 'son', 'sons', 'reparer', 'exporter', 'nettoyer', 'voix', 'outils')]
    [string]$Commande = 'jouer',

    # Pour 'integrer' : le modele livre, sa destination dans game\assets, et
    # la hauteur voulue EN METRES. C est le seul chemin par lequel un modele
    # entre dans le jeu — voir CLAUDE.md.
    [string]$Fichier = '',
    [string]$Vers = '',
    [double]$Hauteur = 0.0,
    [double]$Lacet = 0.0,

    [int]$Blocs = 2,

    # Ou deposer le joueur au lancement : 'banc', 'desert', 'jesse',
    # 'walter'. Voir DEPARTS dans systemes/controleur.gd.
    [string]$Ou = '',

    # Sur quel ecran ouvrir le jeu, 0-indexe. Par defaut le SECOND : sur le
    # poste de dev, le jeu s ouvre a cote de l editeur et du terminal, pas
    # par-dessus. Ignore si l ecran demande n existe pas - sur une machine a un
    # seul moniteur, on ouvre normalement. C est une preference de LANCEMENT,
    # jamais ecrite dans project.godot : l executable des joueurs n en sait rien.
    [int]$Ecran = 1,

    [int]$Graine = 505,
    [string]$Couleur = 'voiture_aztek',

    # Pour 'generer' : jour ou nuit. Ce n est pas un curseur de jeu, parce
    # que l etat des vitres est CUIT dans les textures de facade. Le moment
    # choisi ici est aussi ecrit dans game\donnees\monde.json, que le jeu
    # relit pour son ciel, son soleil et ses lampadaires.
    [ValidateSet('jour', 'nuit')]
    [string]$Moment = 'nuit',

    # Pour 'sons' : convertit les fichiers que Godot refuse au lieu de se
    # contenter de les signaler. Le drapeau etait utilise dans le corps du
    # script sans jamais avoir ete declare ici : PowerShell refusait la
    # commande, et la conversion etait donc inatteignable.
    [switch]$Corriger,

    # Pour 'test' : ne joue que les suites dont la cle ou le nom contient ce
    # texte. .\bg.ps1 test -Suite camera
    [string]$Suite = '',

    # Pour 'capture' : joue une situation declaree dans donnees\scenarios.json
    # au lieu de photographier le point de depart. 'tous' rend la planche
    # complete. C est la boucle de controle visuel du projet : la plupart des
    # defauts trouves ici ne se voient sur aucun test, seulement a l image.
    [string]$Scenario = '',

    # Pour 'test' : demande a git ce qui a bouge et n en joue que les suites
    # concernees. C est le mode a utiliser avant chaque commit.
    [switch]$Modifies,

    # Pour 'test' : montre les suites qui SERAIENT jouees, et sort. Ne lance ni
    # Godot ni aucune suite. Sert a verifier ce qu une modification declenche -
    # notamment ce que project.godot relance depuis qu il n est plus global.
    [switch]$Lister,

    # Pour 'voix' : refabrique meme ce qui existe deja. A utiliser apres avoir
    # touche a un profil dans donnees\voix.json - le nom de fichier depend du
    # TEXTE, pas du timbre, donc rien ne se regenere tout seul.
    [switch]$Refaire,

    # Pour 'voix' : liste les voix installees sur la machine, et sort.
    [switch]$Voix,

    # Pour 'voix' : ecrit docs\08-script-voix.md, la liste numerotee des
    # repliques a enregistrer. C est ce qu on donne a celui qui prete sa voix.
    [switch]$Script,

    # Pour 'voix' : range les enregistrements deposes dans livraisons\voix\.
    [switch]$Integrer,

    # Pour 'voix' : decoupe une longue prise en segments parles. C est le cas
    # normal - on n arrete pas le micro entre chaque phrase.
    [string]$Decouper = '',
    [double]$Seuil = -40.0,
    [double]$Pause = 0.6,

    # Pour 'voix' : affecte les segments decoupes aux repliques, dans l ordre,
    # a partir de -Depuis. Et -Reconnaitre les confronte au script.
    # Pour 'voix' : combien de segments consecutifs forment chaque replique.
    #   .\bg.ps1 voix -Assigner -Grouper "1,1,1,1,1,1,1,1,2,6"
    # Une replique longue contient toujours des silences : le comedien respire,
    # et le decoupage la coupe en deux. Seize segments pour dix repliques est
    # le cas normal.
    [string]$Grouper = '',

    [switch]$Assigner,
    [int]$Depuis = 1,
    # Une replique sur -Pas. 2 quand chaque comedien enregistre sa propre
    # piste, ce qui est le cas normal d un dialogue a deux.
    [int]$Pas = 1,
    [switch]$Reconnaitre
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

function Get-HorsEntrees {
    # Rend le contenu de project.godot PRIVE de sa section [input]. Deux
    # versions du fichier identiques une fois cette section retiree n ont
    # differe que par la carte d entrees - c est ce qui permet de dire qu une
    # modification ne touche QUE les entrees, et ne concerne donc que les
    # suites qui en simulent.
    param([string]$Contenu)
    $lignes = ($Contenu -replace "`r", '') -split "`n"
    $sortie = New-Object System.Collections.Generic.List[string]
    $dans = $false
    foreach ($l in $lignes) {
        if ($l -match '^\[input\]') { $dans = $true; continue }
        if ($dans -and $l -match '^\[') { $dans = $false }
        if (-not $dans) { $sortie.Add($l) }
    }
    return ($sortie -join "`n").TrimEnd()
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

# SUR QUEL ECRAN OUVRIR UNE FENETRE GODOT. Ca vaut pour tout ce qui en ouvre
# une - jouer, mais aussi les tests, les captures et le releve : chacune d elles
# s ouvrait sur l ecran principal et faisait reduire ce qui tournait en plein
# ecran a cote. Une fenetre d outil ne doit jamais interrompre ce qu on fait.
#
# On n ouvre sur un autre ecran QUE s il existe : sinon, sur un poste a un seul
# moniteur, la fenetre s ouvrirait dans le vide. Les deux PC partagent ce
# script, donc le garde-fou evite qu ils divergent.
function Get-ArgsEcran {
    $ecrans = @()
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $ecrans = @([System.Windows.Forms.Screen]::AllScreens)
    } catch {}
    if ($Ecran -ge 0 -and $Ecran -lt $ecrans.Count) {
        return , @('--screen', "$Ecran")
    }
    if ($Ecran -gt 0) {
        Write-Host ("  (ecran {0} demande, mais {1} ecran(s) detecte(s) : ouverture par defaut)" -f $Ecran, $ecrans.Count) -ForegroundColor Gray
    }
    return , @()
}

# La version vit dans project.godot, et nulle part ailleurs.
#
# C est deja le champ que Godot utilise pour l export et les proprietes de
# l executable. En tenir un second ici garantirait qu ils divergent : on
# bumperait l un, on oublierait l autre, et l exe annoncerait un numero que le
# jeu contredit a l ecran.
function Get-Version {
    $ligne = Select-String -Path (Join-Path $Projet 'project.godot') `
             -Pattern '^config/version="(.+)"' | Select-Object -First 1
    if ($ligne) { return $ligne.Matches[0].Groups[1].Value }
    return '0.0.0'
}

# Le numero de commit ne peut pas venir de git une fois le jeu exporte : il n y
# a plus de depot. On l ecrit donc dans un fichier que le jeu lit.
#
# Ecrit SEULEMENT si le contenu change. Godot reimporte tout ce qui a bouge
# sous game\, et reecrire ce fichier a chaque lancement couterait dix secondes
# d import pour un texte identique.
function Set-Build {
    $cible = Join-Path $Projet 'donnees\version.json'
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $sha = (& git -C $Racine rev-parse --short HEAD 2>$null)
    $sale = (& git -C $Racine status --porcelain 2>$null)
    $ErrorActionPreference = $ancien
    if (-not $sha) { return }

    # Un depot qui a des modifications non commitees ne correspond a AUCUN
    # commit : afficher le dernier serait un mensonge, et c est exactement le
    # cas ou l on cherche a savoir ce qui tourne.
    if ($sale) { $sha = "$sha+" }

    $contenu = @{ version = (Get-Version); commit = $sha } |
               ConvertTo-Json -Compress
    if ((Test-Path $cible) -and ((Get-Content $cible -Raw).Trim() -eq $contenu)) { return }
    Set-Content -Path $cible -Value $contenu -Encoding UTF8
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
        [pscustomobject]@{ Outil = 'Version'; Chemin = "$(Get-Version)  (commit $((git -C $Racine rev-parse --short HEAD 2>$null)))" }
    }

    'jouer' {
        Exiger $Godot 'Godot'
        Set-Build
        Initialize-Projet
        $argsGodot = @('--path', $Projet) + (Get-ArgsEcran)
        # -Ou depose le joueur ailleurs qu au point de depart. Raccourci de
        # developpement : aller regarder quelque chose a l autre bout de la
        # carte vingt fois dans une soiree coute une minute a chaque fois.
        if ($Ou) { $argsGodot += @('--', '--ou', $Ou) }
        & $Godot @argsGodot
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
            Write-Host "`n--- textures ($Moment) ---" -ForegroundColor Cyan
            & $Python 'outils/gen_textures.py' --moment $Moment
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
            Write-Host "`n--- decor ---" -ForegroundColor Cyan
            & $Blender -b -P 'outils/gen_decor.py' -- --nom tous
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
        Set-Build
        Initialize-Projet
        New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

        if (-not $Scenario) {
            $sortie = Join-Path $Tmp 'capture.png'
            & $GodotConsole @('--path', $Projet) @(Get-ArgsEcran) `
                --script 'res://verifs/capture.gd' -- --sortie $sortie --frames 150
            if (Test-Path $sortie) { Write-Host "-> $sortie" -ForegroundColor Green }
            Write-Host "Situations disponibles : .\bg.ps1 capture -Scenario tous" -ForegroundColor Gray
            break
        }

        # Les situations sont declarees dans game\donnees\scenarios.json. On les
        # lit ICI aussi, pour pouvoir en jouer plusieurs et dire lesquelles
        # existent quand le nom demande n en est pas une.
        $fiche = Join-Path $Projet 'donnees\scenarios.json'
        $connus = (Get-Content $fiche -Raw -Encoding UTF8 | ConvertFrom-Json).scenarios
        $noms = @($connus.PSObject.Properties.Name)
        $choisis = if ($Scenario -eq 'tous') { $noms }
                   else { @($noms | Where-Object { $_ -like "*$Scenario*" }) }
        if ($choisis.Count -eq 0) {
            Write-Host "Aucune situation ne correspond a '$Scenario'." -ForegroundColor Red
            Write-Host "Connues : $($noms -join ', ')" -ForegroundColor Gray
            exit 1
        }

        $dossier = Join-Path $Tmp 'captures'
        New-Item -ItemType Directory -Force -Path $dossier | Out-Null
        foreach ($s in $choisis) {
            $sortie = Join-Path $dossier "$s.png"
            Write-Host "`n--- $s ---" -ForegroundColor Cyan
            Write-Host "    $($connus.$s.quoi)" -ForegroundColor Gray
            & $GodotConsole @('--path', $Projet) @(Get-ArgsEcran) `
                --script 'res://verifs/capture.gd' -- --sortie $sortie --scenario $s
            if (Test-Path $sortie) { Write-Host "  -> $sortie" -ForegroundColor Green }
            else { Write-Host "  rien produit" -ForegroundColor Red }
        }
        Write-Host "`n$($choisis.Count) vue(s) dans $dossier" -ForegroundColor Green
    }

    # INTEGRER UN MODELE LIVRE, et le seul chemin par lequel il entre.
    #
    # Les livraisons arrivent a des echelles, des orientations et des
    # resolutions sans rapport les unes avec les autres — c est normal, et ca
    # ne se corrige pas a la main. Un modele importe hors de cette chaine est
    # une incoherence qui se decouvrira trois sessions plus tard, a l ecran.
    #
    # Deux passes, et la seconde n est pas redondante :
    #   importer_modele      met a l echelle, pose au sol, oriente, texture
    #   mettre_a_l_echelle   RELIT le fichier ecrit et corrige ce qui n a pas
    #                        survecu a l export — l echelle d objet, notamment,
    #                        que le glTF ne transporte pas
    'integrer' {
        Exiger $Blender 'Blender'
        if (-not $Fichier) { throw "Il manque -Fichier. Exemple : .\bg.ps1 integrer -Fichier livraisons\modeles\x.glb -Vers game\assets\vehicules\x.glb -Hauteur 1.5" }
        if (-not $Vers)    { throw "Il manque -Vers, la destination dans game\assets\." }
        Push-Location $Racine
        try {
            Write-Host "`n--- integration de $(Split-Path $Fichier -Leaf) ---" -ForegroundColor Cyan
            & $Blender -b -P outils/importer_modele.py -- `
                --fichier $Fichier --sortie $Vers `
                --hauteur $Hauteur --lacet $Lacet
            if ($LASTEXITCODE -ne 0) { throw "l import a echoue" }

            # La seconde passe ne sert que pour les modeles RIGGES : sans
            # squelette elle n a rien a mesurer et le dit sans casser.
            if ($Hauteur -gt 0) {
                Write-Host "`n--- controle de la taille du fichier ecrit ---" -ForegroundColor Cyan
                & $Blender -b -P outils/mettre_a_l_echelle.py -- `
                    --fichier $Vers --hauteur $Hauteur 2>&1 |
                    Select-String -Pattern 'hauteur voulue|->|ECHEC|squelette'
            }
            Write-Host "`nEt maintenant, la seule etape qui compte :" -ForegroundColor Yellow
            Write-Host "  .\bg.ps1 capture -Scenario <une vue qui le montre>" -ForegroundColor Gray
            Write-Host "Un modele qu on n a pas REGARDE n est pas integre." -ForegroundColor Gray
        } finally { Pop-Location }
    }

    'verif' {
        Exiger $GodotConsole 'Godot (console)'
        Set-Build
        Initialize-Projet
        & $GodotConsole --headless --path $Projet --script 'res://verifs/verif.gd'
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
            # La palette de textures vit dans .tmp depuis qu elle est sortie du
            # projet Godot. Elle disparait donc ici, et les generateurs Blender
            # s arretent net tant qu on ne l a pas refaite - franchement, ils
            # le disent. Autant l annoncer avant.
            Write-Host "  .\bg.ps1 generer   AVANT de regenerer un modele :" -ForegroundColor Gray
            Write-Host "                     la palette de textures partait avec." -ForegroundColor Gray
        }
    }

    'voix' {
        # La synthese est fournie avec Windows : rien a installer, rien en
        # ligne. Le script est en PowerShell parce que l API vocale est une
        # API .NET - Python devrait passer par un pont pour y acceder.
        & (Join-Path $Racine 'outils\gen_voix.ps1') -Racine $Racine `
            -Refaire:$Refaire -Voix:$Voix -Script:$Script -Integrer:$Integrer `
            -Decouper $Decouper -Seuil $Seuil -Pause $Pause `
            -Assigner:$Assigner -Depuis $Depuis -Pas $Pas -Grouper $Grouper -Reconnaitre:$Reconnaitre
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        # Les nouveaux .wav doivent etre importes, sinon le jeu cherche des
        # fichiers que Godot n a jamais convertis et reste muet.
        if (-not $Voix) { Initialize-Projet }
    }

    'exporter' {
        Exiger $GodotConsole 'Godot (console)'
        Set-Build
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
        Write-Host "`n--- export Windows $(Get-Version) ---" -ForegroundColor Cyan
        & $GodotConsole --headless --path $Projet --export-release 'Windows' | Out-Null
        $exe = Join-Path $dossier 'BG.exe'
        if (Test-Path $exe) {
            $mo = [math]::Round((Get-Item $exe).Length / 1MB, 1)
            Write-Host "`nOK  $exe  ($mo Mo)  version $(Get-Version)" -ForegroundColor Green
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
        & $GodotConsole --path $Projet --script 'res://verifs/diag_son.gd'
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

    'diag' {
        # Un RELEVE de cout, pas un test : diag_ville mesure les images/seconde,
        # la memoire et le temps de chargement. Rien a valider, aucun seuil - on
        # compare deux releves avant et apres un changement de taille ou de
        # densite. Il tourne quelques secondes puis se ferme tout seul.
        #
        # DE NUIT par defaut : de jour les lampadaires sont masques et ne coutent
        # rien, donc mesurer a midi ne mesure pas la ville eclairee. Un vrai
        # rendu est necessaire (pas de --headless), sinon les FPS ne veulent rien
        # dire.
        Exiger $GodotConsole 'Godot (console)'
        Set-Build
        Initialize-Projet
        & $GodotConsole @('--path', $Projet) @(Get-ArgsEcran) `
            --script res://verifs/diag_ville.gd -- --heure 22
    }

    'test' {
        # Tests de comportement : ils ont besoin d un vrai rendu, donc pas de
        # --headless. Et imperativement la variante console : le binaire
        # graphique se detache, PowerShell ne recupere jamais son code de
        # sortie et toutes les suites paraissent echouer. On ne l EXIGE toutefois
        # qu au moment de jouer, plus bas : choisir ou lister les suites ne
        # demande pas Godot, et -Lister doit pouvoir repondre sans rien importer.
        #
        # Chaque suite declare les FICHIERS qu elle couvre. C est ce qui
        # permet de ne rejouer que ce qui est concerne par une modification,
        # au lieu de payer la totale a chaque commit.
        #
        # Les motifs sont volontairement larges : une suite lancee pour rien
        # coute quelques secondes, une suite oubliee coute un bug livre.
        $suites = @(
            @{ cle = 'sens'; nom = 'sens de conduite'
               script = 'res://verifs/test_sens.gd'
               couvre = @('systemes/vehicule', 'gen_voiture', 'scenes/vehicule') }
            @{ cle = 'conduite'; nom = 'tenue de route'
               script = 'res://verifs/test_conduite.gd'
               couvre = @('systemes/vehicule', 'scenes/vehicule', 'systemes/reglages') }
            @{ cle = 'virage'; nom = 'comportement en virage'
               script = 'res://verifs/test_virage.gd'
               couvre = @('systemes/vehicule', 'scenes/vehicule', 'systemes/reglages') }
            @{ cle = 'montee'; nom = 'montee et descente'
               script = 'res://verifs/test_montee.gd'
               couvre = @('systemes/controleur', 'systemes/vehicule', 'systemes/joueur', 'scenes/joueur') }
            @{ cle = 'mission'; nom = 'mission 1'
               script = 'res://verifs/test_mission.gd'
               couvre = @('systemes/mission', 'systemes/scenario', 'systemes/tir',
                          'systemes/bourse', 'systemes/point', 'systemes/cachette',
                          'systemes/equipement', 'donnees/mission1', 'donnees/dialogues',
                          'donnees/outils', 'scenes/mission1') }

            @{ cle = 'allures'; nom = 'allures de Walter'

               script = 'res://verifs/test_allures.gd'

               couvre = @('systemes/joueur', 'systemes/demarche', 'systemes/reglages',

                          'scenes/joueur', 'assets/personnages', 'importer_perso',
                          'animer_perso') }

            @{ cle = 'marche'; nom = 'orientation de marche'
               script = 'res://verifs/test_marche.gd'
               couvre = @('systemes/joueur', 'systemes/silhouette', 'gen_personnage', 'scenes/joueur', 'segmenter_modele', 'assets/personnages') }
            @{ cle = 'camera'; nom = 'boucle camera'
               script = 'res://verifs/test_camera.gd'
               couvre = @('systemes/camera_poursuite', 'systemes/joueur', 'scenes/joueur') }
            @{ cle = 'trottoir'; nom = 'franchissement de bordure'
               script = 'res://verifs/test_trottoir.gd'
               couvre = @('systemes/joueur', 'gen_ville', 'systemes/camera_poursuite', 'scenes/joueur') }
            @{ cle = 'audio'; nom = 'audio'
               script = 'res://verifs/test_audio.gd'
               couvre = @('systemes/audio', 'assets/sons', 'default_bus_layout') }
            @{ cle = 'trafic'; nom = 'circulation'

               script = 'res://verifs/test_trafic.gd'

               couvre = @('systemes/trafic', 'systemes/circulant', 'gen_ville',

                          'assets/ville', 'assets/vehicules', 'gen_voiture') }

            @{ cle = 'bordure'; nom = 'bordure en voiture'
               script = 'res://verifs/test_bordure_voiture.gd'
               couvre = @('gen_ville', 'assets/ville', 'systemes/vehicule',
                          'scenes/vehicule', 'systemes/reglages') }
            @{ cle = 'chocs'; nom = 'chocs de la voiture'
               script = 'res://verifs/test_chocs.gd'
               couvre = @('systemes/vehicule', 'systemes/audio', 'systemes/controleur',
                          'donnees/sons', 'assets/sons', 'systemes/reglages',
                          'systemes/garee', 'systemes/circulant') }
            @{ cle = 'temps'; nom = 'cycle jour et nuit'
               script = 'res://verifs/test_temps.gd'
               couvre = @('systemes/temps', 'systemes/reglages', 'systemes/ville',
                          'rendu/rendu_ps2', 'gen_textures', 'gen_ville', 'donnees/monde') }
            @{ cle = 'desert'; nom = 'aller au desert'
               script = 'res://verifs/test_desert.gd'
               couvre = @('systemes/desert', 'systemes/passage', 'systemes/controleur',
                          'gen_desert', 'assets/desert', 'systemes/hud',
                          'systemes/audio', 'assets/sons/ambiance') }
            @{ cle = 'telephone'; nom = 'le telephone'
               script = 'res://verifs/test_telephone.gd'
               couvre = @('systemes/telephone', 'systemes/controleur',
                          'systemes/dialogue', 'donnees/telephone', 'donnees/dialogues') }
            @{ cle = 'sons'; nom = 'sons branches'
               script = 'res://verifs/test_sons.gd'
               couvre = @('systemes/audio', 'systemes/roue', 'systemes/equipement',
                          'systemes/silhouette', 'systemes/joueur', 'systemes/controleur',
                          'systemes/moteur_audio', 'donnees/sons', 'assets/sons') }
            @{ cle = 'moteur'; nom = 'son du moteur'
               script = 'res://verifs/test_moteur.gd'
               couvre = @('systemes/moteur_audio', 'systemes/vehicule', 'rendu/rendu_ps2', 'assets/sons') }
            @{ cle = 'maison'; nom = 'entrer dans les maisons'
               script = 'res://verifs/test_maison.gd'
               couvre = @('systemes/maison', 'systemes/controleur', 'gen_maison') }
            @{ cle = 'dialogue'; nom = 'habitants et dialogue'
               script = 'res://verifs/test_dialogue.gd'
               couvre = @('systemes/dialogue', 'systemes/pnj', 'systemes/maison', 'donnees/dialogues') }
            @{ cle = 'outils'; nom = 'roue des outils'
               script = 'res://verifs/test_outils.gd'
               couvre = @('systemes/roue', 'systemes/equipement', 'donnees/outils', 'gen_objets', 'scenes/joueur') }
            @{ cle = 'decor'; nom = 'mobilier urbain'
               script = 'res://verifs/test_decor.gd'
               couvre = @('systemes/ville', 'gen_decor', 'gen_ville', 'systemes/maison',
                          'systemes/garee', 'assets/decor') }
            @{ cle = 'jour'; nom = 'jour et nuit'
               script = 'res://verifs/test_jour.gd'
               couvre = @('rendu/rendu_ps2', 'systemes/reglages', 'systemes/ville', 'gen_textures', 'donnees/monde') }
            @{ cle = 'murs'; nom = 'camera et murs'
               script = 'res://verifs/test_camera_murs.gd'
               couvre = @('systemes/camera_poursuite', 'systemes/maison') }
            @{ cle = 'voix'; nom = 'voix des dialogues'
               script = 'res://verifs/test_voix.gd'
               couvre = @('systemes/dialogue', 'donnees/dialogues', 'donnees/voix', 'assets/voix', 'gen_voix') }
            @{ cle = 'souris'; nom = 'visee a la souris'
               script = 'res://verifs/test_souris.gd'
               couvre = @('systemes/camera_poursuite', 'systemes/controleur') }
            @{ cle = 'foule'; nom = 'passants'
               script = 'res://verifs/test_foule.gd'
               couvre = @('systemes/foule', 'systemes/pieton', 'systemes/silhouette',
                          'gen_ville', 'systemes/demarche', 'assets/personnages') }
            @{ cle = 'sauvegarde'; nom = 'sauvegarder et reprendre'
               script = 'res://verifs/test_sauvegarde.gd'
               couvre = @('systemes/sauvegarde', 'systemes/bourse', 'systemes/temps',
                          'systemes/equipement', 'systemes/mission', 'systemes/pause',
                          'systemes/scenario', 'systemes/fin_de_partie', 'donnees/outils') }
            @{ cle = 'titre'; nom = 'ecran-titre et menu'
               script = 'res://verifs/test_titre.gd'
               couvre = @('systemes/titre', 'systemes/sauvegarde', 'scenes/titre') }
        )

        # Toute modification de la scene principale ou des reglages touche tout
        # le monde : ce sont les fichiers que chaque suite charge.
        #
        # project.godot N Y EST PLUS. Il y etait, et ajouter une action d entree
        # y relancait les 27 suites. Mais une action d entree ne concerne que les
        # suites qui SIMULENT des entrees ; le reste du fichier - autoloads,
        # rendu, affichage - touche tout. On regarde donc CE QUI a change dedans,
        # plus bas, au lieu de le declarer global d office.
        $Global = @('scenes/monde', 'systemes/reglages.tres')

        # Les suites qui envoient de vrais evenements d entree. Ce sont les
        # seules qu une modification de la carte d entrees puisse affecter : les
        # autres pilotent le jeu par appels directs, la carte leur est
        # indifferente. Genereux a dessein, comme les motifs de couverture - une
        # suite jouee pour rien coute des secondes, une oubliee un bug livre.
        $SuitesEntree = @('allures', 'camera', 'chocs', 'jour', 'outils',
                          'sons', 'souris', 'telephone', 'trottoir')

        $choisies = $suites
        $raison = 'toutes'

        if ($Suite) {
            $choisies = @($suites | Where-Object { $_.cle -like "*$Suite*" -or $_.nom -like "*$Suite*" })
            $raison = "filtre '$Suite'"
            if ($choisies.Count -eq 0) {
                Write-Host "Aucune suite ne correspond a '$Suite'." -ForegroundColor Red
                Write-Host "Disponibles : $(($suites | ForEach-Object { $_.cle }) -join ', ')" -ForegroundColor Gray
                exit 1
            }
        }
        elseif ($Modifies) {
            # On demande a git ce qui a bouge, plutot que de s en remettre a
            # la memoire de celui qui commite.
            $ancien = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $fichiers = @(& git -C $Racine status --porcelain 2>$null |
                          ForEach-Object { ($_ -replace '^..\s+', '') -replace '\\', '/' })
            $ErrorActionPreference = $ancien

            if ($fichiers.Count -eq 0) {
                Write-Host "Rien de modifie : aucune suite a rejouer." -ForegroundColor Green
                exit 0
            }
            Write-Host "Modifie :" -ForegroundColor Gray
            $fichiers | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

            # project.godot a-t-il change, et si oui, EST-CE UNIQUEMENT sa
            # section [input] ? On compare la version de travail a celle de HEAD,
            # section [input] retiree des deux : si le reste est identique, seule
            # la carte d entrees a bouge.
            $godot_touche = @($fichiers | Where-Object { $_ -like '*project.godot' }).Count -gt 0
            $entree_seule = $false
            if ($godot_touche) {
                # Lecture UTF-8 des DEUX cotes, et c est indispensable :
                # project.godot porte des tirets cadratins hors [input], que
                # Get-Content -Raw lit en CP-1252 et casse, alors que git sort de
                # l UTF-8. Compares tels quels, les deux differaient TOUJOURS et
                # project.godot relancait les 27 suites - le bug que ce ticket
                # corrige, reintroduit par la mesure elle-meme.
                $prev = [Console]::OutputEncoding
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                $tete = & git -C $Racine show HEAD:game/project.godot 2>$null
                $ok = $LASTEXITCODE -eq 0
                [Console]::OutputEncoding = $prev
                if ($ok -and $tete) {
                    $travail = [System.IO.File]::ReadAllText((Join-Path $Projet 'project.godot'))
                    $entree_seule = (Get-HorsEntrees $travail) -eq (Get-HorsEntrees ($tete -join "`n"))
                }
            }

            $global_touche = @($fichiers | Where-Object {
                $f = $_; ($Global | Where-Object { $f -like "*$_*" }).Count -gt 0 })

            # Un fichier partage a bouge - ou project.godot a change AILLEURS que
            # dans [input] : dans les deux cas, tout se rejoue.
            if ($global_touche.Count -gt 0 -or ($godot_touche -and -not $entree_seule)) {
                $raison = 'un fichier partage a bouge'
            } else {
                $choisies = @($suites | Where-Object {
                    $s = $_
                    ($fichiers | Where-Object {
                        $f = $_; ($s.couvre | Where-Object { $f -like "*$_*" }).Count -gt 0
                    }).Count -gt 0
                })
                $raison = 'lie aux fichiers modifies'
                # Seule la carte d entrees a bouge : on ajoute les suites qui
                # exercent les entrees a celles que la couverture a deja retenues.
                if ($godot_touche -and $entree_seule) {
                    $choisies = @($choisies) + @($suites | Where-Object { $SuitesEntree -contains $_.cle })
                    $vues = @{}
                    $uniques = @()
                    foreach ($s in $choisies) {
                        if (-not $vues.ContainsKey($s.cle)) { $vues[$s.cle] = $true; $uniques += $s }
                    }
                    $choisies = $uniques
                    $raison = 'project.godot : entrees seules'
                }
                if ($choisies.Count -eq 0) {
                    Write-Host "`nAucune suite ne couvre ces fichiers." -ForegroundColor Yellow
                    Write-Host "Si c est du code de jeu, ajoute-le a 'couvre' dans bg.ps1." -ForegroundColor Gray
                    exit 0
                }
            }
        }

        Write-Host "`n$($choisies.Count) suite(s) - $raison" -ForegroundColor Gray
        if ($Lister) {
            $choisies | ForEach-Object { Write-Host "  $($_.cle)  -  $($_.nom)" -ForegroundColor Gray }
            exit 0
        }

        # A PARTIR D ICI ON JOUE : c est le seul moment ou Godot est necessaire.
        # Le tenir jusqu ici laisse -Lister et la selection repondre sans rien
        # importer.
        Exiger $GodotConsole 'Godot (console)'
        Set-Build
        Initialize-Projet
        $echecs = @()
        foreach ($s in $choisies) {
            Write-Host "`n--- $($s.nom) ---" -ForegroundColor Cyan
            & $GodotConsole @('--path', $Projet) @(Get-ArgsEcran) --script $s.script
            if ($LASTEXITCODE -ne 0) { $echecs += $s.nom }
        }
        Write-Host ""
        if ($echecs.Count -gt 0) {
            Write-Host "$($echecs.Count) suite(s) en echec : $($echecs -join ', ')" -ForegroundColor Red
            exit 1
        }
        Write-Host "$($choisies.Count) suite(s) OK" -ForegroundColor Green
    }
}
