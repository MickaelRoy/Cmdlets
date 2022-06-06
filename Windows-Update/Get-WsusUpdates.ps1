Function Get-WsusUpdates {
    <#
    .Synopsis
       Get windows updates in pending status.
    
    .DESCRIPTION
       Get windows updates in pending status from a WSUS, the packages can be downloaded to make them installable offline.
    
    .PARAMETER ComputerName
        Specifies the computer name of the client.
    
    .PARAMETER UpdateServer
        Specifies the computer name of wsus.
    
    .PARAMETER DownloadPath
        Specifies where the packages have to be stored.
    
    .PARAMETER Credential
        Specifies the credential allowed to wsus. 
        
    .EXAMPLE
       $hnodes | Get-WsusUpdates -DownloadPath D:\Packages -Credential $PSCredential
       Download all updates pending related to the computers stored in the hnodes variable in the folder D:\Packages
    
    .INPUTS
        System.String
    
    .OUTPUTS
        System.Object
    .LINK
        More at https://mickaelroy.starprince.fr
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true ,HelpMessage = 'Name of the client with pending updates.' )]
        [Alias('Computer','NodeName','Name')]
        [string[]]$ComputerName,

        [Parameter(Mandatory=$true, HelpMessage = 'Name of the Windows Update Server.' )]
        [string]$UpdateServer,

        [Parameter(Mandatory=$false, HelpMessage = 'Location to store the packages files' )]
        [String]$DownloadPath,

        [Parameter(Mandatory=$false, HelpMessage = 'Credentials use to connect to WSUS server' )]
        [pscredential] $Credential
    )
    Begin {

        Try {
            $SessionOption = New-PSSessionOption -SkipCACheck -SkipRevocationCheck
            $Session = New-PSSession -ComputerName $UpdateServer -ErrorAction Stop -UseSSL -SessionOption $SessionOption
        }
        Catch { Throw $_ }
        $Results = [System.Collections.ArrayList]::new()

    }
    Process {
        Foreach ($computers in $ComputerName) {
        Write-Verbose -Message "$computers in progress"
            $ComputerObject = Invoke-Command  -Session $Session -ErrorAction Stop -ScriptBlock {

                [reflection.assembly]::LoadWithPartialName("Microsoft.Updateservices.Administration") | Out-Null
                $wsus = [Microsoft.Updateservices.Administration.AdminProxy]::GetUpdateServer($UpdateServer,$true,8531);

                $computerScope = [Microsoft.Updateservices.Administration.ComputerTargetScope]::new()
                $computerScope.IncludedInstallationStates = [Microsoft.Updateservices.Administration.UpdateInstallationStates]::All
                $ComputerScope.OSFamily = 'Windows'

                $updateScope = [Microsoft.Updateservices.Administration.Updatescope]::new()
                $updateScope.IncludedInstallationStates = 44
                $updateScope.ExcludedInstallationStates = 3
                $updateScope.ApprovedStates = 1

                $ComputerObjects = [System.Collections.ArrayList]::new()

                Foreach ($Computer in $Using:computers) {

                    $ComputerScope.NameIncludes = $Computer
                    $ComputerTargets = $wsus.GetComputerTargets($computerScope)

                    Foreach ($ComputerTarget in $ComputerTargets) {
                        $ComputerObject = $ComputerTarget | Select-Object Id, FullDomainName, IPAddress, Model

                        $updates = $ComputerTarget.GetUpdateInstallationInfoPerUpdate($updateScope) 
                    
                        $Updateobjects = [System.Collections.ArrayList]::new()  
                        ForEach ($update in $updates) {
                            $update = $wsus.GetUpdate($update.UpdateId)
                            [void]$Updateobjects.Add([pscustomobject] @{
                                Update = $update.Title
                                Computername = $ComputerTargets.FullDomainName
                                KB = $update.KnowledgebaseArticles[0]
                                SecurityBulletin = $update.SecurityBulletins[0]
                                IsSuperseded = $update.IsSuperseded
                                File = $update.GetInstallableItems().Files | Where-Object Type -eq SelfContained
                                FileName =($update.GetInstallableItems().Files | Where-Object Type -eq SelfContained).Name
                            })
                        }
                        $ComputerObject | Add-Member -NotePropertyName Updates -NotePropertyValue $Updateobjects
                        [Void]$ComputerObjects.Add($ComputerObject)
                    }
                }
                Return $ComputerObjects
            } # End invoke-command
            [Void]$Results.Add($ComputerObject)
        }
    } # End Process
    End {
        $Session | Remove-PSSession -WhatIf:$false
        If ($Results) {
            If ($DownloadPath) {
                $Jobs = [System.Collections.ArrayList]::new()

                $Groups = $Results | Select-Object -ExpandProperty updates | Select-Object -ExpandProperty File | Select-Object Name, FileUri -Unique
                
                $DownloadListObject = Foreach ($Group in $Groups) {
                        [PsCustomObject]@{
                        Source = $Group.FileUri
                        Destination =  ( ($Group.Name | ForEach-Object { [System.IO.Path]::Combine($DownloadPath,$_ )}) -join "," )
                        }
                }

                $Jobs = $DownloadListObject | Start-BitsTransfer -Asynchronous -Suspended -TransferPolicy Standard -RetryTimeout 120 -RetryInterval 60

                Do {

                    $Jobs = ($jobs | Get-BitsTransfer -ErrorAction SilentlyContinue) # Refresh the list
                    Foreach ($job in $jobs | Where-Object JobState -match 'Suspended|Error|TransientError') {
                        Try {
                            Resume-BitsTransfer -BitsJob $Job -Asynchronous -ErrorAction Stop | Out-Null
                            Write-Verbose -Message "$($Job.JobId) resume requested."
                        } Catch {
                            Throw $_
                        }
                    }

                    Foreach ($job in $jobs | Where-Object JobState -eq 'Transferred') {
                        Try { 
                            Complete-BitsTransfer -BitsJob $Job -ErrorAction Stop
                            Write-Verbose -Message "$($Job.JobId) Completed."
                        } Catch {
                            Throw $_
                        }
                    }

                    If ('Transferring' -in $jobs.JobState) { 
                        Write-Verbose -Message "Waiting two sec to achieve the download."
                        Start-Sleep 2
                    }

                } Until (@($jobs).Count -eq 0)

                If ($null -ne $Results.Updates) {
                    $Results.Updates | ForEach-Object {
                        $FullPath = @()
                        $_.FileName | ForEach-Object { $FullPath += [System.IO.Path]::Combine($DownloadPath,$_) }
                        $_.psobject.properties.Add( [psnoteproperty]::new('FullPath', $FullPath ) )
                    }
                }
                $Results.Updates
            } Else {
                Return $Results
            }
        } Else {
            Write-Warning -Message "No update found or, computer name(s) mismatch."
        }
    }
}
    