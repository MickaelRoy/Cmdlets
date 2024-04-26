Function Invoke-RemoteDesktop {
<#
    .DESCRIPTION
        Cette fonction permet de se connecter à un ordinateur distant via une session Bureau à distance.

    .PARAMETER ComputerName
        Spécifie l'adresse IP ou le nom DNS de l'ordinateur distant.

    .PARAMETER Admin
        Indique si la connexion doit être effectuée en mode console.

    .PARAMETER Credential
        Fournit les informations d'identification à utiliser pour se connecter.

    .EXAMPLE
        PS C:\> Invoke-RemoteDesktop -ComputerName "192.168.1.100"

        Lance une session Bureau à distance vers l'ordinateur distant ayant l'adresse IP 192.168.1.100.

    .EXAMPLE
        PS C:\> Invoke-RemoteDesktop -ComputerName "srv01" -Admin -Credential $cred

        Lance une session Bureau à distance vers l'ordinateur distant "srv01" en tant qu'administrateur en utilisant les informations d'identification fournies.

#>
    [cmdletBinding()]
    Param( 
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [alias("Server")]
        [string]$ComputerName,

        [Parameter()]
        [switch]$Admin,

        [Parameter()]
        [pscredential]$Credential = $RdpCreds
    )

    [string[]]$argArray = $null

    If ($ComputerName -like "*:*") { $argArray += "/v:{0}:{1}" -f ($ComputerName -split ":")[1], ($ComputerName -split ":")[0] }
    Else { $argArray += "/v:$ComputerName" }
    
    If ($Admin) { $argArray += "/admin"}
    
    Write-Verbose ($argarray -join " ")
    
    If (-not [String]::IsNullOrEmpty($Credential)) {
        #setup registry to ignore certIficate warnings
        $regKeyPath = "HKCU:\SOFTWARE\Microsoft\Terminal Server Client\Servers\$ComputerName"
        $regKeyPath2 = "HKCU:\Software\Microsoft\Terminal Server Client\LocalDevices"
        $delKeyFlag = $false
        $delPropertyFlag = $false

        If(Test-Path $regKeyPath) {

            If (-not (Get-Item $regKeyPath).Property -contains "CertHash") {
                Try { 
                    Set-ItemProperty -Path $regKeyPath -Name "CertHash" -Value ([byte[]](,0 * 20)) -Force
                    $delPropertyFlag = $true
                }
                Catch { Write-Warning -Message "Impossible d'écrire dans $regKeyPath" }
            }
        } Else {
            $delKeyFlag = $true
            New-Item -Path $regKeyPath -Force | Out-Null
            Set-ItemProperty -Path $regKeyPath -Name "CertHash" -Value ([byte[]](,0 * 20))            
        }

        If (-not (Get-ItemProperty $regKeyPath2 -Name $ComputerName) ) {
            Try {
                Write-Host "Pose d'un flag pour eviter un warning inutile: " -NoNewline
                New-ItemProperty -Path $regKeyPath2 -Name $ComputerName -Value 0x45 -PropertyType DWORD -Force
                Write-Host "OK" -ForegroundColor Green
            }
            Catch { Write-Warning -Message "Impossible d'écrire dans $regKeyPath2" }
        }

        Try {
            Start-Process -FilePath "cmdkey.exe" -ArgumentList ("/add:TERMSRV/{0} /user:{1} /pass:{2}" -f $ComputerName, $Credential.UserName, $Credential.GetNetworkCredential().Password) -WindowStyle Hidden -Wait
            Start-Sleep -Milliseconds 100
            Start-Process -FilePath "mstsc.exe" -ArgumentList $argArray 
        } Catch{
            Throw $_
        } Finally {
            Start-Sleep -Seconds 1
            Start-Process -FilePath "cmdkey.exe" -ArgumentList "/delete:TERMSRV/$ComputerName" -WindowStyle Hidden -Wait
        }
        If ($delPropertyFlag) { Remove-ItemProperty -Path $regKeyPath -Name "CertHash" }
        ElseIf ($delKeyFlag) { Remove-Item -Path $regKeyPath }
    }
    Else { Start-Process -FilePath "mstsc.exe" -ArgumentList $argArray }
}

New-Alias -Name rdp -value Invoke-RemoteDesktop
Export-ModuleMember -Function Invoke-RemoteDesktop -Alias rdp
