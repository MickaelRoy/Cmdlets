Function Convert-ADLogonHours {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,

        [Switch] $Gui
    )
    Begin {

$msgTable = Data {
    #culture="en-US"
    ConvertFrom-StringData @'
    warningMsg1 = Logon hours is not the correct array size of 21 for: {1}
    warningMsg2 = No logon hours were found on the input object: {0}{1}Please ensure you have included them using the -Properties parameter and logon hours have been defined"
    Sunday = Sun
    Monday = Mon
    Tuesday = Tue
    Wednesday = Wed
    Thursday = Thi
    Friday = Fri
    Saturday = Sat
    Permitted = Permitted
    Denied = Denied
'@
}

Import-LocalizedData -BindingVariable msgTable

    }
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

                $ExportObj = [PSCustomObject]::new()
                $ExportObj.psobject.properties.Add( [psnoteproperty]::new('Name', $User.Name) )
                $ExportObj.psobject.properties.Add( [psnoteproperty]::new('SamAccountName', $User.SamAccountName) )
                $ExportObj.psobject.properties.Add( [psnoteproperty]::new('UserPrincipalName', $User.UserPrincipalName) )
                $ExportObj.psobject.properties.Add( [psnoteproperty]::new('DistinguishedName', $User.DistinguishedName) )

                $BinaryResult = $FixedTimeZoneOffSet -split '(\d{24})' -ne ''

                $Inc = 0
                Foreach ($Result in $BinaryResult) {
                    $DayOfWeek = [dayofweek]$Inc
        
                    $Result = $Result -split '(.)' -ne ''

                    $LogonHours = [ordered]@{}
                    For ($Hour = 0; $Hour -le 23; $Hour++) {
                        $LogonAuth = $Result[$Hour]
                        [Void]$LogonHours.Add(("{0:d2}" -f $Hour), $LogonAuth)
                    }
                    $ExportObj.psobject.Properties.Add( [psnoteproperty]::new($DayOfWeek, $LogonHours) )
                    $Inc++
                }
                

                If (-not $Gui) {
                    Return $ExportObj
                } Else {
                    $ExportObj | Select *Name | Out-Default
                    $Week = $ExportObj.psobject.Properties.name -match ".*day$"
                    Write-Host ("{0,-5}" -f " ") -NoNewline ; (00..23).ForEach({ Write-host $("{0:d2} " -f $_) -NoNewline })
                    Write-Host `r
                    Foreach ($day in $week) {
                        Write-Host ("{0,-5}" -f $msgTable.$Day) -NoNewline
                        $ExportObj.$day.Values.ForEach({ 
                            If ($_ -eq 1) { Write-Host "  " -BackgroundColor Blue -NoNewline ; Write-Host " " -NoNewline } 
                            Else { Write-Host "  " -BackgroundColor DarkGray -NoNewline ; Write-Host " " -NoNewline }
                            
                        })
                        Write-Host `r
                    }
                }
            }
            Else { Write-Warning -Message $($msgTable.warningMsg1 -f $_)}
        }
        Else { Write-Warning -Message $($msgTable.warningMsg2 -f $_, "`r`n") }
    }
    End {

        Write-Host "`n`t" -NoNewline ; Write-Host "  " -BackgroundColor Blue -NoNewline ; Write-Host "`t`t$($msgTable.Permitted)"
        Write-Host "`t" -NoNewline ; Write-Host "  " -BackgroundColor DarkGray -NoNewline ; Write-Host "`t`t$($msgTable.Denied)"
    }
}
