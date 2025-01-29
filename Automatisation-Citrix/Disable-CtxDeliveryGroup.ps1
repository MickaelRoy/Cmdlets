Function Disable-CtxDeliveryGroup {
<#
    .SYNOPSIS
    Disable-CtxDeliveryGroup désactive un groupe de livraison dans Citrix.

    .DESCRIPTION
    Cette fonction PowerShell désactive un groupe de livraison dans Citrix. Elle prend en charge la désactivation d'un groupe de livraison spécifié en utilisant le nom du groupe de livraison. Si aucun nom de groupe de livraison n'est spécifié, la fonction recherche et désactive le premier groupe de livraison trouvé.

    .PARAMETER DeliveryGroup
    Nom du groupe de livraison à désactiver.

    .PARAMETER DDCs
    Spécifiez les contrôleurs de livraison Citrix à utiliser. Par défaut, il utilisera les contrôleurs 'xendc001.contoso.fr' ou 'xendc002.contoso.fr' s'ils ne sont pas spécifiés.

    .EXAMPLE
    Disable-CtxDeliveryGroup -DeliveryGroup "MonGroupe"

    Cela désactive le groupe de livraison "MonGroupe".

    .EXAMPLE
    Disable-CtxDeliveryGroup

    Cela désactive le premier groupe de livraison trouvé.

    .NOTES
    Auteur: Mickael Roy
    Date de création: 07/05/2024
    Dernière modification: 07/05/2024
#>

    [CmdletBinding()]

    Param (
        [Parameter(Mandatory=$false, HelpMessage='Specify the delivery group name')]
        [Alias("DesktopGroupName")]
        [String]$DeliveryGroup,
        
        [Parameter(Mandatory=$false)]
        [Alias("AdminAddress")]
        [String[]]$DDCs = @('xenddc101.contoso.fr', 'xenddc201.contoso.fr')
    )

    $ErrorActionPreference = 'Stop'

    Try {

        If (-not (Get-Module Citrix.Broker.Commands)) {
            Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
            Import-Module Citrix.Broker.Commands
            Write-Host 'OK' -ForegroundColor Green
        }

        If ($null -eq $global:AdminAddress) {
            Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
            $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-TcpPort -Port 80 | Select-Object ComputerName,TcpTestSucceeded
            If ((!$ConnectionTes1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun delivery controllers n'est joignable." }
            Write-Host 'OK' -ForegroundColor Green

            $global:AdminAddress = $ConnectionTest1, $ConnectionTest2 | Where-Object TcpTestSucceeded | Get-Random | Select-Object -ExpandProperty ComputerName
            Set-HypAdminConnection -AdminAddress $global:AdminAddress
        }
        Write-Host "$global:AdminAddress est notre interlocuteur..."

    } Catch {
        Write-Host 'NOK' -ForegroundColor Red
        Throw $_
    }

    Try {
        Write-Host "Recherche du groupe de livraison: " -NoNewline
        $DG = Get-BrokerDesktopGroup -Name $DeliveryGroup -AdminAddress $AdminAddress
        Write-Host 'OK' -ForegroundColor Green

        Write-Host "Désactivation: " -NoNewline
        $DG | Set-BrokerDesktopGroup -Enabled:$false
        Write-Host 'OK' -ForegroundColor Green
    } Catch {
        Write-Host 'NOK' -ForegroundColor Red
        Throw $_
    }
}

Export-ModuleMember Disable-CtxDeliveryGroup