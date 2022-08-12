Function Set-RegistryValue {
    <#
        .SYNOPSIS
         Sets a value from a registry key.

        .DESCRIPTION
         Sets the value from a registry key.

        .PARAMETER ComputerName
         Specifies the name of the server for remote execution.

        .PARAMETER RegPath
         Specifies the path to the registry key including the hive.
         If the hive is not specified, HKLM is set by default.

        .PARAMETER RegValue
         Specifies the name of the value.

        .PARAMETER RegData
         Specifies the value.

        .EXAMPLE
         Set-RegistryValue -ComputerName srvparclu01 -RegPath "SOFTWARE\BUILD\parameters" -RegValue "DISTSERVER" -RegData GWMMKTPARPFIL

        .EXAMPLE
         Set-RegistryValue -ComputerName srvparclu01 -RegPath "HKLM\SOFTWARE\BUILD\parameters" -RegValue "DISTSERVER" -RegData GWMMKTPARPFIL

        .NOTES
           Author: Mickael ROY
           Date: 2021-07-21T09:17:00

         The script will use .Net to access remote registry
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipeLineByPropertyName=$True, HelpMessage="ComputerName")]
        [Alias('ServerName', 'HostName')]
        [String]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Position=0, Mandatory=$True, HelpMessage="Registry Path")]
        [Alias('Path')]
        [string]$RegPath,

        [Parameter(Position=1, Mandatory=$True, HelpMessage="Value Name")]
        [Alias('Name')]
        [string]$RegValue,

        [Parameter(Position=2, Mandatory=$True, HelpMessage="Value Data")]
        [Alias('Data')]
        [object]$RegData,

        [Parameter(Position=3, Mandatory=$False, HelpMessage="Value Type")]
        [Alias('Type')]
        [Microsoft.Win32.RegistryValueKind]$RegType = [Microsoft.Win32.RegistryValueKind]::None

    )
    Try { 
        $HostEntry = [System.Net.Dns]::GetHostEntry($ComputerName)
        $Hostname = $HostEntry.HostName
    }
    Catch {
        Throw "unresolvable($computername)" 
    }
    
    Switch -Wildcard ($RegPath) {
        "HKEY_LOCAL_MACHINE*" {
            $RegHive = [Microsoft.Win32.RegistryHive]::LocalMachine
            $Regpath = $Regpath.Substring($RegPath.IndexOf([System.IO.Path]::DirectorySeparatorChar)+1)
        }
        "HKLM*" {
            $RegHive = [Microsoft.Win32.RegistryHive]::LocalMachine
            $Regpath = $Regpath.Substring($RegPath.IndexOf([System.IO.Path]::DirectorySeparatorChar)+1)
        }
        "HKEY_USERS*" {
            $RegHive = [Microsoft.Win32.RegistryHive]::Users
            $Regpath = $Regpath.Substring($RegPath.IndexOf([System.IO.Path]::DirectorySeparatorChar)+1)
        }
        "HKU*" {
            $RegHive = [Microsoft.Win32.RegistryHive]::Users
            $Regpath = $Regpath.Substring($RegPath.IndexOf([System.IO.Path]::DirectorySeparatorChar)+1)
        }
        "HKEY_CLASSES_ROOT*" {
            $RegHive = [Microsoft.Win32.RegistryHive]::ClassesRoot
            $Regpath = $Regpath.Substring($RegPath.IndexOf([System.IO.Path]::DirectorySeparatorChar)+1)
        }
        "HKCR*" {
            $RegHive = [Microsoft.Win32.RegistryHive]::ClassesRoot
            $Regpath = $Regpath.Substring($RegPath.IndexOf([System.IO.Path]::DirectorySeparatorChar)+1)
        }
        "HKEY_CURRENT_CONFIG*" {
            $RegHive = [Microsoft.Win32.RegistryHive]::CurrentConfig
            $Regpath = $Regpath.Substring($RegPath.IndexOf([System.IO.Path]::DirectorySeparatorChar)+1)
        }
        "HKCC*" {
            $RegHive = [Microsoft.Win32.RegistryHive]::CurrentConfig
            $Regpath = $Regpath.Substring($RegPath.IndexOf([System.IO.Path]::DirectorySeparatorChar)+1)
        }
        Default { $RegHive = 'LocalMachine' }
    }

    $regKeyOp = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegHive, $Hostname)
    $regKey = $regKeyOp.OpenSubKey($RegPath, $True)
    Try {
        If ([Microsoft.Win32.RegistryValueKind]$RegType -ne 'None') { 
            $DataType = $RegType
        } Else {
            $DataType = $regKey.GetValueKind($RegValue)
        }
        $regKey.SetValue($RegValue, $RegData, $DataType)
        $Data = $regKey.GetValue($RegValue)

        $obj = New-Object PSObject
        $obj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Hostname.Split(".")[0].ToUpper()
        $obj | Add-Member -MemberType NoteProperty -Name Value -Value $RegValue

        If ($Null -ne $Data) {
                $obj | Add-Member -MemberType NoteProperty -Name Data -Value $Data
                $obj | Add-Member -MemberType NoteProperty -Name Type -Value $DataType
        } Else {
            Throw "Value not found"
        }

    } Catch [System.UnauthorizedAccessException] {
        Write-warning "Unable to access to the specified path (ACCESS DENIED)"
        Throw $_

    } Catch {
        Write-Warning "A non managed error occured while accessing the specified path."
        throw $_
    }
        $Obj.PsTypeNames.Insert(0,'ToolSet.RegValue')
        Return $obj
}