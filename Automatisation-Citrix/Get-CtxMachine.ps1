Function Get-CtxMachine {
<#
    .SYNOPSIS
    Récupère des informations sur les machines dans un environnement Citrix.

    .DESCRIPTION
    La fonction `Get-CtxMachine` permet de récupérer des informations sur les machines dans un environnement Citrix, en fonction du groupe de livraison (Delivery Group) ou du catalogue de machines spécifié. Elle vérifie également la connectivité aux Delivery Controllers avant d'établir une connexion.

    .PARAMETER DeliveryGroup
    Nom du groupe de livraison (Delivery Group). Ce paramètre est facultatif.
    Alias: DesktopGroupName

    .PARAMETER CatalogName
    Nom du catalogue de machines. Ce paramètre est facultatif.
    Alias: BrokerCatalog, MachineCatalog

    .PARAMETER DDCs
    Liste des Delivery Controllers (DDCs) à utiliser pour vérifier la connectivité. Ce paramètre est facultatif et par défaut, il utilise les adresses 'xendc001.contoso.fr'.

    .EXAMPLE
    PS C:\> Get-CtxMachine -DeliveryGroup "SalesGroup"
    Récupère les machines appartenant au groupe de livraison "SalesGroup".

    .EXAMPLE
    PS C:\> Get-CtxMachine -CatalogName "Win10Catalog"
    Récupère les machines appartenant au catalogue de machines "Win10Catalog".

    .EXAMPLE
    PS C:\> Get-CtxMachine
    Récupère les informations sur toutes les machines sans filtrage par groupe de livraison ou catalogue.

    .NOTES
        Auteur: Mickael Roy
        Date de création: 15/05/2024
        Dernière modification: 15/05/2024

    .LINK
    https://confluence.boursorama.com/x/wA_aLQ
#>

    [CmdletBinding(HelpUri = 'https://confluence.boursorama.com/x/wA_aLQ')]

    Param (
        [Parameter(Mandatory=$false, HelpMessage='Specify the delivery group name')]
        [Alias("DesktopGroupName")]
        [String]$DeliveryGroup,

        [Parameter(Mandatory=$false, HelpMessage='Specify the machine catalog name')]
        [Alias("BrokerCatalog", "MachineCatalog")]
        [String]$CatalogName,
            
        [Parameter(Mandatory=$false)]
        [Alias("AdminAddress")]
        [String[]]$DDCs = @('xendc001.contoso.fr', 'xendc001.contoso.fr')
    )

    Begin {

        $ErrorActionPreference = 'Stop'

        Try {
        
            If (-not (Get-Module Citrix.Broker.Commands)) {
                Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
                Import-Module Citrix.Broker.Commands
                Write-Host 'OK' -ForegroundColor Green
            }
                
            If ($null -eq $global:AdminAddress) {
                Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
                $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-NetConnection -Port 80 | Select-Object ComputerName,TcpTestSucceeded
                If ((!$ConnectionTes1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun delivery controllers n'est joignable." }
                Write-Host 'OK' -ForegroundColor Green

                $global:AdminAddress = $ConnectionTest1, $ConnectionTest2 | Where-Object TcpTestSucceeded | Get-Random | Select-Object -ExpandProperty ComputerName
                Set-HypAdminConnection -AdminAddress $global:AdminAddress
            }
            Write-Host "$global:AdminAddress est notre interlocuteur..."
            $Parameters = @{
                AdminAddress = $AdminAddress
            }


        } Catch {
            Write-Host 'NOK' -ForegroundColor Red
            Throw $_
        }

        $MachineList = [System.Collections.ArrayList]::new()
    } Process {
        Switch ($PSBoundParameters.Keys) {
            "DeliveryGroup"  {
                Write-Verbose -Message "DeliveryGroup = $DeliveryGroup"
                $Parameters.DesktopGroupName = $DeliveryGroup
            }
            "CatalogName"  {
                Write-Verbose -Message "CatalogName = $CatalogName"
                $Parameters.CatalogName = $CatalogName
            }
        }
        $(Get-BrokerMachine @Parameters) | ForEach-Object {
            [Void]$MachineList.Add( $_ )
        }

    } End {

        $MachineList | ForEach-Object {
            $_.PsTypeNames.Insert(0,'BrsAdminTool.Machine')
        }
        Return $MachineList
    }

}
