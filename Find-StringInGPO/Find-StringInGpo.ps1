Function Find-StringInGpo {
<#
.SYNOPSIS
    Recherche une chaîne spécifique dans les objets GPO (Objets de Stratégie de Groupe).

.DESCRIPTION
    La fonction `Find-StringInGpo` permet de rechercher une chaîne spécifique dans les objets de Stratégie de Groupe (GPO) de votre environnement Active Directory. Elle peut effectuer une recherche dans tous les GPOs de votre domaine ou dans un emplacement de recherche spécifié.

.PARAMETER String
    La chaîne de caractères à rechercher dans les objets GPO.

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
    Dernière modification : 28/03/2024

.LINK
    Lien de l'aide : https://docs.microsoft.com/fr-fr/powershell/module/grouppolicy/?view=windowsserver2022-ps

#>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [String] $String,

        [Parameter(ParameterSetName ='All')]
        [Switch] $All,

        [Parameter(Mandatory=$true, ParameterSetName ='SearchBase')]
        [String] $SearchBase
    )

    Import-Module GroupPolicy

    If ($All) {
        # Set the domain to search for GPOs 
        $DomainName = $env:USERDNSDOMAIN 
        
        # Find all GPOs in the current domain 
        Write-Host "Finding all the GPOs in $DomainName" 

        $allGpos = Get-GPO -Domain $DomainName -All
    } Else {
        $allGpos = (Get-GPInheritance -Target $SearchBase).InheritedGpoLinks
    }


    [String[]] $MatchedGPOList = @()

    # Look through each GPO's XML for the string 
    Write-Host "Starting search.... " -NoNewline
    Foreach ($gpo in $allGpos) {

        If ($All) {
            $GpoId = $Gpo.Id
        } Else {
            $GpoId = $Gpo.GpoId
        }

        $report = Get-GPOReport -Guid $GpoId -ReportType Xml 
        If ($report -match $string) {
            If($i) { $iLength = $i.tostring().length }
            Write-Host ("`b" * $iLength) -NoNewline
            Write-Verbose "********** Match found in: $($gpo.DisplayName) **********"
            $MatchedGPOList += "$($gpo.DisplayName)"
            $i++
            Write-Host "$i" -NoNewline
        }
    } # end foreach
    
    If ($MatchedGPOList) {
        $iLength = $i.tostring().length
        Write-Host ("`b" * $iLength) -NoNewline
        Write-Host "Found ($i) !`r`n" -ForegroundColor Green
        Return $MatchedGPOList
    }
}
