Function Get-McAfeeWebContent {
    [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=217035')]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [uri] ${Uri},

        [string] ${OutFile},

        [switch] ${UseBasicParsing},

        [switch] ${DisableKeepAlive}

    )

    process {
        try {
            $response = Invoke-WebRequest @PSBoundParameters -PassThru

            if ($response.Headers.ContainsKey('Via') -and $response.Headers.Via.Contains('McAfee Web Gateway')) {
                $unixEpochStart = [DateTime]::new(1970,1,1,0,0,0,([DateTimeKind]::Utc))
                $content = $response.Content
                if ($content -match '<meta id="progresspageid" content="(.*?)">') {
					    $RequestID = $matches[1]
                        Write-Verbose "Detected request ID of '$RequestID'"
                }
                if ($content -match '/mwg-internal/(.*?)/files/') {
                    $URLPart1 = $matches[1]
                    Write-Verbose "Detected internal URL with folder '$URLPart1'"
                }
                $requestDomain = $Uri.ToString().Split('/')[0..2] -join '/'
                $statusComplete = $false

                While (!$statusComplete) {
                    Start-Sleep -Seconds 3
					$statusUri = "$requestDomain/mwg-internal/$URLPart1/progress?id=$RequestID&a=1&$([Int64]([DateTime]::UtcNow - $unixEpochStart).TotalMilliseconds)"
                    Write-Verbose "Requesting status URI: $statusUri"
                    $PSBoundParameters['Uri'] = $statusUri
					$statusResponse = Invoke-WebRequest @PSBoundParameters -PassThru
                    if ($statusResponse.StatusCode -eq 200) {
                        $Global:colStat = $statusResponse.Content.Split(';')
                        if ($colStat[3] -eq 1 -or $colStat[3] -eq $null) {
                            Write-Verbose "Detected completion status. Attempting request of original content"
                            $statusComplete = $true
							$PSBoundParameters['Uri'] = "$requestDomain/mwg-internal/$URLPart1/progress?id=$RequestID&dl"
							$result = Invoke-WebRequest @PSBoundParameters
                        } elseif ($colStat[4] -eq 0) {
                            Write-Verbose "Downloaded $($colStat[0]) of $($colStat[1])"
                        } else {
                            Write-Verbose "Scanning in progress ($($colStat[4])s)"
                        }
                    }
                }
            }
        } catch {
            throw
        }
    }
}