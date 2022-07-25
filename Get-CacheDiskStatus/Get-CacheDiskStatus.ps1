Function Get-CacheDiskStatus {
<#
    .SYNOPSIS

        Checks the bind list of drives against the cache devices.

    .DESCRIPTION

        Get-CacheDiskStatus is a script that can be used to verify the bindings of cache devices in Storage Spaces Direct.

    .PARAMETER ClusterName

        Specifies the file Cluster name.

    .EXAMPLE

        Get-CacheDiskStatus -ClusterName Clus001

    .INPUTS

        None. You cannot pipe objects to Add-Extension.

    .NOTES

        Author: Darryl van der Peijl
        Website: http://www.DarrylvanderPeijl.nl/
        Email: DarrylvanderPeijl@outlook.com
        Date created: 3.january.2018
        Last modified: 25.july.2022
        Modified by: Mickael ROY
        Version: 1.2


    .LINK

        http://www.DarrylvanderPeijl.nl/
        https://mickaelroy.starprince.fr/

#>
    Param (
        [parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClusterName
    )


Function Get-PCStorageReportSSBCache {
    BEGIN {
        #$csvf = New-TemporaryFile
        $csvf =[System.IO.Path]::GetTempFileName()
    }

    <#
    These are the possible DiskStates
    typedef enum
    {
        CacheDiskStateUnknown                   = 0,
        CacheDiskStateConfiguring               = 1,
        CacheDiskStateInitialized               = 2,
        CacheDiskStateInitializedAndBound       = 3,     <- expected normal operational
        CacheDiskStateDraining                  = 4,     <- expected during RW->RO change (waiting for dirty pages -> 0)
        CacheDiskStateDisabling                 = 5,
        CacheDiskStateDisabled                  = 6,     <- expected post-disable of S2D
        CacheDiskStateMissing                   = 7,
        CacheDiskStateOrphanedWaiting           = 8,
        CacheDiskStateOrphanedRecovering        = 9,
        CacheDiskStateFailedMediaError          = 10,
        CacheDiskStateFailedProvisioning        = 11,
        CacheDiskStateReset                     = 12,
        CacheDiskStateRepairing                 = 13,
        CacheDiskStateIneligibleDataPartition   = 2000,
        CacheDiskStateIneligibleNotGPT          = 2001,
        CacheDiskStateIneligibleNotEnoughSpace  = 2002,
        CacheDiskStateIneligibleUnsupportedSystem = 2003,
        CacheDiskStateIneligibleExcludedFromS2D = 2004,
        CacheDiskStateIneligibleForS2D          = 2999,
        CacheDiskStateSkippedBindingNoFlash     = 3000,
        CacheDiskStateIgnored                   = 3001,
        CacheDiskStateNonHybrid                 = 3002,
        CacheDiskStateInternalErrorConfiguring  = 9000,
        CacheDiskStateMarkedBad                 = 9001,
        CacheDiskStateMarkedMissing             = 9002,
        CacheDiskStateInStorageMaintenance      = 9003   <- expected during FRU/maint
    }
    CacheDiskState;
    #>

    PROCESS {

        $log = Get-ClusterLog -Node $env:ComputerName -Destination C:\Clusterlog
        Get-ChildItem C:\clusterlog\*cluster.log | Sort-Object -Property LastWriteTime | Select-Object -First 1 | ForEach-Object {
            $node = "<unknown>"
            If ($_.BaseName -match "^(.*)_cluster$") {
                $node = $matches[1]
            }

            $NodeW = ("│ Node: $node │").Length -2
            Write-Output "`n╒$([string]::new('═', $NodeW))╕"
            Write-Output "│ Node: $node │"
            Write-Output "╘$([string]::new('═', $NodeW))╛"


            ##
            # Parse cluster log for the SBL Disk section
            ##

            $sr = [System.IO.StreamReader]$_.FullName

            $in = $false
            $parse = $false
            $(Do {
                $l = $sr.ReadLine()

                # Heuristic ...
                # SBL Disks comes before System

                If ($in) {
                    # in section, blank line terminates
                    If ($l -notmatch '^\s*$') {
                        $l
                    } Else {
                        # parse was good
                        $parse = $true
                        break
                    }
                } ElseIf ($l -match '^\[=== SBL Disks') {
                    $in = $true
                } ElseIf ($l -match '^\[=== System') {
                    break
                }

            } While (-not $sr.EndOfStream)) > $csvf

            ##
            # With a good parse, provide commentary
            ##

            If ($parse) {
                $d = Import-Csv $csvf

                ##
                # Table of raw data, friendly cache device numbering
                ##

                $idmap = @{}
                $d | ForEach-Object {
                    $idmap[$_.DiskId] = $_.DeviceNumber
                }


                $d | Select-Object @{ Label = 'DiskState'; Expression = { $_.DiskState.TrimStart('CacheDiskState') }},
                    DiskId, @{Label = 'DeviceNumber' ; Expression = {[Int]$_.DeviceNumber}},@{
                    Label = 'CacheDeviceNumber'; Expression = {
                        If ($_.IsSblCacheDevice -eq 'true') {
                            '= cache'
                        } ElseIf ($idmap.ContainsKey($_.CacheDeviceId)) {
                            $idmap[$_.CacheDeviceId]
                        } ElseIf ($_.CacheDeviceId -eq '{00000000-0000-0000-0000-000000000000}') {
                            "= unbound"
                        } Else {
                            # should be DiskStateMissing or OrphanedWaiting? Check live.
                            "= not present $($_.CacheDeviceId)"
                        }
                    }
                },HasSeekPenalty,PathId,BindingAttributes,DirtyPages | Sort-Object IsSblCacheDevice,CacheDeviceId,DiskState,DeviceNumber | Format-Table -AutoSize


                ##
                # Now do basic testing of device counts
                ##

                $dcache = $d | Where-Object IsSblCacheDevice -EQ 'true'
                $dcap = $d | Where-Object IsSblCacheDevice -NE 'true'

                Write-Output ( [string]::Format(“Device counts: `n`tCache: {0} `n`tCapacity: {1}”,@($dcache).count,@($dcap).count) )

                ##
                # Test cache bindings if we do have cache present
                ##

                If ($dcache) {

                    # first uneven check, the basic count case
                    $uneven = $false
                    If ($dcap.count % @($dcache).Count) {
                        $uneven = $true
                        Write-Warning "Capacity device count does not evenly distribute to cache devices"
                    }

                    # now look for unbound devices
                    $unbound = $dcap | Where-Object CacheDeviceId -eq '{00000000-0000-0000-0000-000000000000}'
                    If ($unbound) {
                        Write-Warning "There are $(@($unbound).Count) unbound capacity device(s)"
                    }

                    # unbound devices give us the second uneven case
                    If (-not $uneven -and ($dcap.Count - @($unbound).Count) % @($dcache).Count) {
                        $uneven = $true
                    }

                    $gdev = $dcap | Where-Object DiskState -EQ 'CacheDiskStateInitializedAndBound' | Group-Object -Property CacheDeviceId

                    If (@($gdev).Count -ne @($dcache).Count) {
                        Write-Warning "Not all cache devices in use"
                    }

                    $gdist = $gdev | ForEach-Object { $_.Count } | Group-Object

                    # in any given round robin binding of devices, there should be at most two counts; n and n-1

                    # single ratio
                    If (@($gdist).Count -eq 1) {
                        Write-Output "Binding ratio is even: 1:$($gdist.Name)"
                    } Else {
                        # group names are n in the 1:n binding ratios
                        $delta = [math]::Abs([int]$gdist[0].Name - [int]$gdist[1].Name)

                        If ($delta -eq 1 -and $uneven) {
                            Write-Output "Binding ratios are as expected for uneven device ratios"
                        } Else {
                            Write-Warning "Binding ratios are uneven"
                        }

                        # form list of group sizes
                        $s = ($gdist | ForEach-Object {
                            "1:$($_.Name) ($($_.Count) total)"
                        }) -join ", "

                        Write-Output "Groups: $s"
                    }
                }

                ##
                # Provide summary of diskstate if more than one is present in the results
                ##

                $g = $d | Group-Object -Property DiskState

                If (@($g).count -ne 1) {
                    Write-Output "Disk State Summary:"
                    $g | Sort-Object -Property Name | Format-Table @{ Label = 'DiskState'; Expression = { $_.Name.TrimStart('CacheDiskState') }},@{ Label = "DisksCount"; Expression = { $_.Count }}
                } Else {
                    $gname = (($g.name) -replace 'CacheDiskState','')
                    Write-Output "All disks are in $gname"
                }
            }
        }
    }

    END {

        Remove-Item $csvf
    }
}

    FailoverClusters\Get-ClusterNode -Cluster $ClusterName | ForEach-Object {

        Invoke-Command -ComputerName $_ -ScriptBlock ${Function:Get-PCStorageReportSSBCache}

    }

}
    