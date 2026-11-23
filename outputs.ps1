$stateFile = Join-Path $PSScriptRoot "terraform.tfstate"

if (-not (Test-Path -LiteralPath $stateFile)) {
    Write-Error "Terraform state file not found: $stateFile"
    exit 1
}

$state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json

$lines = @()

Write-Host "{"
$lines += "{"
$properties = @($state.outputs.PSObject.Properties)

for ($i = 0; $i -lt $properties.Count; $i++) {
    $property = $properties[$i]
    $line = "  `"$($property.Name)`": "
    Write-Host $line -ForegroundColor Cyan
    $lines += $line

    $json = ConvertTo-Json -InputObject $property.Value.value -Depth 10

    $line = ($json -split "`r?`n" | ForEach-Object { "    $_" }) -join "`n"
    if ($i -lt $properties.Count - 1) {
        $line += ","
    }
    Write-Host $line
    $lines += $line

}
$lines += "}"

$outputFile = Join-Path $PSScriptRoot "outputs.json"
$lines -join "`r`n" | Set-Content -LiteralPath $outputFile -Encoding utf8


write-host "--------------------------" -ForegroundColor Green
write-host "--                      --" -ForegroundColor Green
write-host "-- "-ForegroundColor Green -noNewLine
write-host "outputs.json created" -ForegroundColor Yellow -noNewLine
write-host " --"-ForegroundColor Green
write-host "--                      --" -ForegroundColor Green
write-host "--------------------------" -ForegroundColor Green

