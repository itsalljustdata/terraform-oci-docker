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
  apply    Run terraform apply -auto-approve -compact-warnings -replace=oci_core_instance.compute_instance
  preserve  Run terraform apply -auto-approve -compact-warnings without replacing oci_core_instance.compute_instance
  destroy  Run terraform apply -destroy -auto-approve

Examples:
  .\tf_apply.ps1
  .\tf_apply.ps1 apply
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

$terraformArgsDefault = @('-auto-approve', '-compact-warnings')
$terraformArgumentsDestroy = @('-destroy') + $terraformArgsDefault
$terraformArguments = $terraformArgsDefault + ('-replace=oci_core_instance.compute_instance')

$extraLogName=''

switch ($Action) {
    'preserve' {
        $terraformArguments = $terraformArgsDefault
        $extraLogName+='.' + $Action
    }
    'destroy' {
        $terraformArguments = $terraformArgumentsDestroy
        $extraLogName+='.' + $Action
    }
}

if ($TerraformArguments.Count -gt 0) {
    $terraformArguments += $TerraformArguments
}

$terraformArguments = @($terraformArguments | Select-Object -Unique)

$stdoutFile = "terraform.stdout.$extraLogName.log"
$stderrFile = "terraform.stderr.$extraLogName.log"

if ( Test-Path $stdoutFile) {
    Remove-Item $stdoutFile -Force
}
if ( Test-Path $stderrFile) {
    Remove-Item $stderrFile -Force
}

Write-Host "terraform " -ForegroundColor DarkYellow -NoNewline
Write-Host "apply " -ForegroundColor Cyan -NoNewline
Write-Host "$($terraformArguments -join ' ')" -ForegroundColor DarkRed
& terraform apply @terraformArguments 2>&1 |
    ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $theFile = $stderrFile
        } else {
            $theFile = $stdoutFile
        }
        $_ | Tee-Object -FilePath $theFile -Append
    }
$terraformExit = $LASTEXITCODE

if ($terraformExit -eq 0 -and $Action -in @('apply', 'preserve')) {
    & (Join-Path $PSScriptRoot 'outputs.ps1')
    # & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'outputs.ps1')
}

if ($terraformExit -eq 0 -and $Action -eq 'destroy') {
    & $hostExecutable -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tf_apply.ps1') apply
    $terraformExit = $LASTEXITCODE
}
exit $terraformExit 
