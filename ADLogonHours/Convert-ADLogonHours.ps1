Function Convert-ADLogonHours {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,

        [Switch] $Gui
    )
    Process {
        $Properties = $User.PropertyNames
        If ($Properties -contains "logonhours") {
            If ($User.LogonHours.Count -eq 21) {
                $AllTheWeek = $User.LogonHours.ForEach({
                    $TempArray = [Convert]::ToString($_,2).PadLeft(8,'0').ToCharArray()
                    [Array]::Reverse($TempArray)
                    $TempArray
                })

                $AllTheWeek = -join $AllTheWeek
              # Timezone Check
                If ((Get-TimeZone).BaseUtcOffset.Hours -le 0) {
                    $TimeZoneOffset = $AllTheWeek.Substring(0,((Get-TimeZone).BaseUtcOffset.Hours))
                    $TimeZoneOffset1 = $AllTheWeek.SubString(((Get-TimeZone).BaseUtcOffset.Hours))
                    $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
                }
                If ((Get-TimeZone).BaseUtcOffset.Hours -gt 0) {
                    $TimeZoneOffset = $AllTheWeek.Substring(0,168 - ((Get-TimeZone).BaseUtcOffset.Hours))
                    $TimeZoneOffset1 = $AllTheWeek.SubString(168 - ((Get-TimeZone).BaseUtcOffset.Hours))
                    $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
                }
                
                $BinaryResult = $FixedTimeZoneOffSet -split "(.)" -ne '' 

                $i = 0

                $ExportObj = [PSCustomObject]::new()
                $ExportObj.psobject.properties.Add( [psnoteproperty]::new('Name', $User.Name) )
                $ExportObj.psobject.properties.Add( [psnoteproperty]::new('SamAccountName', $User.SamAccountName) )
                $ExportObj.psobject.properties.Add( [psnoteproperty]::new('UserPrincipalName', $User.UserPrincipalName) )
                $ExportObj.psobject.properties.Add( [psnoteproperty]::new('DistinguishedName', $User.DistinguishedName) )

                $ExportArray = For ($Inc = 0; $Inc -lt $BinaryResult.count; $Inc += 24) {
        
                    $EndIndex = [int32]$Inc + 23

                    Switch ($Inc) {
                        0 { $DayOfWeek = [dayofweek]::Sunday }
                        24 { $DayOfWeek = [dayofweek]::Monday }
                        48 { $DayOfWeek = [dayofweek]::Tuesday }
                        72 { $DayOfWeek = [dayofweek]::Wednesday }
                        96 { $DayOfWeek = [dayofweek]::Thursday }
                        120 { $DayOfWeek = [dayofweek]::Friday }
                        144 { $DayOfWeek = [dayofweek]::Saturday }
                    }
                    
                    $LogonHours = [ordered]@{}
                    For ($Hour = 0; $Hour -lt 24; $Hour++) {

                        If ($Hour -eq 23) {$EndHour = 0}
                        Else {$EndHour = $Hour + 1}

                        Switch ($BinaryResult[$Hour]) {
                            '1' {$LogonAuth = '1'}
                            '0' {$LogonAuth = '0'}
                        }
                        [Void]$LogonHours.Add(("{0:d2}" -f $Hour), $LogonAuth)
                    }
                    $ExportObj.psobject.Properties.Add( [psnoteproperty]::new($DayOfWeek, $LogonHours) )
                }
                If (-not $Gui) {
                    Return $ExportObj
                } Else {
                    $Week = $ExportObj.psobject.Properties.name -match ".*day$"
                    Write-Host ("{0,-15}" -f "DayOfWeek") -NoNewline ; (00..23).ForEach({ Write-host $("{0:d2} " -f $_) -NoNewline })
                    Write-Host `r
                    Foreach ($day in $week) {
                        Write-Host ("{0,-15}" -f $Day) -NoNewline
                        $ExportObj.$day.Values.ForEach({ 
                            If ($_ -eq 1) { Write-Host "  " -BackgroundColor Blue -ForegroundColor Blue -NoNewline ; Write-Host " " -NoNewline } 
                            Else { Write-Host "  " -BackgroundColor DarkGray -ForegroundColor DarkGray -NoNewline ; Write-Host " " -NoNewline }
                            
                        })
                        Write-Host `r
                    }
                }
            }
            Else { Write-Warning -Message "Logon hours is not the correct array size of 21 for: $_" }
        }
        Else { Write-Warning -Message "No logon hours were found on the input object: $_ `r`nPlease ensure you have included them using the -Properties parameter and logon hours have been defined" }
    }
}
