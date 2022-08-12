Function Get-RegistryLeaf {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False, HelpMessage="ComputerName")]
        [Alias('ServerName', 'HostName')]
        [String]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory, HelpMessage="Registry Path")]
        [string]$RegPath
    )

        Try { 
            $HostEntry = [System.Net.Dns]::GetHostEntry($ComputerName)
            $Hostname = $HostEntry.HostName
        } Catch {
            Throw "unresolvable($ComputerName)" 
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
            
            $Object = Foreach ($Key in $regKey.GetSubKeyNames()) {
                #$Property = [PsCustomObject]::new()
                $SubKey = $regKey.OpenSubKey($Key)
                
                $Obj = $SubKey
                $Obj.psobject.properties.Add( [psnoteproperty]::new('Property', $SubKey.GetValueNames()) )
                $Obj.psobject.properties.Add( [psnoteproperty]::new('ComputerName', $ComputerName) )
                $Obj.psobject.properties.Add( [psnoteproperty]::new('ParentPath', $regKey.Name) )
                $Obj.psobject.properties.Add( [psnoteproperty]::new('Hive', $RegHive) )

                $Obj.PsTypeNames.Insert(0,'ToolSet.RegistryLeaf')
                $Obj
            }


        } Catch {

            Throw $_
        }
        Return $Object

}
