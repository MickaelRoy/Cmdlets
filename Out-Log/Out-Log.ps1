Function Out-Log {
<#
.Synopsis
   Append dated and categorized text.
.DESCRIPTION
   Append dated and categorized text to the stadard output or log formated file.
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
    Specifies to Write the line on both stadard output and log file.
    
.EXAMPLE
   "Messsage" | Out-Log ACTION C:\Temp\log3.txt

.EXAMPLE
    "Message action affiché en sortie standard ET journalisé" | Out-Log Action -Tee -Path c:\temp\Log.txt

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
