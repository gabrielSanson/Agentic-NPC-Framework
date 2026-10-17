# Windows equivalent of stop_all.sh. Stops the servers recorded in servers\.pids by start_all.ps1.
# Usage: .\stop_all.ps1
$ErrorActionPreference = "Stop"
$pidsFile = Join-Path $PSScriptRoot ".pids"
if (-not (Test-Path $pidsFile)) {
	Write-Host "No servers recorded."
	exit 0
}
foreach ($line in Get-Content $pidsFile) {
	$name, $procId = $line -split " "
	$proc = Get-Process -Id ([int]$procId) -ErrorAction SilentlyContinue
	if ($proc) {
		Stop-Process -Id $proc.Id
		Write-Host "stopped $name ($procId)"
	} else {
		Write-Host "$name was not running"
	}
}
Remove-Item $pidsFile
