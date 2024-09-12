Function Get-CtxMachineCatalog {
<#
    .SYNOPSIS
        Obtient les catalogues de machines d'une ou plusieurs groupes de livraison Citrix.
    .DESCRIPTION
        Cette fonction récupère les catalogues de machines pour un ou plusieurs groupes de livraison Citrix.
        Si aucun groupe de livraison n'est spécifié, elle récupère tous les catalogues de machines disponibles.
    .PARAMETER DeliveryGroups
        Spécifie le ou les noms des groupes de livraison pour lesquels récupérer les catalogues de machines.
        Vous pouvez spécifier plusieurs groupes en les séparant par des virgules.
        Par défaut, la fonction récupère les catalogues de machines de tous les groupes de livraison.
    .PARAMETER DDCs
        Spécifie les contrôleurs de livraison Citrix à utiliser pour la connexion.
        Par défaut, les contrôleurs 'xendc001.contoso.fr' et 'xendc002.contoso.fr' seront utilisés.
    .EXAMPLE
        Get-CtxMachineCatalog -DeliveryGroups "Finance"
        Récupère les catalogues de machines pour le groupe de livraison "Finance".
    .EXAMPLE
        Get-CtxMachineCatalog
        Récupère tous les catalogues de machines disponibles.
    .NOTES
        Auteur: Mickael Roy
        Site Web: mickaelroy.starprince.fr
        Date de création: 30/04/2024
        Dernière modification: 30/04/2024
#>
        [CmdletBinding()]

        Param (
            [Parameter(Mandatory=$false, ValueFromPipeline = $True , ValueFromPipelineByPropertyName = $True, HelpMessage='Specify the delivery group name')]
            [Alias("DesktopGroupName")]
            [String[]]$DeliveryGroups,
            
            [Parameter(Mandatory=$false)]
            [String[]]$DDCs = @('xendc001.contoso.fr', 'xendc002.contoso.fr')
        )
    Begin {
        $ErrorActionPreference = 'Stop'

        Try {
        
            Write-Host 'Chargement du PSSnapin Citrix... ' -NoNewline
            @('Citrix.Host.Admin.V2', 'Citrix.Broker.Admin.V2', 'Citrix.MachineCreation.Admin.V2').ForEach({
                If ( $null -eq  (Get-PSSnapin $_ -ErrorAction SilentlyContinue)) { 
                    Add-PSSnapin $_
                    $i++
                    Write-Host " $i" -ForegroundColor Green -NoNewline
                }
            })
            Write-Host ' OK' -ForegroundColor Green

            If ($null -eq $global:AdminAddress) {
                Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
                $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-NetConnection -Port 80 | Select-Object ComputerName,TcpTestSucceeded
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
    } Process {
        If ($PSBoundParameters.ContainsKey('DeliveryGroups')) {

            Foreach ($DeliveryGroup in $DeliveryGroups) {
                $Parameters = @{
                    AdminAddres = $AdminAddress
                }

                Try {
                    Write-Verbose -Message "Get-BrokerDesktopGroup -AdminAddress $AdminAddress -DesktopGroupName $DeliveryGroup -ErrorAction Stop"
                    $DeliveryGroupObject = Get-BrokerDesktopGroup -AdminAddress $AdminAddress -DesktopGroupName $DeliveryGroup -ErrorAction Stop
                    $Parameters.Add('DesktopGroupName', $DeliveryGroupObject.DesktopGroupName)

                } Catch {

                    Throw "Groupe de livraison `'$DeliveryGroup`' introuvable."
                }
                $MachineObjects = Get-BrokerMachine @Parameters

                If ($null -ne $MachineObjects) {
                    ($MachineObjects | Select-Object CatalogUid -Unique) | ForEach-Object { Get-BrokerCatalog -AdminAddress $AdminAddress -Uid $_.CatalogUid }
                }
            }
        } Else {
            Get-BrokerCatalog @Parameters
        }


    } End {

    }

}

Export-ModuleMember Get-CtxMachineCatalog