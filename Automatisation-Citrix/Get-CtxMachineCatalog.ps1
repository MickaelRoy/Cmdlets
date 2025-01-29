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
        Par défaut, les contrôleurs 'xendc102.contoso.fr' et 'xendc202.contoso.fr' seront utilisés.
    .EXAMPLE
        Get-CtxMachineCatalog -DeliveryGroups "Finance"
        Récupère les catalogues de machines pour le groupe de livraison "Finance".
    .EXAMPLE
        Get-CtxMachineCatalog
        Récupère tous les catalogues de machines disponibles.
    .NOTES
        Auteur: Mickael Roy
        Date de création: 30/04/2024
        Dernière modification: 15/05/2024
    .LINK
        Lien vers la page confluence : https://confluence.contoso.com/x/wA_aLQ

#>
    [CmdletBinding(HelpUri = 'https://confluence.contoso.com/x/wA_aLQ',DefaultParameterSetName = 'Implicit')]
    Param (
        [Parameter(Mandatory=$false, Position=0, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, ParameterSetName = 'Implicit')]
        [Alias("DesktopGroupName")]
        [String[]]$InputObject,

        [Parameter(Mandatory=$false, Position = 2)]
        [String[]]$DDCs = @('xenddc101.contoso.fr', 'xenddc201.contoso.fr')
    )
    DynamicParam {
        $ParameterName = "DeliveryGroups"

    # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

    # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $false
        $ParameterAttribute.Position = 1
        #$ParameterAttribute.ValueFromPipeline = $True
        #$ParameterAttribute.ValueFromPipelineByPropertyName = $True
        $ParameterAttribute.ParameterSetName = "Explicit"


    # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

    # Create the Alias Attributes
        #$ParameterAliases = [System.Management.Automation.AliasAttribute]::new("DesktopGroupName")

    # Add the attributes to the attributes collection
        #$AttributeCollection.Add($ParameterAliases)

    # Generate and set the ValidateSet

        $Devices = Get-CtxDeliveryGroup
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($Devices.DesktopGroupName)

    # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)

    # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string[]], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }
    Begin {
        $ErrorActionPreference = 'Stop'

        Try {
        
            If (-not (Get-Module Citrix.Broker.Commands)) {
                Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
                Import-Module Citrix.Broker.Commands
                Write-Host $OK -ForegroundColor Green
            }

            If ($null -eq $global:AdminAddress) {
                Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
                $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-TcpPort -Port 80 | Select-Object ComputerName,TcpTestSucceeded
                If ((!$ConnectionTest1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun delivery controllers n'est joignable." }
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
        $MachineObjects = [System.Collections.ArrayList]::new()
    } Process {
        If ($PSCmdlet.ParameterSetName -eq "Explicit") {
            $DeliveryGroups = $PSBoundParameters.DeliveryGroups
        } Else {
            $DeliveryGroups = $PSBoundParameters.InputObject
        }

        If ($DeliveryGroups) {

            Foreach ($DeliveryGroup in $DeliveryGroups) {
                
                Try {
                    Write-Verbose -Message "Get-BrokerDesktopGroup -AdminAddress $AdminAddress -DesktopGroupName $DeliveryGroup -ErrorAction Stop"
                    $DeliveryGroupObject = Get-BrokerDesktopGroup -AdminAddress $AdminAddress -DesktopGroupName $DeliveryGroup -ErrorAction Stop

                    $Parameters.Add('DesktopGroupName', $DeliveryGroupObject.Name)
                    [Array]$Machines = Get-BrokerMachine @Parameters
                    If ($null -ne $Machines) { [Void]$MachineObjects.AddRange($Machines) }
                    
                    If ($null -ne $MachineObjects) {
                        $CatalogUids = ($MachineObjects | Select-Object CatalogUid -Unique) 
                        $Catalogs = $CatalogUids | ForEach-Object { Get-BrokerCatalog -AdminAddress $AdminAddress -Uid $_.CatalogUid }
                    }

                } Catch {

                    Write-Verbose "Groupe de livraison $DeliveryGroup introuvable ?"
                    Throw $_
                } Finally {
                    $Parameters.Remove('DesktopGroupName')
                }
            }
        } Else {
        
            $Catalogs = Get-BrokerCatalog @Parameters
        }
        

    } End {
        If ($null -ne $Catalogs) {
            $Catalogs | ForEach-Object {
                $_.PsTypeNames.Insert(0,'BrsAdminTool.MachineCatalog')
            }

            Return $Catalogs
        }
    }
}

Export-ModuleMember Get-CtxMachineCatalog