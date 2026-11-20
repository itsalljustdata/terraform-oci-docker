param(
    [string]$RepoDir = ""
)

if (-not $RepoDir) {
    $RepoDir = Split-Path -Parent $PSScriptRoot
}

try {
    $commit = (git -C $RepoDir rev-parse HEAD 2>$null).Trim()
} catch {
    $commit = "unknown"
}

if (-not $commit) { $commit = "unknown" }

try {
    $remoteUrl = (git -C $RepoDir remote get-url origin 2>$null).Trim()
} catch {
    $remoteUrl = "unknown"
}

if (-not $remoteUrl) { $remoteUrl = "unknown" }

$is_dirty = $false
try {
    $statusOutput = git -C $RepoDir status --porcelain 2>$null
    if ($statusOutput) {
        $is_dirty = $true
    }
} catch {
    $is_dirty = $false
}

$source = "unknown"
if ($remoteUrl -and $remoteUrl -ne "unknown") {
    $normalized = $remoteUrl.TrimEnd('/')
    $normalized = $normalized -replace '\.git$', ''

    if ($normalized -match '^https?://[^/]+/(.+)$') {
        $source = $Matches[1]
    }
    elseif ($normalized -match '^ssh://[^/]+/(.+)$') {
        $source = $Matches[1]
    }
    elseif ($normalized -match '^[^@]+@[^:]+:(.+)$') {
        $source = $Matches[1]
    }
    elseif ($normalized -match '^git@[^:]+:(.+)$') {
        $source = $Matches[1]
    }
    else {
        $source = $normalized
    }
}

@{
    commit     = [string]$commit
    remote_url = [string]$remoteUrl
    source     = [string]$source
    is_dirty    = [string]$is_dirty.ToString().ToLowerInvariant()
} | ConvertTo-Json -Compress
