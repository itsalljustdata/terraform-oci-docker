[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('apply', 'force', 'destroy')]
    [string]$Action = 'apply',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$TerraformArguments,

    [switch]$Help
)

if ($Help) {
    @'
Usage:
  .\tf_apply.ps1 [action] [terraform arguments]

Actions:
  apply    Run terraform apply -auto-approve -compact-warnings
  force    Apply while replacing oci_core_instance.compute_instance
  destroy  Run terraform apply -destroy -auto-approve

Examples:
  .\tf_apply.ps1
  .\tf_apply.ps1 apply
  .\tf_apply.ps1 force
  .\tf_apply.ps1 destroy
  .\tf_apply.ps1 -Help
'@ | Write-Host
    exit 0
}

$hostExecutable = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    'pwsh'
} else {
    'powershell'
}

Set-Location $PSScriptRoot

$terraformArguments = @('-auto-approve', '-compact-warnings')

switch ($Action) {
    'force' {
        $terraformArguments += '-replace=oci_core_instance.compute_instance'
    }
    'destroy' {
        $terraformArguments = @('-destroy', '-auto-approve')
    }
}

if ($TerraformArguments.Count -gt 0) {
    $terraformArguments += $TerraformArguments
}

$terraformArguments = @($terraformArguments | Select-Object -Unique)

Write-Host "terraform " -ForegroundColor DarkYellow -NoNewline
Write-Host "apply " -ForegroundColor Cyan -NoNewline
Write-Host "$($terraformArguments -join ' ')" -ForegroundColor DarkRed
& terraform apply @terraformArguments 1>NUL
$terraformExit = $LASTEXITCODE

if ($terraformExit -eq 0 -and $Action -in @('apply', 'force')) {
    & (Join-Path $PSScriptRoot 'outputs.ps1')
    # & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'outputs.ps1')
}

if ($terraformExit -eq 0 -and $Action -eq 'destroy') {
    & $hostExecutable -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tf_apply.ps1') apply
    $terraformExit = $LASTEXITCODE
}
exit $terraformExit 
