# Genere une texture avec Magnific, la telecharge et la met a la taille du jeu.
#
#     .\outils\magnific.ps1 -Cle labo_paillasse -Taille 256 `
#                           -Prompt "seamless tileable texture, scratched steel..."
#
# CE FICHIER EST EN ASCII STRICT, sans le moindre caractere accentue.
# PowerShell 5.1 - celui de Windows, celui que lance JOUER.bat - lit un .ps1 en
# CP-1252 quand il n'a pas de marque d'octets. Un tiret cadratin y devient trois
# caracteres dont un guillemet, qui ferme la chaine et casse tout le fichier a
# partir de la. L'erreur pointe alors une ligne jamais touchee.
#
# CE QUE CE SCRIPT NE SAIT PAS FAIRE : la 3D. L'API REST de Magnific n'expose
# que les images, l'upscale et la video - douze chemins ont ete sondes le
# 08/08/2026, tous en 404. La generation de modeles n'existe que dans le MCP,
# qui demande une session OAuth. Voir docs/17-assets-ia.md.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Cle,
    [Parameter(Mandatory = $true)][string]$Prompt,
    [int]$Taille = 256,
    [string]$Modele = 'mystic',
    [string]$Decor = 'divers',
    [switch]$Garder,
    [int]$Attente = 240
)

$ErrorActionPreference = 'Stop'
$Racine = Split-Path -Parent $PSScriptRoot
Set-Location $Racine

$ApiKey = [Environment]::GetEnvironmentVariable('MAGNIFIC_API_KEY', 'User')
if (-not $ApiKey) {
    Write-Host "MAGNIFIC_API_KEY absente." -ForegroundColor Red
    Write-Host "  [Environment]::SetEnvironmentVariable('MAGNIFIC_API_KEY','<cle>','User')" -ForegroundColor Gray
    Write-Host "  La cle ne va JAMAIS dans le depot." -ForegroundColor Gray
    exit 1
}
$Entetes = @{ 'x-magnific-api-key' = $ApiKey }
$Base = 'https://api.magnific.com/v1/ai'

# --- 1. demander -------------------------------------------------------------
Write-Host ""
Write-Host "modele    $Modele" -ForegroundColor Gray
Write-Host "prompt    $Prompt" -ForegroundColor Gray

$corps = @{ prompt = $Prompt } | ConvertTo-Json -Compress
$reponse = Invoke-RestMethod -Uri "$Base/$Modele" -Method Post -Headers $Entetes `
                             -Body $corps -ContentType 'application/json'
$tache = $reponse.data.task_id
if (-not $tache) { Write-Host "aucun task_id rendu" -ForegroundColor Red; exit 1 }
Write-Host "tache     $tache" -ForegroundColor Gray

# --- 2. attendre -------------------------------------------------------------
# L'API est asynchrone : CREATED, puis IN_PROGRESS, puis COMPLETED ou FAILED.
$debut = Get-Date
do {
    Start-Sleep -Seconds 4
    $etat = Invoke-RestMethod -Uri "$Base/$Modele/$tache" -Method Get -Headers $Entetes
    $ecoule = [int]((Get-Date) - $debut).TotalSeconds
    if ($ecoule -gt $Attente) {
        Write-Host "abandon apres $ecoule s (statut $($etat.data.status))" -ForegroundColor Red
        exit 1
    }
} while ($etat.data.status -in @('CREATED', 'IN_PROGRESS'))

if ($etat.data.status -ne 'COMPLETED') {
    Write-Host "echec : $($etat.data.status) $($etat.data.error)" -ForegroundColor Red
    exit 1
}
$url = $etat.data.generated[0]
if (-not $url) { Write-Host "aucune image rendue" -ForegroundColor Red; exit 1 }
Write-Host "genere    en $ecoule s" -ForegroundColor Green

# --- 3. telecharger dans le sas ---------------------------------------------
# livraisons/ia/ est hors de git : un original pese des Mo et se regenere depuis
# le manifeste. C'est le manifeste la source, pas le fichier.
$sas = Join-Path $Racine "livraisons/ia/$Decor"
New-Item -ItemType Directory -Force $sas | Out-Null
$brut = Join-Path $sas "$Cle-brut.png"
Invoke-WebRequest -Uri $url -OutFile $brut

$empreinte = (Get-FileHash $brut -Algorithm SHA256).Hash.ToLower()

# --- 4. ramener a la taille du jeu ------------------------------------------
# ON MESURE LE FICHIER PRODUIT, jamais l'intention : on relit les cotes reels
# apres ecriture. Un redimensionnement qui echoue silencieusement laisserait une
# texture de 2048 px au milieu d'un jeu qui en attend 256, et ca se voit plus
# qu'un modele rate.
Add-Type -AssemblyName System.Drawing
$source = [System.Drawing.Image]::FromFile($brut)
$avantL = $source.Width; $avantH = $source.Height

$cible = New-Object System.Drawing.Bitmap($Taille, $Taille)
$g = [System.Drawing.Graphics]::FromImage($cible)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($source, 0, 0, $Taille, $Taille)
$g.Dispose(); $source.Dispose()

# LA TEXTURE FINALE EST VERSIONNEE, et pas dans .tmp/.
#
# .tmp/ est le dossier de ce qui se REGENERE : bg.ps1 nettoyer le vide, et
# gen_textures.py le reecrit en entier. Une texture generee n'est ni l'un ni
# l'autre - elle a coute des credits, et relancer le meme prompt rend une AUTRE
# image. La perdre, c'est la repayer sans la retrouver.
#
# Elle vit donc dans outils/textures-ia/, a cote du manifeste qui la decrit, et
# une copie part dans .tmp/textures/ pour que les generateurs Blender la voient
# la ou ils cherchent deja.
$dest = Join-Path $Racine "outils/textures-ia/$Cle.png"
New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
$cible.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
$cible.Dispose()

$pourBlender = Join-Path $Racine ".tmp/textures/$Cle.png"
New-Item -ItemType Directory -Force (Split-Path $pourBlender) | Out-Null
Copy-Item $dest $pourBlender -Force

$relu = [System.Drawing.Image]::FromFile($dest)
$reluL = $relu.Width; $reluH = $relu.Height
$relu.Dispose()
if ($reluL -ne $Taille -or $reluH -ne $Taille) {
    Write-Host "ECRIT FAUX : $reluL x $reluH au lieu de $Taille" -ForegroundColor Red
    exit 1
}

if (-not $Garder) { Remove-Item $brut -Force }

Write-Host "texture   $avantL x $avantH -> $reluL x $reluH" -ForegroundColor Green
Write-Host "produit   $dest"
Write-Host ""
Write-Host "A RECOPIER dans outils/assets-ia.json :" -ForegroundColor Yellow
Write-Host "  `"creation_id`": `"$tache`","
Write-Host "  `"sha256`": `"$empreinte`""
