Function Enable-WinRMforHTTPS {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Switch]$Force
    )
    $ADModule = Get-Module -ListAvailable ActiveDirectory
    If ($null -eq $ADModule) { Throw "ActiveDirectory module not available." }
    
    If ($Force.IsPresent) {
        Write-Verbose -Message "The force is requested. Feel it !"
        Try {
            $WsManInst = Get-WSManInstance -ComputerName $ComputerName -ResourceURI winrm/config/Listener -SelectorSet @{Address="*";Transport="HTTPS"} -ErrorAction Stop
        } Catch {
            Write-Verbose "WsMan instance not found"
        }
        If (-not [string]::IsNullOrEmpty($wsmanInst)) {
            Write-Verbose -Message "Removing Cert $($WsManInst.CertificateThumbprint)"
            Invoke-Command -ComputerName $ComputerName -ScriptBlock { Gci Cert:\LocalMachine\My | ? Thumbprint -eq $($Using:WsManInst.CertificateThumbprint) | Remove-Item }
            
            Write-Verbose -Message "Removing WsMan listener"
            Remove-WSManInstance -ComputerName $ComputerName -ResourceURI winrm/config/Listener -SelectorSet @{Address="*";Transport="HTTPS"}

        } Else {
            Write-Verbose "WsManInst is Null $($null -eq $WsManInst)"
        }
    }

    $Subject = $ComputerName.ToUpper()
    
    $SPN = ((Get-ADObject -Filter {(cn -eq $ComputerName)} -Properties serviceprincipalname).serviceprincipalname -match "^Host*").Trim("HOST/")
    $Subjects = $SPN #-join ","
    $Subjects = $Subjects.ToLower()

    Try {
        $NWsManInst = Get-WSManInstance -ComputerName $ComputerName -ResourceURI winrm/config/Listener -SelectorSet @{Address="*";Transport="HTTPS"} -ErrorAction Stop
    } Catch {
        Write-Verbose "WsMan instance still not found"
    }

    Write-Verbose "NWsManInst is Null $($null -eq $NWsManInst)"
    If (-not [String]::IsNullOrEmpty($NWsManInst)) {
        Write-Warning -Message "WinRM over HTTPS already enabled on $ComputerName"
        Return $NWsManInst
    }


    $Cert = Invoke-Command -ComputerName $ComputerName -ScriptBlock { 
        New-SelfSignedCertificate  -DnsName $Using:Subjects -CertStoreLocation cert:\LocalMachine\My -TextExtension '2.5.29.37={text}1.3.6.1.5.5.7.3.1' -Subject $Using:Subject
    }
    $NWsManInst = New-WSManInstance -ComputerName $ComputerName -ResourceURI winrm/config/Listener -SelectorSet @{Address="*";Transport="HTTPS"} -ValueSet @{Hostname="$Subject";CertificateThumbprint="$($Cert.Thumbprint)"}
    Return $NWsManInst

}


Export-ModuleMember Enable-WinRMforHTTPS