Function Invoke-Parallel {
<#
    .SYNOPSIS
        Exécute des scripts PowerShell en parallèle sur plusieurs ordinateurs.

    .DESCRIPTION
        La fonction `Invoke-Parallel` permet d'exécuter des scripts PowerShell en parallèle sur plusieurs ordinateurs, ce qui permet d'optimiser les performances lors du traitement de tâches simultanées sur un grand nombre de machines. Elle utilise des runspaces pour exécuter les scripts de manière asynchrone, ce qui permet de réduire le temps d'exécution global.

    .PARAMETER Computername
        Spécifie les noms des ordinateurs sur lesquels exécuter les scripts. Vous pouvez fournir une liste d'ordinateurs en utilisant une chaîne de caractères ou une variable contenant les noms des ordinateurs. Si ce paramètre n'est pas spécifié, la fonction utilise le nom de l'ordinateur local par défaut.

        Le paramètre `Computername` peut être alimenté de deux manières différentes :
    
        1. Par le pipeline : Vous pouvez transmettre une liste d'ordinateurs via le pipeline. Dans ce cas, la fonction exécute le script sur chaque ordinateur de la liste.
    
        2. En spécifiant explicitement les ordinateurs : Vous pouvez fournir une liste d'ordinateurs en tant qu'argument du paramètre `Computername`. Dans ce cas, la fonction exécute le script sur chaque ordinateur spécifié.

    .PARAMETER Throttle
        Définit le nombre maximal de threads simultanés à utiliser pour exécuter les scripts en parallèle. La valeur par défaut est 10.

    .PARAMETER TotalCount
        Indique le nombre total d'ordinateurs sur lesquels les scripts seront exécutés. Cette information est utilisée pour afficher la progression de l'exécution des scripts. 
        
        Ce paramètre est facultatif lorsque les noms des ordinateurs sont spécifiés explicitement via le paramètre `Computername`.

        Lorsque vous fournissez explicitement une liste d'ordinateurs via le paramètre `Computername`, vous n'avez pas besoin de spécifier le paramètre `TotalCount`. Dans ce cas, la fonction détermine automatiquement le nombre total d'ordinateurs à partir de la liste fournie.

    .PARAMETER ScriptBlock
        Spécifie le script PowerShell à exécuter sur chaque ordinateur. Ce script peut contenir des instructions à exécuter sur chaque machine. Assurez-vous de protéger la variable `$Computername` dans le script avec un backtick (`) pour éviter qu'elle ne soit évaluée localement. Par exemple :

        ```
        Invoke-Parallel -Computername "Server01", "Server02", "Server03" -ScriptBlock { Get-Service -Name WinRM -Computername `$Computername }
        ```

        Cela garantit que la variable `$Computername` est correctement passée à la commande `Get-Service` sur chaque ordinateur de manière appropriée.

    .PARAMETER Parameters
        Fournit des paramètres supplémentaires à passer au script PowerShell spécifié dans le paramètre `ScriptBlock`.

    .PARAMETER Variables
        Spécifie des variables à rendre disponibles dans l'environnement du script PowerShell exécuté sur chaque ordinateur.

    .PARAMETER ImportModules
        Spécifie les modules PowerShell à importer dans l'environnement du script exécuté sur chaque ordinateur. Vous pouvez fournir une liste de noms de modules à importer.

    .PARAMETER Sleep
        Définit le délai en millisecondes entre chaque vérification de l'état des runspaces. Ceci peut être utilisé pour ajuster la vitesse de traitement des scripts en parallèle. La valeur par défaut est 100.

    .EXAMPLE
        Invoke-Parallel -Computername "Server01", "Server02", "Server03" -ScriptBlock { Get-Service -Name WinRM -Computername `$Computername }

        Exécute la commande `Get-Service -Name WinRM` sur les ordinateurs "Server01", "Server02" et "Server03" en parallèle.

    .EXAMPLE
        "Server01", "Server02", "Server03" | Invoke-Parallel -ScriptBlock { Get-Service -Name WinRM -Computername '$Computername' }

        Exécute la commande `Get-Service -Name WinRM` sur les ordinateurs "Server01", "Server02" et "Server03" en parallèle en utilisant le pipeline pour fournir les noms des ordinateurs.

    .EXAMPLE
        Utilisez un scriptblock qui nécessite la variable `$Computername` protégée :

        ```
        $ScriptBlock = [scriptblock]::Create("
        param(
        `$ComputerName
        )
        Echo `$computername >> c:\temp\log.txt
        Get-Service -Name WinRM -ComputerName `$computername 
        ")

        Invoke-Parallel -Computername "Server01", "Server02", "Server03" -ScriptBlock $ScriptBlock
        ```
    
    .NOTES
        Auteur : Mickael ROY
        Date de création : [Date de création]
#>
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline = $True,ValueFromPipeLineByPropertyName = $True)]
        [Alias('CN','__Server','IPAddress','Server')]
        [String[]]$Computername = $Env:Computername,

        [int]$Throttle = 10,

        [int]$TotalCount,

        [Scriptblock]$ScriptBlock,

        [PSObject]$Parameters,

        [HashTable]$Variables,

        [String]$ImportModules,

        [int]$Sleep = 100
    )

    Begin {

        [Int32]$nbloop = 0
        [Int32]$Global:nbdone = 0

        If ($PSBoundParameters['ImportModules']) {
            $ModulesPaths = [System.Collections.ArrayList]::new()
            Foreach ( $Modules in $ImportModules ) {
                [VOID]$ModulesPaths.Add((Get-Module $Modules).ModuleBase)
            }
        }

      # Function that will be used to process runspace jobs
        Function Get-RunspaceData {
            [cmdletbinding()]
            Param(
                [Switch]$Wait
            )

            Do {
                $more = $false
                Foreach( $runspace in $runspaces ) {

                    If ($runspace.Runspace.isCompleted) {
                        $Objs = $runspace.Powershell.EndInvoke($runspace.Runspace)
                        $Objs

                        $runspace.Powershell.Dispose()
                        $runspace.Runspace = $null
                        $runspace.Powershell = $null
                        $Script:i++
                        [System.GC]::Collect()
                    } ElseIf ( $runspace.Runspace -ne $null ) {
                        $more = $true
                    }
                }
                If ($more -AND $PSBoundParameters['Wait']) {
                    Start-Sleep -Milliseconds $Sleep
                }
                # Clean out unused runspace jobs
                $colTemphash = $runspaces.Clone()
                $colTemphash | Where-Object { $_.Runspace -eq $Null } | ForEach-Object {
                    If ( $TotalCount ) {
                        $Global:nbdone++
                        Write-Progress -Activity "Script $ScriptName in Progress" -Status "Handled servers : $nbdone/$nbloop/$TotalCount -- Process done on $($_.Computer)" -PercentComplete $($nbdone/$TotalCount*100)
                    }
                    Write-Verbose ("Removing {0}" -f $_.Computer)
                    $Runspaces.Remove($_)
                }
            } while ($more -AND $PSBoundParameters['Wait'])
        }

      # Define hash table for Get-RunspaceData function
        $runspacehash = @{}

        Write-Verbose ("Creating runspace pool and session states")
        $sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
        If ($Variables) {
            $sessionstate.Variables.Add( 
                ([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('Variables', $Variables, $null)) 
            ) 
        }

      # Import the specified modules
        If ($PSBoundParameters['ImportModules']) {
         Write-Verbose (" There is/are $($ImportModules.count) module(S) to load {0}" -f $_.Computer)
            If ($ImportModules.count -gt 0) { 
                Foreach($ModulePath in $ModulesPaths) {
                    Write-Verbose ("Importing module $ModulePath {0}" -f $_.Computer)
                    $sessionstate.ImportPSModule($ModulePath) 
                } 
            }
        }
     
      # Create the pool of runspace - the pool cannot get more runspace than the value #throttle
        $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
        $RunspacePool.Open()

        Write-Verbose ("Creating empty collection to gather runspace jobs")
        $Script:runspaces = [System.Collections.ArrayList]::new()
    }
    Process {
        If ($_ -eq $null) { $TotalCount = $Computername.Count }
        If ( $TotalCount ) {
            Write-Progress -Activity "Script $ScriptName in Progress" -Status "Handled servers : $nbdone/$nbloop/$TotalCount" -PercentComplete $($nbdone/$TotalCount*100)
        }

        ForEach ($Computer in $Computername) {
          # Create the powershell instance and supply the scriptblock with the other parameters
            $PowerShell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($Computer)

          # Add the parameters requested by the scriptblock
            If ($Parameters) {
                [Void]$PowerShell.AddArgument($Parameters)
            }

          # Add the runspace into the powershell instance
            $PowerShell.RunspacePool = $RunspacePool
            
          # Create a temporary collection for each runspace
            $colTemp = "" | Select-Object PowerShell,Runspace,Computer
            $colTemp.Computer = $Computer
            $colTemp.PowerShell = $PowerShell

          # Save the handle output when calling BeginInvoke() that will be used later to end the runspace
            $colTemp.Runspace = $powershell.BeginInvoke()
            Write-Verbose ("Adding {0} collection" -f $colTemp.Computer)
            [Void]$runspaces.Add($colTemp)
            $nbloop++
            Write-Verbose ("Checking status of runspace jobs")
            Get-RunspaceData @runspacehash
        }
    }
    End {
        Write-Verbose ("Finish processing the remaining runspace jobs: {0}" -f (@(($runspaces | Where-Object {$_.Runspace -ne $Null}).Count)))
        $runspacehash.Wait = $true
        Get-RunspaceData @runspacehash

        Write-Verbose ("Closing the runspace pool")
        $RunspacePool.Close()
        $RunspacePool.Dispose()
    }
}