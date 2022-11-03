Function Invoke-InputBox {
<#
    .SYNOPSIS
     Prompts the user with a multi-line input box and returns an object with property values.

    .DESCRIPTION
     Prompts the user with a multi-line input box and returns the text they enter, or null if they cancelled the prompt.

    .PARAMETER OutputPropertyName
     The property name that will be used by the output object.
     If not specified, property values will be : ComputerName, HostName, ServerName, Server, Name.

    .PARAMETER WindowTitle
     The text to display on the prompt window's title.

    .PARAMETER ComputerName
     Specifies computername(s) to fill the InputBox.

    .EXAMPLE
     Get-InputBox | Test-Connection
     This will open the input box so you can paste a server list into it and then send it to command Test-Connection to display information.

    .EXAMPLE
     'ServerNameA' | Invoke-InputBox
     This will put ServerNameA in the InputBox.

    .EXAMPLE
     Server[1..5] | Invoke-InputBox
     This will in put Server1 up to Server5 in the InputBox.

    .NOTES
       Author: Mickael R.
       Date: 2017-04-05 16:28:04 +0200 
#>

    [CmdletBinding()]
    Param (
        [Parameter(HelpMessage="The property name of the output object")]
        [string]$OutputPropertyName = "ComputerName",

        [string]$Message = "Insert a hostname list",

        [string]$WindowTitle = "InputBox",

        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipeLineByPropertyName=$True, HelpMessage="ComputerName")]
        [Alias('HostName','ServerName','Server','Name')]
        $ComputerName
        
    )

    Begin {

        Add-Type -AssemblyName "System"
        Add-Type -AssemblyName "System.Drawing"
        Add-Type -AssemblyName "System.Windows.Forms"

        $height = 320
        $width = 320

        $inputSeparators = "[]/ ,;'`"`n`r`t"
        
        $DefaultTextContent = $Global:InputBoxList

        # Will be used if input object is specified only
        $InputList = [System.Collections.ArrayList]::new()
        
        $script:ResultInputBox = @()

        # Create the Label
        $label = New-Object System.Windows.Forms.Label
        $label.Location = [System.Drawing.Point]::new(10,10)
        $label.Size = [System.Drawing.Size]::new(280,20)
        $label.AutoSize = $true
        $label.Text = $Message
     
        # Create the TextBox used to capture the user's text.
        $textBox = New-Object System.Windows.Forms.RichTextBox
        $textBox.Location = [System.Drawing.Point]::new(10,40)
        $textBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
        $textBox.AcceptsTab = $false
        $textBox.Multiline = $true
        $textBox.ScrollBars = 'Both'
        $textBox.BorderStyle = 'FixedSingle'

        # Create the Cancel button.
        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Size = [System.Drawing.Size]::new(75,25)
        $cancelButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
        $cancelButton.UseVisualStyleBackColor = $True
        $cancelButton.Text = "Cancel"
        $cancelButton.Add_Click({ 
            $form.Tag = $null
            $form.Close()
            $form.Dispose()
        })

        # Create the OK button.
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Size = $cancelButton.Size
        $okButton.Anchor =[System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
        $okButton.UseVisualStyleBackColor = $True
        $okButton.Text = "Ok"
        $okButton.Add_Click({ 
            $form.Tag = $textBox.Text
            # Split the input $form.Tag by any separators defined in $inputSeparators, case insensitive deduplicate, and then create the output
            $form.Tag.Split($inputSeparators,[System.StringSplitOptions]::RemoveEmptyEntries) | Sort-Object -Unique | % {
                $script:ResultInputBox += [PSCustomObject]@{
                    $OutputPropertyName = $_.ToUpper().Trim()
                }
            }
            $Global:InputBoxList = $script:ResultInputBox
            $form.Close()
            $form.Dispose()
        })
     
    
        # Create the form.
        $form = New-Object System.Windows.Forms.Form

        $iconBase64 = 'AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAQAQAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACQYlPRIKTHQPCj5eDgk6WQ4JPFwMCC9KCQYnPQoG
        KUALBy1JBwYjPQEBBg0AAAAAAAAAAAAAAAAAAAAAAAAAAA0JN1MlGKDkKhyw8igaqvApHLH1Jhme
        4BsQcakaD2ykGhFysB4Tgb4QCkNiAAAAAAAAAAAAAAAAAAAAAAAAAAAIBCM5IhiU0DAgzf8qHLf5
        KBuv9Cwdu/8aEXCsGRFvqxoRb6whFY7LIhaPywUDEx4AAAAAAAAAAAAAAAAAAAAACAQiOSIWkcwy
        IdL/HRR+sw4JOloQC0ZpCQUlPwoGK0UKBilECwcuSBYOWosJBCQ/AAAAAAAAAAAAAAAAAAAAAAgE
        IjkjF5HNMyLX/xcPYIoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAMMAwIKFgAAAAAAAAAAAAAA
        AAAAAAAIBCI5IxeRzTMi1v8YEGWQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAACAQiOSMXkc0zItb/GBBlkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAgEIjkjF5HNMyLW/xgQZZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIBCI5IxeRzTMi1v8YEGWQAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAQiOSIWkMwzItf/Fw9mkgAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgEIjkjF5LOMyHW/xYPYYsA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAANCThTKhuu9ykZ
        qecNCDRQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQEEDQg1
        WBgQZpsNCDZRAQEFCwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AQEBBAMCDBwAAAEIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAA=='
        $iconBytes = [Convert]::FromBase64String($iconBase64)
        # initialize a Memory stream holding the bytes
        $stream = [System.IO.MemoryStream]::new($iconBytes, 0, $iconBytes.Length)
        $form.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($stream).GetHIcon()))
        $form.ShowIcon = $True


        $form.Text = $WindowTitle
        $form.CancelButton = $cancelButton
        $form.AcceptButton = $okButton
        $form.MaximizeBox = $false
        $form.Size = [System.Drawing.Size]::new($width,$height)
        $form.BackColor = [System.Drawing.SystemColors]::Control
        $form.ForeColor = [System.Drawing.SystemColors]::ControlText
        $form.Font = [System.Drawing.SystemFonts]::DefaultFont
        #$form.FormBorderStyle = 'SizableToolWindow'
        $form.StartPosition = 'CenterScreen'
        $form.AutoSizeMode = 'GrowAndShrink'
        $form.Topmost = $True
        $form.AcceptButton = $okButton
        $form.CancelButton = $cancelButton
        $form.ShowInTaskbar = $true
        $form.KeyPreview = $true

        $form.Add_KeyDown({
            # $Global:Key = $_ # Astuce pour consigner la combinaison de touche dans une variable
            If (($_.Control) -and ($_.KeyCode -eq [System.Windows.Forms.Keys]::C)) {
                $cancelButton.PerformClick()
            }
        })


        # Add all of the controls to the form.
        $form.Controls.Add($label)
        $form.Controls.Add($textBox)
        $form.Controls.Add($okButton)
        $form.Controls.Add($cancelButton)

        # Initialize and show the form.
        $form.Add_Shown({
            $textBox.Focus()
            $form.Activate()
            
            $textBox.Size = [System.Drawing.Size]::new(($form.clientsize.width -20),($form.clientsize.Height -90))

            $cancelButtonX = $form.clientsize.width - ($cancelButton.Size.Width + 10)
            $cancelButtonY = $form.clientsize.Height - ($cancelButton.Size.Height + 10)
            $cancelButton.Location = [System.Drawing.Point]::new($cancelButtonX,$cancelButtonY)

            $okButtonX = $cancelButtonX - ($okButton.Size.Width + 10)
            $okButtonY = $form.clientsize.Height - ($okButton.Size.Height + 10)
            $okButton.Location = [System.Drawing.Point]::new($okButtonX,$okButtonY)

        })

    } # End Begin
    Process {
        If ($null -ne $ComputerName) {

            If ( $ComputerName -match ".*\[d*.*d*\].*" ) { # Split the entry to allow a range as input (ex [1..5])
                $StartsWith = $ComputerName.Split("[")[0]
                $EndsWith = $ComputerName.Split("]")[-1]
                $Range = $ComputerName.Substring($ComputerName.IndexOf('[')+1,$ComputerName.IndexOf(']')-1-$ComputerName.IndexOf('[')) -Replace "-",".."
                for ( $i = [int]$Range.Split("..",[System.StringSplitOptions]::RemoveEmptyEntries)[0]; $i -le [int]$Range.Split("..",[System.StringSplitOptions]::RemoveEmptyEntries)[1]; $i++ ) {
                    [void]$InputList.Add( [PsCustomObject]@{ComputerName = $StartsWith + $i + $EndsWith})
                }
            }
            ElseIf ( $ComputerName -is [String] ) {
                [void]$InputList.Add( [PsCustomObject]@{ComputerName = $ComputerName} )
            }
            Else {
                [void]$InputList.Add( $ComputerName )
            }
        }
    }
    End {
        If ( $InputList  ) {
            Switch ($InputList[0].psobject.Properties) { # Check the first entry to select only the pertinent property
                {$_.Name -Contains 'ComputerName'} { $textBox.text = ($InputList | Select-Object -ExpandProperty ComputerName ) -join "`n" }
                {$_.Name -Contains 'HostName'} { $textBox.text = ($InputList | Select-Object -ExpandProperty HostName ) -join "`n" }
                {$_.Name -Contains 'ServerName'} { $textBox.text = ($InputList | Select-Object -ExpandProperty ServerName ) -join "`n" }
                {$_.Name -Contains 'Server'} { $textBox.text = ($InputList | Select-Object -ExpandProperty Server ) -join "`n" }
                {$_.Name -Contains 'Name'} { $textBox.text = ($InputList | Select-Object -ExpandProperty Name ) -join "`n" }
            }
        }
        ElseIf ( $DefaultTextContent  ) {
            $textBox.text = ($DefaultTextContent | Select-Object -ExpandProperty $OutputPropertyName) -join "`n"
        }

        $form.Opacity = 0.01
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 10;  #we'll increase the opacity every 10ms
        $timer.add_Tick({
            If ($form.Opacity -eq 1) {
                $timer.Stop()
                $timer.Dispose()
            }
            Else {
                $form.Opacity += 1*$($form.Opacity/15)
            }
        })
        $timer.Start()

        $form.ShowDialog() > $null   # Trash the text of the button that was clicked.
        $form.Dispose()

        # Add default alias to ComputerName if user doesn't use custom $OutputPropertyName
        if ($OutputPropertyName -eq "ComputerName") {
            $script:ResultInputBox | Add-Member -MemberType AliasProperty -Name HostName -Value $OutputPropertyName
            $script:ResultInputBox | Add-Member -MemberType AliasProperty -Name ServerName -Value $OutputPropertyName
            $script:ResultInputBox | Add-Member -MemberType AliasProperty -Name Server -Value $OutputPropertyName
            $script:ResultInputBox | Add-Member -MemberType AliasProperty -Name Name -Value $OutputPropertyName
            $script:ResultInputBox | Foreach { $_.PsTypeNames.Insert(0,'InputBox.Output') }
        }
        
        $script:ResultInputBox
    }
}
