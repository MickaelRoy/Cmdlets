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
                vCenterServer = $vCenterServer
            }
            If ($PSBoundParameters.ContainsKey('vCenterUser')) {
                $vCenterConnectionParameter.User = $vCenterUser
            }
            $vCenterConnection = Connect-VIServer $vCenterServer -User $vCenterUser
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
            Write-Host 'OK' -ForegroundColor Green
        }
       
        If ([String]::IsNullOrEmpty($Snap)) {
            Write-Host "Recherche du snapshot pour le présenter lors du provisionnement... " -NoNewLine
            Write-Verbose -Message "Recherche dans: XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm"
            $Snaps = Get-ChildItem -Recurse -Path XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm
            $Snap = $Snaps[-1].PSPath
            Write-Host 'OK' -ForegroundColor Green
            Write-Host "L'Id du snapshot est $($Snaps[-1].Id.Split('-')[-1])"
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
