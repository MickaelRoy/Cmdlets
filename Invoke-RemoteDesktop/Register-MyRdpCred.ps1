Function Register-MyRdpCred {
    [cmdletBinding()]
    Param( 
        [Parameter(Mandatory = $false, Position = 0)]
        [alias("Server")]
        [String]$UserName = $env:USERNAME,
        [Switch]$Force
    )

    If ($Force -or ($null -eq $RdpCreds)) {
        $Script:RdpCreds = Get-Credential -UserName $env:USERNAME -Message "Entrez vos identifiants de connexion RDP:"
    } Else {
        Write-Host "Vos identifiants RDP ont déjà été enregistrés. Utilisez -Force pour le mettre à jour."
    }
}

New-Alias -Name rrc -value Register-MyRdpCred
Export-ModuleMember Register-MyRdpCred -Alias rrc