function Remove-VMSnapshotsInBulk {
<#
    .SYNOPSIS
    Supprime les snapshots VMware plus anciens qu'une date spécifiée et consolide les disques virtuels ensuite.

    .DESCRIPTION
    La fonction `Remove-VMSnapshotsInBulk` permet de supprimer en bloc tous les snapshots d'une machine virtuelle (VM) plus anciens qu'une date donnée, sans exécuter de consolidation après chaque suppression. 
    Une fois tous les snapshots supprimés, une consolidation des disques virtuels est effectuée.

    .PARAMETER VMName
    Le nom de la machine virtuelle (VM) dont les snapshots doivent être supprimés.

    .PARAMETER EndDate
    La date limite jusqu'à laquelle les snapshots doivent être supprimés. Par défaut, cette date est définie à un mois avant la date actuelle. Tous les snapshots créés avant cette date seront supprimés.

    .EXAMPLE
    Remove-VMSnapshotsInBulk -VMName "NomDeVotreVM"

    Ce script supprime tous les snapshots de la VM "NomDeVotreVM" qui ont été créés avant un mois à compter de la date actuelle, puis exécute une consolidation des disques.

    .EXAMPLE
    Remove-VMSnapshotsInBulk -VMName "NomDeVotreVM" -EndDate (Get-Date "2023-01-01")

    Supprime tous les snapshots de la VM "NomDeVotreVM" créés avant le 1er janvier 2023, puis exécute une consolidation des disques.

    .EXAMPLE
    Remove-VMSnapshotsInBulk -VMName "NomDeVotreVM" -EndDate '2024-09-12'

    Supprime tous les snapshots de la VM "NomDeVotreVM" créés avant le 12 septembre 2024, puis exécute une consolidation des disques.

    .NOTES
    - Cette fonction se connecte automatiquement à vCenter via `Connect-vSphere`.
    - La suppression de snapshots utilise la méthode `RemoveSnapshot_Task()` sans consolidation immédiate.
    - Une consolidation unique des disques est effectuée à la fin via `ConsolidateVMDisks_Task()`.

    
    Auteur : Mickael ROY
    Date   : 2024-09-25


#>
    [CmdletBinding( SupportsShouldProcess=$true, ConfirmImpact='High' )]
    param (
        [string]$VMName,
        [datetime]$EndDate = [DateTime]::Now.AddMonths(-1),

        [Parameter(Mandatory=$false)]
        [String] $vCenterServer = 'vcenter001.contoso.fr'

    )

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

    Try {
        # Get VM object
        $vm = vmware.vimautomation.core\Get-VM -Name $VMName
        $vmView = $vm | Get-View -Property 'Name'
        
        # Get all snapshots of the VM between the specified dates
        [Array]$snapshots = Get-Snapshot -VM $vm | Where-Object { $_.Created -le $endDate }

        if ($snapshots.Count -eq 0) {
            Write-Host "Aucun snapshot à supprimer concernant la VM $VMName."
            return
        }

        $shouldProcess = $PSCmdlet.ShouldProcess($VMName, "Suppression des $($snapshots.Count) snapshot ?")
        If ($shouldProcess) {

            # Remove all selected snapshots without consolidating after each removal
            foreach ($snapshot in $snapshots) {
                $snapshotView = $snapshot | Get-View -Property 'Vm'
                Write-Host "Suppression du snapshot: $($snapshot.Name) créé le $($snapshot.Created):" -NoNewline
                # Remove snapshot without consolidation
                # RemoveSnapshot_Task(bool removeChildren, System.Nullable[bool] consolidate)
                $RTask = $snapshotView.RemoveSnapshot_Task($false, $False)
                If ($RTask.Value) { Write-Host $RTask.Value }
                Else { Write-Host "Echec." }
            }

            # After all snapshots are removed, consolidate the VM disks manually
            $vmView = $vm | Get-View -Property Snapshot

            Write-Host "Consolidation: " -NoNewline
            $CTask = $vmView.ConsolidateVMDisks_Task()
            If ($CTask.Value) { Write-Host $CTask.Value }
            Else { Write-Host "Echec." }

        }

    } Catch {
        Throw $_
    } Finally {
        # Disconnect from vCenter
        Disconnect-VIServer -Confirm:$false
    }
}

Export-ModuleMember Remove-VMSnapshotsInBulk