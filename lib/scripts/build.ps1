param(
    [string]$Arg = '',
    [string]$Tag = ''
)

try {
    $versionName = $null

    $versionCode = [int](git rev-list --count HEAD).Trim()

    $commitHash = (git rev-parse HEAD).Trim()

    $updatedContent = foreach ($line in (Get-Content -Path 'pubspec.yaml' -Encoding UTF8)) {
        if ($line -match '^\s*version:\s*([\d\.]+)') {
            if (-not [string]::IsNullOrEmpty($Tag)) {
                $suffix = $null
                $baseTag = $Tag

                if ($Tag -match '\+') {
                    $parts = $Tag -split '\+', 2
                    $baseTag = $parts[0]
                    $suffix = $parts[1]
                }
                elseif ($Tag -match '-') {
                    $parts = $Tag -split '-', 2
                    $baseTag = $parts[0]
                    $suffix = $parts[1]
                }

                if ($baseTag -match '^v?(\d+)\.(\d+)\.(\d+)') {
                    $versionName = "$($matches[1]).$($matches[2]).$($matches[3])"
                }
                elseif ($baseTag -match '^v?(\d+)\.(\d+)') {
                    $versionName = "$($matches[1]).$($matches[2]).0"
                }
                else {
                    $versionName = $baseTag
                }

                if (-not [string]::IsNullOrEmpty($suffix)) {
                    $versionName = "$versionName-$suffix"
                }
            }
            else {
                $versionName = $matches[1]
                if ($Arg -eq 'android') {
                    $versionName += '-' + $commitHash.Substring(0, 9)
                }
            }

            "version: $versionName+$versionCode"
        }
        else {
            $line
        }
    }

    if ($null -eq $versionName) {
        throw 'version not found'
    }

    $updatedContent | Set-Content -Path 'pubspec.yaml' -Encoding UTF8

    $buildTime = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds())

    $data = @{
        'pili.name' = $versionName
        'pili.code' = $versionCode
        'pili.hash' = $commitHash
        'pili.time' = $buildTime
    }

    $data | ConvertTo-Json -Compress | Out-File 'pili_release.json' -Encoding UTF8

    Add-Content -Path $env:GITHUB_ENV -Value "version=$versionName+$versionCode"
}
catch {
    Write-Error "Prebuild Error: $($_.Exception.Message)"
    exit 1
}