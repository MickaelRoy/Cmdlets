Function Reset-CtxProfileDirectory {
<#
.SYNOPSIS
    Réinitialise un répertoire de profil Citrix en supprimant tout son contenu.

.DESCRIPTION
    Cette fonction réinitialise un répertoire de profil Citrix spécifié en supprimant tous les fichiers et sous-dossiers qu'il contient.
    Elle supporte plusieurs versions de Windows Server pour les répertoires de profils Citrix.

.PARAMETER Path
    (Obligatoire) Chemin du répertoire que vous souhaitez nettoyer. Doit se trouver dans CTXProfiles.

.PARAMETER OSName
    (Obligatoire) Nom du système d'exploitation pour le profil Citrix. Les valeurs acceptées sont :
    - Win2008v1
    - Win2012v2
    - Win2012R2v4
    - Win2016v6
    - Win2019v6
    - Win2022v6

.EXAMPLE
    Reset-CtxProfileDirectory -Path "\\Nas\Ctx\Users\CTXProfiles\User1" -OSName "Win2016v6"
    Réinitialise le répertoire de profil Citrix pour l'utilisateur User1 sous Windows Server 2016.

.EXAMPLE
    Reset-CtxProfileDirectory -Path "\\Nas\Ctx\Users\CTXProfiles\User2" -OSName "Win2019v6"
    Réinitialise le répertoire de profil Citrix pour l'utilisateur User2 sous Windows Server 2019.

.NOTES
    Cette fonction supprime de manière récursive tous les fichiers et dossiers dans le répertoire spécifié.
    Utilisez avec précaution, car cette action est irréversible.
#>

    [CmdletBinding( SupportsShouldProcess=$true, ConfirmImpact='High' )]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, HelpMessage='Specify the path you want to clean')]
        [ValidatePattern("\\\\.*CTXProfiles\\\w*.\w*$")]
        [Alias("FullName")]
        [String]$Path,
        [ValidateSet("Win2008v1","Win2012v2","Win2012R2v4","Win2016v6","Win2019v6","Win2022v6", "ALL")]
        [Parameter(Mandatory=$true)]
        [String]$OSName
    )
    Begin {
        [char[]] $taken = (Get-PSDrive -Name [H-Z]).Name
        [String]$nextAvailable = ([char[]] (72..90)).Where({ $_ -notin $taken }, 'First')

    } Process {
        $ErrorActionPreference = 'stop'
        $ParentPath = ([System.IO.Directory]::GetParent($Path).FullName)
        $w = [System.Diagnostics.Stopwatch]::new()

        Try {
            If (-not (Test-Path $Path)) { Throw "$Path est introuvable" }
            Else {
                Write-Verbose "Montage du lecteur $nextAvailable"
                $PSDrive =  New-PSDrive -Name $nextAvailable -PSProvider FileSystem -Root $ParentPath -Persist -Confirm:$false -WhatIf:$false -ErrorAction Stop
                Write-Verbose "Lecteur $($PSDrive.name) monté"
            }

            If ($OSName -ne 'ALL') { 
                [Array]$ChildedPath = Join-Path -Path $Path -ChildPath $OSName
            } Else { 
                [Array]$ChildedPath = (Get-ChildItem -Directory $Path).FullName
            }
            $ChildedPath.Foreach({
                $CurrentPath = $_

                $P = $CurrentPath.Replace("$ParentPath","\\?\$($PSDrive.Name):")
            
                If (-not (Test-Path $($P.Replace("\\?\","")))) { Write-Warning "$P est introuvable" }
                Else {         

                    If ($PSCmdlet.ShouldProcess("$CurrentPath","Supression du contenu ?")) {

                        Write-Host "Suppression de ${CurrentPath}: " -NoNewline

                        $w.Start()
                        [System.IO.Directory]::EnumerateFiles($P, "*.*", "AllDirectories").Foreach({

                            If ((([System.IO.FileInfo]$_).Attributes -band 3) -in [int]1..3) {
                                ([System.IO.FileInfo]$_).Attributes = [System.IO.FileAttributes]::Normal
                            }
                        })

                        [System.IO.Directory]::EnumerateDirectories($P, "*.*", "AllDirectories").Foreach({
                            If ((([System.IO.FileInfo]$_).Attributes -band 3) -in [int]1..3) {
                                ([System.IO.DirectoryInfo]$_).Attributes = [System.IO.FileAttributes]::Normal
                            }
                        })
                        [System.IO.Directory]::Delete($P,$true)
                        $w.Stop()
                        Write-host "$($w.Elapsed.TotalSeconds)s"
                        $w.Reset()
                    }
                }
            })
            Start-Sleep -Milliseconds 100
            If ("" -eq [System.IO.Directory]::EnumerateFiles($Path) -and "" -eq [System.IO.Directory]::EnumerateDirectories($Path)) { [System.IO.Directory]::Delete($Path) }
            
        } Catch {
            Throw $_
        } Finally {
            If ($null -ne $PSDrive) {
                $PSDrive | Remove-PSDrive -Confirm:$false -Force -WhatIf:$false
            }
        }
    }
    End {
    }
}

Export-ModuleMember Reset-CtxProfileDirectory