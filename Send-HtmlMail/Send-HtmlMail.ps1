Function ConvertTo-HtmlTable {
	Param (
        [parameter(mandatory=$false, ValueFromPipeline = $true)]
        [PsObject]$InputObject,
        [String] $PreContent,
        [String] $PostContent,
        [String] $Color = "#eeeeee"
	)

Begin { 
    $Body = [System.Text.StringBuilder]::new()
    If ($PreContent) {
        [void]$Body.AppendLine($PreContent)
    }
    [void]$Body.AppendLine('<table>')
    $n = 0
}
Process {
    If ($n -eq 0) {
        [void]$Body.Append('<tr>')
        Foreach ($Property in ($InputObject[0].PsObject.Properties)) {
            [void]$Body.Append("<th>$($Property.Name)</th>")
        }
        [void]$Body.Append('</tr>')
    }
    Foreach ($Item in $InputObject) {
        $n++
        If ($n%2 -eq 1) {
            [void]$Body.Append("`n<tr style=`"background-color: $Color;`">")
        } Else { [void]$Body.Append("`n<tr>") }

        Foreach ($Property in $Item.PsObject.Properties) {
            If ($Property.Name -match  'Percent') { 
                $Value = $Property.Value
                $Red = '{0:x2}' -f [INt]([Math]::Min([Math]::Max(255*($value/75*100)/100, 0), 255))
                $Green = '{0:x2}' -f [INt]([Math]::Min([Math]::Max(255 * ((100-$value) / 25 *100) / 100, 0), 255))
                $GaugeColor = "$Red$Green" + "00"
                [Void]$body.Append("<td><div class=`"ProgressL`" style=`"width:$Value%;background-color: `#$GaugeColor`">$Value%</div></td>")
            } Else {
                [void]$Body.Append("<td>$($Property.Value)</td>")
            }
        }
        [void]$Body.Append("</tr>")
    }
}
End {
    [void]$Body.AppendLine("`n</table>")
    If ($PostContent) {
        [void]$Body.AppendLine($PostContent)
    }
    $Body.ToString()
}

}

Function New-HtmlSubTitle {
	Param (
        [parameter(mandatory=$false, ValueFromPipeline = $true)]
        [String]$Text,
        [String] $mainColor = "#505050",
        [String] $SubColor = "#e46c0a"
	)

    $Body = [System.Text.StringBuilder]::new()
    [void]$Body.AppendLine('<table>')
    [void]$Body.AppendLine('<tr>')
    [void]$Body.AppendLine('    <td style="text-align: left; padding:5px 10px 10px 10px;">')
    [void]$Body.AppendLine("        <div style=`"border-bottom: 2px solid $SubColor; display:inline-block;width:100%;`">")
    [void]$Body.AppendLine("                <strong style=`"color: $mainColor;`">")
    [void]$Body.AppendLine('                <span style="font-size: 1.1em; color: #e46c0a;">///</span>')
    [void]$Body.AppendLine("                    &nbsp;$Text")
    [void]$Body.AppendLine('                </strong>')
    [void]$Body.AppendLine('        </div>')
    [void]$Body.AppendLine('    </td>')
    [void]$Body.AppendLine('</tr>')
    [void]$Body.AppendLine('</table>')

    Return $Body.ToString()

}

Function New-MailImageLinker {
	Param (
        [String] $Path,
        [String] $Id
	)

    [byte[]] $reader = [System.IO.File]::ReadAllBytes($Path);
    $Image = [System.IO.MemoryStream]::new($reader);

    $imagelink = [System.Net.Mail.LinkedResource]::new($Image, [System.Net.Mime.MediaTypeNames+Image]::Jpeg)
    $imagelink.ContentId = $Id
    $imagelink.TransferEncoding = [System.Net.Mime.TransferEncoding]::Base64

    Return $imagelink

}

Function Send-htmlMail{
    Param(
		[Parameter(Mandatory=$False)][string]$From = "INFRA_VIRTUALISATION_EMEA_AUTOMATION@corp.bnpparibas.com",
		[Parameter(Mandatory=$true)][string[]]$To,
		[Parameter(Mandatory=$true)][string]$Subject,
        [Parameter(Mandatory=$False)][string]$Title,
		[Parameter(Mandatory=$true)][string[]]$Body,
        [Parameter(Mandatory=$False)][string]$SmtpServer = 'vip-parapop.fr.net.intra'
    )
    $head = @"
<head>
<meta http-equiv="Content-Type" content="text/html; charset=us-ascii">
<!--[if gte mso 9]><xml>
 <o:OfficeDocumentSettings>
  <o:AllowPNG/>
  <o:PixelsPerInch>96</o:PixelsPerInch>
 </o:OfficeDocumentSettings>
</xml><![endif]-->

<style type="text/css">
body { margin-left: 10%; margin-right: 10%; min-width:260px; color: #505050; background-color:#E3E3E3; font-family: "BNPP Sans Light", Arial, sans-serif; font-size:9pt }

h1 {font-family: "BNPP Sans Light", Arial, sans-serif; font-size: 12pt ;font-weight:bold;vertical-align: text-bottom;}
h2 {font-family: "BNPP Sans Light", Arial, sans-serif; color: #b5482a; font-size: 11pt ;font-weight:bold}
h3 {font-family: "BNPP Sans Light", Arial, sans-serif; color: #2e6c80; font-size: 10pt ;font-weight:bold}
table {font-family: Arial, sans-serif; background-color:White;border-collapse: collapse; width: 100%;}
th {
    background: #395870;
    background: linear-gradient(#49708f, #293f50);
    color: #fff;
    font-size: 11px;
    text-transform: uppercase;
    padding: 5px 10px 5px 10px;
    vertical-align: middle;
    text-align: center;
}
td { border: 2px solid white; padding: 4px; text-align: center}

td.ProgressL {
    border: solid 0px;
    padding: 0px;
    height:15px;
    float:left;
}
strong {
    font-family: "BNPP Sans Light", Geneva, sans-serif; 
    font-size: 1.5em;
}
p {
    font-family: "BNPP Sans Light", Geneva, sans-serif; 
    font-size: 1.1em;
}
</style>
</head>
"@
    $nbody = [System.Text.StringBuilder]::new()
  # add meta data
    [Void]$nBody.AppendLine('<html lang="fr" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">')
  # insert header
    [Void]$nBody.AppendLine($head)
  # start body, main table.
    [Void]$nBody.AppendLine('<body>')
    #[Void]$nBody.AppendLine('<table width="800" border="0" cellspacing="0" cellpadding="0" style="width:800px; margin:0px auto;" align="center">')
    [Void]$nBody.AppendLine('<table border="0" style="margin: 10px 30px 10px 30px; width: 95%;"><tbody><tr><td style="text-align: left; padding:24px; width: 95%;">')

#region Add Title on the Banner
    [void]$nBody.AppendLine('<table>')
    [void]$nBody.AppendLine('<tr>')
    [void]$nBody.AppendLine("  <td background=`"cid:Banner`" bgcolor=`"transparent`" width=`"800`" height=`"100`" valign=`"top`" style=`"background:url('cid:Banner') no-repeat top center; background-image:url('cid:Banner'); background-position:top center; background-repeat:no-repeat; width:800px; height:100px; vertical-align:top;`">")
  # add singularities for ms outlook greater then 2000.
    [void]$nBody.AppendLine('    <!--[if gte mso 9]>')
    [void]$nBody.AppendLine('      <v:rect xmlns:v="urn:schemas-microsoft-com:vml" fill="true" stroke="false" style="width:800px;height:100px;">')
    [void]$nBody.AppendLine('      <v:fill type="frame" src="cid:Banner" />')
    [void]$nBody.AppendLine('      <v:textbox inset="0,0,0,0">')
    [void]$nBody.AppendLine('    <![endif]-->')
  # add the content over the banner
    [void]$nBody.AppendLine('<div>')
    [void]$nBody.AppendLine('  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color:transparent; width:100%; margin:0px auto;" align="center">')
    [void]$nBody.AppendLine('   <tr>')
    [void]$nBody.AppendLine('     <td style="border:none;line-height:1px; font-size:1px; width:10px;" width="10">&nbsp;</td>')
    [void]$nBody.AppendLine('     <td style="border:none; padding:10px 0;">')
    [void]$nBody.AppendLine('       <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color:transparent; width:100%; margin:0px auto;" align="center">')
    [void]$nBody.AppendLine('         <tr>')
    [void]$nBody.AppendLine('           <td style="border:none; line-height:1px; font-size:1px; width:10px;" width="10">&nbsp;</td>')
    [void]$nBody.AppendLine("           <td style=`"border:none; padding:10px 0;`"><h1 style=`"text-align:center;line-height:140%; margin:0px; padding:0px;`">$Title</h1></td>")
    [void]$nBody.AppendLine('           <td style="border:none; line-height:1px; font-size:1px; width:10px;" width="10">&nbsp;</td>')
    [void]$nBody.AppendLine('         </tr>')
    [void]$nBody.AppendLine('       </table>')
    [void]$nBody.AppendLine('     </td>')
    [void]$nBody.AppendLine('     <td style="border:none; line-height:1px; font-size:1px; width:10px;" width="10">&nbsp;</td>')
    [void]$nBody.AppendLine('   </tr>')
    [void]$nBody.AppendLine(' </table>')
    [void]$nBody.AppendLine('</div>')
    [void]$nBody.AppendLine('')
  # close singularities for ms outlook greater then 2000.
    [void]$nBody.AppendLine('<!--[if gte mso 9]>')
    [void]$nBody.AppendLine('  </v:textbox>')
    [void]$nBody.AppendLine('  </v:rect>')
    [void]$nBody.AppendLine('<![endif]-->')
  
    [void]$nBody.AppendLine('        </td>')
    [void]$nBody.AppendLine('      </tr>')
    [void]$nBody.AppendLine('</table>')
    #endregion Title on the banner
  # Close main table, body
    [Void]$nBody.AppendLine($Body)
    [Void]$nBody.AppendLine('</td></tr></tbody></table>')
    [Void]$nBody.AppendLine('</body>')
#region Signature
    [Void]$nBody.AppendLine('<body>')
    [Void]$nBody.AppendLine('  <p><br>Regards,</p>')
    [Void]$nBody.AppendLine('  <table width="100" border=0 style="width:200px;border-collapse:collapse;border:none;background-color:transparent">')
    [Void]$nBody.AppendLine('  <tr>')
    [Void]$nBody.AppendLine('  <td width="27" style="width:27px;border:none">')
    [Void]$nBody.AppendLine('  <p>')
    [Void]$nBody.AppendLine('  <a href="mailto:emea.cib.itip.vmware@bnpparibas.com">')
    [Void]$nBody.AppendLine('  <span style="color:windowtext;text-decoration:none"><img border=0 width=25 height=25 src="cid:mailto ">')
    [Void]$nBody.AppendLine('  </span>')
    [Void]$nBody.AppendLine('  </a>')
    [Void]$nBody.AppendLine('  </p>')
    [Void]$nBody.AppendLine('  </td>')
    [Void]$nBody.AppendLine('   <td style="text-align: left;padding: 0px 5px 0px 5px;border:none">')
    [Void]$nBody.AppendLine('  <p><a href="mailto:emea.cib.itip.vmware@bnpparibas.com">Team VmWare</a></p>')
    [Void]$nBody.AppendLine('  </td>')
    [Void]$nBody.AppendLine('  </tr>')
    [Void]$nBody.AppendLine('  </table>')
    [Void]$nBody.AppendLine("  <p>This was an automated message from monitoring portal on $env:COMPUTERNAME.</p>")
    [Void]$nBody.AppendLine("  <p>Creation Date: $(Get-Date)</p><br>")
    [Void]$nBody.AppendLine('</body>')
#endregion Signature
    [Void]$nBody.AppendLine('</html>')

    $banner = New-MailImageLinker -Path "C:\Users\GENEUMADADMINFVMW28\Documents\Projects\mshypervmanagement\Images\BNP_Banner.png" -Id Banner
    $mailtoImg = New-MailImageLinker -Path "C:\Users\GENEUMADADMINFVMW28\Documents\Projects\mshypervmanagement\Images\mailto.png" -Id mailto

    $htmlView = [System.Net.Mail.AlternateView]::CreateAlternateViewFromString($nbody, $null, "text/html")
    $htmlView.LinkedResources.Add($banner)
    $htmlView.LinkedResources.Add($mailtoImg)

    $From = [mailaddress]::new($From, "Vmware Team").ToString()
    $emailMsg = [System.Net.Mail.MailMessage]::new()
    $emailMsg.From = $From 
    $emailMsg.Sender = $From 
    $emailMsg.ReplyToList.Add([mailaddress]::new("emea.cib.itip.vmware@bnpparibas.com", "Vmware Team"))

    Foreach ($Dest in $to) { $emailMsg.To.Add($Dest) }
    $emailMsg.Subject = $Subject
    $emailMsg.Body = $nbody
    $emailMsg.BodyEncoding = [System.Text.Encoding]::ASCII
    $emailMsg.IsBodyHtml = $true
    $emailMsg.AlternateViews.Add($htmlView)

    #$emailMsg.Attachments.Add("$PSScriptRoot\$AttachmentFile")
    #$emailMsg.Headers.Add("In-Reply-To", "<emea.cib.itip.vmware@bnpparibas.com>")

    $smtpClient = [System.Net.Mail.SmtpClient]::new($SmtpServer)
    $smtpClient.Send($emailMsg)

}
