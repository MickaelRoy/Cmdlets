Function Reset-AclInheritance {
<#
.SYNOPSIS
    Réinitialise l'héritage des listes de contrôle d'accès (ACL) pour un objet spécifié et ses enfants récursivement.

.DESCRIPTION
    La fonction Reset-AclInheritance réactive l'héritage des ACL pour un chemin spécifié, en supprimant toutes les listes de contrôle d'accès non héritées. 
    Si l'objet est un dossier, la fonction réinitialise également les ACL de tous les objets enfants de manière récursive.

.PARAMETER Path
    Le chemin de l'objet (fichier ou dossier) pour lequel réinitialiser les ACL.

.EXAMPLE
    PS C:\> Reset-AclInheritance -Path "C:\MonDossier"
    Réactive l'héritage des ACL et supprime toutes les entrées de contrôle d'accès non héritées dans le dossier spécifié et ses sous-dossiers.

.EXAMPLE
    PS C:\> Reset-AclInheritance -Path "C:\MonFichier.txt" -Verbose
    Réactive l'héritage des ACL et supprime toutes les entrées de contrôle d'accès non héritées dans le fichier spécifié. Affiche des messages détaillés.

.EXAMPLE
    PS C:\> Reset-AclInheritance -Path "C:\MonDossier" -WhatIf
    Simule l'exécution de la commande sans effectuer de modifications, affichant ce qui serait changé.

.NOTES
    Cette fonction utilise le paramètre SupportsShouldProcess pour permettre l'utilisation de -WhatIf et -Confirm.

    Auteur : Mickael ROY
    Date   : 2024-06-10

#>

    [CmdletBinding( SupportsShouldProcess=$true, ConfirmImpact='High' )]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, HelpMessage='Specify the path you want to clean')]
        [Alias("FullName")]
        [String]$Path,
        [Switch]$Recurse
    )
    Begin {
    } Process {
        If (-not (Test-Path -LiteralPath $Path)) {
            Write-Error -Message "The object at '$Path' does not exist"
            Return
        }

        Write-Verbose -Message "Getting security descriptor for item at '$Path'"
        $security_descriptor = Get-Acl -LiteralPath $Path
        $changed = $false

        If ($security_descriptor.AreAccessRulesProtected) {
            Write-Verbose -Message "Object at '$Path' has disabled inheritance, re-enabling it"
            $security_descriptor.SetAccessRuleProtection($false, $false)
            $changed = $true
        }

        $acls = $security_descriptor.GetAccessRules($true, $false, [System.Security.Principal.NTAccount])
        Foreach ($ace in $acls) {
            $ace_string = "$($ace.IdentityReference.Value): $($ace.AccessControlType.ToString()) ($($ace.FileSystemRights.ToString()))"
            Write-Verbose -Message "Removing non-inherited ACE at '$Path' - $ace_string"
            $result = $security_descriptor.RemoveAccessRule($ace)
            If (-not $result) {
                Write-Error -Message "Failed to remove non-inherited ACE at '$Path' - $ace_string"
            } Else {
                $changed = $true
            }
        }
        $shouldProcess = $PSCmdlet.ShouldProcess($Path, "Propagation des permissions ?")
        If ($changed) {
            If ($shouldProcess) {
            
                Write-Verbose -Message "Setting new security descriptor for item at '$Path'"
                Set-Acl -LiteralPath $Path -AclObject $security_descriptor
            } Else {
                Write-Verbose -Message "What if: Setting new security descriptor for item at '$Path'"
            }
        } Else {
            Write-Verbose -Message "No changes required to the security descriptor for item at '$Path'"
        }

        If ($Recurse -and $shouldProcess) {
            Try {
                If (Test-Path -LiteralPath $Path -PathType Container) {
                    Write-Host "Traitement recursif sur ${Path}: " -NoNewline
                    Get-ChildItem -LiteralPath $Path -Recurse:$Recurse | ForEach-Object { Reset-AclInheritance -Path $_.FullName -Confirm:$false}
                    Write-Host "OK" -ForegroundColor Green
                }
            } Catch {
                Write-Host "NOK" -ForegroundColor Red
            }
        }
    }
}

Export-ModuleMember Reset-AclInheritance