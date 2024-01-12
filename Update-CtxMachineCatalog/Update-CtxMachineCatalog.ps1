Function Update-CtxMachineCatalog {
        [CmdletBinding(
            SupportsShouldProcess=$true,
            HelpUri = 'https://support.citrix.com/article/CTX129205',
            ConfirmImpact='High'
        )]

        Param (
            [Parameter(Mandatory=$false)]
            [String[]]$DDCs = @('xendc001.contoso.fr', 'xendc002.contoso.fr'),

            [Parameter(Mandatory=$true)]
            $MachineCatalog,

            [Parameter(Mandatory=$false)]
            $MasterVM,

            [Parameter(Mandatory=$false)]
            [String] $vCenterUser = 'svc_vcenter_user',

            [Parameter(Mandatory=$false)]
            [String] $vCenterServer = 'vcenter001.contoso.fr', 

            [Switch] $ForceSnapShot
        )


    Function Out-Log {
    <#
    .Synopsis
       Append dated and categorized text.
    .DESCRIPTION
       Append dated and categorized text to the standard output or log formated file.
    .PARAMETER Path
        Specifies the path of the log file.

    .PARAMETER String
        Specifies the string description.

    .PARAMETER Action
        Specifies the colored tag.

    .PARAMETER Encoding
        Specifies the file encoding. 

    .PARAMETER NoNewLine
        Prevent crlf at this end of the line.

    .PARAMETER Tee
        Specifies to Write the line on both standard output and log file.
    
    .EXAMPLE
       "Messsage" | Out-Log ACTION C:\Temp\log3.txt
       Append a new line tagged ACTION in log3.txt file.

    .EXAMPLE
        "Message action affiché en sortie standard ET journalisé" | Out-Log Action -Tee -Path c:\temp\Log.txt
        Display a line on standard outpur and appen the same line in log.txt, both tagged ACTION

    .INPUTS
        System.String

    .OUTPUTS
        System.String
    .LINK
        More at https://mickaelroy.starprince.fr
    #>
        Param (        
            [ValidateScript({
                If($_ -notmatch "(\.log|\.txt|\.err)"){
                    throw "The file specified in the path argument must be either of type log or txt"
                }
                return $true 
            })]
            [Parameter(Mandatory=$false, position = 1, ParameterSetName = 'OutFile')]
            [Alias('LogPath')]
            [string]$Path,

            [Parameter(Mandatory=$true, ValueFromPipeline=$True)]
            [string]$String,

            [ValidateSet("ERROR", "WARNING", "ACTION" ,"INFO", "SUCCESS")]
            [Parameter(Mandatory=$false, position = 0)]
            [string]$Action = "INFO",

            [Parameter(Mandatory=$false)]
            [System.Text.Encoding]$Encoding = [System.Text.Encoding]::Default,

            [Parameter(Mandatory=$false)]
            [Switch]$NoNewLine,

            [Parameter(Mandatory=$false, ParameterSetName = 'OutFile')]
            [Switch]$Tee

        )
        Begin {
            $Action = $Action.ToUpper()

            If (-not [string]::IsNullOrEmpty($Path)) {
                Try {
                    Write-Verbose -Message "Check if $Path exists and create if needed"
                    If (-not [System.IO.File]::Exists($Path) ) {
                        $logFileInfo = [System.IO.FileInfo]::new($Path)
                        $logDirInfo = [System.IO.DirectoryInfo]($logFileInfo.DirectoryName)
                        If (-not $logDirInfo.Exists) { $logDirInfo.Create() }
                        $logFile = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                    } Else {
                        $logFile = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                    }
                    $Stream = [System.IO.StreamWriter]::new($logFile, $Encoding)
                } Catch {
                    throw $_
                }
            } Else {
                $Console = $true
            }
            Function Out-Standard {
                Param (
                    $NewLine,
                    $Action
                )

                $Color = Switch ($Action) {
                    "ERROR" { [System.ConsoleColor]::Red }
                    "WARNING" { [System.ConsoleColor]::Yellow }
                    "ACTION" { [System.ConsoleColor]::Blue }
                    "SUCCESS" { [System.ConsoleColor]::Green }
                    "INFO" { [System.ConsoleColor]::White }
                }
                $pieces = [Regex]::Split($NewLine, "(\[[^\]]*\])")

                for($i=0 ; $i -lt $pieces.Length  ;$i++)  {
                    [string]$piece = $pieces[$i]
                    If ($piece -match "^\[\w+\]$" -and (!$ActionWriten)) {
                        $piece = "[$($piece.Substring(1,$piece.Length-2))]"
                    
                        Write-Host -ForegroundColor $color -NoNewline $piece
                        $ActionWriten = $true
                    }
                    Else {
                        Write-Host -NoNewline $piece
                    }
                    
                }
                If (-not $NoNewLine.IsPresent) {
                    Write-Host "`n" -NoNewline
                } Else {
                    Write-Host "`r" -NoNewline
                }
            }
        } Process {

            $Date = [datetime]::Now
            $NewLine = "[{0:dd/MM/yy - HH:mm:ss}][{1}] {2}" -F $Date, $Action, $String

            If (-not [string]::IsNullOrEmpty($Path)) {
                If ($NoNewLine) { 
                    $Stream.Write($NewLine)
                }
                Else { 
                    $Stream.WriteLine($NewLine)
                }
        
                $i++
            } Else {
                Out-Standard $NewLine $Action
            }
            If ($Tee) {
                Out-Standard $NewLine $Action
            }

        } End {
            If (-not [string]::IsNullOrEmpty($Path)) { 
                $Stream.Close()
                [System.Threading.Thread]::Sleep(50)
            }
            If (! $Console) {
                Write-Verbose -Message "$i line(s) wrote in $Path"
            }
        }
    }

    $ErrorActionPreference = 'Stop'

    Try {

        'Chargement du module ActiveDirectory... ' | Out-Log -NoNewLine
        Import-Module ActiveDirectory
        Write-Host 'OK' -ForegroundColor Green

        'Chargement du module VMware.VimAutomation.Core... ' | Out-Log -NoNewline
        Import-Module VMware.VimAutomation.Core
        Write-Host 'OK' -ForegroundColor Green

        'Chargement du PSSnapin Citrix... ' | Out-Log -NoNewline
        Add-PSSnapin Citrix*
        Write-Host 'OK' -ForegroundColor Green

        'Connexion au vCenter... ' | Out-Log -NoNewline
        $vCenterConnection = Connect-VIServer $vCenterServer -User $vCenterUser
        Write-Host 'OK' -ForegroundColor Green

        'Verification de la connectivité aux delivery controllers... ' | Out-Log -NoNewline
        $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-NetConnection -Port 443 | Select-Object ComputerName,TcpTestSucceeded
        If ((!$ConnectionTes1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun dedlivery controllers n'est joignable." }
        Write-Host 'OK' -ForegroundColor Green

        $AdminAddress = $ConnectionTest1, $ConnectionTest2 | Where-Object TcpTestSucceeded | Get-Random | Select-Object -ExpandProperty ComputerName
        "$AdminAddress sera notre interlocuteur..." | Out-Log

        If ($null -eq $MasterVM) {
            "Déduction du Master Template relatif au MCA $MachineCatalog... " | Out-Log -NoNewline
            $Session = New-PSSession -ComputerName $AdminAddress
            $TempResult = Get-ProvScheme -ProvisioningSchemeUid (Get-BrokerCatalog -Name $MachineCatalog).ProvisioningSchemeId | Select-Object HostingUnitName, MasterImageVM
            $MasterVM = $TempResult.MasterImageVM.Split('\')[3].Split('.')[0]
            $HostingUnitName = $TempResult.HostingUnitName
            Write-Host 'OK' -ForegroundColor Green
            "Il semble que le Golden Image soit $MasterVM" | Out-Log
        } Else {
            "Vous avez choisi le Master nommé $MasterVM... " | Out-Log
            $TempResult = Get-ProvScheme -ProvisioningSchemeUid (Get-BrokerCatalog -Name $MachineCatalog).ProvisioningSchemeId | Select-Object HostingUnitName
            $HostingUnitName = $TempResult.HostingUnitName
        }
    
        $LatestSnapshot = Get-Snapshot -VM $MasterVM | Sort-Object Created -Descending | Select-Object Name, Created -First 1
        If ($null -eq $LatestSnapshot -or (([DateTime]::Now - [DateTime]$LatestSnapshot.Created).Days -gt 1) -or $ForceSnapShot) {
            "Création du snapshot..." | Out-Log -NoNewline
            $NewSnapshotDescription = "Automated Snapshot completed by Update-MachineCatalog script. Initiated by: $env:USERNAME"
            $NewSnapshotName = "Citrix_XD_Automated_Deployement_$([DateTime]::Now.ToString("yyyy-MM-dd"))"
            New-Snapshot -VM $MasterVM -Name $NewSnapshotName -Description $NewSnapshotDescription -Confirm:$false | Out-Null
            Write-Host 'OK' -ForegroundColor Green
        }
        $LatestSnapshot = Get-Snapshot -VM $MasterVM | Sort-Object Created -Descending | Select-Object Name, Id, Created -First 1
        "l'Id du snapshot est $($LatestSnapshot.Id.Split('-')[-1])" | Out-Log

        "Recherche du snapshot pour le présenter lors du provisionnement... " | Out-Log -NoNewline
        Write-Verbose -Message "Recherche dans: XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm"
        $Snaps = Invoke-Command -Session $Session -ScriptBlock { Add-PSSnapin Citrix*; Get-ChildItem -Recurse -Path "XDHyp:\hostingunits\$using:HostingUnitName\$($Using:MasterVM).vm"  }
        $Snap = $Snaps | Where-Object Id -Match ".*$($LatestSnapshot.Id.Split('-')[-1])$"
        Write-Host 'OK' -ForegroundColor Green

        if ($PSCmdlet.ShouldProcess("$MasterVM -> $MachineCatalog","Publication de l'image ?")) {
            "Invocation de la publication... " | Out-Log -NoNewline
            $PubTask = Publish-ProvMasterVmImage -AdminAddress $adminAddress -MasterImageVM $Snap.FullPath -ProvisioningSchemeName $MachineCatalog -RunAsynchronously
            Write-Host 'OK' -ForegroundColor Green
        }
        Return $PubTask

    } Catch {

        Write-Host 'NOK' -ForegroundColor Red
        Throw $_
    }

}
