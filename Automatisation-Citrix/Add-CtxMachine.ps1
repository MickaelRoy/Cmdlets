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
        (Facultatif) Spécifie les contrôleurs de domaine à utiliser pour la connexion. Par défaut, utilise les contrôleurs de domaine 'xendc001.contoso.fr' et 'xendc002.contoso.fr'.

    .EXAMPLE
        Add-CtxMachine -CatalogName "MyMachineCatalog" -DeliveryGroup "MyDeliveryGroup"

        Cette commande ajoute des machines au catalogue "MyMachineCatalog" et les associe au groupe de livraison "MyDeliveryGroup".

    .NOTES
        Auteur: Mickael Roy
        Site Web: www.lanaconsulting.fr
        Date de création: 30/04/2024
        Dernière modification: 30/04/2024

    .LINKS
        Lien vers la page Citrix : https://support.citrix.com/article/CTX550420

#>

    [CmdletBinding(HelpUri = 'https://support.citrix.com/article/CTX550420')]
    Param (
        [Parameter(Mandatory=$true, HelpMessage='Specify the machine catalog name')]
        [Alias("BrokerCatalog", "MachineCatalog")]
        [String]$CatalogName,

        [Parameter(Mandatory=$true, HelpMessage='Specify the delivery group name')]
        [Alias("DesktopGroupName")]
        [String]$DeliveryGroup,

        [Parameter(Mandatory=$true, HelpMessage='Specify the count of machine to generate')]
        [Int]$Count = 1,
            
        [Parameter(Mandatory=$false)]
        [String[]]$DDCs = @('xendc001.contoso.fr', 'xendc002.contoso.fr')
    )

    $ErrorActionPreference = 'Stop'

    Try {
        $Catalog = Get-BrokerCatalog -CatalogName $CatalogName -AdminAddress $AdminAddress
        $DeliveryGroup = Get-BrokerDesktopGroup -DesktopGroupName $DeliveryGroup -AdminAddress $AdminAddress

        If ([String]::IsNullOrEmpty($Catalog.ProvisioningSchemeId)) {
            Throw "Aucun schema de provisionnement associé a ce catalog de machines."

        } Else {
            Write-Host "Recherche du schema de provisionnement associé: " -NoNewline
            $Scheme = Get-ProvScheme -ProvisioningSchemeUid $Catalog.ProvisioningSchemeId -AdminAddress $AdminAddress
            Write-Host 'OK' -ForegroundColor Green

            Write-Host "Creation des objets Ordinateur dans Active Directory: " -NoNewline
            $AdAccount = New-AcctADAccount -IdentityPoolName $Scheme.IdentityPoolName -Count $Count -AdminAddress $AdminAddress
            Write-Host $AdAccount.SuccessfulAccountsCount -ForegroundColor Green

            Write-Host "Provisionnement des machines virtuelles: " -NoNewline
            $provVMTaskID = New-ProvVM -ADAccountName $AdAccount.SuccessfulAccounts -ProvisioningSchemeName $Scheme.IdentityPoolName -RunAsynchronously -AdminAddress $AdminAddress
        
        # wait for the VMS tp finish Provisioning
            $ProvTask = Get-ProvTask -TaskID $provVMTaskID -AdminAddress $AdminAddress

            $jLength = 0
            While ($provTask.Active) {
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
            Write-Host "Enregistrement des machines virtuelles: " -NoNewline
            New-brokermachine -CatalogUid $($Catalog.Uid) -MachineName $($AdAccount.SuccessfulAccounts) -AdminAddress $AdminAddress
            Write-Host "OK" -ForegroundColor Green 

            Write-Host "Ajout des machines virtuelles au groupe $DeliveryGroup`: " -NoNewline
            $($AdAccount.SuccessfulAccounts) | ForEach-Object { Add-BrokerMachine -MachineName $($_.ADAccountName.TrimEnd('$')) -DesktopGroup $DeliveryGroup -AdminAddress $AdminAddress }
            Write-Host "OK" -ForegroundColor Green
        }
    } Catch {
        Write-Host "NOK" -ForegroundColor Red
        Throw $_
    }

}