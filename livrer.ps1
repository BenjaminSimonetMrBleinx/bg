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
# Aucun bloc param() ici, volontairement : on passe par $args.
#
# Avec un parametre nomme $Arguments, PowerShell traitait "Invoke-Git add -A"
# comme un -A abrege de -Arguments et reclamait une valeur qui ne venait
# jamais. Les noms de parametres s abregent, et les drapeaux courts de git
# entrent en collision avec a peu pres n importe quel nom qu on choisirait.
function Invoke-Git {
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lignes = & git @args 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Code = $LASTEXITCODE; Lignes = $lignes }
    } finally {
        $ErrorActionPreference = $ancien
    }
}

# Meme isolement que pour git, pour les autres programmes appeles.
function Invoke-Externe {
    $prog = $args[0]
    $reste = @()
    if ($args.Count -gt 1) { $reste = $args[1..($args.Count - 1)] }
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lignes = & $prog @reste 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Code = $LASTEXITCODE; Lignes = $lignes }
    } finally { $ErrorActionPreference = $ancien }
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
$temoin = "game/assets/ville/ville.glb"
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

# Un depot laisse EN PLEIN CONFLIT ne peut plus rien recuperer.
#
# Git repond alors « Pulling is not possible because you have unmerged files »
# a chaque tentative, indefiniment, et le message ne dit pas comment en sortir.
# On y arrive apres une fusion interrompue — une fenetre fermee, un ordinateur
# eteint, un abandon qui n a pas abouti — et plus rien ne marche ensuite.
#
# On nettoie donc AVANT de tirer, au lieu de constater apres. C est sans risque
# pour le travail qui compte : les commits sont intacts, et les fichiers pas
# encore ajoutes a git — les sons qu on vient de deposer — ne sont pas touches.
# Seules disparaissent les modifications locales sur des fichiers suivis, qui
# ici sont toujours des assets regeneres.
$conflits = @(& git diff --name-only --diff-filter=U 2>$null)
$rebase_en_cours = (Test-Path (Join-Path $PSScriptRoot '.git\rebase-merge')) -or
                   (Test-Path (Join-Path $PSScriptRoot '.git\rebase-apply'))
$fusion_en_cours = Test-Path (Join-Path $PSScriptRoot '.git\MERGE_HEAD')

if ($conflits.Count -gt 0 -or $rebase_en_cours -or $fusion_en_cours) {
    Souci "Ton depot etait reste au milieu d une fusion interrompue."
    Info  "Je remets les choses d aplomb. Tes fichiers deposes ne bougent pas."
    if ($rebase_en_cours) { Invoke-Git rebase --abort | Out-Null }
    if ($fusion_en_cours) { Invoke-Git merge --abort | Out-Null }
    Invoke-Git reset --hard HEAD | Out-Null
    Bien "Depot remis d aplomb"
}

$r_pull = Invoke-Git pull --rebase --autostash
Select-Utile $r_pull.Lignes | ForEach-Object { Info $_ }
if ($r_pull.Code -ne 0) {
    # Deuxieme chance : on jette les modifications locales sur les fichiers
    # suivis — ce sont des assets regeneres, refabricables en une commande — et
    # on retire du chemin les fichiers que git n a plus a suivre. Les vraies
    # livraisons, elles, ne sont pas encore suivies : elles survivent.
    Souci "Recuperation bloquee. Deuxieme tentative, sans les fichiers regeneres."
    Invoke-Git rebase --abort | Out-Null
    Invoke-Git reset --hard HEAD | Out-Null
    foreach ($jetable in @('game/donnees/version.json', '.tmp')) {
        Invoke-Git rm -r --cached -q --ignore-unmatch $jetable | Out-Null
    }
    Invoke-Git checkout -- . | Out-Null
    $r_pull = Invoke-Git pull --rebase --autostash
    Select-Utile $r_pull.Lignes | ForEach-Object { Info $_ }
}
if ($r_pull.Code -ne 0) {
    Invoke-Git rebase --abort | Out-Null
    Stop-Net @"
La recuperation a echoue : quelqu un a modifie les memes fichiers que toi.

Rien n est perdu et rien n a ete envoye. Envoie une copie d ecran de ce
message a Benjamin, il demelera en deux minutes.
"@
}
# On reclame systematiquement les objets LFS manquants. C'est instantane
# quand tout est deja la, et ca evite le symptome le plus deroutant du depot :
# un fichier present mais qui n'est qu'un pointeur texte de 130 octets. Godot
# ne l'ouvre pas, aucune erreur visible, le son ne sort simplement pas.
$r_lfspull = Invoke-Git lfs pull
Select-Utile $r_lfspull.Lignes | ForEach-Object { Info $_ }
if ($r_lfspull.Code -ne 0) {
    Souci "Recuperation des fichiers binaires incomplete."
    Info  "Les images ou les sons risquent de manquer. Reessaie plus tard."
}

Bien "A jour avec GitHub"

# ------------------------------------------------------- 3. ce que tu vas envoyer

# Le dossier de depot s appelait "assets" avant d etre renomme "livraisons",
# parce qu il portait exactement le meme nom que celui du jeu. Quelqu un qui
# depose ses fichiers AVANT de recuperer cette version les pose forcement dans
# l ancien dossier — et le script qui tourne alors est encore l ancien, donc il
# ne peut pas le savoir. On rattrape ici, au passage suivant : c est gratuit
# quand il n y a rien a rattraper, et ca evite un fichier qui dort sans que
# personne ne comprenne pourquoi il n arrive jamais dans le jeu.
if (Test-Path "assets") {
    $restes = @(Get-ChildItem "assets" -Recurse -File -ErrorAction SilentlyContinue)
    foreach ($f in $restes) {
        $relatif = $f.FullName.Substring((Resolve-Path "assets").Path.Length).TrimStart('\')
        $cible = Join-Path "livraisons" $relatif
        New-Item -ItemType Directory -Force -Path (Split-Path $cible) | Out-Null
        Move-Item $f.FullName $cible -Force
        Info "recupere : assets\$relatif -> livraisons\$relatif"
    }
    Remove-Item "assets" -Recurse -Force -ErrorAction SilentlyContinue
    if ($restes.Count -gt 0) {
        Bien "$($restes.Count) fichier(s) recuperes de l ancien dossier assets\"
    }
}

# Meme rattrapage cote jeu : les sons vivaient a plat dans game/assets/sons/,
# ils sont maintenant classes par mecanisme. Un fichier arrive a la racine n est
# pas perdu, mais il n est branche sur rien : on le signale au lieu de le
# deviner, parce que deviner mal reviendrait a le ranger la ou personne ne le
# cherchera.
# Le chemin finit par \* : sans joker, -Include sans -Recurse ne renvoie
# jamais rien, en silence. Et un controle qui ne trouve jamais rien ressemble
# exactement a un controle qui passe.
$vrac = @(Get-ChildItem "game/assets/sons/*" -File -Include *.wav,*.ogg `
          -ErrorAction SilentlyContinue)
if ($vrac.Count -gt 0) {
    Souci "$($vrac.Count) son(s) sont a la racine de game\assets\sons\ :"
    $vrac | ForEach-Object { Info "  $($_.Name)" }
    Info "Ils doivent aller dans un sous-dossier — vehicule, pas, maison,"
    Info "interface, telephone ou ambiance. Voir docs/03-conventions-assets.md"
}

# Les sons deposes dans livraisons/sons sont remis la ou Godot les lit. Autant
# que le script s en charge plutot que d exiger qu on retienne le chemin.
if (Test-Path "livraisons/sons") {
    $audio = @(Get-ChildItem "livraisons/sons" -Recurse -File -Include *.wav,*.ogg,*.mp3 -ErrorAction SilentlyContinue)
    foreach ($f in $audio) {
        $relatif = $f.FullName.Substring((Resolve-Path "livraisons/sons").Path.Length).TrimStart('\')
        $cible = Join-Path "game/assets/sons" $relatif
        New-Item -ItemType Directory -Force -Path (Split-Path $cible) | Out-Null
        Move-Item $f.FullName $cible -Force
        Info "range : $relatif -> game/assets/sons/"
    }
    if ($audio.Count -gt 0) { Bien "$($audio.Count) son(s) ranges au bon endroit" }
}

# Meme principe pour les voix, mais elles ont besoin d etre converties et
# RENOMMEES : le jeu les retrouve par une empreinte du texte, que personne ne
# doit calculer a la main. On depose des numeros, le script fait le reste.
# Sans exclure les archives, le compte annoncait « 24 enregistrements a
# integrer » puis « aucun enregistrement a integrer » deux lignes plus bas :
# l integration, elle, ignore deja originaux/.
$depot_voix = @(Get-ChildItem "livraisons/voix" -File -Include *.wav,*.mp3,*.ogg,*.flac `
                -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.DirectoryName -notlike '*\originaux*' })
if ($depot_voix.Count -gt 0) {
    Info "$($depot_voix.Count) enregistrement(s) de voix a integrer..."
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & (Join-Path $PSScriptRoot 'bg.ps1') voix -Integrer }
    finally { $ErrorActionPreference = $ancien }
}

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

# Chacun sa voie : livraisons/ et docs/ pour ce qu on depose, game/ et outils/
# pour le code et ce qui en est genere. Rien n est bloque - il arrive tout a
# fait qu on doive toucher a l autre moitie - mais un binaire ne se fusionne
# pas : si deux personnes regenerent le meme .glb, l un des deux travaux est
# perdu au moment de resoudre le conflit. Autant le voir avant d envoyer.
$hors_voie = @($fichiers | Where-Object {
    $_.Fichier -notmatch '^(livraisons|docs)/' -and $_.Fichier -notmatch '^[^/]+$'
})
$generes = @($hors_voie | Where-Object {
    $_.Fichier -match '\.(glb|import|uid)$' -or $_.Fichier -match '^game/assets/'
})
if ($generes.Count -gt 4) {
    Souci "$($generes.Count) fichiers generes par Godot ou Blender vont partir."
    Info  "C est normal apres un premier import, ou si tu as lance bg.ps1 generer."
    Info  "Si tu n as fait ni l un ni l autre, signale-le a Benjamin avant d envoyer."
}

# Godot n importe que du WAV en PCM. Les stations audio exportent volontiers
# autre chose sous la meme extension, et l erreur n apparait qu a l import,
# bien plus tard, avec un message qui ne dit pas quoi faire.
$sons_envoyes = @($fichiers | Where-Object { $_.Fichier -match '\.(wav|ogg)$' })
if ($sons_envoyes.Count -gt 0 -and (Get-Command python -ErrorAction SilentlyContinue)) {
    $ctrl = Invoke-Externe python 'outils/normaliser_sons.py'
    if ($ctrl.Code -ne 0) {
        Souci "Certains sons ne sont pas au format que Godot sait lire :"
        $ctrl.Lignes | Where-Object { $_ -match 'A CORRIGER|^\s{14}' } |
            ForEach-Object { Info $_ }
        Info "Corrige avec : .\bg.ps1 sons -Corriger"
        Info "Tu peux envoyer quand meme, ils seront convertis a l arrivee."
    }
}

# Les gros fichiers passent par LFS, mais autant savoir ce qu on envoie.
foreach ($f in $fichiers) {
    if ((Test-Path $f.Fichier) -and (Get-Item $f.Fichier).Length -gt 50MB) {
        $mo = [math]::Round((Get-Item $f.Fichier).Length / 1MB)
        Souci "$($f.Fichier) pese $mo Mo. C est gros, verifie que c est voulu."
    }
}

# Un script casse ne se voit PAS sur la machine qui l envoie.
#
# PowerShell 7 lit un .ps1 en UTF-8 quoi qu il arrive. PowerShell 5.1, celui
# livre avec Windows et celui que lance JOUER.bat, le lit en CP-1252 s il n y a
# pas de marque d octets au debut. Un tiret cadratin devient alors trois
# caracteres dont un guillemet, qui ferme la chaine ou il se trouve et casse la
# totalite du fichier a partir de la.
#
# C est arrive : bg.ps1 est parti parfaitement fonctionnel d ici, et repondait
# a l arrivee par « Le terminateur " est manquant » sur une ligne qui n avait
# jamais ete touchee. On verifie donc AVANT d envoyer, avec le meme analyseur
# que celui qui echouera.
$scripts = @($fichiers | Where-Object { $_.Fichier -match '\.ps1$' -and (Test-Path $_.Fichier) })
if ($scripts.Count -gt 0) {
    $casses = @()
    foreach ($s in $scripts) {
        $octets = [System.IO.File]::ReadAllBytes((Resolve-Path $s.Fichier).Path)
        $bom = ($octets.Length -ge 3 -and $octets[0] -eq 0xEF -and $octets[1] -eq 0xBB)
        $accents = @($octets | Where-Object { $_ -gt 127 }).Count -gt ($(if ($bom) { 3 } else { 0 }))
        if ($accents -and -not $bom) {
            $casses += "$($s.Fichier) : caracteres accentues SANS marque d octets"
        }
        $err = $null; $jetons = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            (Resolve-Path $s.Fichier).Path, [ref]$jetons, [ref]$err)
        if ($err.Count -gt 0) {
            $casses += "$($s.Fichier) : $($err[0].Message)"
        }
    }
    if ($casses.Count -gt 0) {
        Souci "Un script ne s executerait pas chez l autre :"
        $casses | ForEach-Object { Info "  $_" }
        Stop-Net @"
Rien n a ete envoye.

Le fichier fonctionne peut-etre ici et pas ailleurs : c est le symptome d un
encodage sans marque d octets. Reenregistre-le en UTF-8 AVEC BOM, ou retire
les caracteres accentues, puis relance.
"@
    }
    Bien "$($scripts.Count) script(s) verifie(s)"
}

# Un envoi qui touche au jeu sans bouger le numero laisse deux versions
# differentes portant le meme nom. C est exactement ce qui rend inutile la
# question « tu es sur quelle version » — et donc l affichage a l ecran.
#
# On ne bloque pas : un envoi de docs ou d outils n a aucune raison de bumper.
# On demande, une fois, au moment ou l on peut encore le faire.
# Le CODE et les DONNEES, pas les assets.
#
# Deposer des sons ou un modele ne change pas ce qu'un testeur peut essayer :
# ca habille ce qui existe deja. Reclamer un numero de version et une note a
# celui qui livre des bruitages, c'est lui demander de raconter un lot dont il
# ne connait pas le contenu — et l'agacer a chaque envoi.
#
# Guillaume ne verra donc jamais ce rappel. C'est voulu : bumper et ecrire la
# note reviennent a celui qui a change le comportement du jeu.
$touche_jeu = @($fichiers | Where-Object {
    $_.Fichier -match '^game/(systemes|scenes|rendu|donnees)/' -or
    $_.Fichier -eq 'game/project.godot'
})
if ($touche_jeu.Count -gt 0) {
    $version = ''
    $l = Select-String -Path 'game/project.godot' -Pattern '^config/version="(.+)"' |
         Select-Object -First 1
    if ($l) { $version = $l.Matches[0].Groups[1].Value }

    $ancienne = ''
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $texte = (& git show 'origin/main:game/project.godot' 2>$null) -join "`n"
    $ErrorActionPreference = $ancien
    if ($texte -match 'config/version="(.+)"') { $ancienne = $Matches[1] }

    # Un numero qui bouge sans note de version ne sert a personne.
    #
    # Celui qui recupere la version veut savoir CE QU IL PEUT ESSAYER, et quel
    # bug genant a disparu. Sans cette note il relance le jeu et cherche la
    # difference — ou, plus souvent, ne cherche pas et ne la trouve jamais.
    if ($version -and $ancienne -and $version -ne $ancienne) {
        $notes = Get-Content 'docs/10-versions.md' -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($notes -notmatch [regex]::Escape("## $version")) {
            Souci "La version passe en $version, mais docs/10-versions.md n en parle pas."
            Info  "Une entree dit deux choses : ce qu on peut essayer, et le bug"
            Info  "genant qui a disparu. Les ajustements internes n y sont pas."
            if (-not $Oui -and -not $Quoi) {
                $r = Read-Host "`n  Envoyer sans note de version ? [o/N]"
                if ($r -notmatch '^[oOyY]') {
                    Write-Host "`n  Annule. Ecris la note, puis relance.`n" -ForegroundColor Yellow
                    exit 0
                }
            }
        } else {
            Bien "Note de version presente pour $version"
        }
    }

    if ($version -and $ancienne -and $version -eq $ancienne) {
        Souci "Le jeu a change ($($touche_jeu.Count) fichier(s)) mais la version reste $version."
        Info  "Elle se bouge dans game/project.godot, ligne config/version."
        Info  "Voir docs/10-versions.md pour ce qui merite un chiffre."
        # -Quoi ne demande rien : il montre. Poser la question ici bloquait le
        # mode apercu, qui est justement celui qu'on lance sans y assister.
        if (-not $Oui -and -not $Quoi) {
            $r = Read-Host "`n  Envoyer quand meme sans bouger la version ? [o/N]"
            if ($r -notmatch '^[oOyY]') {
                Write-Host "`n  Annule. Bouge la version, puis relance.`n" -ForegroundColor Yellow
                exit 0
            }
        }
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

# version.json est REGENERE avant chaque lancement : il change a chaque commit,
# et le suivre cree un conflit a chaque envoi croise.
#
# Le mettre dans .gitignore ne suffit pas, et c'est le piege : .gitignore ne
# s'applique qu'aux fichiers NON suivis. Une fois qu'il est entre dans l'index
# de quelqu'un - et il y est entre avant qu'on l'ignore - il y reste, et
# "git add -A" le represente a chaque fois. Il est donc retire de l'index ici,
# explicitement, a chaque envoi.
foreach ($jetable in @('game/donnees/version.json', '.tmp')) {
    Invoke-Git rm -r --cached -q --ignore-unmatch $jetable | Out-Null
}

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
