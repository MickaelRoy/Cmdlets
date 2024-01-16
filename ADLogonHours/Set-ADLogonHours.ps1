Function Set-ADLogonHours {
     [CmdletBinding()]
     Param(
        [Parameter(Mandatory=$True)]
        [ValidateRange(0,23)]
        $TimeIn24Format,

        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True, Position=0)]
        [Microsoft.ActiveDirectory.Management.ADUser]$Identity,

        [parameter(Mandatory=$False)]
        [ValidateSet("WorkingDays", "NonWorkingDays", "Ignored")]
        [String]$NonSelectedDaysare ="Ignored",

        [parameter(Mandatory=$False)]
        [ValidateSet("Permitted", "Deny")]
        [String]$LogonPrecedence ="Permitted",
            
        [parameter(Mandatory=$false)]
        [switch]$Sunday,

        [parameter(Mandatory=$false)]
        [switch]$Monday,

        [parameter(Mandatory=$false)]
        [switch]$Tuesday,

        [parameter(Mandatory=$false)]
        [switch]$Wednesday,

        [parameter(Mandatory=$false)]
        [switch]$Thursday,

        [parameter(Mandatory=$false)]
        [switch]$Friday,

        [parameter(Mandatory=$false)]
        [switch]$Saturday
     )
     Process {

        Switch ($LogonPrecedence) {
            "Permitted" { $Basis = 0 ; $Exc = 1 }
            "Deny" { $Basis = 1 ; $Exc = 0 }
        }

        $FullByte = [byte[]]::new(21)
        $FullDay = [ordered]@{}
        0..23 | Foreach {$FullDay.Add($_,$Basis)}

        $TimeIn24Format.ForEach({$FullDay[$_]=$Exc})

        $Working = -join ($FullDay.Values)
        Switch ($PSBoundParameters["NonSelectedDaysare"]) {
            'NonWorkingDays' { $SundayValue=$MondayValue=$TuesdayValue=$WednesdayValue=$ThursdayValue=$FridayValue=$SaturdayValue="000000000000000000000000" }
            'WorkingDays' { $SundayValue=$MondayValue=$TuesdayValue=$WednesdayValue=$ThursdayValue=$FridayValue=$SaturdayValue="111111111111111111111111" }
            'Ignored' { }
        }
        Switch ($PSBoundParameters.Keys) {
            'Sunday' { $SundayValue=$Working }
            'Monday' { $MondayValue=$Working }
            'Tuesday' { $TuesdayValue=$Working }
            'Wednesday' { $WednesdayValue=$Working }
            'Thursday' { $ThursdayValue=$Working }
            'Friday' { $FridayValue=$Working }
            'Saturday' { $SaturdayValue=$Working }
        }
        $AllTheWeek = "{0}{1}{2}{3}{4}{5}{6}" -f $SundayValue,$MondayValue,$TuesdayValue,$WednesdayValue,$ThursdayValue,$FridayValue,$SaturdayValue
        
      # Timezone Check
        If ((Get-TimeZone).BaseUtcOffset.Hours -le 0) {
            $TimeZoneOffset = $AllTheWeek.Substring(0,168 + ((Get-TimeZone).BaseUtcOffset.Hours))
            $TimeZoneOffset1 = $AllTheWeek.SubString(168 + ((Get-TimeZone).BaseUtcOffset.Hours))
            $FixedTimeZoneOffSet="$TimeZoneOffset1$TimeZoneOffset"
        }
        If ((Get-TimeZone).BaseUtcOffset.Hours -gt 0) {
            $TimeZoneOffset = $AllTheWeek.Substring(0,((Get-TimeZone).BaseUtcOffset.Hours))
            $TimeZoneOffset1 = $AllTheWeek.SubString(((Get-TimeZone).BaseUtcOffset.Hours))
            $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
        }
         
        $i=0
        $BinaryResult = $FixedTimeZoneOffSet -split '(\d{8})' -ne ''
         
        Foreach ($singleByte in $BinaryResult) {
            $Tempvar = $singleByte.ToCharArray()
            [array]::Reverse($Tempvar)
            $Tempvar = -join $Tempvar
            $Byte = [Convert]::ToByte($Tempvar, 2)
            $FullByte[$i] = $Byte
            $i++
        }
        
        Write-Host "Paramètrage du compte sur l'AD: " -NoNewline
        Try {
            Set-ADUser -Identity $Identity -Replace @{logonhours = $FullByte} -ErrorAction Stop
            Write-Host "OK`n" -ForegroundColor Green
        } Catch {
            Write-Host "NOK`n" -ForegroundColor Red
        } Finally {
            Get-ADUser -Identity $Identity -Properties logonhours | Convert-ADLogonHours -Gui
        }
    }
    End {
         
    }
}
