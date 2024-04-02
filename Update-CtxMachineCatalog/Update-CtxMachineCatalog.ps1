Function Update-CtxMachineCatalog {
<#
    .SYNOPSIS
    Met à jour un catalogue de machines Citrix avec les dernières modifications de l'image maître.

    .DESCRIPTION
    La fonction Update-CtxMachineCatalog met à jour un catalogue de machines Citrix avec les dernières modifications de l'image maître.
    Elle crée un snapshot de l'image maître si nécessaire, puis le publie dans le catalogue de machines spécifié.

    .PARAMETER MachineCatalog
    Spécifie le nom du catalogue de machines à mettre à jour.

    .PARAMETER DDCs
    Spécifie les contrôleurs de livraison Citrix auxquels se connecter pour effectuer la mise à jour.

    .PARAMETER vCenterUser
    Spécifie le nom de l'utilisateur à utiliser pour se connecter au serveur vCenter.

    .PARAMETER vCenterServer
    Spécifie le nom du serveur vCenter auquel se connecter.

    .PARAMETER ForceSnapShot
    Indique si un nouveau snapshot doit être créé, même s'il existe déjà un snapshot récent.

    .INPUTS
    Aucune entrée requise. Vous devez spécifier les paramètres requis.

    .OUTPUTS
    System.Object
    La fonction renvoie un objet contenant les détails de la tâche de publication.

    .EXAMPLE
    Update-CtxMachineCatalog -MachineCatalog "Catalogue1" -DDCs "pwxendc102.boursorama.fr", "pwxendc202.boursorama.fr"
    Met à jour le catalogue de machines "Catalogue1" en utilisant les contrôleurs de livraison spécifiés.

    .NOTES
    Auteur : Mickael ROY
    Date de création : 28/03.2024
#>
        [CmdletBinding(
            SupportsShouldProcess=$true,
            HelpUri = 'https://support.citrix.com/article/CTX129205',
            ConfirmImpact='High'
        )]

        Param (
            [Parameter(Mandatory=$true)]
            $MachineCatalog,

            [Parameter(Mandatory=$false)]
            [String[]]$DDCs = @('xendc001.contoso.fr', 'xendc001.contoso.fr'),

            [Parameter(Mandatory=$false, HelpMessage='Specify a vCenter account')]
            [String] $vCenterUser,

            [Parameter(Mandatory=$false)]
            [String] $vCenterServer = 'vcenter.contoso.fr', 

            [Switch] $ForceSnapShot
        )

    $ErrorActionPreference = 'Stop'

    Try {
        
        If (-not (Get-Module VMware.VimAutomation.Core)) {
            Write-Host 'Chargement du module VMware.VimAutomation.Core...' -NoNewline
            Import-Module VMware.VimAutomation.Core
            Write-Host 'OK' -ForegroundColor Green
        }

        Write-Host 'Chargement du PSSnapin Citrix... ' -NoNewline
        @('Citrix.Host.Admin.V2', 'Citrix.Broker.Admin.V2', 'Citrix.MachineCreation.Admin.V2').ForEach({
            If ( $null -eq  (Get-PSSnapin $_ -ErrorAction SilentlyContinue)) { 
                Add-PSSnapin $_
                $i++
                Write-Host " $i" -ForegroundColor Green -NoNewline
            }
        })
        Write-Host ' OK' -ForegroundColor Green
       
        If ($null -eq $global:defaultviserver) {
            Write-Host 'Connexion au vCenter... ' -NoNewline
            $vCenterConnectionParameter = @{
                Server = $vCenterServer
            }
            If ($PSBoundParameters.ContainsKey('vCenterUser')) {
                $vCenterConnectionParameter.User = $vCenterUser
            }
            $vCenterConnection = Connect-VIServer @vCenterConnectionParameter
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
        
        Write-Host "Déduction du Master Template relatif au MCA $MachineCatalog... " -NoNewline
        $TempResult = Get-ProvScheme -AdminAddress $AdminAddress -ProvisioningSchemeUid (Get-BrokerCatalog -AdminAddress $AdminAddress -Name $MachineCatalog).ProvisioningSchemeId | Select-Object HostingUnitName, MasterImageVM
        $MasterVM = $TempResult.MasterImageVM.Split('\')[3].Split('.')[0]
        $HostingUnitName = $TempResult.HostingUnitName
        Write-Host 'OK' -ForegroundColor Green
        Write-Host "Il semble que le Golden Image soit $MasterVM"
    
        $LatestSnapshot = Get-Snapshot -VM $MasterVM | Sort-Object Created -Descending | Select-Object Name, Id, Created -First 1
        If ($null -eq $LatestSnapshot -or (([DateTime]::Now - [DateTime]$LatestSnapshot.Created).Days -gt 1) -or $ForceSnapShot) {
            Write-Host "Création du snapshot..." -NoNewline
            $NewSnapshotDescription = "Automated Snapshot completed by Update-MachineCatalog script. Initiated by: $env:USERNAME"
            $NewSnapshotName = "Citrix_XD_Automated_Deployement_$([DateTime]::Now.ToString("yyyy-MM-dd"))"
            $Snap = New-HypVMSnapshot -AdminAddress $AdminAddress -LiteralPath XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm -SnapshotName $NewSnapshotName -SnapshotDescription $NewSnapshotDescription
            Write-Host ' OK' -ForegroundColor Green
        } Else {
            Write-Host "L'Id du snapshot est $($LatestSnapshot.Id.Split('-')[-1])."
            Write-Host "Recherche du snapshot pour le présenter lors du provisionnement... " -NoNewLine
            Write-Verbose -Message "Recherche dans: XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm"
            $Snaps = Get-ChildItem -Recurse -Path XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm
            $Snap = $Snaps[-1].PSPath
            Write-Host 'OK' -ForegroundColor Green
        }


        If ($PSCmdlet.ShouldProcess("$MachineCatalog","Publication de l'image $MasterVM ?")) {
            Write-Host "Invocation de la publication... " -NoNewLine
            $PubTask = Publish-ProvMasterVmImage -AdminAddress $AdminAddress -MasterImageVM $Snap -ProvisioningSchemeName $MachineCatalog -RunAsynchronously
            Write-Host 'OK' -ForegroundColor Green
        }
        Return $PubTask

    } Catch {
        Write-Host 'NOK' -ForegroundColor Red
        Throw $_
    }
   
}
