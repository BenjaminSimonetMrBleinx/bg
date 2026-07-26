# Exporte les tickets GitHub vers livraisons/TICKETS.csv.
#
#     .\outils\tickets.ps1
#
# LE CSV N'EST PLUS UNE SAISIE, C'EST UNE PHOTO.
#
# Les deux existent parce qu'ils ne servent pas au meme moment : les issues
# pour ecrire — depuis le web, depuis le telephone, a deux sans se marcher
# dessus — et le CSV pour lire d'un coup d'oeil, hors ligne, dans Excel.
#
# Mais tenir les deux A LA MAIN, c'est garantir qu'ils divergent : on corrige
# d'un cote, on oublie de l'autre, et six semaines plus tard personne ne sait
# lequel dit vrai. Il n'y a donc qu'une source, GitHub, et le CSV en est
# REGENERE. Toute modification faite dans le fichier sera ecrasee au prochain
# export : c'est voulu, et c'est ecrit dans sa premiere colonne.

$ErrorActionPreference = 'Stop'

function Trouver-Gh {
    $c = (Get-Command gh -ErrorAction SilentlyContinue).Source
    if ($c) { return $c }
    # gh est souvent installe sans etre dans le PATH du terminal courant.
    # Le chercher evite un « command not found » qui laisse croire qu il
    # faut l installer alors qu il est deja la.
    foreach ($p in @("$env:ProgramFiles\GitHub CLI\gh.exe",
                     "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe")) {
        if (Test-Path $p) { return $p }
    }
    throw "GitHub CLI introuvable. Installer : winget install --id GitHub.cli"
}

$gh = Trouver-Gh
$racine = Split-Path $PSScriptRoot -Parent
$sortie = Join-Path $racine 'livraisons\TICKETS.csv'

Write-Host ""
Write-Host "  Lecture des tickets GitHub..." -ForegroundColor Cyan

$brut = & $gh issue list --state all --limit 200 `
        --json number,title,body,labels,state,assignees,updatedAt
$issues = $brut | ConvertFrom-Json

function Etiquette($issue, $prefixe) {
    ($issue.labels | Where-Object { $_.name -like "$prefixe*" } |
     ForEach-Object { $_.name -replace "^$prefixe", '' }) -join ', '
}

$lignes = foreach ($i in ($issues | Sort-Object number)) {
    $noms = @($i.labels | ForEach-Object { $_.name })
    $type = @('son','voix','modele','animation','texture','info') |
            Where-Object { $noms -contains $_ } | Select-Object -First 1
    $prio = if ($noms -contains 'priorite-haute') { 'Haute' }
            elseif ($noms -contains 'priorite-basse') { 'Basse' } else { 'Moyenne' }
    $statut = if ($i.state -eq 'CLOSED') { 'Integre' }
              elseif ($noms -contains 'a-integrer') { 'Livre - a integrer' }
              else { 'A faire' }
    # Le corps est aplati : un CSV n a qu une ligne par enregistrement, et les
    # retours a la ligne d une issue le couperaient en morceaux dans Excel.
    $corps = ($i.body -replace "`r", '' -replace "`n", ' ' -replace '\s+', ' ').Trim()
    [pscustomobject]@{
        'ID'              = "#$($i.number)"
        'Type'            = if ($type) { (Get-Culture).TextInfo.ToTitleCase($type) } else { '' }
        'Titre'           = $i.title
        'Ce qu''on attend'= $corps
        'Priorite'        = $prio
        'Statut'          = $statut
        'Mis a jour'      = ([datetime]$i.updatedAt).ToString('yyyy-MM-dd')
        'Lien'            = "https://github.com/BenjaminSimonetMrBleinx/bg/issues/$($i.number)"
    }
}

# Point-virgule et UTF-8 AVEC BOM : c est ce qu attend Excel en francais. Une
# virgule met toute la ligne dans une seule colonne, et sans BOM les accents
# arrivent en mojibake. Les deux se voient au premier double-clic, chez l autre.
$entete = "# GENERE depuis les issues GitHub par outils\tickets.ps1 - NE PAS EDITER, tout changement sera ecrase"
$csv = $lignes | ConvertTo-Csv -Delimiter ';' -NoTypeInformation
[System.IO.File]::WriteAllLines($sortie, (@($entete) + $csv),
        (New-Object System.Text.UTF8Encoding $true))

$ouverts = @($issues | Where-Object { $_.state -eq 'OPEN' }).Count
Write-Host ("  {0} ticket(s), dont {1} ouvert(s)" -f $lignes.Count, $ouverts) -ForegroundColor Green
Write-Host "  -> $sortie"
Write-Host ""
