Function Start-WUScan {
<#
    .Synopsis
       Striggers a sync with wsus.
    
    .DESCRIPTION
       Striggers a sync between the client its configured wsus and returns the updates corresponding to the search criteria.
    
    .PARAMETER ComputerName
        Specifies the computer name of the client.
    
    .PARAMETER SearchCriteria
        Specifies the computer name of wsussearch criteria, default is 'isInstalled=0'.
            
    .EXAMPLE
       $hnodes | Start-WUScan
       Starts a sync with wsus and returns all updates not installed on the client.

    .INPUTS
        System.String
    
    .OUTPUTS
        System.Object
    .LINK
        More at https://mickaelroy.starprince.fr
        Source: https://github.com/microsoft/MSLab
#>

    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [Alias("Name", "Server")]
        [String[]]$ComputerName,
        [parameter(Mandatory = $false)]
        [String]$SearchCriteria = 'isInstalled=0'

    )
    Begin {
        $arrlist = [System.Collections.ArrayList]::new()
        $Namespace = 'root/Microsoft/Windows/WindowsUpdate'
    }

    Process {
        Foreach ($Computer in $ComputerName) {
            $ReleaseID = Get-WindowsRelease $Computer
            Try {
                If ($ReleaseID -eq 1607) {
                    #Command for Windows Server 2016
                    $Instance = New-CimInstance -ComputerName $Computer -Namespace $Namespace -ClassName MSFT_WUOperationsSession
                    $ScanResults = $Instance | Invoke-CimMethod -MethodName ScanForUpdates -Arguments @{SearchCriteria=$SearchCriteria ;OnlineScan=$true} -ErrorAction Stop
                }
                If ($ReleaseID -ge 1809) {
                    #Command for Windows Server 2019
                    $ScanResults = Invoke-CimMethod -ComputerName $Computer -Namespace $Namespace -ClassName "MSFT_WUOperations" -MethodName ScanForUpdates -Arguments @{SearchCriteria=$SearchCriteria}
                }
            } Catch {
                Throw "Scan hit error: $_"
            }

        
            Try {
                $PendingReboots = Invoke-CimMethod -ComputerName $Computer -Namespace $Namespace -ClassName MSFT_WUSettings -MethodName IsPendingReboot
            } Catch {
                Throw $_
            } Finally {
                If ($true -in @($PendingReboots.PendingReboot)) {
                $ServerToReboot = $PendingReboots | Where-Object PendingReboot -eq $false
                    Write-Warning -Message "Pending reboot: $($ServerToReboot.PSComputerName -join ", ")"
                }
            }

            Foreach ($ScanResult in $ScanResults) {
                If ($ScanResult.ReturnValue -eq 0) {
                    [Void]$arrlist.AddRange($ScanResult.Updates)
                } Else {
                    Write-Error "Scan hit error: $($ScanResult.ReturnValue)"
                }
            }
        } # End Foreach Computer
    } # End Process
    End {
        $Instance | Remove-CimInstance -ErrorAction SilentlyContinue

        # Comma is added to prevent powershell from converting return to an array
        Return ,$arrlist
    }
}