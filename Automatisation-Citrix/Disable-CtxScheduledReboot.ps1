﻿Function Disable-CtxScheduledReboot {
<#
.SYNOPSIS
Désactive les redémarrages planifiés pour un groupe de bureaux ou un nom de planification spécifié.

.DESCRIPTION
La fonction Disable-CtxScheduledReboot désactive les redémarrages planifiés pour un groupe de bureaux Citrix ou pour un nom de planification spécifié.
Elle vérifie la connectivité aux contrôleurs de livraison, importe le module Citrix nécessaire, et désactive les planifications de redémarrage correspondantes.

.PARAMETER Name
Nom de la planification de redémarrage à désactiver.
Obligatoire : Oui, sauf si DeliveryGroup est spécifié.

.PARAMETER DeliveryGroup
Nom du groupe de bureaux pour lequel les redémarrages doivent être désactivés.
Alias: DesktopGroupName
Obligatoire : Oui, sauf si Name est spécifié.

.PARAMETER DDCs
Liste des adresses des contrôleurs de livraison Citrix.
Alias: AdminAddress
Par défaut : @('xendc102.contoso.fr', 'xendc202.contoso.fr')

.EXAMPLE
Disable-CtxScheduledReboot -Name "Samedi_reboots_User_Bureau"

Cet exemple désactive la planification de redémarrage nommée "Samedi_reboots_User_Bureau".

.EXAMPLE
Disable-CtxScheduledReboot -DeliveryGroup "Bastion-2022" -DDCs @('xendc102.contoso.fr', 'xendc202.contoso.fr')

Cet exemple désactive les redémarrages planifiés pour le groupe de bureaux "Bastion-2022" avec des contrôleurs de livraison spécifiés.

.NOTES
Assurez-vous que le module Citrix.Broker.Commands est installé et accessible.
La fonction vérifie la connectivité aux contrôleurs de livraison spécifiés et utilise un contrôleur joignable pour établir une connexion.

#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ParameterSetName='ScheduledName',HelpMessage='Specify the name of the scheduled reboot')]
        [String]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='DeliveryGroup',HelpMessage='Specify the delivery group name')]
        [Alias("DesktopGroupName")]
        [String]$DeliveryGroup,
        
        [Parameter(Mandatory=$false)]
        [Alias("AdminAddress")]
        [String[]]$DDCs = @('xenddc101.contoso.fr', 'xenddc201.contoso.fr')
    )
    $ErrorAction = 'Stop'

    If ($null -ne $Env:WT_SESSION) { $OK = '✔'; $NOK = '❌'; $WARN = '⚠' }
    Else { $OK = 'OK'; $NOK = 'NOK'; $WARN = '/!\'}

    Try {
        If (-not (Get-Module Citrix.Broker.Commands)) {
            Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
            Import-Module Citrix.Broker.Commands
            Write-Host $OK -ForegroundColor Green
        }
       
        If ($null -eq $global:AdminAddress) {
            Write-Host 'Verification de la connectivité aux delivery controllers... ' -NoNewline
            $ConnectionTest1, $ConnectionTest2 = $DDCs | Test-TcpPort -Port 80 | Select-Object ComputerName,TcpTestSucceeded
            If ((!$ConnectionTes1.TcpTestSucceeded) -and (!$ConnectionTest2.TcpTestSucceeded)) { Throw "Aucun delivery controllers n'est joignable." }
            Write-Host $OK -ForegroundColor Green

            $global:AdminAddress = $ConnectionTest1, $ConnectionTest2 | Where-Object TcpTestSucceeded | Get-Random | Select-Object -ExpandProperty ComputerName
            Set-HypAdminConnection -AdminAddress $global:AdminAddress
            Write-Verbose -Message "$global:AdminAddress est notre interlocuteur..."
            Write-Host $OK -ForegroundColor Green
        }
    } Catch {
        Write-Host $NOK -ForegroundColor Red
        Throw $_
    }
    Try {
        $Parameters = @{}
        If ($PSBoundParameters.ContainsKey('DeliveryGroup')) { $Parameters.Add('DesktopGroupName', "$DeliveryGroup") }
        If ($PSBoundParameters.ContainsKey('Name')) { $Parameters.Add('Name', "$Name") }
        $Parameters.Add('AdminAddress', "$AdminAddress")

        [Array]$Items = Get-BrokerRebootScheduleV2 @Parameters
        Write-Host "Désctivation de la planification sur les $($Items.count) machine catalog(s): " -NoNewline
        $Items | Set-BrokerRebootScheduleV2 -Enabled:$false 
        Write-Host $OK -ForegroundColor Green
    } Catch {
        Write-Host $NOK -ForegroundColor Red
        Throw $_
    }
}

Export-ModuleMember Disable-CtxScheduledReboot