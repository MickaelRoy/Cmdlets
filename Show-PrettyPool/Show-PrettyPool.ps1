Function Show-PrettyPool {
    [cmdletbinding()]
	Param (
        [Parameter(Mandatory=$true, HelpMessage = 'Name of the cluster that has remediation pending' )]
        [Alias('Cluster')]
        [string]$Clustername
	)

# List physical disks
    $Drives = Get-PhysicalDisk -CimSession $Clustername | Sort-Object DeviceId

    $Output = [System.Collections.ArrayList]::new()

#  Loop on physical disk to create an object including SerialNumber, MediaType and Size and Footprint
    ForEach ($Drive in $Drives) {
        If ($Drive.DeviceId -Eq 0) {
            Continue
        }
        If ($Drive.BusType -Eq "NVMe") {
            $SerialNumber = $Drive.AdapterSerialNumber
            $Type = $Drive.BusType
        } Else { # SATA, SAS
            $SerialNumber = $Drive.SerialNumber
            $Type = $Drive.MediaType
        }

        If ($Drive.Usage -Eq "Journal") {
            $Size = $Drive.Size
            $Used = "-"
            $Percent = "-"
        } Else {
            $Size = $Drive.Size
            $Used = $Drive.VirtualDiskFootprint
            $Percent = "{0:N2}" -f (($Drive.VirtualDiskFootprint/$Drive.Size)*100)
        }

        $NodeObj = $Drive | Get-StorageNode -CimSession $Clustername -PhysicallyConnected
        If ($Null -ne $NodeObj) {
            $Node = $NodeObj.Name.Split('.')[0]
        } Else {
            $Node = "-"
        }

        $value = [PSCustomObject]@{
            "SerialNumber" = $SerialNumber
            "Type" = $Type
            "Node" = $Node
            "Size" = $Size
            "Used" = $Used
            "Percent" = $Percent
        }
        $value.PsTypeNames.Insert(0,'ToolSet.PrettyPool')

        $i = $Output.Add($value)
        Write-Progress -Activity "Scanning physical disks . . ." -Status "Scanned: $($Drive.DeviceId)" -PercentComplete (($i / $Drives.Count)  * 100)
    }
    Write-Progress -Activity "Scanning physical disks . . ." -Completed
    Return $Output

}

Export-ModuleMember Show-PrettyPool