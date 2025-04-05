Function Get-VMStorageWinMapping {
<#
    .SYNOPSIS
    Fais la correlation entre les disques virtuels et les volumes Windows.

    .DESCRIPTION
    Cette fonction récupère les disques virtuels d'une machine virtuelle spécifiée, ainsi que les disques physiques associés sur la machine hôte. Elle associe les disques virtuels aux disques physiques en utilisant les informations SCSI et retourne les détails formatés.

    .PARAMETER VMName
    Le nom de la machine virtuelle pour laquelle récupérer les détails des disques.

    .EXAMPLE
    $VMName = "NomDeVotreVM"
    $diskDetails = Get-DiskDetails -VMName $VMName
    $diskDetails | Format-Table

    .NOTES
    Assurez-vous que les modules nécessaires sont installés et que vous avez les permissions appropriées pour exécuter les commandes sur la machine hôte et la machine virtuelle.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )

    # Récupérer les disques virtuels
    $VM = VMware.VimAutomation.core\Get-VM $VMName 

    $hardDisks = $VM | Get-HardDisk
     
    $DiskUUidEnabled = [Bool]($VM.ExtensionData.Config.ExtraConfig | Where-Object { $_.Key -eq "disk.EnableUUID" }).Key
    # Afficher les détails des disques virtuels
    $VMDisks = Foreach ($disk in $hardDisks) {
        # Associer chaque disque à son contrôleur et port
        $scsiController = Get-ScsiController -HardDisk $Disk
        $ctrl = $Disk.Parent.Extensiondata.Config.Hardware.Device | Where-Object { $_.Key -eq $Disk.ExtensionData.ControllerKey }
        $uuidSetting = $Disk.Parent.ExtensionData.Config.ExtraConfig | Where-Object { $_.Key -eq "disk.EnableUUID" }

        [PSCustomObject]@{
            DiskName = $disk.Name
            CapacityGB = $disk.CapacityGB
            Filename = $disk.Filename
            SCSIController = $disk.ExtensionData.ControllerKey
            SCSIBusNumber = $scsiController.ExtensionData.BusNumber
            CtrlUnitNumber = $ctrl.UnitNumber
            DiskUnitNumber = $Disk.ExtensionData.UnitNumber
            Uuid = $Disk.ExtensionData.Backing.Uuid.replace("-","")
            uuidSetting = $uuidSetting.Value
            SlotId = $scsiController.ExtensionData.SlotInfo.PciSlotNumber
        }
    }

    # Récupérer les disques physiques
    $GuestDisks = Invoke-Command { 
        $physicalDisks = Get-CimInstance -ClassName Win32_DiskDrive -Property DeviceID, Size, scsiport, scsibus, scsitargetid, scsilogicalunit, SerialNumber

        $Results = Foreach ($disk in $physicalDisks) {

            $DiskInfos = $Disk | Select-Object DeviceID,@{N='Size';E={$_.size/1gb}}, scsiport, scsibus, scsitargetid, scsilogicalunit, SerialNumber | Sort-Object scsiport, scsitargetid
            $SCSIController = $Disk | Get-CimAssociatedInstance -ResultClassName Win32_PnPEntity -KeyOnly | Get-CimAssociatedInstance -ResultClassName Win32_SCSIController
            $SCSIControllerRegKeys = Get-ItemProperty  -path "HKLM:\SYSTEM\CurrentControlSet\Enum\$($SCSIController.DeviceID)"
            If ($SCSIControllerRegKeys.UINumber) { $SlotId = $SCSIControllerRegKeys.UINumber }
            Else { $SlotId = $Null }

            $Volumes = $Disk | Get-CimAssociatedInstance -ResultClassName Win32_DiskPartition -KeyOnly |
            Get-CimAssociatedInstance -ResultClassName Win32_LogicalDisk

            Foreach ($volume in $volumes) {        
                # Afficher le label du volume
                [PsCustomObject]@{
                    Volume = $volume.DeviceId
                    Label = $volume.VolumeName
                    SCSIPort = $DiskInfos.scsiport
                    SCSITargetId = $DiskInfos.scsitargetid
                    SerialNumber = $DiskInfos.SerialNumber
                    SlotId = $SlotId
                }
            }
        } 
        $Results

    } -ComputerName $VMName
    
    If ($DiskUUidEnabled) {
        Foreach ($VMDisk in $VMDisks) {
            $GuestDisk = $GuestDisks | Where-Object { $_.SerialNumber -eq $Vmdisk.Uuid }
             $finalDetails += [PsCustomObject]@{
                Volume = $GuestDisk.Volume
                Label =  $GuestDisk.Label
                FilePath = $Vmdisk.Filename
                FileName = $($Vmdisk.Filename).Split('/')[-1]
                Capacity = $Vmdisk.CapacityGB
                Location = "$($Vmdisk.SlotId):$($Vmdisk.SCSIBusNumber):$($Vmdisk.DiskUnitNumber)"
                GuestLocation = "$($PhysicalDisk.SlotId):$($GuestDisk.SCSIPort):$($GuestDisk.SCSITargetId)"
            }
        }
    } Else {
        $finalDetails = Foreach ($GuestDisk in $GuestDisks) {
            $SlotIdLookUp = If (($GuestDisk.SlotId -band 0x1) -eq 1) { (($GuestDisk.SlotId - 1) -Bor 0x400) }
            Else { $GuestDisk.SlotId }
            $VMDisk = $VMDisks | Where-Object { $_.SlotId -eq $SlotIdLookUp -and $_.DiskUnitNumber -eq $GuestDisk.SCSITargetId }

            If ($null -ne $VMDisk) {
                [PsCustomObject]@{
                    Volume = $GuestDisk.Volume
                    Label =  $GuestDisk.Label
                    FilePath = $Vmdisk.Filename
                    FileName = $($Vmdisk.Filename).Split('/')[-1]
                    Capacity = $Vmdisk.CapacityGB
                    Location = "$($Vmdisk.SlotId):$($Vmdisk.SCSIBusNumber):$($Vmdisk.DiskUnitNumber)"
                    GuestLocation = "$($GuestDisk.SlotId):$($GuestDisk.SCSIPort):$($GuestDisk.SCSITargetId)"
                }
            }
        }
    }

    $finalDetails | ForEach-Object {
        $_.PsTypeNames.Insert(0,'BrsAdminTool.VMStorageWinMapping')
    }

    # Retourner les détails finaux
    Return $finalDetails
}