Function Update-CtxMachineCatalog {
<#
    .SYNOPSIS
    Met à jour un catalogue de machines Citrix avec les dernières modifications de l'image maître.

    .DESCRIPTION
    La fonction Update-CtxMachineCatalog met à jour un catalogue de machines Citrix avec les dernières modifications de l'image maître.
    Elle crée un snapshot de l'image maître si nécessaire, puis le publie dans le catalogue de machines spécifié.

    .PARAMETER MachineCatalog
    Spécifie le nom du catalogue de machines à mettre à jour.

    .PARAMETER DDCs
    Spécifie les contrôleurs de livraison Citrix auxquels se connecter pour effectuer la mise à jour. Par défaut, les contrôleurs de livraison 'xendc102.contoso.fr' et 'xendc202.contoso.fr' sont utilisés.

    .PARAMETER vCenterUser
    Spécifie le nom de l'utilisateur à utiliser pour se connecter au serveur vCenter. Par défaut, 'svc_vcenter_RO_Script_Snap' est utilisé.

    .PARAMETER vCenterServer
    Spécifie le nom du serveur vCenter auquel se connecter. Par défaut, 'pavcenter001.contoso.fr' est utilisé.

    .PARAMETER SnapShotRetentionDelay
    Spécifie la durée de rétention, en jours, du dernier snapshot du template.
    Si un snapshot existe déjà et que sa date de création est inférieure à ce nombre de jours, il sera considéré comme valide et ne sera pas recréé.
    Par défaut, le délai est de 1 jour.

    .SWITCH ForceSnapShot
    Indique si un nouveau snapshot doit être créé, même s'il existe déjà un snapshot récent.

    .INPUTS
    Aucune entrée requise. Vous devez spécifier les paramètres requis.

    .OUTPUTS
    System.Object
    La fonction renvoie un objet contenant les détails de la tâche de publication.

    .EXAMPLE
    Update-CtxMachineCatalog -MachineCatalog "Catalogue1" -DDCs "xendc102.contoso.fr", "xendc202.contoso.fr"
    Met à jour le catalogue de machines "Catalogue1" en utilisant les contrôleurs de livraison spécifiés.

    .NOTES
    Auteur : Mickael ROY
    Date de création : 28/03/2024
    Dernière modification: 30/09/2024

    .LINK
        Lien vers la page confluence : https://confluence.contoso.com/x/wA_aLQ

#>
    [CmdletBinding(
        SupportsShouldProcess=$true,
        HelpUri = 'https://support.citrix.com/article/CTX129205',
        ConfirmImpact='High'
    )]

    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline = $True , ValueFromPipelineByPropertyName = $True, HelpMessage='Specify the machine catalog name')]
        [Alias("BrokerCatalog", "MachineCatalog")]
        [String[]]$CatalogName,

        [Parameter(Mandatory=$false)]
        [Alias("AdminAddress")]
        [String[]]$DDCs = @('xenddc101.contoso.fr', 'xenddc201.contoso.fr'),

        [Parameter(Mandatory=$false)]
        [String] $vCenterUser = 'svc_vcenter_RO_Script_Snap',

        [Parameter(Mandatory=$false)]
        [String] $vCenterServer = 'vcenter001.contoso.fr', 

        [Switch] $ForceSnapShot, 

        [Int] $SnapShotRetentionDelay = 0,

        [ValidateRange(30, 900)]
        [Int] $WaitForShutdown = 300
    )
    Begin {

        $ErrorActionPreference = 'Stop'

        Function Test-Date {
            param (
                [datetime]$date
            )

            # Obtenir la date d'aujourd'hui, d'hier et d'avant-hier
            $aujourdhui = Get-Date
            $hier = $aujourdhui.AddDays(-1).Date
            $avantHier = $aujourdhui.AddDays(-2).Date

            # Comparer la date donnée
            Switch ($date.Date) {
                { $_ -eq $aujourdhui.Date } { Return "0" }
                { $_ -eq $hier } { Return "1" }
                { $_ -eq $avantHier } { Return "2" }
                { $_ -lt $avantHier } { Return "3+" }
                default { Return "Future date" }
            }
        }
        Function Get-TimeSpanPretty {
        <#
        .Synopsis
           Displays the time span between two dates in a single line, in an easy-to-read format
        .DESCRIPTION
           Only non-zero weeks, days, hours, minutes and seconds are displayed.
           If the time span is less than a second, the function display "Less than a second."
        .PARAMETER TimeSpan
           Uses the TimeSpan object as input that will be converted into a human-friendly format
        .EXAMPLE
           Get-TimeSpanPretty -TimeSpan $TimeSpan
           Displays the value of $TimeSpan on a single line as number of weeks, days, hours, minutes, and seconds.
        .EXAMPLE
           $LongTimeSpan | Get-TimeSpanPretty
           A timeline object is accepted as input from the pipeline. 
           The result is the same as in the previous example.
        .OUTPUTS
           String(s)
        .NOTES
           Last changed on 28 July 2022
        #>

            [CmdletBinding()]
            Param
            (
                # Param1 help description
                [Parameter(Mandatory,ValueFromPipeline)][ValidateNotNull()][timespan]$TimeSpan
            )

            Begin {}
            Process{

                # Initialize $TimeSpanPretty, in case there is more than one timespan in the input via pipeline
                [string]$TimeSpanPretty = ""
    
                $Ts = [ordered]@{
                    Semaines   = [math]::Floor($TimeSpan.Days / 7)
                    Jours    = [int]$TimeSpan.Days % 7
                    Heures   = [int]$TimeSpan.Hours
                    Minutes = [int]$TimeSpan.Minutes
                    Secondes = [int]$TimeSpan.Seconds
                } 

                # Process each item in $Ts (week, day, etc.)
                foreach ($i in $Ts.Keys){

                    # Skip if zero
                    if ($Ts.$i -ne 0) {
                
                        # Append the value and key to the string
                        $TimeSpanPretty += "{0} {1}, " -f $Ts.$i,$i
                
                    } #Close if
    
                } #Close for
    
            # If the $TimeSpanPretty is not 0 (which could happen if start and end time are identical.)
            if ($TimeSpanPretty.Length -ne 0){

                # delete the last coma and space
                $TimeSpanPretty = $TimeSpanPretty.Substring(0,$TimeSpanPretty.Length-2)
            }
            else {
        
                # Display "Less than a second" instead of an empty string.
                $TimeSpanPretty = "Less than a second"
            }

            $TimeSpanPretty

            } # Close Process

            End {}

        } #Close function Get-TimeSpanPretty

        Try {
        
            If (-not (Get-Module Citrix.Broker.Commands)) {
                Write-Host 'Chargement du module Citrix.Broker.Commands...' -NoNewline
                Import-Module Citrix.Broker.Commands
                Write-Host $OK -ForegroundColor Green
            }
       
            If (-not $global:DefaultVIServers.Isconnected) {
                Write-Host 'Connexion au vCenter... ' -NoNewline
                $vCenterConnectionParameter = @{
                    Server = $vCenterServer
                }
                If ($PSBoundParameters.ContainsKey('vCenterUser')) {
                    $vCenterConnectionParameter.User = $vCenterUser
                }
                $vCenterConnection = Connect-VIServer @vCenterConnectionParameter
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
        $Tasks = [System.Collections.ArrayList]::new()

        $UnicId = ([DateTime]::Now.ToString("yyyyMMddHHmmss"))

    } Process {

        Foreach ($Catalog in $CatalogName) {
            Remove-Variable snap, snaps, LatestSnapshot -ErrorAction SilentlyContinue
            Try {
             # https://support.citrix.com/article/CTX216896
                Write-Host "Déduction du Master Template relatif au MCA $Catalog... " -NoNewline
                $TempResult = Get-ProvScheme -AdminAddress $AdminAddress -ProvisioningSchemeUid (Get-BrokerCatalog -AdminAddress $AdminAddress -Name $Catalog).ProvisioningSchemeId | Select-Object HostingUnitName, MasterImageVM
                If ($TempResult -match '\\(\w+)(\.vm)\\') {
                    $MasterVM = $Matches[1]
                }
                $HostingUnitName = $TempResult.HostingUnitName
                Write-Host $OK -ForegroundColor Green
                Write-Host "Il semble que le Golden Image soit " -NoNewline
                Write-Host $MasterVM -ForegroundColor Yellow
            } Catch {
                Write-Host $NOK -ForegroundColor Red
                Throw $_
            }

            # Récupérer l'état de la VM
            Try {
                Write-Host "Vérification de l'état de la VM: " -NoNewline
                $vm = VMware.VimAutomation.Core\Get-VM -Name $MasterVM -ErrorAction SilentlyContinue
                Write-Host "$OK" -ForegroundColor Green

                If ($vm.PowerState -ne 'PoweredOff') { 
                    Write-Host "Attention la machine virtuelle $MasterVM est $($vm.PowerState)." -ForegroundColor Yellow
             
                    $userChoice = $PSCmdlet.ShouldProcess("$MasterVM","Souhaitez-vous attendre son extinction complète ?")

                    If ($userChoice) {
                        $Chrono = [System.Diagnostics.Stopwatch]::startnew()

                        While ($vm.PowerState -ne 'PoweredOff') {
                            $remainingTime = [Math]::Max(0, [int][Math]::Floor($WaitForShutdown - $Chrono.Elapsed.TotalSeconds))
                            Write-Host "`rMachine en attente d'extinction. $remainingTime secondes restantes.  " -NoNewline
                            If ($Chrono.Elapsed.TotalSeconds -gt $WaitForShutdown) { 
                                Write-Host "`nTrop tard. La golden image doit être à l'arrêt pour pouvoir être déployée.`n" -ForegroundColor Red
                                Return
                                $Chrono.Stop()
                            }

                            $vm = VMware.VimAutomation.Core\Get-VM -Name $MasterVM -ErrorAction SilentlyContinue
                            If ($vm.PowerState -eq 'PoweredOff') {
                                Write-Host "`rLa VM '$MasterVM' est éteinte." -ForegroundColor Green
                                break
                            } Else {
                                $Sleep = If ($remainingTime -gt 10) { 10 } Else { $remainingTime }
                                Start-Sleep -Seconds $Sleep
                            }
                        }
                    } Else {
                         Write-Host "Nous n'irons pas plus loin dans ce cas.`n" -ForegroundColor Yellow
                         Return
                    }
                }
            } Catch {
                Write-Host "$NOK" -ForegroundColor Red
                Throw $_
            }

            If ($PSCmdlet.ShouldProcess("$Catalog","Déploiement du master $MasterVM ?")) {

                $PreviousTasks = Get-ProvTask -AdminAddress $AdminAddress -Type PublishImage | Where-Object { ($_.HostingUnitName -eq $HostingUnitName) -and ($_.TaskStateInformation -eq "Terminated") }
                If ($PreviousTasks) {
                    Try {
                        Write-Host "Suppression des tâches de provisionnement précédemment en échec..."
                        $PreviousTasks| ForEach-Object {
                            If (($_ | Remove-ProvTask) -eq "Success") { Write-Host "Tâche `'$($_.TaskId)`' supprimnée." -ForegroundColor Yellow }
                        }
                    } Catch {
                        Write-Host $NOK -ForegroundColor Red
                        Throw $_
                    }
                }

                Write-Host "Recherche du dernier snapshot sur le vCenter... " -NoNewline
                $LatestSnapshot = VMware.VimAutomation.Core\Get-Snapshot -VM $MasterVM | Sort-Object Created -Descending | Select-Object Name, Id, Created -First 1
                If ($LatestSnapshot) { 
                    Write-Host $OK -ForegroundColor Green
                    [String]$TimeSpanDays = Test-Date ([DateTime]$LatestSnapshot.Created)
                    $TimeSpan = New-TimeSpan -Start ([DateTime]$LatestSnapshot.Created) -End ([DateTime]::Now)

                    Switch ($TimeSpanDays) {
                        "0" { Write-Host "Le dernier snapshot date d'aujourd'hui. " -NoNewline }
                        "1" { Write-Host "Le dernier snapshot date d'hier. " -NoNewline }
                        "2" { Write-Host "Le dernier snapshot date de deux jours. " -NoNewline }
                        "3+" { Write-Host "Le dernier snapshot date de plus de trois jours. " -NoNewline }
                        default { Write-Host "La date du dernier snapshot n'a aucun sens. " -NoNewline }
                    }
                } Else  {
                    Write-Host $WARN -ForegroundColor Yellow
                }

              # Algorithme de snapshot
                $NewSnapshotDescription = "Automated Snapshot completed by Update-CtxMachineCatalog script. Initiated by: $env:USERNAME"
                $NewSnapshotName = "$MasterVM-Citrix_XD_Automated_Deployement_$UnicId"

                If ($ForceSnapShot) { Write-Host "Vous avez demandé un snapshot systématique.";$DoSnap = $true }
                Elseif ($null -eq $LatestSnapshot) { Write-Host "Il n'y a pas encore de snapshot.";$DoSnap = $true }
                ElseIf (($SnapshotRetentionDelay -eq 0) -and ($LatestSnapshot.Name -ne $NewSnapshotName)) { Write-Host "`'SnapshotRetentionDelay`' est à 0, il ne sera donc pas réutilisé.";$DoSnap = $true }
                ElseIf (($SnapshotRetentionDelay -ne 0) -and ($TimeSpanDays -gt $SnapshotRetentionDelay)) { Write-Host "Selon vos critères de rétention, le snapshot trouvé est expiré.";$DoSnap = $true }
                Else { Write-Host "Selon vos critères de rétention le snapshot trouvé est valide";$DoSnap = $False }

                If ($DoSnap) {
                    Try {
                        Write-Host "Création du snapshot `"$NewSnapshotName`"..." -NoNewline
                        $Snap = New-HypVMSnapshot -AdminAddress $AdminAddress -LiteralPath XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm -SnapshotName $NewSnapshotName -SnapshotDescription $NewSnapshotDescription
                        Write-Host $OK -ForegroundColor Green
                    } Catch {
                        Write-Host $NOK -ForegroundColor Red
                        Throw $_
                    }
                } Else {
                    Write-Host "Le snapshot qui sera réutilisé date de $(Get-TimeSpanPretty $TimeSpan)."
                }
            } Else {
                Return
            }

            Try {
                If ([String]::IsNullOrEmpty($Snap)) {
                    If ($null -eq $HostingUnitName -or $null -eq $MasterVM) { 
                        Throw "Un parachute a été déployé, contactez votre expert PowerShell le plus proche."
                    }
                    Write-Host "Recherche du snapshot sur `"XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm`" pour le présenter lors du provisionnement... " -NoNewLine
                    Write-Verbose -Message "Recherche dans: XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm"
                    $Snaps = Get-ChildItem -Recurse -Path XDHyp:\hostingunits\$HostingUnitName\$($MasterVM).vm
                    $Snap = $Snaps[-1].PSPath
                    Write-Host $OK -ForegroundColor Green
                    Write-Host "Le nom du snapshot est $($Snaps[-1].Name) (Id: $($Snaps[-1].Id.Split('-')[-1]))"
                } 

                If ($PSCmdlet.ShouldProcess("$Catalog","Publication de l'image $MasterVM ?")) {
                    Write-Host "Invocation de la publication... " -NoNewLine
                    $PubTask = Publish-ProvMasterVmImage -AdminAddress $AdminAddress -MasterImageVM $Snap -ProvisioningSchemeName $Catalog -RunAsynchronously
                    [Void]$Tasks.Add($PubTask)
                    Write-Host $OK -ForegroundColor Green
                }
            } Catch {
                Write-Host $NOK -ForegroundColor Red
                Throw $_
            }
        }
    } End {
            Return $Tasks
    }
}
 
Export-ModuleMember Update-CtxMachineCatalog