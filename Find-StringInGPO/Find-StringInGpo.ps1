Function Find-StringInGpo {
<#
.SYNOPSIS
    Recherche une chaîne spécifique dans les objets GPO (Objets de Stratégie de Groupe).

.DESCRIPTION
    La fonction `Find-StringInGpo` permet de rechercher une chaîne spécifique dans les objets de Stratégie de Groupe (GPO) de votre environnement Active Directory. Elle peut effectuer une recherche dans tous les GPOs de votre domaine ou dans un emplacement de recherche spécifié.

.PARAMETER Pattern
    Spécifie le texte a rechercher, une chaîne de caractères ou une expression régulière.

.PARAMETER All
    Indique si la recherche doit être effectuée dans tous les GPOs du domaine. Si cette option est spécifiée, la fonction recherche dans tous les GPOs du domaine actuel. Cet argument est un commutateur, il n'accepte pas de valeur.

.PARAMETER SearchBase
    Spécifie l'emplacement à partir duquel effectuer la recherche des GPOs. Il s'agit généralement d'une unité d'organisation (OU) spécifique ou d'un conteneur. Cette option est utilisée lorsque l'argument `All` n'est pas spécifié.

.EXAMPLE
    Find-StringInGpo -String "Audit"
    Recherche la chaîne "Audit" dans tous les GPOs du domaine actuel.

.EXAMPLE
    Find-StringInGpo -String "PasswordPolicy" -SearchBase "OU=Security Policies,DC=contoso,DC=com"
    Recherche la chaîne "PasswordPolicy" dans les GPOs situés dans l'unité d'organisation "Security Policies" de domaine contoso.com.

.EXAMPLE
    Find-StringInGpo -String "Audit" -All
    Recherche la chaîne "Audit" dans tous les GPOs du domaine actuel.

.NOTES
    Auteur : Mickael ROY
    Date : 26/06/2023
    Dernière modification : 19/04/2024

.LINK
    Lien de l'aide : https://docs.microsoft.com/fr-fr/powershell/module/grouppolicy/?view=windowsserver2022-ps

#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias("String")]
        [String] $Pattern,

        [Parameter(ParameterSetName ='All')]
        [Switch] $All,

        [Parameter(Mandatory=$true, ParameterSetName ='SearchBase')]
        [String] $SearchBase
    )

    Import-Module GroupPolicy

    If ($All) {
        # Set the domain to search for GPOs 
        $DomainName = $env:USERDNSDOMAIN.ToLower()
        
        # Find all GPOs in the current domain 
        Write-Host "Finding all the GPOs in $DomainName" 

        $allGpos = Get-GPO -Domain $DomainName -All
    } Else {
        $allGpos = (Get-GPInheritance -Target $SearchBase).InheritedGpoLinks
    }

    # Look through each GPO's XML for the string 
    Write-Host "Starting search.... " -NoNewline
    $Objects = [System.Collections.ArrayList]::new()

    #This Line is useless in a powershell module context. 
    Update-FormatData -PrependPath .\Formats\Brs.GpoString.Format.ps1xml
    $i = 0
    Foreach ($gpo in $allGpos) {
        $Lines = $null
        If ($All) {
            $GpoId = $Gpo.Id
        } Else {
            $GpoId = $Gpo.GpoId.Guid
        }
        Try {
            $report = Get-GPOReport -Guid $GpoId -ReportType Xml -ErrorAction Stop
        } Catch {
            Write-Warning -Message "Impossible de lire la GPO `'$GpoId`', vous n'avez peut être pas les droits."
        }
        $Lines = $report.Split("`n") -match $Pattern
        $Lines = $Lines -notmatch "^<.*\sxmlns"
        If (-not[String]::IsNullOrEmpty($Lines)) {
            If ($i) { $iLength = $i.tostring().length }
            Write-Host ("`b" * $iLength) -NoNewline
            $Object = [PsCustomObject]@{ 
                GroupPolicy = $($gpo.DisplayName)
                Strings  = $Lines.Trim()
            }
            $Object.PsTypeNames.Insert(0,'Brs.GpoString')

            [Void]$Objects.Add($Object)
            $i++
            Write-Host "$i" -NoNewline
        }
    } # end foreach
    
    If ($Objects) {

        $iLength = $i.tostring().length
        Write-Host ("`b" * $iLength) -NoNewline
        Write-Host "Found ($i) !`r`n" -ForegroundColor Green
        Return $Objects
    }
}
