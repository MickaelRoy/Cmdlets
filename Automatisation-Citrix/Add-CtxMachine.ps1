Function Add-CtxMachine {
<#
    .SYNOPSIS
        Ajoute des machines au catalogue de machines et au groupe de livraison spécifiés.

    .DESCRIPTION
        Cette fonction ajoute des machines virtuelles au catalogue de machines spécifié et les associe au groupe de livraison spécifié dans Citrix XenDesktop. Elle procède à la création des objets ordinateurs dans Active Directory, au provisionnement des machines virtuelles, à leur enregistrement dans Citrix XenDesktop, et à leur ajout au groupe de livraison.

    .PARAMETER CatalogName
        Spécifie le nom du catalogue de machines dans Citrix XenDesktop.

    .PARAMETER DeliveryGroup
        Spécifie le nom du groupe de livraison dans Citrix XenDesktop.

    .PARAMETER DDCs
        (Facultatif) Spécifie les contrôleurs de domaine à utiliser pour la connexion. Par défaut, utilise les contrôleurs de domaine 'xendc102.contoso.fr' et 'xendc202.contoso.fr'.

    .EXAMPLE
        Add-CtxMachines -CatalogName "MyMachineCatalog" -DeliveryGroup "MyDeliveryGroup"
        Cette commande ajoute des machines au catalogue "MyMachineCatalog" et les associe au groupe de livraison "MyDeliveryGroup".

    .NOTES
        Auteur: Mickael Roy
        Date de création: 30/04/2024
        Dernière modification: 22/11/2024

    .LINK
        Lien vers la page confluence : https://confluence.contoso.com/x/wA_aLQ

#>

 [CmdletBinding(HelpUri = 'https://confluence.contoso.com/x/wA_aLQ')]
    Param (
        [Parameter(Mandatory=$true, HelpMessage='Specify the count of machine to generate')]
        [Int]$Count = 1,
            
        [Parameter(Mandatory=$false)]
        [String[]]$DDCs = @('xenddc101.contoso.fr', 'xenddc201.contoso.fr')
    )
    DynamicParam {
        $ParameterName1 = "CatalogName"
        $ParameterName2 = "DeliveryGroupName"

    # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    # Create the collection of attributes
        $AttributeCollection1 = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttributeCollection2 = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

    # Create and set the parameters' attributes
        $ParameterAttribute1 = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute1.Mandatory = $true
        $ParameterAttribute1.Position = 1
        $ParameterAttribute1.ValueFromPipeline = $True
        $ParameterAttribute1.ValueFromPipelineByPropertyName = $True
        $ParameterAttribute2 = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute2.Mandatory = $false
        $ParameterAttribute2.Position = 2

    # Add the attributes to the attributes collection
        $AttributeCollection1.Add($ParameterAttribute1)
        $AttributeCollection2.Add($ParameterAttribute2)

    # Create the Alias Attributes
        $ParameterAliases1 = [System.Management.Automation.AliasAttribute]::new("BrokerCatalog", "MachineCatalog")
        $ParameterAliases2 = [System.Management.Automation.AliasAttribute]::new("BrokerDesktopGroup", "DeliveryGroup")

    # Add the attributes to the attributes collection
        $AttributeCollection1.Add($ParameterAliases1)
        $AttributeCollection2.Add($ParameterAliases2)

    # Generate and set the ValidateSet
        $Devices = Get-CtxMachineCatalog
        $ValidateSetAttribute1 = New-Object System.Management.Automation.ValidateSetAttribute($Devices.CatalogName)
        $PulishedGroups = Get-CtxDeliveryGroup
        $ValidateSetAttribute2 = New-Object System.Management.Automation.ValidateSetAttribute($PulishedGroups.Name)

    # Add the ValidateSet to the attributes collection
        $AttributeCollection1.Add($ValidateSetAttribute1)
        $AttributeCollection2.Add($ValidateSetAttribute2)

    # Create and return the dynamic parameter
        $RuntimeParameter1 = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName1, [string], $AttributeCollection1)
        $RuntimeParameter2 = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName2, [string], $AttributeCollection2)

        $RuntimeParameterDictionary.Add($ParameterName1, $RuntimeParameter1)
        $RuntimeParameterDictionary.Add($ParameterName2, $RuntimeParameter2)
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
            Write-Host "$global:AdminAddress est notre interlocuteur..."

        } Catch {
            Write-Host $NOK -ForegroundColor Red
            Throw $_
        }

        $OuSearchBase = "OU=DeliveryGroups,OU=Citrix,OU=Servers,OU=Computers,OU=contoso,DC=contoso,DC=fr"

    } Process {
        $CatalogName = $PSBoundParameters.CatalogName

        If ($PSBoundParameters.ContainsKey("DeliveryGroupName")) {
            $DeliveryGroupName = $PSBoundParameters.DeliveryGroupName
        }

        Write-Host "MachineCatalogs: $CatalogName"
        Foreach ($Catalog in $CatalogName) {

            Try {
                $BrokerCatalog = Get-BrokerCatalog -CatalogName $Catalog -AdminAddress $AdminAddress

                $DeliveryGroup = Get-BrokerDesktopGroup -DesktopGroupName $DeliveryGroupName -AdminAddress $AdminAddress

                If ([String]::IsNullOrEmpty($BrokerCatalog.ProvisioningSchemeId)) {
                    Throw "Aucun schema de provisionnement associé a ce catalog de machines."

                } Else {
                    Write-Host "Recherche du schema de provisionnement associé: " -NoNewline
                    $Scheme = Get-ProvScheme -ProvisioningSchemeUid $BrokerCatalog.ProvisioningSchemeId -AdminAddress $AdminAddress
                    Write-Host $OK -ForegroundColor Green

                    $IdentityPool = Get-AcctIdentityPool -IdentityPoolName $Scheme.IdentityPoolName -AdminAddress $AdminAddress
                    $IdentityPoolName = $IdentityPool.IdentityPoolName 
                    Try {
                        Write-Host "Recherche de l'OU de destination: " -NoNewline
                        $OU = Get-ADOrganizationalUnit -Identity $($IdentityPool.OU)
                        Write-Host $OK -ForegroundColor Green
                    } Catch {
                        Write-Host $NOK -ForegroundColor Red
                        $SuggestedOU = $(Get-ADOrganizationalUnit -SearchBase $OuSearchBase -Filter "Name -like '*$DeliveryGroup*'" | Select-Object -ExpandProperty DistinguishedName -First 1)
                        Write-Host "l'OU n'existe pas, éxécutez la commande `"Set-AcctIdentityPool -IdentityPoolName $IdentityPoolName -AdminAddress $AdminAddress -OU [NomDistingué]`""                        
                        If ($SuggestedOU) { Write-Host "Genre $SuggestedOU" }
                        Throw "L'OU '$($IdentityPool.OU)' n'éxite pas"
                    }

                    Write-Host "Creation des objets Ordinateur dans Active Directory: " -NoNewline
                    $AdAccount = New-AcctADAccount -IdentityPoolName $IdentityPoolName -Count $Count -AdminAddress $AdminAddress -ErrorAction Stop
                    If ($AdAccount.SuccessfulAccountsCount -eq 0) {
                        Throw "Création de l'object dans l'AD en échec. Avez-vous les droits suffisants ?"
                    } ElseIf ($AdAccount.SuccessfulAccountsCount -lt $Count) {
                        Write-Host "$($AdAccount.SuccessfulAccountsCount)/$Count" -ForegroundColor Yellow
                        Write-Warning "Certaines créations de comptes ont échoué. Investiguez !"
                    } Else {
                        Write-Host $AdAccount.SuccessfulAccountsCount -ForegroundColor Green
                    }
                    Try {
                        Write-Host "Provisionnement des machines virtuelles: " -NoNewline
                        $provVMTaskID = New-ProvVM -ADAccountName $AdAccount.SuccessfulAccounts -ProvisioningSchemeName $IdentityPoolName -AdminAddress $AdminAddress | Select-Object -ExpandProperty TaskId
                
                    # wait for the VMS tp finish Provisioning
                        $ProvTask = Get-ProvTask -TaskID $provVMTaskID -AdminAddress $AdminAddress

                        $jLength = 0
                        While ($provTask.Active) {
                            If ($provTask.TaskProgress -lt 100) {
                                Write-Host ("`b" * $jLength) -NoNewline
                                $jLength = "$($provTask.TaskProgress.Count)".Length
                                Write-Host "$($provTask.TaskProgress.Count)" -NoNewline
                                Start-Sleep 1
                            }
                            $ProvTask = Get-ProvTask -TaskID $provVMTaskID -AdminAddress $AdminAddress
                        }
                        If ($null -ne $ProvTask.TerminatingError) { 
                            Throw $ProvTask.TerminatingError
                        } Else {
                            If ($jLength -gt 0 ) { Write-Host ("`b" * $jLength) -NoNewline }
                            Write-Host $OK -ForegroundColor Green
                        }
                    } Catch {
                        Write-Host "Une erreur a eu lieu durant le provitionnement des machines virtuelles."
                        Try {
                            $FailedAccounts = $AdAccount.SuccessfulAccounts | Remove-AcctADAccount -IdentityPoolName $IdentityPoolName -AdminAddress $AdminAddress -Force -ErrorAction Stop
                        } Catch {
                            Write-Host "La tentative de néttoyage de l'AD a échouée, vérifiez les hôtes suivants:"
                            $FailedAccounts.FailedAccounts | Out-Host
                            Throw $_
                        }

                    }

                    Write-Host "Enregistrement des machines virtuelles: " -NoNewline
                    $($ProvTask.CreatedVirtualMachines) | ForEach-Object { New-BrokerMachine -CatalogUid $($BrokerCatalog.Uid) -MachineName $_.VMName -AdminAddress $AdminAddress | Out-Null }
                    Write-Host $OK -ForegroundColor Green 

                    Write-Host "Ajout des machines virtuelles au groupe $($DeliveryGroup.Name): " -NoNewline
                    $($ProvTask.CreatedVirtualMachines) | ForEach-Object { Add-BrokerMachine -MachineName $($_.ADAccountName.TrimEnd('$')) -DesktopGroup $DeliveryGroup.Name -AdminAddress $AdminAddress }
                    Write-Host $OK -ForegroundColor Green
                }
            } Catch {
                Write-Host $NOK -ForegroundColor Red
                Throw $_
            }
        }
    }

}

Export-ModuleMember Add-CtxMachine