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
            [Alias("HostingUnit")]
            [String]$HostingName,

            [Parameter(Mandatory=$true)]
            [Alias("MasterImage")]
            [String]$MasterVM,

            [Parameter(Mandatory=$false)]
            [String]$NamingScheme,

            [Parameter(Mandatory=$false)]
            [Int]$Count = 1,

            [Parameter(Mandatory=$false)]
            [Alias("AdminAddress")]
            [String[]]$DDCs = @('xendc102.contoso.fr', 'xendc202.contoso.fr')
        )


    $ErrorActionPreference = 'Stop'

    Function New-NamingScheme {
        Param ( $CatalogName )
        # This function is a sample, enter you own code to presume the Naming Scheme automatically.
        $TriGram = $CatalogName.Split("_")[4]
        [Int]$SiteNum = If (($CatalogName.Split("_")[1]) -eq 'CLY') { 2 }
        ElseIf (($CatalogName.Split("_")[1]) -eq 'CLG') { 1 }
        Else { Throw "Le Machine Catalog ne contient ni CLY ni CLG." }
        $NamingScheme = "pwxa" + $TriGram + $SiteNum + "##"
        Return $NamingScheme.ToLower()
    }

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
  
        Write-Host "Verification de la disponibilité du Machine Catalog: " -NoNewline
        $CatalogExists = (-not $null -eq (Get-BrokerCatalog -Name $CatalogName -AdminAddress $AdminAddress -ErrorAction SilentlyContinue))
        If ($CatalogExists) { Throw "Ce machine catalog existe déjà." }
        Else { Write-Host "OK" -ForegroundColor Green }

        Write-Host "Recherche de la VM dans les resources virtuelles: " -NoNewline
        $HostingUnitPath = Get-Item "XDHyp:\HostingUnits\$HostingName"
        $VmPath = "$($HostingUnitPath.PSPath)\$MasterVM`.vm"

        $VmPathExists = (Test-Path $VmPath)
        If (-not $VmPathExists) { Throw "Le Golden Image n'est pas accessible depuis ce hosting."}
        Else { Write-Host "OK" -ForegroundColor Green }

        Write-Host "Création du machine catalog: " -NoNewline
        $numVMsToCreate = $Count
        $hostConnection = $HostingUnitPath.hypervisorConnection
        $brokerHypConnection = Get-BrokerHypervisorConnection -AdminAddress $AdminAddress -HypHypervisorConnectionUid $hostConnection.HypervisorConnectionUid

        $catalog = New-BrokerCatalog -Name $CatalogName -AllocationType Random -ProvisioningType MCS -AdminAddress $AdminAddress -MinimumFunctionalLevel LMAX -PersistUserChanges Discard -SessionSupport MultiSession
        Write-Host "OK" -ForegroundColor Green

        If ([String]::IsNullOrEmpty($NamingScheme)) {
            Write-Host "Définition du préfix: " -NoNewline
            $NamingScheme = New-NamingScheme -CatalogName $CatalogName -AdminAddress $AdminAddress
            Write-Host " $($NamingScheme.ToLower())" -ForegroundColor Green
        } Else { Write-Host "Vous avec spécifié un préfix tel que: $($NamingScheme.ToLower())" }

        $dname = (Get-ADComputer $MasterVM).DistinguishedName
        $OU = $dname.split(',',2)[1]

        $Domain = (Get-ADDomain).DNSRoot

        Write-Host "Création du Identity Pool: " -NoNewline
        $adPool = New-AcctIdentityPool -IdentityPoolName $CatalogName -NamingScheme $($NamingScheme.ToLower()) -NamingSchemeType Numeric -OU $OU -Domain $Domain -AllowUnicode -AdminAddress $AdminAddress
        Write-Host "OK" -ForegroundColor Green
        
        Write-Host "Création du snapshot: " -NoNewline
        $ConfDataForVM = Get-HypConfigurationDataForItem -LiteralPath $VmPath
        $NewSnapshotName = "Citrix_XD_Automated_Deployement_$([DateTime]::Now.ToString("yyyy-MM-dd"))"
        $Snap = New-HypVMSnapshot -AdminAddress $AdminAddress -LiteralPath $VmPath -SnapshotName $NewSnapshotName -SnapshotDescription $NewSnapshotDescription
        Write-Host "OK" -ForegroundColor Green

        Write-Host "Création schéma de provisionnement: " -NoNewline
        If ((Test-ProvSchemeNameAvailable -ProvisioningSchemeName $CatalogName).Available) {
            $provSchemeTaskID = New-ProvScheme -ProvisioningSchemeName $CatalogName -HostingUnitUID $HostingUnitPath.HostingUnitUID -IdentityPoolUID $adpool.IdentityPoolUid -VMCpuCount $ConfDataForVM.CpuCount -VMMemoryMB $ConfDataForVM.MemoryMB -CleanOnBoot -MasterImageVM $Snap -RunAsynchronously -AdminAddress $AdminAddress
        } Else {
            Throw "Nom du Schéma de provisionnement indisponible."
        }
        $ProvTask = Get-ProvTask -TaskID $provSchemeTaskID -AdminAddress $AdminAddress
        $iLength = 0
        While ($provTask.Active){
            If ($provTask.TaskProgress -le 100){
                Write-Host ("`b" * $iLength) -NoNewline
                $iLength = "$($provTask.TaskProgress)%".Length
                Write-Host "$($provTask.TaskProgress)`%" -NoNewline
            }
            $ProvTask = Get-ProvTask -TaskID $provSchemeTaskID -AdminAddress $AdminAddress
            Start-Sleep 1
            
        }
        If ($null -ne $ProvTask.TerminatingError) { 
            Throw $ProvTask.TerminatingError
        } Else {
            If ($iLength -gt 0 ) { Write-Host ("`b" * $iLength) -NoNewline }
            Write-Host "OK" -ForegroundColor Green
        }

        Write-Host "Ajout des Delivery Controllers au schéma de provisionnement: " -NoNewline
        $provScheme = Get-ProvScheme -ProvisioningSchemeUID $ProvTask.ProvisioningSchemeUid
        $DDCs.ForEach({
            If ($_ -notin $provScheme.ControllerAddress ) { Add-ProvSchemeControllerAddress -ProvisioningSchemeUID $provScheme.ProvisioningSchemeUID -ControllerAddress $_ | Out-null}
        })
        Write-Host "OK" -ForegroundColor Green

        Write-Host "Création des comptes ordinateurs: " -NoNewline
        $accts = New-AcctADAccount -IdentityPoolUid $adPool.IdentityPoolUid -Count $numVMsToCreate -AdminAddress $AdminAddress
        Write-Host "OK" -ForegroundColor Green

        Write-Host "Provisionnement des machines virtuelles: " -NoNewline
        $provVMTaskID = New-ProvVM -ProvisioningSchemeUID $provScheme.ProvisioningSchemeUID -ADAccountName $accts.SuccessfulAccounts -RunAsynchronously -AdminAddress $AdminAddress
        # wait for the VMS tp finish Provisioning
        $ProvTask = Get-ProvTask -TaskID $provVMTaskID -AdminAddress $adminAddress

        $jLength = 0
        While (($provTask.Active) -or ($provTask.TaskProgress -gt 99)) {
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
            If ($iLength -gt 0 ) { Write-Host ("`b" * $iLength) -NoNewline }
            Write-Host "OK" -ForegroundColor Green
        }
                   
        Write-Host "Affectation du schema de provisonnement au Machine Catalog: " -NoNewline
        Set-BrokerCatalog -Name $catalog.Name -ProvisioningSchemeId $provScheme.ProvisioningSchemeUID -AdminAddress $AdminAddress
        Write-Host "OK" -ForegroundColor Green

        # Lock the VMs and add them to the broker Catalog
        Write-Host "Ajout des machines dans le Machine Catalog: "
        $provisionedVMs = Get-ProvVM -ProvisioningSchemeUID $provScheme.ProvisioningSchemeUID -AdminAddress $AdminAddress
        $provisionedVMs | Lock-ProvVM -ProvisioningSchemeUID $provScheme.ProvisioningSchemeUID -Tag Brokered -AdminAddress $AdminAddress
        $provisionedVMs | ForEach-Object { New-BrokerMachine  -CatalogUid $catalog.UID -HostedMachineId $_.VMId -HypervisorConnectionUid $brokerHypConnection.UID -MachineName $_.ADAccountSid -AdminAddress $AdminAddress | Out-Null}
        Write-Host "OK" -ForegroundColor Green

        If ($PSCmdlet.ShouldProcess("$CatalogName","Publication de l'image $MasterVM ?")) {
            Write-Host "Invocation de la publication... " -NoNewLine
            $PubTask = Publish-ProvMasterVmImage -AdminAddress $AdminAddress -MasterImageVM $Snap -ProvisioningSchemeUid $provScheme.ProvisioningSchemeUID -RunAsynchronously
            Write-Host 'OK' -ForegroundColor Green
        }
        Return $PubTask

    } Catch {

        Write-Host 'NOK' -ForegroundColor Red
        Throw $_
    }

}

Export-ModuleMember New-CtxMachineCatalog