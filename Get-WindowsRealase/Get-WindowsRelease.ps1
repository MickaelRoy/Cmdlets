Function Get-WindowsRelease {
    [cmdletbinding()]
    Param(
        [Parameter(HelpMessage = 'Provide Computer Name')]
        [System.String] $Computername = $env:COMPUTERNAME
    )
    Try {
        $Release = (Get-RegistryValue -ComputerName $Computername -RegPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -RegValue ReleaseId).Data
        If ($Release -eq '2009') {
            $Release = (Get-RegistryValue -ComputerName $Computername -RegPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -RegValue DisplayVersion).Data
        }

        Return $Release
    } Catch {
        Throw $_
    }

}

Export-ModuleMember Get-WindowsRelease