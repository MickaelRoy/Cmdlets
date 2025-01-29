Function ConvertTo-HtmlTable {
<#
.SYNOPSIS
Convertit un objet en une table HTML avec des options de couleur et de contenu personnalisé.

.DESCRIPTION
La fonction ConvertTo-HtmlTable prend un objet PowerShell en entrée et le transforme en un tableau HTML. Il est possible de personnaliser la couleur de fond des lignes et d’ajouter un contenu HTML avant ou après la table.

.PARAMETER InputObject
Objet à convertir en table HTML. Accepte l’entrée par pipeline.

.PARAMETER PreContent
Contenu HTML à insérer avant la table (facultatif).

.PARAMETER PostContent
Contenu HTML à insérer après la table (facultatif).

.PARAMETER Color
Couleur de fond des lignes alternées dans le tableau HTML (par défaut : #eeeeee).

.EXAMPLE
Get-Process | ConvertTo-HtmlTable -PreContent "<h2>Liste des processus</h2>" -Color "#d3d3d3"
#>
    [CmdletBinding()]
	Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [PsCustomObject]$InputObject,
        [String] $PreContent,
        [String] $PostContent,
        [String] $Color = "#f9f9f9",
        [String] $HeaderColor = "#003883",
        [String] $MaxWidth = "800px",
        [Switch] $RevertRedGreenGauge
	)

Begin { 
    $Body = [System.Text.StringBuilder]::new()
    If ($PreContent) {
        [void]$Body.AppendLine($PreContent)
    }
    [void]$Body.AppendLine("<table width=`"$MaxWidth`" align=`"center`" style=`"max-width: $MaxWidth; margin: 0 auto;`">")
    $n = 0
}
Process {
    If ($n -eq 0) {
        [void]$Body.Append("<tr style=`"background-color: $HeaderColor;`">")
        Foreach ($Property in ($InputObject[0].PsObject.Properties)) {
            [void]$Body.Append("<th style=`"border: solid 2px $HeaderColor; font-size: 11px; line-height: 1.2;`">$($Property.Name)</th>")
        }
        [void]$Body.Append('</tr>')
    }
    Foreach ($Item in $InputObject) {
        $n++
        If ($n % 2 -eq 1) {
            [void]$Body.Append("`n<tr style=`"background-color: $Color;`">")
        } Else { 
            [void]$Body.Append("`n<tr>") 
        }

        Foreach ($Property in $Item.PsObject.Properties) {
            If ($Property.Name -match  'Percent') { 
                $Value = $Property.Value
                If ($RevertRedGreenGauge) {
                    # Inverser les calculs : Rouge pour les faibles valeurs, vert pour les fortes
                    $Red = '{0:x2}' -f [int]([Math]::Min([Math]::Max(255 * ((100 - $Value) / 25 * 100) / 100, 0), 255))
                    $Green = '{0:x2}' -f [int]([Math]::Min([Math]::Max(255 * ($Value / 75 * 100) / 100, 0), 255))
                } Else {
                    # Calculs normaux : Vert pour les faibles valeurs, rouge pour les fortes
                    $Red = '{0:x2}' -f [int]([Math]::Min([Math]::Max(255*($value/75*100)/100, 0), 255))
                    $Green = '{0:x2}' -f [int]([Math]::Min([Math]::Max(255 * ((100-$value) / 25 *100) / 100, 0), 255))
                }
                $GaugeColor = "$Red$Green" + "00"
                [Void]$body.Append("<td style=`"border: solid 2px $Color; font-size: 11px; line-height: 1.2;`"><div style=`"width:${Value}%; background-color: `#$GaugeColor`">$Value%</div></td>")
            } Else {
                [void]$Body.Append("<td style=`"border: solid 2px $Color; font-size: 11px; line-height: 1.2;`">$($Property.Value)</td>")
            }
        }
        [void]$Body.Append("</tr>")

    }
    

}
End {
    [void]$Body.AppendLine("`n</table>")

    If ($PostContent) {
        [void]$Body.AppendLine("<table width=`"$MaxWidth`" align=`"center`" style=`"max-width: $MaxWidth; margin: 0 auto;`">")
        [void]$Body.Append("`n<tr>") 
        [void]$Body.AppendLine($PostContent)
        [void]$Body.Append("`n<`/tr>")
        [void]$Body.AppendLine("`n</table>")

    }
    $Body.ToString()
}

}

Function New-HtmlSubTitle {
<#
.SYNOPSIS
Génère un sous-titre HTML stylisé avec des couleurs personnalisées.

.DESCRIPTION
La fonction New-HtmlSubTitle crée un sous-titre en HTML avec une bordure colorée en bas. Permet de définir des couleurs pour le texte principal et la bordure.

.PARAMETER Text
Le texte du sous-titre.

.PARAMETER mainColor
Couleur du texte principal (par défaut : #505050).

.PARAMETER SubColor
Couleur de la bordure sous le texte (par défaut : #e46c0a).

.EXAMPLE
New-HtmlSubTitle -Text "Rapport quotidien" -mainColor "#333333" -SubColor "#ff6600"
#>
    [CmdletBinding()]
	Param (
        [parameter(mandatory=$false, ValueFromPipeline = $true)]
        [String]$Text,
        [String] $mainColor = "#505050",
        [String] $SubColor = "#e46c0a",
        [String]$MaxWidth = "800px"
	)

    $Body = [System.Text.StringBuilder]::new()
    [void]$Body.AppendLine("<table width=`"$MaxWidth`" align=`"center`" style=`"max-width: $MaxWidth; margin: 0 auto;`">")
    [void]$Body.AppendLine('<tr>')
    [void]$Body.AppendLine('    <td style="text-align: left; padding:25px 10px 10px 10px;">')
    [void]$Body.AppendLine("        <div style=`"border-bottom: 2px solid $SubColor; display:inline-block;width:100%;`">")
    [void]$Body.AppendLine("                <strong style=`"color: $mainColor;`">")
    [void]$Body.AppendLine("                <span style=`"color: $SubColor;`">///</span>")
    [void]$Body.AppendLine("                    &nbsp;$Text")
    [void]$Body.AppendLine('                </strong>')
    [void]$Body.AppendLine('        </div>')
    [void]$Body.AppendLine('    </td>')
    [void]$Body.AppendLine('</tr>')
    [void]$Body.AppendLine('</table>')

    Return $Body.ToString()

}

Function New-MailImageLinker {
<#
.SYNOPSIS
Crée un lien vers une image intégrée pour un e-mail HTML.

.DESCRIPTION
La fonction New-MailImageLinker charge une image et la lie dans un e-mail HTML en définissant son ContentId, permettant une référence facile dans le corps de l'e-mail.

.PARAMETER Path
Chemin d'accès au fichier image.

.PARAMETER Id
Identifiant de contenu pour l'image (ContentId), qui permet de la référencer dans le HTML de l’e-mail.

.EXAMPLE
New-MailImageLinker -Path "C:\Images\logo.png" -Id "logoImage"
#>
    [CmdletBinding()]
	Param (
        [String] $Path,
        [String] $Id
	)

    #[byte[]] $reader = [System.IO.File]::ReadAllBytes($Path);
    #$Image = [System.IO.MemoryStream]::new($reader);

    #$imagelink = [System.Net.Mail.LinkedResource]::new($Image, [System.Net.Mime.MediaTypeNames+Image]::Jpeg)
    $imagelink = [System.Net.Mail.Attachment]::new($Path)
    $imagelink.ContentId = $Id
    $imagelink.TransferEncoding = [System.Net.Mime.TransferEncoding]::Base64
    $imagelink.ContentDisposition.Inline = $true
    $imagelink.ContentDisposition.DispositionType = "Inline"

    Return $imagelink

}

Function Send-htmlMail {
<#
.SYNOPSIS
Envoie un email HTML avec des destinataires multiples et un contenu formaté.

.DESCRIPTION
La fonction `Send-htmlMail` envoie un email HTML personnalisé à un ou plusieurs destinataires. Elle accepte des options de configuration pour l'adresse de l’expéditeur, le serveur SMTP, le titre de l’email, et le corps du message.

.PARAMETER From
Adresse de l’expéditeur de l’email. Par défaut, une adresse générique est utilisée.

.PARAMETER To
Adresse(s) email du ou des destinataires.

.PARAMETER Subject
Sujet de l’email.

.PARAMETER Title
Titre HTML pour l’entête de l’email, qui apparaît en haut du message.

.PARAMETER Body
Contenu HTML principal de l’email.

.PARAMETER SmtpServer
Serveur SMTP utilisé pour envoyer l’email. Par défaut, il est défini sur 'vip-parapop.fr.net.intra'.

.EXAMPLE
Send-htmlMail -To "destinataire@exemple.com" -Subject "Rapport Mensuel" -Body "<p>Bonjour, voici le rapport...</p>"

.GENERAL REMARKS
Cette fonction est idéale pour les envois automatisés d’emails HTML, souvent nécessaires pour des rapports ou des notifications.
#>
    [CmdletBinding()]
    Param(
		[Parameter(Mandatory=$False)]
        [String]$From = "architect-windows@boursorama.fr",

		[Parameter(Mandatory=$False)]
        [String[]]$To = "mickael.roy.ext@boursorama.fr",

		[Parameter(Mandatory=$true)]
        [String]$Subject,

        [Parameter(Mandatory=$False)]
        [String]$Title,

		[Parameter(Mandatory=$true)]
        [String[]]$Body,

		[Parameter(Mandatory=$False)]
        [System.IO.FileInfo[]]$Attachment,

        [Parameter(Mandatory=$False)]
        [string]$InReplyToId,

        $MaxWidth = "800",

        [Parameter(Mandatory=$False)]
        [String]$LogoPath = "$PSScriptRoot\..\Resources\Logo.png",

        [Parameter(Mandatory=$False)]
        [String]$BannerPath = "$PSScriptRoot\..\Resources\banner.png",

        [Parameter(Mandatory=$False)]
        [String]$MailToImgPath = "$PSScriptRoot\..\Resources\e-mail.png",

        [Parameter(Mandatory=$False)]
        [string]$SmtpServer = 'smtp.boursorama.fr'
    )
    $head = @"
<!DOCTYPE html>
<html lang="fr" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>

<!-- Déclare le type de contenu et l'encodage -->
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">

<!-- Optimise l'affichage pour les appareils mobiles -->
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<!-- Force le mode de compatibilité moderne dans Internet Explorer -->
<meta http-equiv="X-UA-Compatible" content="IE=edge">

<!--[if gte mso 9]><xml>
 <o:OfficeDocumentSettings>
  <o:AllowPNG/>
  <o:PixelsPerInch>96</o:PixelsPerInch>
 </o:OfficeDocumentSettings>
</xml><![endif]-->

<style type="text/css">

body { margin-left: 10%; margin-right: 10%; min-width:260px; color: #505050; background-color:#E3E3E3;}

h1 {
    font-family: Arial, sans-serif;
    font-size: 14pt; /* Augmentation de la taille */
    font-weight: bold;
    color: #FFFFFF; /* Couleur blanche pour plus de contraste */
}

table {
    border: 0;
    width: 95%;
    border-spacing: 0;
    border-collapse: collapse;
}

th, td {
    text-align: center;
    border: none;
    padding: 5px;
}

th {
    font-family: Arial, sans-serif; 
    text-transform: uppercase;
    padding: 10px;
    vertical-align: middle;
    text-align: center;
    color: #f9f9f9;
}


p, a {
    font-family: Arial, sans-serif; 
    font-size: 8pt;
}
strong {
    font-family: Arial, sans-serif;
    font-size: 12pt;
    display: block; /* Convertit le texte en bloc pour mieux contrôler les marges */
    padding: 10px 0; /* Ajuste cette valeur pour plus d'espace avant */
}
</style>
</head>
"@
    $nbody = [System.Text.StringBuilder]::new()
  # insert header
    [Void]$nBody.AppendLine($head)
  # start body, main table.
    [Void]$nBody.AppendLine('<body style="font-family: Arial, sans-serif; margin: 0; padding: 0;">')

    # Table principale contenant la bannière, centrée avec "margin: 0 auto" et largeur max de 800px
    [Void]$nBody.AppendLine("<table cellspacing=`"0`" cellpadding=`"0`" border=`"0`" width=`"$MaxWidth`" align=`"center`" style=`"max-width: $MaxWidth;`">")

    # VML pour Outlook (MS Office uniquement)
    [Void]$nBody.AppendLine('                <!--[if mso]>')
    [Void]$nBody.AppendLine('                <center>')
    [Void]$nBody.AppendLine('                <tr><td>')
    [Void]$nBody.AppendLine("                <table border=`"0`" cellpadding=`"0`" cellspacing=`"0`" width=`"$MaxWidth`">")
    [Void]$nBody.AppendLine('            <![endif]-->')


    # Fallback pour OWA et autres clients
    [Void]$nBody.AppendLine('            <!--[if !mso]><!-->')
    [Void]$nBody.AppendLine("            <table width=`"$MaxWidth`" cellspacing=`"0`" cellpadding=`"0`" border=`"0`" style=`"margin: 0 auto; position: relative; z-index: 1;`">")
    [Void]$nBody.AppendLine('            <![endif]-->')
    [Void]$nBody.AppendLine('    <center>')

    If (Test-Path $LogoPath) {

        [Void]$nBody.AppendLine('    <tr>')
        [Void]$nBody.AppendLine('        <td style="text-align: left; padding: 10px;">')
        [Void]$nBody.AppendLine('            <img src="cid:Logo" alt="Logo" style="max-width: 200px; height: auto;" />')
        [Void]$nBody.AppendLine('        </td>')
        [Void]$nBody.AppendLine('    </tr>')

    }

    If (Test-Path $BannerPath) {

        [Void]$nBody.AppendLine('    <tr>')
        [Void]$nBody.AppendLine('        <td style="text-align: center; padding: 10px;">')
        [Void]$nBody.AppendLine("            <img src=`"cid:Banner`" alt=`"Banner`" width=`"$MaxWidth`" height=`"auto`" style=`"width: 100%; max-width: ${MaxWidth}px; height: auto; border-radius: 15px; display: block;`" />")
        [Void]$nBody.AppendLine('        </td>')
        [Void]$nBody.AppendLine('    </tr>')
        [Void]$nBody.AppendLine('    </center>')
    }

    [Void]$nBody.AppendLine('                <!--[if mso]>')
    [Void]$nBody.AppendLine('                </td></tr>')
    [Void]$nBody.AppendLine('                </table>')
    [Void]$nBody.AppendLine('               </center>')
    [Void]$nBody.AppendLine('            <![endif]-->')

    [Void]$nBody.AppendLine('            </table>')

    # Contenu principal
    [Void]$nBody.AppendLine('    <tbody>')
    [Void]$nBody.AppendLine("        $Body")
    [Void]$nBody.AppendLine('    </tbody>')

    # Signature
    [Void]$nBody.AppendLine("    <table width=`"$MaxWidth`" align=`"center`" style=`"max-width:${MaxWidth}px; margin: 0 auto;`">")
    [Void]$nBody.AppendLine('    <tr>')
    [Void]$nBody.AppendLine('        <td style="position: relative; text-align: left;">')
    [Void]$nBody.AppendLine("        <p><br>Regards,</p>")
    [Void]$nBody.AppendLine('        </td>')
    [Void]$nBody.AppendLine('    </tr>')

    [Void]$nBody.AppendLine('    <tr>')

    If (Test-Path $MailToImgPath) {
        [Void]$nBody.AppendLine('        <td style="width: 27px; text-align: left; padding: 0;">')
        [Void]$nBody.AppendLine("            <a href=`"mailto:$From`">")
        [Void]$nBody.AppendLine('                <img src="cid:mailto" alt="Email" width="25" height="25" style="display: block;" />')
        [Void]$nBody.AppendLine('            </a>')
        [Void]$nBody.AppendLine('        </td>')
    }
    [Void]$nBody.AppendLine('        <td style="padding: 0 5px; text-align: left;">')
    [Void]$nBody.AppendLine("            <p>Equipe Technique</p>")
    [Void]$nBody.AppendLine('        </td>')
    [Void]$nBody.AppendLine('    </table>')

    [Void]$nBody.AppendLine('    </tr>')
    [Void]$nBody.AppendLine('</table>')

    # Pied de page
    [Void]$nBody.AppendLine("<p>This was an automated message from $env:COMPUTERNAME.</p>")
    [Void]$nBody.AppendLine("<p>Creation Date: $(Get-Date)</p>")

    [Void]$nBody.AppendLine('</body>')
    [Void]$nBody.AppendLine('</html>')


    $htmlView = [System.Net.Mail.AlternateView]::CreateAlternateViewFromString($nbody, $null, "text/html")

    $From = [mailaddress]::new($From).ToString()
    $emailMsg = [System.Net.Mail.MailMessage]::new()
    $emailMsg.From = $From
    $emailMsg.Sender = $From
    #$emailMsg.ReplyToList.Add([mailaddress]::new("", ""))

    Foreach ($Dest in $to) { $emailMsg.To.Add($Dest) }
    $emailMsg.Subject = $Subject
    $emailMsg.Body = $nbody
    $emailMsg.BodyEncoding = [System.Text.Encoding]::UTF8
    $emailMsg.IsBodyHtml = $true
    $emailMsg.AlternateViews.Add($htmlView)

    If (Test-Path $BannerPath) {
        $Logo = New-MailImageLinker -Path $LogoPath -Id Logo
        $emailMsg.Attachments.Add($Logo)
    }
    If (Test-Path $BannerPath) {
        $banner = New-MailImageLinker -Path $BannerPath -Id Banner
        $emailMsg.Attachments.Add($Banner)
    }

    If (Test-Path $MailToImgPath) {
        $mailtoImg = New-MailImageLinker -Path $MailToImgPath -Id mailto
        $emailMsg.Attachments.Add($mailtoImg)
    }

    $Attachment.Foreach({
        If ($_.Exists) {
            Write-Host "Ajout de $($_.FullName)"
            $emailMsg.Attachments.Add("$($_.FullName)")
        }
    })

    If ($InReplyToId) {
        $emailMsg.Headers.Add("In-Reply-To", "<$InReplyToId>")
    }
    Write-Verbose "$nbody"
    $smtpClient = [System.Net.Mail.SmtpClient]::new($SmtpServer)
    $smtpClient.Send($emailMsg)

}

Export-ModuleMember Send-htmlMail

Export-ModuleMember New-MailImageLinker

Export-ModuleMember ConvertTo-HtmlTable

Export-ModuleMember New-HtmlSubTitle
