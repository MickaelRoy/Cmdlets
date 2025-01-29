Function Get-CtxDeliveryGroup {
    [CmdletBinding(HelpUri = 'https://confluence.contoso.com/x/wA_aLQ',DefaultParameterSetName = 'Implicit')]
    Param (

        [Parameter(Mandatory=$false, Position = 2)]
        [String[]]$DDCs = @('xenddc101.contoso.fr', 'xenddc201.contoso.fr')
    )
    Begin {
        $ErrorActionPreference = 'Stop'

        Try {        
            If (-not (Get-Module Citrix.Broker.Commands)) {
                Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
                Import-Module Citrix.Broker.Commands
                Write-Host 'OK' -ForegroundColor Green
            }

            If ($null -eq $global:AdminAddress) {
                Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
                $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-TcpPort -Port 80 | Select-Object ComputerName,TcpTestSucceeded
                If ((!$ConnectionTes1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun delivery controllers n'est joignable." }
                Write-Host 'OK' -ForegroundColor Green

                $global:AdminAddress = $ConnectionTest1, $ConnectionTest2 | Where-Object TcpTestSucceeded | Get-Random | Select-Object -ExpandProperty ComputerName
                Set-HypAdminConnection -AdminAddress $global:AdminAddress
            }
            Write-Verbose -Message "$global:AdminAddress est notre interlocuteur..."
            $Parameters = @{
                AdminAddress = $AdminAddress
            }

        } Catch {
            Write-Host $NOK -ForegroundColor Red
            Throw $_
        }
        $MachineObjects = [System.Collections.ArrayList]::new()
    } Process {

        Get-BrokerDesktopGroup -AdminAddress $Global:AdminAddress

    } End {

    }
}

Export-ModuleMember Get-CtxDeliveryGroup
