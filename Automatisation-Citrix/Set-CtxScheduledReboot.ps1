Function Set-CtxScheduledReboot {
<#
    .SYNOPSIS
    Configure des redémarrages planifiés pour un groupe de bureaux Citrix.

    .DESCRIPTION
    La fonction Set-CtxScheduledReboot configure des redémarrages planifiés pour un groupe de bureaux Citrix spécifié. 
    Elle vérifie la connectivité aux contrôleurs de livraison, importe le module Citrix nécessaire, et affecte des tags spécifiques aux machines selon leurs noms.

    .PARAMETER DeliveryGroup
    Nom du groupe de bureaux pour lequel les redémarrages doivent être configurés.
    Alias: DesktopGroupName

    .PARAMETER Type
    Type de redémarrage à planifier. Peut être "Bastion" ou "Bureau".
    Obligatoire : Oui

    .PARAMETER DDCs
    Liste des adresses des contrôleurs de livraison Citrix.
    Alias: AdminAddress
    Par défaut : @('xendc102.contoso.fr', 'xendc202.contoso.fr')

    .EXAMPLE
    Set-CtxScheduledReboot -DeliveryGroup "Bastion-Adm_prd_2k22" -Type "Bastion"

    Cet exemple configure des redémarrages planifiés pour le groupe de bureaux "Bastion-Adm_prd_2k22" en tant que type "Bastion".

    .EXAMPLE
    Set-CtxScheduledReboot -DeliveryGroup "Bureau-User_prd_2k22" -Type "Bureau" -DDCs @('controller1.domain.com', 'controller2.domain.com')

    Cet exemple configure des redémarrages planifiés pour le groupe de bureaux "Bureau-User_prd_2k22" en tant que type "Bureau" avec des contrôleurs de livraison spécifiés.

    .NOTES
    Assurez-vous que le module Citrix.Broker.Commands est installé et accessible.
    La fonction vérifie la connectivité aux contrôleurs de livraison spécifiés et utilise un contrôleur joignable pour établir une connexion.

#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage='Specify the delivery group name')]
        [Alias("DesktopGroupName")]
        [String]$DeliveryGroup,

        [ValidateSet("Bastion","Bureau")]
        [Parameter(Mandatory=$true)]
        [String]$Type,
        
        [Parameter(Mandatory=$false)]
        [Alias("AdminAddress")]
        [String[]]$DDCs = @('xendc102.contoso.fr', 'xendc202.contoso.fr')
    )
    $ErrorActionPreference = 'Stop'

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
            }

        } Catch {
        Write-Host $NOK -ForegroundColor Red
        Throw $_
    }

    Switch ($type) {
        'Bastion' {
            $StartTime = "03:30"
            $Descr = 'reboots_Bastion'
         }
        'Bureau' { 
            $StartTime = "00:30"
            $Descr = 'reboots_User_Bureau'
        }
    }

    Try {
        $DG = Get-BrokerDesktopGroup -Name $DeliveryGroup | Select-Object Name, UID

        "SiteA", "SiteB" | ForEach-Object {
            Switch ($_) {
                'SiteA' { $Day = "Saturday"; $FrDay = "Samedi" }
                'SiteB' { $Day = "Sunday"; $FrDay = "Dimanche"  }
            }
            Write-Host "Paramètrage du site ${_}: " -NoNewline
            New-BrokerRebootScheduleV2 -Name "$($FrDay)_$($Descr)_$($_)_$($DG.UID)" -DesktopGroupUid $($DG.UID) -Frequency Weekly -Day $Day -StartTime $StartTime -Enabled $false -RebootDuration 30 -WarningTitle "WARNING: Reboot pending" -WarningMessage "Redemarrage dans %m% minutes, merci de sauvegarder votre travail." -WarningDuration 15 -WarningRepeatInterval 5 -RestrictToTag $_ | Out-Null
            Write-Host $OK -ForegroundColor Green
        }
    } Catch {
        Write-Host $NOK -ForegroundColor Red
        Throw $_
    }

    Try {
        Write-Host "Affectation du tag aux machines: "  -NoNewline
        $Machines = Get-CtxMachine -DeliveryGroup $DeliveryGroup -AdminAddress $AdminAddress
        $Machines | ForEach-Object {
            If ($_.HostedMachineName -match ".*1\d{2}$") { Get-BrokerTag -Name SiteA | Add-BrokerTag -Machine $_ }
            ElseIf ($_.HostedMachineName -match ".*2\d{2}$") { Get-BrokerTag -Name SiteB | Add-BrokerTag -Machine $_ }
        }
        Write-Host $OK -ForegroundColor Green
    } Catch {
        Write-Host $NOK -ForegroundColor Red
        Throw $_
    }

}

Export-ModuleMember Set-CtxScheduledReboot