Function New-CtxMachineCatalog {

    <#
    .SYNOPSIS
        Créer un Machine Catalog dans Citrix XenDesktop à l'aide de PowerShell.

    .DESCRIPTION
        Cette fonction permet de créer un Machine Catalog dans Citrix XenDesktop en utilisant PowerShell. Elle prend en charge divers paramètres pour personnaliser le processus de création du Catalogue, notamment le nom du Catalogue, le nom de l'unité d'hébergement, le nom de l'image maître, le schéma de dénomination des VDAs, le nombre de machines à inclure dans le Catalogue, les contrôleurs de livraison Citrix, etc.

    .PARAMETER CatalogName
        Le nom du Catalogue de Machines à créer.

    .PARAMETER HostingName
        Le nom de l'unité d'hébergement où se trouve l'image maître.

    .PARAMETER MasterVM
        Le nom de l'image maître à utiliser pour créer les machines virtuelles.

    .PARAMETER NamingScheme
        Le schéma de dénomination des machines virtuelles.

    .PARAMETER Count
        Le nombre de machines à inclure dans le Catalogue. Par défaut, il est défini sur 1.

    .PARAMETER DDCs
        La liste des contrôleurs de livraison Citrix à utiliser.

    .EXAMPLE
        New-CtxMachineCatalog -CatalogName "MonCatalogue" -HostingName "MonHébergement" -MasterVM "MonImageMaître" -Count 5 -DDCs @("xendc102.contoso.fr", "xendc202.contoso.fr")

        Crée un Machine Catalog nommé "MonCatalogue" avec l'image maître "MonImageMaître" sur l'unité d'hébergement "MonHébergement". Il crée 5 machines virtuelles et les associe aux contrôleurs de livraison "xendc001.contoso.fr" et "xendc002.contoso.fr".

    .NOTES
        Auteur: Mickael Roy
        Date de création: 30/04/2024
        Dernière modification: 30/04/2024

    .LINK
    Lien vers la documentation Citrix PowerShell : https://www.citrix.com/blogs/2012/03/06/using-powershell-to-create-a-catalog-of-machine-creations-services-machines/
    Lien vers la page confluence : https://confluence.contoso.com/x/wA_aLQ

#>

    [CmdletBinding(
        SupportsShouldProcess=$true,
        HelpUri = 'https://www.citrix.com/blogs/2012/03/06/using-powershell-to-create-a-catalog-of-machine-creations-services-machines/',
        ConfirmImpact='High'
    )]

    Param (
        [Parameter(Mandatory=$true)]
        [Alias("BrokerCatalog", "MachineCatalog")]
        [String]$CatalogName,

        [Parameter(Mandatory=$true)]
        [Alias("MasterImage")]
        [String]$MasterVM,

        [Parameter(Mandatory=$false)]
        [String]$NamingScheme,

        [Parameter(Mandatory=$false)]
        [Int]$Count = 1,

        [Parameter(Mandatory=$false)]
        [Alias("AdminAddress")]
        [String[]]$DDCs = @('xenddc101.contoso.fr', 'xenddc201.contoso.fr')
    )
    DynamicParam {
        $ParameterName2 = "HostingName"

        # Create the dictionary 
        $RuntimeParameterDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()

        # Create the collection of attributes
        $AttributeCollection2 = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()

        $ParameterAttribute2 = [System.Management.Automation.ParameterAttribute]::new()
        $ParameterAttribute2.Mandatory = $true
        $ParameterAttribute2.Position = 2
        $AttributeCollection2.Add($ParameterAttribute2)

        # Create and add alias attributes
        $AttributeCollection2.Add([System.Management.Automation.AliasAttribute]::new("HostingUnit"))

        # Generate and set the ValidateSet
        $Hostings = Get-CtxHostingUnit
        if ($Hostings) {
            $ValidateSetAttribute2 = New-Object System.Management.Automation.ValidateSetAttribute($Hostings.HostingUnitName)
        # Add the ValidateSet to the attributes collection
            $AttributeCollection2.Add($ValidateSetAttribute2)
        }

        # Create and return the dynamic parameters
        $RuntimeParameter2 = [System.Management.Automation.RuntimeDefinedParameter]::new($ParameterName2, [string[]], $AttributeCollection2)
        $RuntimeParameterDictionary.Add($ParameterName2, $RuntimeParameter2)
        return $RuntimeParameterDictionary
    }

    Begin {
        $ErrorActionPreference = 'Stop'

        # Retrieve the value of the dynamic parameter
        $HostingName = $PSBoundParameters['HostingName']

        $OuSearchBase = "OU=DeliveryGroups,OU=Citrix,OU=Servers,OU=Computers,OU=contoso,DC=contoso,DC=fr"
   
        Try {
        
            If (-not (Get-Module Citrix.Broker.Commands)) {
                Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
                Import-Module Citrix.Broker.Commands
                Write-Host "$OK" -ForegroundColor Green
            }
       
            If ($null -eq $global:AdminAddress) {
                Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
                $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-TcpPort -Port 80 | Select-Object ComputerName,TcpTestSucceeded
                If ((!$ConnectionTes1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun delivery controllers n'est joignable." }
                Write-Host "$OK" -ForegroundColor Green

                $global:AdminAddress = $ConnectionTest1, $ConnectionTest2 | Where-Object TcpTestSucceeded | Get-Random | Select-Object -ExpandProperty ComputerName
                Set-HypAdminConnection -AdminAddress $global:AdminAddress
            }
            Write-Host "$global:AdminAddress est notre interlocuteur..."
        } Catch {

            Write-Host "$NOK" -ForegroundColor Red
            Throw $_
        }
    } Process {

        Try {

            Write-Host "Verification de la disponibilité du Machine Catalog: " -NoNewline
            $CatalogExists = (-not $null -eq (Get-BrokerCatalog -Name $CatalogName -AdminAddress $AdminAddress -ErrorAction SilentlyContinue))
            If ($CatalogExists) { Throw "Ce machine catalog existe déjà." }
            Else { Write-Host "$OK" -ForegroundColor Green }

            Write-Host "Verification de la disponibilité du Provisioning Scheme: " -NoNewline
            If (-not (Test-ProvSchemeNameAvailable -ProvisioningSchemeName $CatalogName).Available) {
                Throw "Ce Provisioning Scheme existe déjà." }
            Else { Write-Host "$OK" -ForegroundColor Green }

            Write-Host "Verification de la disponibilité du Pool d'identité: " -NoNewline
            $IdentityPoolExists = (-not $null -eq (Get-AcctIdentityPool -IdentityPoolName $CatalogName -AdminAddress $AdminAddress -ErrorAction SilentlyContinue))
            If ($IdentityPoolExists) { Throw "Ce Pool d'identité existe déjà." }
            Else { Write-Host "$OK" -ForegroundColor Green }

            Write-Host "Recherche de la VM dans les resources virtuelles: " -NoNewline
            $HostingUnitPath = Get-Item "XDHyp:\HostingUnits\$HostingName"
            $VmPath = "$($HostingUnitPath.PSPath)\${MasterVM}.vm"

            $VmPathExists = (Test-Path $VmPath)
            If (-not $VmPathExists) { Throw "Le Golden Image n'est pas accessible depuis ce hosting ($HostingName)."}
            Else { Write-Host "$OK" -ForegroundColor Green }

            Write-Host "Création du machine catalog: " -NoNewline
            $numVMsToCreate = $Count
            $hostConnection = $HostingUnitPath.hypervisorConnection
            $brokerHypConnection = Get-BrokerHypervisorConnection -AdminAddress $AdminAddress -HypHypervisorConnectionUid $hostConnection.HypervisorConnectionUid

            $Catalog = New-BrokerCatalog -Name $CatalogName -AllocationType Random -ProvisioningType MCS -AdminAddress $AdminAddress -MinimumFunctionalLevel LMAX -PersistUserChanges Discard -SessionSupport MultiSession
            Write-Host "$OK" -ForegroundColor Green

            If ([String]$MasterVM[0] -eq [String]$NamingScheme[0]) {
                $dname = (Get-ADComputer $MasterVM).DistinguishedName
                $OU = $dname.Split(',',2)[1]
            } Else {
                If ($CatalogName -match ".*(PRD|HPRD)$") {
                    Write-Host "Risque d'erreur sur l'OU de destination." -ForegroundColor Yellow

                    $SuggestedOUs = Get-ADOrganizationalUnit -SearchBase $OuSearchBase -Filter "Name -like '*$($CatalogName.Split("_")[-2] )*'" | Select-Object -ExpandProperty DistinguishedName
                    $SuggestedOUs = Switch -Regex ($NamingScheme) {
                        "^p.*" { $SuggestedOUs -match "PRD" }
                        default { $SuggestedOUs -match "HPRD" }
                    }
                } Else {
                    $SuggestedOUs = Get-ADOrganizationalUnit -SearchBase $OuSearchBase -Filter "Name -like '*'" | Select-Object -ExpandProperty DistinguishedName
                }

                If ($SuggestedOUs.count -gt 1) {
                    $OU = Show-InteractiveMenu -Title "Choisissez une option :" -Options $SuggestedOUs
                } Else {
                    $OU = $SuggestedOUs
                }
            }
            $OU
            $Domain = (Get-ADDomain).DNSRoot

            Write-Host "Création du Identity Pool: " -NoNewline
            $adPool = New-AcctIdentityPool -IdentityPoolName $CatalogName -NamingScheme $($NamingScheme.ToLower()) -NamingSchemeType Numeric -OU $OU -Domain $Domain -AllowUnicode -AdminAddress $AdminAddress
            Write-Host "$OK" -ForegroundColor Green
        
            Write-Host "Création du snapshot: " -NoNewline
            $ConfDataForVM = Get-HypConfigurationDataForItem -LiteralPath $VmPath
            $NewSnapshotName = "Citrix_XD_New_Catalog_$([DateTime]::Now.ToString("yyyy-MM-dd"))"
            $Snap = New-HypVMSnapshot -AdminAddress $AdminAddress -LiteralPath $VmPath -SnapshotName $NewSnapshotName -SnapshotDescription $NewSnapshotDescription
            Write-Host "$OK" -ForegroundColor Green

            Write-Host "Création schéma de provisionnement: " -NoNewline
            $provSchemeTaskID = New-ProvScheme -ProvisioningSchemeName $CatalogName -HostingUnitUID $HostingUnitPath.HostingUnitUID -IdentityPoolUID $adpool.IdentityPoolUid -VMCpuCount $ConfDataForVM.CpuCount -VMMemoryMB $ConfDataForVM.MemoryMB -CleanOnBoot -MasterImageVM $Snap -RunAsynchronously -AdminAddress $AdminAddress
            
            $ProvTask = Get-ProvTask -TaskID $provSchemeTaskID -AdminAddress $AdminAddress
            [int]$ProgressTask = $ProvTask.TaskProgress
            $iLength = "${ProgressTask}%".Length
            Write-Host "${ProgressTask}%" -NoNewline

            While ($provTask.Active) {
                If ($ProgressTask -le 100) {
                    Write-Host ("`b" * $iLength) -NoNewline
                    $iLength = "${ProgressTask}%".Length
                    Write-Host "${ProgressTask}%" -NoNewline
                }
                Start-Sleep 10
                $ProvTask = Get-ProvTask -TaskID $provSchemeTaskID -AdminAddress $AdminAddress
                [int]$ProgressTask = $ProvTask.TaskProgress
            }
            If ($null -ne $ProvTask.TerminatingError) { 
                Throw $ProvTask.TerminatingError
            } Else {
                If ($iLength -gt 0) { Write-Host ("`b" * $iLength) -NoNewline }
                Write-Host "${ProgressTask}%" -ForegroundColor Green
            }

            Write-Host "Ajout des Delivery Controllers au schéma de provisionnement: " -NoNewline
            $provScheme = Get-ProvScheme -ProvisioningSchemeUID $ProvTask.ProvisioningSchemeUid
            $DDCs.ForEach({
                If ($_ -notin $provScheme.ControllerAddress) { Add-ProvSchemeControllerAddress -ProvisioningSchemeUID $provScheme.ProvisioningSchemeUID -ControllerAddress $_ | Out-null }
            })
            Write-Host "$OK" -ForegroundColor Green

            Write-Host "Création des comptes ordinateurs: " -NoNewline
            $accts = New-AcctADAccount -IdentityPoolUid $adPool.IdentityPoolUid -Count $numVMsToCreate -AdminAddress $AdminAddress
            Write-Host "$OK" -ForegroundColor Green

            Write-Host "Provisionnement des machines virtuelles $($provVMTaskID.Guid): " -NoNewline
            $provVMTaskID = New-ProvVM -ProvisioningSchemeUID $provScheme.ProvisioningSchemeUID -ADAccountName $accts.SuccessfulAccounts -RunAsynchronously -AdminAddress $AdminAddress

            # wait for the VMS tp finish Provisioning
            $ProvTask = Get-ProvTask -TaskID $provVMTaskID -AdminAddress $adminAddress

            $jLength = 0

            While (($provTask.Active) -or ($provTask.TaskProgress -le 99)) {
                If ($provTask.CreatedVirtualMachines.Count -le $numVMsToCreate) {
                    Write-Host ("`b" * $jLength) -NoNewline
                    $jLength = "$($provTask.CreatedVirtualMachines.Count)".Length
                    Write-Host "$($provTask.CreatedVirtualMachines.Count)" -NoNewline
                    Start-Sleep 1
                }
                $ProvTask = Get-ProvTask -TaskID $provVMTaskID -AdminAddress $AdminAddress
            }
            If ($null -ne $ProvTask.TerminatingError) { 
                Throw $ProvTask.TerminatingError
            } Else {
                If ($iLength -gt 0) { Write-Host ("`b" * $iLength) -NoNewline }
                Write-Host "$OK" -ForegroundColor Green
            }
                   
            Write-Host "Affectation du schema de provisonnement au Machine Catalog: " -NoNewline
            Set-BrokerCatalog -Name $catalog.Name -ProvisioningSchemeId $provScheme.ProvisioningSchemeUID -AdminAddress $AdminAddress
            Write-Host "$OK" -ForegroundColor Green

            # Lock the VMs and add them to the broker Catalog
            Write-Host "Ajout des machines dans le Machine Catalog: "  -NoNewline
            $provisionedVMs = Get-ProvVM -ProvisioningSchemeUID $provScheme.ProvisioningSchemeUID -AdminAddress $AdminAddress
            $provisionedVMs | Lock-ProvVM -ProvisioningSchemeUID $provScheme.ProvisioningSchemeUID -Tag Brokered -AdminAddress $AdminAddress
            $provisionedVMs | ForEach-Object { New-BrokerMachine  -CatalogUid $catalog.UID -HostedMachineId $_.VMId -HypervisorConnectionUid $brokerHypConnection.UID -MachineName $_.ADAccountSid -AdminAddress $AdminAddress | Out-Null}
            Write-Host "$OK" -ForegroundColor Green

            If ($PSCmdlet.ShouldProcess("$CatalogName","Publication de l'image $MasterVM ?")) {
                Write-Host "Invocation de la publication... " -NoNewLine
                $PubTask = Publish-ProvMasterVmImage -AdminAddress $AdminAddress -MasterImageVM $Snap -ProvisioningSchemeUid $provScheme.ProvisioningSchemeUID -RunAsynchronously
                Write-Host "$OK" -ForegroundColor Green
            }
            Return $PubTask

        } Catch {

            Write-Host "$NOK" -ForegroundColor Red
            Throw $_
        }
    }
}

Export-ModuleMember New-CtxMachineCatalog