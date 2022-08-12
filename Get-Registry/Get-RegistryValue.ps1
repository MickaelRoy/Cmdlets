Function Get-RegistryValue {
    <#
        .SYNOPSIS
         Gets a value from a registry key.

        .DESCRIPTION
         Gets the value from a registry key.

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
         Set-RegistryValue -ComputerName srvparclu01 -RegPath "SOFTWARE\BUILD\parameters" -RegValue "DISTSERVER"

        .EXAMPLE
         Set-RegistryValue -ComputerName srvparclu01 -RegPath "HKLM\SOFTWARE\BUILD\parameters" -RegValue "DISTSERVER"

        .NOTES
           Author: Mickael ROY
           Date: 2021-07-21T09:17:00

         The script will use .Net to access remote registry
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False, HelpMessage="ComputerName")]
        [Alias('ServerName', 'HostName')]
        [String]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory, HelpMessage="Registry Path")]
        [string]$RegPath,

        [Parameter(Mandatory, HelpMessage="Value Name")]
        [string]$RegValue
    )

        Try { 
            $HostEntry = [System.Net.Dns]::GetHostEntry($ComputerName)
            $Hostname = $HostEntry.HostName
        } Catch {
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

        Try {
            $regKeyOp = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegHive, $Hostname)
            $regKey = $regKeyOp.OpenSubKey($RegPath, $False)
        } Catch [System.UnauthorizedAccessException] {
            Write-warning "Unable to access to the specified path (ACCESS DENIED)"
            Throw $_

        } Catch {
            Write-Warning "A non managed error occured while accessing the specified path."
            Throw $_
        }

        If ([String]::IsNullOrEmpty($regKey.Name)) {
            Throw "Path not found"
        }

        Try {
            If ($regKey.GetValueNames() -contains $RegValue) {

                $sValueRefreshed = $regKey.GetValueNames() -iMatch "^$RegValue$"
                $iValueRefreshed = ($regKey.GetValueNames()).indexOf([String]$sValueRefreshed)
                $ValueRefreshed = $regKey.GetValueNames().Item($iValueRefreshed)

                $Data = $regKey.GetValue($RegValue)
                $DataType = $regKey.GetValueKind($RegValue)

                $obj = [PsCustomObject] @{
                    ComputerName = $Hostname.Split(".")[0].ToUpper()
                    Value = $ValueRefreshed
                    Data = $Data
                    Type = $DataType
                }

            } Else {
                Throw [System.Exception]::new("Value not found")
            }

        } Catch {

            Throw $_
        }

        $Obj.PsTypeNames.Insert(0,'ToolSet.RegistryKey')
        Return $obj
    }
