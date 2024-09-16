Function Get-CtxDeliveryGroup {
<#
.SYNOPSIS
    Récupère les informations sur les Delivery Groups Citrix.

.DESCRIPTION
    La fonction Get-CtxDeliveryGroup permet de récupérer les informations sur les Delivery Groups Citrix. 
    Vous pouvez spécifier les Delivery Groups par leur nom et vérifier la connectivité aux Delivery Controllers.

.PARAMETER DeliveryGroups
    Nom du ou des Delivery Groups à récupérer. Ce paramètre est optionnel et peut être passé par pipeline.

.PARAMETER DDCs
    Liste des Delivery Controllers à utiliser pour établir la connexion. 
    Par défaut, les valeurs sont 'xendc102.contoso.fr' et 'xendc202.contoso.fr'.

.EXAMPLE
    # Exemple 1 : Récupérer tous les Delivery Groups
    Get-CtxDeliveryGroup

.EXAMPLE
    # Exemple 2 : Récupérer des Delivery Groups spécifiques
    Get-CtxDeliveryGroup -DeliveryGroups "DG1", "DG2"

.EXAMPLE
    # Exemple 3 : Passer les Delivery Groups par pipeline
    "DG1", "DG2" | Get-CtxDeliveryGroup

.EXAMPLE
    # Exemple 4 : Spécifier des Delivery Controllers personnalisés
    Get-CtxDeliveryGroup -DDCs "myddc1.example.com", "myddc2.example.com"

.NOTES
    Auteur : Mickael ROY
    Date   : 12/07/2024
    Le script nécessite le module Citrix.Broker.Commands.

#>


    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline = $True , ValueFromPipelineByPropertyName = $True, HelpMessage='Specify the delivery group name')]
        [Alias("DesktopGroupName")]
        [String[]]$DeliveryGroups,
            
        [Parameter(Mandatory=$false)]
        [String[]]$DDCs = @('xendc102.contoso.fr', 'xendc202.contoso.fr')
    )

    Begin {
        $ErrorActionPreference = 'Stop'
        
        If ($null -ne $Env:WT_SESSION) { $OK = '✔'; $NOK = '❌'; $WARN = '⚠' }
        Else { $OK = 'ÓK'; $NOK = 'NOK'; $WARN = '/!\'}

        Try {
        
            If (-not (Get-Module Citrix.Broker.Commands)) {
                Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
                Import-Module Citrix.Broker.Commands
                Write-Host $OK -ForegroundColor Green
            }

            If ($null -eq $global:AdminAddress) {
                Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
                $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-TcpPort -Port 80 | Select-Object ComputerName,TcpTestSucceeded
                If ((!$ConnectionTes1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun delivery controllers n'est joignable." }
                Write-Host $OK -ForegroundColor Green

                $global:AdminAddress = $ConnectionTest1, $ConnectionTest2 | Where-Object TcpTestSucceeded | Get-Random | Select-Object -ExpandProperty ComputerName
                Set-HypAdminConnection -AdminAddress $global:AdminAddress
            }
            Write-Verbose -Message "$global:AdminAddress est notre interlocuteur..."
            $Parameters = @{
                AdminAddress = $AdminAddress
            }

        } Catch {
            Write-Host $NOK -ForegroundColor Red
            Throw $_
        }


    } Process {
        If ($PSBoundParameters.ContainsKey('DeliveryGroups')) {

            Foreach ($DG in $DeliveryGroups) {
                $Parameters.DesktopGroupName = $DG
                Get-BrokerDesktopGroup @Parameters
            }
        } Else {
            Get-BrokerDesktopGroup -AdminAddress $AdminAddress
        }

    } End {

    }

}

Export-ModuleMember Get-CtxDeliveryGroup