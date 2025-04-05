Function Show-Menu {
    <#
    .SYNOPSIS
    Affiche un menu formaté en tableau avec les propriétés d'un objet PowerShell.

    .DESCRIPTION
    La fonction `Show-Menu` prend un objet en entrée et affiche ses propriétés sous forme d'un tableau encadré, avec des largeurs ajustées automatiquement pour une meilleure lisibilité.

    .PARAMETER InputObject
    Objet PowerShell dont les propriétés seront affichées sous forme de tableau. Ce paramètre est obligatoire.

    .PARAMETER Title
    Titre du menu affiché en haut du tableau. Si la largeur du titre dépasse celle du tableau, celui-ci s'ajuste automatiquement.

    .PARAMETER KeySize
    Taille minimale de la colonne contenant les noms des propriétés. Si non spécifié, la taille est ajustée dynamiquement en fonction des noms des propriétés.

    .PARAMETER Width
    Largeur totale du tableau. Si non spécifiée, elle est calculée dynamiquement en fonction des valeurs.

    .EXAMPLE
    $Info = [PSCustomObject]@{
        Nom = "John Doe"
        Âge = 30
        Ville = "Paris"
    }
    Show-Menu -InputObject $Info -Title "Informations Utilisateur"

    Affichera :
        ╒══════════════════════════╕
        │ Informations Utilisateur │
        ├──────────────────────────┤
        │ Nom  : John Doe          │
        │ Âge  : 30                │
        │ Ville: Paris             │
        ╘══════════════════════════╛

    .NOTES
    Auteur : [Ton Nom]
    Version : 1.0
    Date : [Date du jour]

    #>

    Param (        
 
        [Parameter(Mandatory=$true, ValueFromPipeline=$True)]
        [PsObject]$InputObject,
        [String] $Title,
        $KeySize = 25,
        $Width = 60
 
    )
    Clear-Host
    $KeySize = $InputObject.psobject.Properties.Name.ForEach({ $_.Length }) | Sort-Object -Descending -Unique | Select-Object -First 1
    $ValueSize = ($InputObject.psobject.Properties.value.ForEach({ $_.Length }) | Sort-Object -Descending -Unique | Select-Object -First 1) + 1
    $Width = $KeySize + $ValueSize + 2

    $LineLengh = ($KeySize + $ValueSize + 3)
    If ($LineLengh -gt $Width) {
        $Width++
    }

    If ($Title.Length -gt $Width) { $Width = $Title.Length + 2 }

    Write-Host "╒$([string]::new('═', $Width))╕"
    If ($Title) {
        $emptyspaces = ($Width - $Title.Length)
        $TitleLSpaces = [Math]::Floor($emptyspaces/2)
        $TitleRSpaces = $emptyspaces - $TitleLSpaces  

        Write-Host "│$([String]::new(' ', $TitleLSpaces))$Title$([String]::new(' ', $TitleRSpaces))│"
        Write-Host $("├$([string]::new('─', $Width))┤")
    
    }

    If ($LineLengh -lt $Width) { 
        $MissingSpaces = $Width - $LineLengh 
        $ValueSize += $MissingSpaces
    }

    Foreach ($Property in $InputObject.psobject.Properties) {
        Write-Host $("│ {0,-$KeySize}: {1, -$ValueSize}│" -f "$($Property.Name)", "$($Property.value)")
    }
    Write-Host $("╘$([string]::new('═', $Width))╛")
    Write-Host `n
} 


Export-ModuleMember Show-Menu