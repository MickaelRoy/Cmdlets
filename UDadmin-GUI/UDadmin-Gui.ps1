# Importer les types nécessaires pour utiliser Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition '
public class DPIAware
{
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
'

[System.Windows.Forms.Application]::EnableVisualStyles()
[void][DPIAware]::SetProcessDPIAware()

# Déclarer les variables pour les valeurs dynamiques
$Global:UsersVal = 0
$Global:DevicesVal = 0
$Global:InUseVal = 0
$Global:InstalledVal = 0
$Global:InstalledOverdraftVal = 0
$Global:updateLabelVal = "N/A"

# Créer la fenêtre principale
$form = New-Object System.Windows.Forms.Form
$form.Text = "UDAdmin GUI"
$form.Size = New-Object System.Drawing.Size(825, 560)
$form.StartPosition = "CenterScreen"

$form.ShowIcon = $true
$iconBase64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAR7SURBVFhHtdT7T1NnHAZwTEy2/bRsyTJvIG6RZcGETI1LZhY3XdziZvYDCTMTHIkLgSU6xi5MMxAvxIGIOMeYYDlAO
wvFUEQEC6XciqUFtFQuCkJBSKEi8Q/gh2fPtytmbtQDAif5hEPf932+zzlNGvTfa3p6OoRySXleY2NjSkpKyhf+yIVdDMh9/PgxFis2NnZmz549Cy/hfwosVlJSEqKiomYiIyMXVuLRo0dLUiAtLQ0JCQm+NxETEzP/ElKAIJr6xmDpG38u6b9mIjk5GYmJiYiPj5+Ji4ubX4
mpqSlfAbfHi1idg+zP5XBOCVKPn8SR1DS+jeNITU2d0Wg0Uf4xga+HDx8qLIGh8Ql8llu/JCRLMj0eT61/TOBLChAGH3iwM+vqkpAsyST1ApOTk4rX64Vn0osf9I04pDUvyo/MkCzJZLZ6gYmJCYUgeGBJzOaRegF+TwrJ97Uc1AuMj48rhGWiXkB+xwnukRFUmiyoqDUviNX
eCTkfgHqB0dFRheB2j8BibYe51bYgnU4X5HwA6gXcbrdCLLAs1AsMDQ0pw8PD4F903u6G45ZzUTro/v378GeqFxgcHFQI/XfvorCsEpoyo6pLxaXI/z0fJT+novDYKWgPHITmYhEuZl3wrXff6YFkknqBe/fuKQQxMDAwezCgPls7+ru6YNy8FTWf7oUx4h1ceXMj6vZHo/qj
3Rjgg/Ta7b48Ui/Q39+vEObLcuQoKt7/ANrgUOSvWw8NXSK514e9jfKt78KhL53dr16gp6dH6e3thct1BxU1dai4Hti15KOoij7wZKghZMMTZSGh+HPtehTx/sbhRFjzC8Bc9QIul0shOLu7UW1uQnV9YNd1pRwcijwOKuEbmMsfXNNu2Qanw4Fup1O9gNPpVAhqrAYDNJsiO
CDE96QFfANzkXUpqP1wFxwWi3qBrq4uhdDR0YnSyuu4bKwOqOibw7jAAfPRpPsLnXa7egGHw6F0dHSAf1Hb0Iwafg1zqSosRtHez3FuTYjPmdXBczrPtfNvbIRu35doM9WpF7DZbEp7ezvmo/r8b8hcHYIcDjm5Kvh/TpGsZb8VjkajEbabN9ULWK1WhdDS0grtlavPlJOcgr
NffY3TfFJ5C8deX4df/E6sWuf7LJ1rl9NPo6ZQAXPVC7S2tirkK1BjblSVdzAexQfjkMaB8sqz1gTjLGXwPiM8AgX79qM8MwuSSeoFWlpafAUWor6qCtk7dyOPw85s34ETYeEo/u57ZO/6+Kl9zH52Ab1ev8JkMv3070Pz0dLcjObGRlTxx6aWv3qGjExYbpjQ1NDw1D6z2Xz
OYDCs8I/759LpdC/QJvqEoukQN2nLy8uvUR01URvZqZNukzMAWZM9svcmyVnJkKzLzP7WP0NmycwXpcArFENnSU8maqNb1EsDNEwPaJw8NOHn9Zv9X9Zkj+x1k5yVDMmSTMkupWw6QK/OvoWV9BK9TK/RWgqlMAqnCNpC2+g9v+20w0/uZz+XPbJXzshZydhAkinZMkNmrQwK
Cgr6G4ACEmBYjqp9AAAAAElFTkSuQmCC"
$iconBytes = [Convert]::FromBase64String($iconBase64)
# initialize a Memory stream holding the bytes
$stream = [System.IO.MemoryStream]::new($iconBytes, 0, $iconBytes.Length)
$form.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($stream).GetHIcon()))
$form.BackColor = [System.Drawing.SystemColors]::Control
$form.ForeColor = [System.Drawing.SystemColors]::ControlText
$form.MaximizeBox = $false
$form.Topmost = $True
$form.ShowInTaskbar = $true

# Ligne de mise à jour
$updateLabel = New-Object System.Windows.Forms.Label
$updateLabel.Text = ""
$updateLabel.ForeColor = "DarkCyan"
$updateLabel.Font = [System.Drawing.Font]::new("Arial", 9, [System.Drawing.FontStyle]::Bold)
$updateLabel.Location = New-Object System.Drawing.Point(400, 200)
$updateLabel.Size = New-Object System.Drawing.Size(350, 20)
$form.Controls.Add($updateLabel)

# --------- Colonne Utilisateurs ---------
$UserPicBase64 = "iVBORw0KGgoAAAANSUhEUgAAADgAAAA4CAYAAACohjseAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAACxMAAAsTAQCanBgAAA9cSURBVGhD7VlrjF3XVV77PO9jxvMee8bj+hEnrZ3WfRknjQsxokDSSCRNa1dtExCVSEULP9oA/QFoZhBCFAqq0lKpDarIj6aFAQQo
oFZK1NitGxzHRa6xE8djO+k87jzv85x7z2ufzbf2uRNbhfoxd0IRyppZd+29z2t9e6291trn0Bv0Br1BP1USbfm/Skq1n8u/6FwhQULQ1QMd0+sOUCklaGJCP0dMTqa6T2ScPTtlFpeHjO6tW50winqj2UuFUu3C0l0ffrTCl/H5G0GvG8DMSopOnSJrpzu9xbCC3UnYGpNRstMQ6Q5K5Ejg
1bYE5eWheOHVfOX8GXO5tHyuGdF9H/3X71X1xRtArwtAtlLtzJleI6k8mPi1j8X1yrvTlpdLmp4ZenUjqlcprlVUWK+pwPMpDBJR96VamF8+HiwF9zw6OxvwbbK7dUYbClC739SUUX7nnlG3WXkyKF24ozU3bSTlkkjqZZH4DUp8X0R+oEKYKmim1Iwt8qUt5iteuqzoSbtv7Ncnjx6VfLvs
rp3RhgFkcAunTxe6ut0HDG/pd/1Xf/C28EdnKV5ZBLA6Jc0WyUgKGacUhpICLybfT6kWCSqHqWqYOerbd2DpzYd+8eG7P3rkaYSb/zsAM5c8udMWra8Fl39wsHHmqBHOviqSICSZpjguRAqbJFJRFEhqNkJqeAnApeSRTZHrktk7oJy+ETW0c0+w5ba9n3nv5enHOSi1H7Fu2hCA3rmTI0b9
0lOLT3/97ZXvP2+EtZBiSYK1UwZRCs9N0AljRc1QUS2E5RJFHsZayAsptLBsU/UMDtDQtltoeOee5rafec8j06n42yNHjrC7rps6BgjrWd6xJ768+E9f+fjS8+eNlYWYVv1YBAAGjESmQYbFIAQBF7XAPpaXjzALD6WQ7wG28NPvmGp4sIc2j+1So+88eN7dvf3nDn3sE6u4y7rdtSOAanzc
qPzSrdsaz3zj+cVjzw2W5hMRjhTEbQ++lQqbu6hRadLsSyv0yourtDjnkd9KCEYkI2dT90CORrcWaXQ0T/miQ6urIZ06NkO5plTDfZuof/veJLf1Te//8Bcef+anBxDXz3/lkYP14898a2mmVmhA6UOPPSTyuRz8s5WphTUYJzGFjRYFtRYlrYgsQ8CwfFCSkpJSCReWNi3NVembjz1Pm+Cz
hVxvqnoG/qB6572fm+xgLcKR1k88s41LLw9EXtNpypT2ffxtlLebJJJ5RJQVMIqSpEZ26lNXPqXBYQful6feYZu6ek0qdptU6LKoULAByKSRrT104O4tcOUUEddXQa3c337UuqkjgExRo9IVq9TIbc3RyDuGAa4MUHUScYOQzSGrGiSPsRSyTlbaIFN5ZAK4qQIyVEgmxWTKFr3lrf1kF6EW
QpShYPoOqWOASRSaWFeib08PmVYIAGxBhI6U25AygGRuacl9QptZwY0VzlfSRx+cBFRwJPUMOghKSkC52sTE5LrXH1PnFpQyDpVQPbuK6DCwBI4L5sSn21g+Cu3XJNYd2po5R7bPS2UECZYx9Q3a1MKkpZZYbj9m3dQxQCVSP4JtiiM54Eq04hkYnngwS7CibAxpBW2WAIex7AgDx7XcV1L1
D9kqQNMwaLHTRNYxwMKOQYotkTq9Noqrq8G1AbHEr0Cb4XD7yh+f0gapLYvMiQptU69FCKzx6FiPovHxjiCuGyD0FbUTDw9su3/7FwLXdNyCiVHEdwanWZ+VMQPlMYbSbuvDVx3nCeFRABTFLlOkOcN51x7jy/Ut37lFja9fz/VbcIKENfujvBNX+s2xvLBsJDcoypZaU1qDStcAZZJhaCjc
bvf5l9tsfb7adQ3l9lrKVlF/eaFWpHOH123FdQMUk5QWfnh0PpfK+f3v60WYYRSZO2aKptplNTD+04DQ10BeG+WmHtMg+RpAMTBX+/fmRM4xKpIK8/R3U3zjdVFna3ACennBS0VCtERTK84g2QzgTCsea4Nr/7G1MqD6aPbXHsteaAiBCk4loSzNkFPu5D1NRwD5wav/vPxHUZmmueRCuFdC
Ihoi7CuWmlGKcR/pIOMr7XRN4hx9PUvtt5im2PxhazH4zKFJvfldN3VmQdDwwXecsbd3fyeNI+CIse+LgTOC0jGUjqFzBFNkbRwHAyBLgM/OhdSMc/Uxniil7K19/3Zm5V0nYNB1W4+pY4BMBtkz0DZTXINhy11pazBXj7PUYLjPElYEa4maFoGULMuea9++I+oc4OGpVCXuORkik8WoSpME
nIHTVtTA1kDxOINYsxra2BmnMdqR5FcauJbXMLYadtf5w3v3dmQ9po4B8jpMVsMTKCWXEmzZZQRXixnIGogE/cxa7ILakgxIg2NgzGizZLAS4Sg1Sy134ORGvLLYEBetvGqthmXxrPQBIgQ4KKslAKyBSwE6k9lYionQ5+lzEyVDCUPzcSSLxPqXO6a/7rVv3xF1VAatEeKemPmru29xiivP
2EPhVsMVBv5g2+z27Gc6K2B9cRbBcs2AYDOUhAoAU2yElcJmAh5anJaFgXvf/tvffaWT9LBGGwKQCZqIl//kjgO5rvKUMxCNmgVhGCYXXnw0i4U6RUoASpAJsMfiDYQEQIBUcYCkkeRfbqWbDx/4w+PnNgIc04a4KBNDeDK856RXHbm/PjN2oTUTqdZqrKJaQnED7MdglgklHrPEZjkBxxT5
UjW9gdN+MHD/Afm+FzcKHNOGWXCN2F2P/9kXR3rip76tgot73KJnWC7HfX4UNIcFUQ/wto/iSKig6WI5Dn23au78yH2fn1rMbL1xtGEWRJnF5SjrJ3p/7+dXhoZrVVmz1ML5XlqcLiAQmVSdVVQrISiVTFqZdWj5Yp6iBYuKjpopfuqT1YlxJcbHlYGbbdjEd3yjDBTRs9gE0Hy4o2lb7y95
4r6fPfHQXeLsKbd8uUHlhUg0I9SZJr9NY2Mqch2DCt2Oyvc6NL/rHu+Fg3/+H2P9zlM9hvrWbMWerr9HhBM8W7xB7IDWDXBcKYMVeMFXW6opfaCRqA8sh7S/VIk3XVoMxSdf+Q3avHSWmgseeUuR8KpYawgowEd23iS3YCGXO8oq2vQ96y76+62/T0OjRTU81OUNdzunBwvm1LZu6x8eeJMo
McL1Ar15gOyK2At+/7NqG4Lgr1YT+q1SoAYXA6HKTSW8ZmRUyjEduPA4fSR5gmQtoJgDTROBBekA20NWloSDDbJjUd3M0V/4n1Kl0fcKoyuvDPhrrttVQ32u2NHvljfnxZcGXeevL98mSpNCfw24KbppgP+plON78gHsYf50IaCx+ZCsSiKohcARxEK0WlL5XigaC3Xa98o/0geTJ2mzXCIV
pTqwpJwqEIkiePaFYJgerz1McwMHyOopksi5ysjbwnKx2YWFi7D0wCZb7hrIXbw1Lz6dtKynP7Ff3NSrxJsCyOBqzXSiktCjsJi1hN0Rg0PU5+8OAkUJoYAhP5DkNyJqrIYklldorHaWdrRepN54CflP0mI8QBeTXXSZdlOS30Rm3ibTtclwLTJgWdNmNpSNdermDNqUN9VYnxPc3mNOVvbZ
n78ZS94wwMtK5eZ89ccrofq0JwWtJMTgBH8l8tHnDysoTigEyABJ3Md6C/hbRAtrD+7Z8hTacFGAJ5RkgssYVlMY2MGDbYNMyyCBdGLqDzYGWaZQtm0I1xaqmBNqS8GgO4bt37Fj+0s3askbAsiR8jlPHZ4L1d+EiXDZWqvQsyaFQK4GQCJ4IKFmhoT7QQYaKLAAdcJVCywnIblEkzhZYdfA
lY1elJAo7fTrCr0+tUQOww+nT8sklUMEhlHV7j6rdkt3es9n9xdO3kjguT5AgDvWUIPwthNzPm13TRLQneoAhwBDDYBpgtmCGiQ40SAFxUjqMaTk8owT/FXMCV+/B8Z61EC5WNUvqNDmPojf0yEpErCRgyxrA3uXmaa3bnKOe37jvq89MIiC/Nogr5vox3GHuXr68MWq2l6PSXjgRiQEKi9t
IV5z2BhkDMDwPrDQBTUriknPrAA3tOF6NrueZr3O4IomGRhH5YqTMXv8wp7bmHsURcAMTnmShEANq0JEp7l6vL/qW7+gJ+M6dG2AsJ53WuVfqogPXaqRWmkqWm4SrbQUVcH1ENYDt5AvAnAIjsDYGaGgBj42NYAKsAmwAooaYBNKcxWuGX1dnLEE6yjLluU2ruevABnDuli6/LmjWo2cpaXw
oSNHpq5roGu7KAA++O3wzbZrnAgJWcoWhg1z8PpAANUfM2NMIwcXPF9/puZxvawYkL5FZguWequEBh/TrooT+V1T1ubjWJfa8uy2sB+uYQ8wwRbYxg0MbJSTIE7DWrpo1ef2nfrLd6/iCTjzf6ZrAuS68NjO8odajvMN07WEg7CN6Ca43OJ3l8ACykp/DQrM+mkwbcbvlce/BpDXYdbWa5Ot
zefzfpHXJs7jAdFmvQ55BjhQNWMVehHxF5F+N7jz3/O3v0CTPzltXN/ELTHsL0WqgvJruRTS8kJEy0sRrSzHVFlNqI5I49ex7UEolYg2ogUOMNOhJFMztxF2MSYQgYTuQ2m0+ZiFtgUXsBB6LR7T49m1fA+D8w4WfFSLyF8JVGM5FGElJDOIVEEmmxEjrkkcqH4iHTpEohS9Zbvnyw9GUDxu
SREj6cUAEnqJirQEAxznOu5HyHUJcp0EIM0AkULplCXGtdSMtu5nUnGORN5UPMYSDGth3whwWOxRNRIJoptqhcqKItVtJjToxo+NOF+dP3r06JqP/De69hqEE/7K517qmp+Pnqi35L2x4TrSsJVC1EM2RsDD/EBAqiyP4Xb8rxl9vgV34Ios2Je12/IPeM0Vs++E3G67qHZVDMhEQGLLD6+A
LwtEGTuNRU6Efl/R+OaWXy795tSRwzhxnWswIyXu/rVn3UiWd7eUcWcs7d0x2dtSo9ADZ9qUCrMLCzIPZ3I4zvP+BhchQCLeI0jpVaBfXDBg6MExH6EjQ4ub84JsbyQ5shj8jh+DRipD3KBpqMQ3hayZsVcxjXi2aMoX3Xz63GDLnJmaOox4fe08yMrcIPFmdEJMEjZJ4EdKo+Y8dj6lCtm2
6jVjO2/EQWxYBTKl6RhJaKOsTAwZof5wYjzHRWBhydNgw+LIcDEAmVKZMkaJaqUOFnCYBKmdM9M8Ul8kUjlcayajo6fir46MSDp3uxjfe1hNXiOo/DjdBMAfJ0x6e+7GJxg4E4Nfo2wiboyuPneCiwtNkxMT2RO0lte21Bv0/5OI/gvSwpD+Lre6rgAAAABJRU5ErkJggg=="

# Décoder et afficher l'image pour les utilisateurs
$UserPicBytes = [System.Convert]::FromBase64String($UserPicBase64)
$UserPicStream = New-Object System.IO.MemoryStream(, $UserPicBytes)
$UserPicture = [System.Drawing.Image]::FromStream($UserPicStream)

$userPicBox = New-Object System.Windows.Forms.PictureBox
$userPicBox.Size = New-Object System.Drawing.Size(56, 56)
$userPicBox.Location = New-Object System.Drawing.Point(10, 10)
$userPicBox.Image = $UserPicture
$userPicBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
$form.Controls.Add($userPicBox)

# Label pour la colonne des utilisateurs
$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Text = "Users:"
$userLabel.Location = New-Object System.Drawing.Point(70, 40)
$userLabel.Size = New-Object System.Drawing.Size(80, 23)
$userLabel.Font = [System.Drawing.Font]::new("Arial", 12, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($userLabel)

# Liste des utilisateurs
$userListBox = New-Object System.Windows.Forms.ListBox
$userListBox.Location = New-Object System.Drawing.Point(10, 70)
$userListBox.Size = New-Object System.Drawing.Size(180, 370)
$userListBox.SelectionMode = "MultiExtended"
$userListBox.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
# Activer/Désactiver le bouton Release Users en fonction de la sélection
$userListBox.Add_SelectedIndexChanged({
    if ($userListBox.SelectedItems.Count -gt 0) {
        $releaseUserButton.Enabled = $true
    } else {
        $releaseUserButton.Enabled = $false
    }
})

$form.Controls.Add($userListBox)


# Bouton pour libérer les utilisateurs sélectionnés
$releaseUserButton = New-Object System.Windows.Forms.Button
$releaseUserButton.Text = "Release Selected User(s)"
$releaseUserButton.Location = New-Object System.Drawing.Point(10, 450)
$releaseUserButton.Size = New-Object System.Drawing.Size(180, 30)
$releaseUserButton.Enabled = $false  # Désactiver par défaut
$releaseUserButton.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($releaseUserButton)

# --------- Colonne Périphériques ---------

$DevicePicBase64 = "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"

#Conversion de l'image en mode graphique.
$DevicePicBytes = [System.Convert]::FromBase64String($DevicePicBase64)
$DevicePicStream = New-Object System.IO.MemoryStream(, $DevicePicBytes)
$DevicePicture = [System.Drawing.Image]::FromStream($DevicePicStream)

#Création d'une image (PictureBox).
$DevicePicBox = New-Object System.Windows.Forms.pictureBox
$DevicePicBox.Location = New-Object Drawing.Point(200,10)
$DevicePicBox.Size = New-Object System.Drawing.Size(56,56)
$DevicePicBox.image = $DevicePicture
$form.controls.add($DevicePicBox)

# Label pour la colonne des périphériques
$deviceLabel = New-Object System.Windows.Forms.Label
$deviceLabel.Text = "Devices:"
$deviceLabel.Location = New-Object System.Drawing.Point(270, 40)
$deviceLabel.Size = New-Object System.Drawing.Size(80, 23)
$deviceLabel.Font = [System.Drawing.Font]::new("Arial", 12, [System.Drawing.FontStyle]::Regular)

$form.Controls.Add($deviceLabel)

# Liste des périphériques
$deviceListBox = New-Object System.Windows.Forms.ListBox
$deviceListBox.Location = New-Object System.Drawing.Point(200, 70)
$deviceListBox.Size = New-Object System.Drawing.Size(180, 370)
$deviceListBox.SelectionMode = "MultiExtended"
$deviceListBox.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)

# Activer/Désactiver le bouton Release Devices en fonction de la sélection
$deviceListBox.Add_SelectedIndexChanged({
    if ($deviceListBox.SelectedItems.Count -gt 0) {
        $releaseDeviceButton.Enabled = $true
    } else {
        $releaseDeviceButton.Enabled = $false
    }
})

$form.Controls.Add($deviceListBox)

# Bouton pour libérer les périphériques sélectionnés
$releaseDeviceButton = New-Object System.Windows.Forms.Button
$releaseDeviceButton.Text = "Release Selected Device(s)"
$releaseDeviceButton.Location = New-Object System.Drawing.Point(200, 450)
$releaseDeviceButton.Size = New-Object System.Drawing.Size(180, 30)
$releaseDeviceButton.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$releaseDeviceButton.Enabled = $false  # Désactiver par défaut
$form.Controls.Add($releaseDeviceButton)

# --------- Colonne d'informations et de contrôle ---------
# Cadre d'utilisation actuelle
$currentUsageGroupBox = New-Object System.Windows.Forms.GroupBox
$currentUsageGroupBox.Text = " Current Usage: "
$currentUsageGroupBox.Location = New-Object System.Drawing.Point(400, 64)
$currentUsageGroupBox.Size = New-Object System.Drawing.Size(400, 100)
$currentUsageGroupBox.Font = [System.Drawing.Font]::new("Arial", 10, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($currentUsageGroupBox)

# Champs d'utilisation
$inUseLabel = New-Object System.Windows.Forms.Label
$inUseLabel.Text = "In Use: $InUseVal"
$inUseLabel.Location = New-Object System.Drawing.Point(10, 30)
$inUseLabel.Size = New-Object System.Drawing.Size(80, 23)
$inUseLabel.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$currentUsageGroupBox.Controls.Add($inUseLabel)

$usersLabel = New-Object System.Windows.Forms.Label
$usersLabel.Text = "Users: $UsersVal"
$usersLabel.Location = New-Object System.Drawing.Point(100, 30)
$usersLabel.Size = New-Object System.Drawing.Size(80, 23)
$usersLabel.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$currentUsageGroupBox.Controls.Add($usersLabel)

$devicesLabel = New-Object System.Windows.Forms.Label
$devicesLabel.Text = "Devices: $DevicesVal"
$devicesLabel.Location = New-Object System.Drawing.Point(200, 30)
$devicesLabel.Size = New-Object System.Drawing.Size(80, 23)
$devicesLabel.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$currentUsageGroupBox.Controls.Add($devicesLabel)

$installedLabel = New-Object System.Windows.Forms.Label
$installedLabel.Text = "Installed: $InstalledVal"
$installedLabel.Location = New-Object System.Drawing.Point(10, 60)
$installedLabel.Size = New-Object System.Drawing.Size(120, 23)
$installedLabel.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$currentUsageGroupBox.Controls.Add($installedLabel)

$installedOverdraftLabel = New-Object System.Windows.Forms.Label
$installedOverdraftLabel.Text = "Installed Overdraft: $InstalledOverdraftVal"
$installedOverdraftLabel.Location = New-Object System.Drawing.Point(150, 60)
$installedOverdraftLabel.Size = New-Object System.Drawing.Size(150, 23)
$installedOverdraftLabel.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$currentUsageGroupBox.Controls.Add($installedOverdraftLabel)

# Cadre des détails du serveur de licence Citrix
$licenseServerGroupBox = New-Object System.Windows.Forms.GroupBox
$licenseServerGroupBox.Text = " Citrix License Server details: "
$licenseServerGroupBox.Location = New-Object System.Drawing.Point(400, 340)
$licenseServerGroupBox.Size = New-Object System.Drawing.Size(400, 100)
$licenseServerGroupBox.Font = [System.Drawing.Font]::new("Arial", 10, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($licenseServerGroupBox)

$licenseServerVersionLabel = New-Object System.Windows.Forms.Label
$licenseServerVersionLabel.Location = New-Object System.Drawing.Point(10, 30)
$licenseServerVersionLabel.Size = New-Object System.Drawing.Size(320, 23)
$licenseServerVersionLabel.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)

$licenseServerGroupBox.Controls.Add($licenseServerVersionLabel)

$udadminLocationLabel = New-Object System.Windows.Forms.Label
$udadminLocationLabel.Location = New-Object System.Drawing.Point(10, 60)
$udadminLocationLabel.Size = New-Object System.Drawing.Size(380, 23)
$udadminLocationLabel.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)

$licenseServerGroupBox.Controls.Add($udadminLocationLabel)

# Boutons de contrôle
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh"
$refreshButton.Location = New-Object System.Drawing.Point(400, 450)
$refreshButton.Size = New-Object System.Drawing.Size(100, 30)
$refreshButton.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($refreshButton)

# Créer un objet ToolTip pour fournir des informations supplémentaires
$toolTip = New-Object System.Windows.Forms.ToolTip

# Ajouter des ToolTips aux boutons et labels
$toolTip.SetToolTip($refreshButton, "Cliquez pour rafraîchir les données d'utilisation")
$toolTip.SetToolTip($releaseUserButton, "Libère les utilisateurs sélectionnés")
$toolTip.SetToolTip($releaseDeviceButton, "Libère les périphériques sélectionnés")

$StatusStrip = [System.Windows.Forms.StatusStrip]::new()
$StatusStrip.Name = 'StatusStrip'
$StatusStrip.AutoSize = $true
$StatusStrip.Left = 0
$StatusStrip.Visible = $true
$StatusStrip.Enabled = $true
$StatusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
$StatusStrip.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$StatusStrip.LayoutStyle = [System.Windows.Forms.ToolStripLayoutStyle]::Table
$StatusStrip.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
# Status Bar Label
[void]$statusStrip.Items.Add($statusLabel)
$statusLabel.AutoSize = $true
$statusLabel.Text = "Ready"
$form.Controls.Add($statusStrip)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Location = New-Object System.Drawing.Point(660, 450)
$exitButton.Size = New-Object System.Drawing.Size(100, 30)
$exitButton.Font = [System.Drawing.Font]::new("Arial", 8, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($exitButton)

# Fonctionnalité du bouton Exit pour fermer l'application
$exitButton.Add_Click({
    $form.Dispose()  # Libère les ressources utilisées par le formulaire
    $form.Close()
})

Function Get-licenseServerVersion {

    $keyPath = "HKLM:\SOFTWARE\WOW6432Node\Citrix\LicenseServer\Install"
    $key = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue

    if ($key) {
        Return "$($key.Version)".ToString()
    }
}
$licenseServerVersionLabel.Text = "Licence Server version: $(Get-licenseServerVersion)"

Try {
    Function Get-UDadminLocation {

        $keyPath = "HKLM:\SOFTWARE\WOW6432Node\Citrix\LicenseServer\Install"
        $key = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue

        if ($key) {
            Return "$($key.LS_Install_Dir)".ToString()
        } Else {
            Throw "UDadmin.exe est introuvable"
        }
    }
    $UDAdminLocation = Join-Path -Path $(Get-UDadminLocation) -ChildPath "udadmin.exe"
    $udadminLocationLabel.Text = "UDadmin location: $([System.IO.Path]::GetDirectoryName($UDAdminLocation))"
} Catch {
    Throw $_
}

# Fonction pour analyser la sortie de la commande udadmin.exe
function Update-UsageData {
    # Exécuter la commande udadmin.exe
    $udadminOutput = & $UDAdminLocation -list -times -a

    # Initialiser les compteurs
    $totalUsers = 0
    $totalDevices = 0
    $totalInUse = 0
    $totalInstalled = 0
    $totalInstalledOverdraft = 0

    # Variables pour stocker les utilisateurs et les devices
    $usersList = @()
    $devicesList = @()

    # Analyser la sortie de la commande
    foreach ($line in $udadminOutput) {
        if ($line -match '^Usage data is.*') {
            $updateLabelVal = $line
        }
        elseif ($line -match '^Feature\s+:\s+(\S+)') {
            $feature = $matches[1] # Stocker la fonctionnalité trouvée
        }
        elseif ($line -match '^Installed:\s+(\d+)\s+.*Installed Overdraft\s+:\s+(\d+)') {
            $totalInstalled = [int]$matches[1]
            $totalInstalledOverdraft = [int]$matches[2]
        }
        elseif ($line -match '^In Use\s+:\s+(\d+)\s+Users:\s+(\d+)\s+Devices:\s+(\d+)') {
            $totalInUse = [int]$matches[1]
            $totalUsers = [int]$matches[2]
            $totalDevices = [int]$matches[3]
        }
        elseif ($line -match '^\s+Users:\s*$') {
            $currentList = "Users"
        }
        elseif ($line -match '^\s+Devices:\s*$') {
            $currentList = "Devices"
        }
        elseif ($currentList -eq "Users" -and $line -match '^\s+(\w+)\s+\(') {
            $usersList += $matches[1]
        }
        elseif ($currentList -eq "Devices" -and $line -match '^\s+(\S+)\s+\(') {
            $devicesList += $matches[1]
        }
    }

    # Mettre à jour les variables globales
    $global:UsersVal = $totalUsers
    $global:DevicesVal = $totalDevices
    $global:InUseVal = $totalInUse
    $global:InstalledVal = $totalInstalled
    $global:InstalledOverdraftVal = $totalInstalledOverdraft
    $global:updateLabelVal = $updateLabelVal
    $global:feature = $feature

    # Mettre à jour les listes dans l'interface
    $userListBox.Items.Clear()
    $userListBox.Items.AddRange($usersList)
    $deviceListBox.Items.Clear()
    $deviceListBox.Items.AddRange($devicesList)

    $usersLabel.Text = "Users: $UsersVal"
    $devicesLabel.Text = "Devices: $DevicesVal"
    $inUseLabel.Text = "In Use: $InUseVal"
    $installedLabel.Text = "Installed: $InstalledVal"
    $installedOverdraftLabel.Text = "Installed Overdraft: $InstalledOverdraftVal"
    $updateLabel.Text = $updateLabelVal
}

# Fonctionnalité pour libérer les utilisateurs sélectionnés
$releaseUserButton.Add_Click({
    foreach ($user in $userListBox.SelectedItems) {
        $command = "& `"$UDAdminLocation`" -f `"$Feature`" -user `"$user`" -delete"
        $Return = Invoke-Expression $command
        $statusLabel.Text = "${command} returns: $Return"  
    }
    # Rafraîchir les données après libération
    Update-UsageData
})

# Fonctionnalité pour libérer les périphériques sélectionnés
$releaseDeviceButton.Add_Click({
    foreach ($device in $deviceListBox.SelectedItems) {
        $command = "& `"$UDAdminLocation`" -f `"$Feature`" -device `"$device`" -delete"
        $Return = Invoke-Expression $command
        $statusLabel.Text = "${command} returns: $Return"  
    }
    # Rafraîchir les données après libération
    Update-UsageData
})

# Fonctionnalité du bouton Refresh pour mettre à jour les informations
$refreshButton.Add_Click({
    Update-UsageData
    $statusLabel.Text = "Refresh completed"
})

# Exécuter la mise à jour initiale pour remplir les données
Update-UsageData
Get-licenseServerVersion

# Initialize and show the form.
$form.Add_Shown({
    $form.Activate()  
})


# Afficher la fenêtre
[Void][system.windows.forms.application]::run($form)