function Show-InteractiveMenu {
<#
    .SYNOPSIS
    Affiche un menu interactif permettant de sélectionner une option avec les touches fléchées.

    .DESCRIPTION
    La fonction `Show-InteractiveMenu` affiche un menu interactif en mode console, où l'utilisateur peut naviguer entre les options à l'aide des touches fléchées et valider son choix avec la touche Entrée. Une fois une option sélectionnée, la fonction retourne la valeur correspondante.

    .PARAMETER Title
    Titre affiché en haut du menu interactif. Par défaut, "Menu Interactif".

    .PARAMETER Options
    Tableau de chaînes représentant les différentes options du menu. Par défaut, trois options génériques sont définies.

    .PARAMETER XOffset
    Décalage horizontal des options affichées dans le menu. Défaut : 3.

    .PARAMETER YOffset
    Décalage vertical du menu par rapport au haut de la console. Défaut : 4.

    .EXAMPLE
    $choix = Show-InteractiveMenu -Title "Sélectionnez une action" -Options @("Démarrer", "Arrêter", "Redémarrer")
    Write-Host "Vous avez choisi : $choix"

    Ce script affiche un menu interactif avec trois options et stocke la sélection dans `$choix`, qui est ensuite affichée.

    .Link
    https://michael-casey.com/2019/07/03/powershell-terminal-menu-template/

    .NOTES
    Auteur : [Mickael Casey]
    Mis à jour : [Mickael Roy]

#>

    param (
        [string]$Title = "Menu Interactif",
        [string[]]$Options = @("Option 1", "Option 2", "Option 3"),
        [int]$XOffset = 3,
        [int]$YOffset = 4
    )

    # Clear screen and display title
    Clear-Host
    Write-Host "`n  $Title"
    Write-Host "  Utilisez les flèches haut/bas pour naviguer, Entrée pour valider.`n"

    # Menu setup
    [Console]::SetCursorPosition(0, $YOffset)
    foreach ($name in $Options) {
        for ($i = 0; $i -lt $XOffset; $i++) {
            Write-Host " " -NoNewline
        }
        Write-Host "   " • $name
    }

    # Highlight functions
    function Write-Highlighted {
        [Console]::SetCursorPosition(1 + $XOffset, $cursorY + $YOffset)
        Write-Host "->" -BackgroundColor White -ForegroundColor Black -NoNewline
        Write-Host "" • $Options[$cursorY] -BackgroundColor White -ForegroundColor Black
        [Console]::SetCursorPosition(0, $cursorY + $YOffset)
    }

    function Write-Normal {
        [Console]::SetCursorPosition(1 + $XOffset, $cursorY + $YOffset)
        Write-Host "  " • $Options[$cursorY]
    }

    # Highlight first item
    $cursorY = 0
    Write-Highlighted

    # Menu loop
    $selection = ""
    $menu_active = $true
    while ($menu_active) {
        if ([Console]::KeyAvailable) {
            $x = $Host.UI.RawUI.ReadKey()
            [Console]::SetCursorPosition(1, $cursorY)
            Write-Normal
            switch ($x.VirtualKeyCode) {
                38 { if ($cursorY -gt 0) { $cursorY-- } } # Up arrow
                40 { if ($cursorY -lt $Options.Length - 1) { $cursorY++ } } # Down arrow
                13 { # Enter key
                    $selection = $Options[$cursorY]
                    $menu_active = $false
                }
            }
            Write-Highlighted
        }
        Start-Sleep -Milliseconds 5
    }

    # Déplacer le curseur une ligne en dessous du menu
    $finalY = [Console]::CursorTop + 1
    [Console]::SetCursorPosition(0, $finalY)

    return $selection
}

# Test
$choix = Show-InteractiveMenu
Write-Host "`nVous avez sélectionné : $choix"
