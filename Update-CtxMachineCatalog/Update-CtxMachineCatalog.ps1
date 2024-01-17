Function Update-CtxMachineCatalog {
        [CmdletBinding(
            SupportsShouldProcess=$true,
            HelpUri = 'https://support.citrix.com/article/CTX129205',
            ConfirmImpact='High'
        )]

        Param (
            [Parameter(Mandatory=$true)]
            $MachineCatalog,

            [Parameter(Mandatory=$false)]
            $MasterVM,

            [Parameter(Mandatory=$false)]
            [String[]]$DDCs = @('pwxendc102.boursorama.fr', 'pwxendc202.boursorama.fr'),

            [Parameter(Mandatory=$false)]
            [String] $vCenterUser = 'svc_vcenter_RO_Script_Snap',

            [Parameter(Mandatory=$false)]
            [String] $vCenterServer = 'pavcenter001.boursorama.fr', 

            [Switch] $ForceSnapShot
        )


    $ErrorActionPreference = 'Stop'

    Try {

        Write-Host 'Chargement du module VMware.VimAutomation.Core... ' -NoNewline
        Import-Module VMware.VimAutomation.Core
        Write-Host 'OK' -ForegroundColor Green

        Write-Host 'Chargement du PSSnapin Citrix... ' -NoNewline
        Add-PSSnapin Citrix*
        Write-Host 'OK' -ForegroundColor Green

        Write-Host 'Connexion au vCenter... ' -NoNewline
        $vCenterConnection = Connect-VIServer $vCenterServer -User $vCenterUser
        Write-Host 'OK' -ForegroundColor Green

        Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
        $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-NetConnection -Port 80 | Select-Object ComputerName,TcpTestSucceeded
        If ((!$ConnectionTes1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun delivery controllers n'est joignable." }
        Write-Host 'OK' -ForegroundColor Green

        $AdminAddress = $ConnectionTest1, $ConnectionTest2 | Where-Object TcpTestSucceeded | Get-Random | Select-Object -ExpandProperty ComputerName
        Set-HypAdminConnection -AdminAddress $AdminAddress
        Write-Host "$AdminAddress sera notre interlocuteur..."

        If ($null -eq $MasterVM) {
            Write-Host "Déduction du Master Template relatif au MCA $MachineCatalog... " -NoNewline
            $TempResult = Get-ProvScheme -AdminAddress $AdminAddress -ProvisioningSchemeUid (Get-BrokerCatalog -AdminAddress $AdminAddress -Name $MachineCatalog).ProvisioningSchemeId | Select-Object HostingUnitName, MasterImageVM
            $MasterVM = $TempResult.MasterImageVM.Split('\')[3].Split('.')[0]
            $HostingUnitName = $TempResult.HostingUnitName
            Write-Host 'OK' -ForegroundColor Green
            Write-Host "Il semble que le Golden Image soit $MasterVM"
        }
    
        $LatestSnapshot = Get-Snapshot -VM $MasterVM | Sort-Object Created -Descending | Select-Object Name, Created -First 1
        If ($null -eq $LatestSnapshot -or (([DateTime]::Now - [DateTime]$LatestSnapshot.Created).Hours -gt 24) -or $ForceSnapShot) {
            Write-Host "Création du snapshot..." -NoNewline
            $NewSnapshotDescription = "Automated Snapshot completed by Update-MachineCatalog script. Initiated by: $env:USERNAME"
            $NewSnapshotName = "Citrix_XD_Automated_Deployement_$([DateTime]::Now.ToString("yyyy-MM-dd"))"
            New-Snapshot -VM $MasterVM -Name $NewSnapshotName -Description $NewSnapshotDescription -Confirm:$false | Out-Null
            Write-Host 'OK' -ForegroundColor Green
        }
        $LatestSnapshot = Get-Snapshot -VM $MasterVM | Sort-Object Created -Descending | Select-Object Name, Id, Created -First 1
        Write-Host "l'Id du snapshot est $($LatestSnapshot.Id.Split('-')[-1])"

        Write-Host "Recherche du snapshot pour le présenter lors du provisionnement... " -NoNewLine
        Write-Verbose -Message "Recherche dans: XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm"
        $Snaps = Get-ChildItem -Recurse -Path XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm
        $Snap = $Snaps | Where-Object Id -Match ".*$($LatestSnapshot.Id.Split('-')[-1])$"
        Write-Host 'OK' -ForegroundColor Green

        If ($PSCmdlet.ShouldProcess("$MasterVM -> $MachineCatalog","Publication de l'image ?")) {
            Write-Host "Invocation de la publication... " -NoNewLine
            $PubTask = Publish-ProvMasterVmImage -AdminAddress $AdminAddress -MasterImageVM $Snaps.FullPath -ProvisioningSchemeName $MachineCatalog -RunAsynchronously
            Write-Host 'OK' -ForegroundColor Green
        }
        Return $PubTask

    } Catch {

        Write-Host 'NOK' -ForegroundColor Red
        Throw $_
    }

}
