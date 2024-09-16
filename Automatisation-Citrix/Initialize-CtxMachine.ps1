Function Initialize-CtxMachine {
<#
.SYNOPSIS
Initialise la machine dans l'environnement Citrix et vCenter, avec des étapes de destruction et de reprovisionnement si nécessaire.

.DESCRIPTION
La fonction `Initialize-CtxMachine` permet de gérer des machines virtuelles Citrix et vCenter. Elle vérifie la connectivité aux Delivery Controllers et au vCenter, capture les informations de la machine spécifiée, et effectue des opérations comme la destruction ou la recréation du VDI (Virtual Desktop Infrastructure) en fonction des paramètres fournis.

.PARAMETER Name
Le nom de la machine pour laquelle les opérations seront effectuées. C'est le nom d'hôte de la machine Citrix/vCenter.

.PARAMETER DDCs
Liste des Delivery Controllers Citrix à vérifier pour la connectivité. Par défaut, la fonction utilise les adresses 'xendc102.contoso.fr' et 'xendc202.contoso.fr'.

.PARAMETER vCenterServer
Nom du serveur vCenter auquel se connecter. Par défaut, 'pavcenter001.contoso.fr' est utilisé.

.EXAMPLE
Initialize-CtxMachine -Name "VM1234"

Cette commande initialise la machine nommée "VM1234", vérifie sa présence dans Citrix et vCenter, et effectue des opérations de maintenance si nécessaire.

.EXAMPLE
Initialize-CtxMachine -Name "VM1234" -DDCs 'xendc103.contoso.fr' -vCenterServer 'pavcenter002.contoso.fr'

Cette commande spécifie un serveur vCenter et un Delivery Controller Citrix spécifiques pour la machine "VM1234".

.INPUTS
[String]
Le nom de la machine Citrix à gérer et la liste des Delivery Controllers.

.OUTPUTS
Aucune sortie explicite. Les messages d'état s'affichent dans la console, avec des informations sur la progression de chaque étape.

.NOTES
Cette fonction est utilisée pour gérer les machines virtuelles dans un environnement Citrix, avec des connexions à un serveur vCenter. Elle supporte des opérations critiques telles que la destruction et la recréation des machines virtuelles, ainsi que la gestion des comptes Active Directory associés.

La fonction demande confirmation avant de procéder aux étapes destructrices si elle est utilisée avec l'option `ShouldProcess`.

.LINK
https://support.citrix.com/article/CTX286861
#>

    [CmdletBinding(
        SupportsShouldProcess=$true,
        HelpUri = 'https://support.citrix.com/article/CTX286861',
        ConfirmImpact='High'
    )]
    Param (
        [Parameter(Mandatory=$false, HelpMessage='Specify the machine name')]
        [Alias("MachineName")]
        [String]$Name,
            
        [Parameter(Mandatory=$false)]
        [Alias("AdminAddress")]
        [String[]]$DDCs = @('xendc102.contoso.fr', 'xendc202.contoso.fr'),

        [Parameter(Mandatory=$false)]
        [String] $vCenterServer = 'vcenter001.contoso.fr'
    )
    Begin {

        $ErrorActionPreference = 'Stop'

        Try {
        
            If (-not (Get-Module Citrix.Broker.Commands)) {
                Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
                Import-Module Citrix.Broker.Commands
                Write-Host $OK -ForegroundColor Green
            }

            If ($null -eq $global:defaultviserver) {
                Write-Host 'Connexion au vCenter... ' -NoNewline
                $vCenterConnectionParameter = @{
                    Server = $vCenterServer
                }
                If ($PSBoundParameters.ContainsKey('vCenterUser')) {
                    $vCenterConnectionParameter.User = $vCenterUser
                }
                $vCenterConnection = Connect-VIServer @vCenterConnectionParameter
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
            Write-Host 'NOK' -ForegroundColor Red
            Throw $_
        }
        
        $OuSearchBase = "OU=DeliveryGroups,OU=Citrix,OU=Servers,OU=Computers,OU=Boursorama,DC=boursorama,DC=fr"

    } Process {

        Try {
            
            Write-Host "Capture des informations relatives à la machine ${Name}: " -NoNewline
            $Machine = Get-BrokerMachine -HostedMachineName $Name -AdminAddress $AdminAddress
            $ADAccount = Get-AcctADAccount -AdminAddress $AdminAddress | Where-Object ADAccountName -Match "^.*\\$Name.$"
            If ($null -ne $Machine) {
                $DeliveryGroup = Get-BrokerDesktopGroup -DesktopGroupName $Machine.DesktopGroupName -AdminAddress $AdminAddress
                $Catalog = Get-BrokerCatalog -CatalogName $Machine.CatalogName -AdminAddress $AdminAddress
                $Scheme = Get-ProvScheme -ProvisioningSchemeUid $Catalog.ProvisioningSchemeId -AdminAddress $AdminAddress
                $IdentityPoolName = $Scheme.IdentityPoolName
                Write-Host $OK -ForegroundColor Green
            } Else {
                Write-Host $WARN -ForegroundColor Yellow
                Write-Host "La machine $name est introuvable coté citrix" -NoNewline

                $VM = VMware.VimAutomation.Core\Get-VM $Name -ErrorAction SilentlyContinue
                If ($null -ne $VM) {
                    Write-Host " mais elle à été trouvée coté hyperviseur."
                } Else {
                    Write-Host ", pas plus que du coté hyperviseur."
                }

                $SupposedNamingScheme = $Name -replace "(\w*\d{1})\d{2}", "`$1"
                $SupposedIdentityPool = Get-AcctIdentityPool | Where-Object NamingScheme -match "^${SupposedNamingScheme}##"
                If ($null -ne $SupposedIdentityPool) {
                    Write-Host "En me basant sur le nom de la machine, je suppose que le nom du pool d'identité est: " -NoNewline
                    $IdentityPoolName = $SupposedIdentityPool.IdentityPoolName
                    Write-Host $IdentityPoolName -ForegroundColor Green
                    
                    $Scheme = Get-ProvScheme  -AdminAddress $AdminAddress | Where-Object IdentityPoolName -eq $IdentityPoolName
                    $Catalog = Get-BrokerCatalog -ProvisioningSchemeId $Scheme.ProvisioningSchemeUid -AdminAddress $AdminAddress
                    $DeliveryGroupName = Get-BrokerMachine -CatalogName $Catalog.CatalogName -AdminAddress $AdminAddress | Select-Object -ExpandProperty DesktopGroupName -Unique
                    If ($DeliveryGroupName.Count -eq 1) {
                        $DeliveryGroup = Get-BrokerDesktopGroup -Name $DeliveryGroupName
                    } Elseif ($DeliveryGroupName.Count -gt 1) {
                        Throw "$($Catalog.CatalogName) se trouve dans plusieurs delivery group. Il est non conforme."
                    } Else {
                        Throw "Je ne peux pas déduire le delivery group à utiliser car le $($Catalog.CatalogName) ne semble contenir aucune machine."
                    }
                } Else {
                    throw "Je ne peux pas identifier le nom du pool d'identité, une intervention manuelle est nécessaire."
                }
            }
            
            If ($PSCmdlet.ShouldProcess("$Name","Destruction du VDI ?")) {
                If ($Machine) {
                    Write-Host "Vérification de l'état de la machine virtuelle: " -NoNewline
                    If (-not $Machine.InMaintenanceMode -and $Machine.PowerState -ne "On") { Throw "La machine se doit d'être en maintenance ou éteinte pour continuer" }
                    Write-Host $OK -ForegroundColor Green

                    Write-Host "`n- Phase de destruction -" -ForegroundColor Red
                    If ($null -ne $Machine.DesktopGroupName) {
                        Write-Host "Retrait de la machine de son delivery group: " -NoNewline
                        $Machine | Remove-BrokerMachine -DesktopGroup $Machine.DesktopGroupName -Force -AdminAddress $AdminAddress
                        Write-Host $OK -ForegroundColor Green
                    }
                    
                    Write-Host "Retrait de la machine du machine catalog: " -NoNewline
                    Get-BrokerMachine $Machine.MachineName -AdminAddress $AdminAddress | Remove-BrokerMachine -AdminAddress $AdminAddress
                    Write-Host $OK -ForegroundColor Green
                }

                $ProvVM = Get-ProvVM -VMName $Name -AdminAddress $AdminAddress
                If ($ProvVM.Lock) {
                    Write-Host "Déverrouillage de la machine: " -NoNewline
                    $ProvVM | Unlock-ProvVM -AdminAddress $AdminAddress
                    Write-Host $OK -ForegroundColor Green
                }

                If ($null -ne $ProvVM.VMName) {
                    Write-Host "Suppression de la machine virtuelle: " -NoNewline
                    $DeleteVMResult = $ProvVM | Remove-ProvVM -AdminAddress $AdminAddress
                    If ($DeleteVMResult.TaskState -eq 'Finished') {
                        Write-Host $OK -ForegroundColor Green
                    } Else { Write-Host $NOK -ForegroundColor Red }
                }

                $VM = VMware.VimAutomation.Core\Get-VM $Name -ErrorAction SilentlyContinue
                If ($null -ne $VM) {
                    Write-Host "Supression de la machine virtelle depuis l'hyperviseur: " -NoNewline
                    If ($VM.PowerState -eq "PoweredOn") { 
                        VMware.VimAutomation.Core\Stop-VM -VM $VM -Kill -Confirm:$false
                        Start-Sleep 5
                    }
                    
                    VMware.VimAutomation.Core\Remove-VM $VM -DeletePermanently -Confirm:$false | Out-Null
                    Write-Host $OK -ForegroundColor Green
                } 

                If ($null -ne $ADAccount) {
                    Write-Host "Suppression de l'object Active Directory: " -NoNewline
                    $RemoveResult = Remove-AcctADAccount -ADAccountName $ADAccount.ADAccountName -IdentityPoolName $IdentityPoolName -RemovalOption "delete"
                    If ($RemoveResult.FailedAccountsCount -eq 0) { Write-Host $OK -ForegroundColor Green }
                    Else { Write-Host $NOK -ForegroundColor Red }
                }
            }
            If ($PSCmdlet.ShouldProcess("$Name","Reconstruction du VDI ?")) {

                Write-Host "`n- Phase de provisionement -" -ForegroundColor Green

                Write-Host "Capture du start count actuel: " -NoNewline
                $IdentityPool = Get-AcctIdentityPool -IdentityPoolName $IdentityPoolName -AdminAddress $AdminAddress
                $CurrentStartCount = $IdentityPool.StartCount
                $TempStartCount = $Name -replace ".*(\d{2})$", "`$1" 
                Write-Host $TempStartCount -ForegroundColor Green

                Try {
                    Write-Host "Recherche de l'OU de destination: " -NoNewline
                    $OU = Get-ADOrganizationalUnit -Identity $($IdentityPool.OU)
                    $OU.DistinguishedName
                } Catch {
                    $SuggestedOU = $(Get-ADOrganizationalUnit -SearchBase $OuSearchBase -Filter "Name -like '*$($DeliveryGroup.Name)*'" | Select-Object -ExpandProperty DistinguishedName -First 1)
                    Write-Host "l'OU n'existe pas, éxécutez la commande `"Set-AcctIdentityPool -IdentityPoolName $IdentityPoolName -AdminAddress $AdminAddress -OU [NomDistingué]`""                        
                    If ($SuggestedOU) { Write-Host "Genre $SuggestedOU" }
                    Throw "L'OU '$($IdentityPool.OU)' n'éxite pas"
                }

                Write-Host "Modification temporaire du start count $CurrentStartCount -> ${TempStartCount}: " -NoNewline
                Set-AcctIdentityPool -IdentityPoolName $IdentityPool.IdentityPoolName -StartCount $TempStartCount
                Write-Host $OK -ForegroundColor Green

                Write-Host "Creation de l'objet Ordinateur dans Active Directory: " -NoNewline
                $AdAccount = New-AcctADAccount -IdentityPoolName $IdentityPoolName -Count 1 -AdminAddress $AdminAddress -ErrorAction Stop
                If ($AdAccount.SuccessfulAccountsCount -eq 0) {
                    Throw "Création de l'object dans l'AD en échec. Avez-vous les droits suffisants ?"
                } ElseIf ($AdAccount.SuccessfulAccountsCount -lt $Count) {
                    Write-Host "$($AdAccount.SuccessfulAccountsCount)/$Count" -ForegroundColor Yellow
                    Write-Warning "La création de comptes a échouée. Investiguez !"
                } Else {
                    Write-Host $AdAccount.SuccessfulAccounts.ADAccountName -ForegroundColor Green
                    $accountPart = $AdAccount.SuccessfulAccounts.ADAccountName -replace '.*\\(.*)\$', '$1'
                    If ($Name -notmatch ([regex]::escape($accountPart))) {
                        Write-Host "Attention le nom fourni lors de la création de l'objet ne correspond pas à la valeur attendue." -ForegroundColor Yellow
                        Write-Host "Cela peut se produire si la suppression précédente prend du temps." -ForegroundColor Yellow
                    }
                }

                Write-Host "Provisionnement de la machine virtuelle: " -NoNewline
                $provVMTaskID = New-ProvVM -ADAccountName $AdAccount.SuccessfulAccounts -ProvisioningSchemeName $IdentityPoolName -AdminAddress $AdminAddress | Select-Object -ExpandProperty TaskId

            # wait for the VMS tp finish Provisioning
                $ProvTask = Get-ProvTask -TaskID $provVMTaskID -AdminAddress $AdminAddress

                $jLength = 0
                While ($provTask.Active) {
                    If ($provTask.TaskProgress -lt $100) {
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
                    If ($iLength -gt 0 ) { Write-Host ("`b" * $iLength) -NoNewline }
                    Write-Host $OK -ForegroundColor Green
                }

                Write-Host "Enregistrement de la machine virtuelle: " -NoNewline
                $($ProvTask.CreatedVirtualMachines) | Foreach { New-BrokerMachine -CatalogUid $($Catalog.Uid) -MachineName $_.VMName -AdminAddress $AdminAddress | Out-Null }
                Write-Host $OK -ForegroundColor Green 

                Write-Host "Ajout de la machine virtuelle au groupe $($DeliveryGroup.Name)`: " -NoNewline
                $($AdAccount.SuccessfulAccounts) | ForEach-Object { Add-BrokerMachine -MachineName $($_.ADAccountName.TrimEnd('$')) -DesktopGroup $DeliveryGroup.Name -AdminAddress $AdminAddress }
                Write-Host $OK -ForegroundColor Green

                Write-Host "Restauration du start count à ${CurrentStartCount}: " -NoNewline
                Set-AcctIdentityPool -IdentityPoolName $IdentityPool.IdentityPoolName -StartCount $CurrentStartCount
                Write-Host $OK -ForegroundColor Green
            }

        } Catch {
            Write-Host $NOK -ForegroundColor Red
            Throw $_

        }
    }
}

Export-ModuleMember Initialize-CtxMachine