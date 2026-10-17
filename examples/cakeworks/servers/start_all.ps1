# Windows equivalent of start_all.sh. Starts the servers of one profile in the background, waits for each health URL
# (at most 180 s each), and writes "name pid" lines to servers\.pids. Logs go to servers\<name>.log.
# Usage: .\start_all.ps1 -Profile light|full|text_only     (default: light)
param(
	[ValidateSet("light", "full", "text_only")]
	[string]$Profile = "light",
	[string]$ModelsDir = (Join-Path $env:USERPROFILE "npcf-models")
)
$ErrorActionPreference = "Stop"
$serversDir = $PSScriptRoot
$pidsFile = Join-Path $serversDir ".pids"
if (Test-Path $pidsFile) {
	throw "Servers are already recorded in $pidsFile. Run stop_all.ps1 first."
}

# Each server: the command, its arguments, and the health URL (strict = only 200 counts).
$servers = [ordered]@{}
$servers["gemma"] = @{ File = "llama-server"; Args = @("-hf", "ggml-org/gemma-4-12B-GGUF:Q4_K_M", "--jinja", "--host", "127.0.0.1", "--port", "8090", "-c", "8192", "-ngl", "99"); Health = "http://127.0.0.1:8090/v1/models"; Strict = $false }
$kevRun = if ($Profile -eq "light") { "jaredpalmer/kev-0.8b" } else { "jaredpalmer/kev-4b" }
$servers["kev"] = @{ File = "uv"; Args = @("run", "--extra", "serve", "python", "-m", "kev.serve", "--run", $kevRun, "--port", "8009"); WorkDir = (Join-Path $ModelsDir "kev"); Health = "http://127.0.0.1:8009/v1/models"; Strict = $false }
$parakeetArgs = @((Join-Path $serversDir "parakeet\server.py"), "--host", "127.0.0.1", "--port", "8010")
if ($Profile -eq "light") { $parakeetArgs += "--cpu" }
$servers["parakeet"] = @{ File = (Join-Path $ModelsDir "parakeet-venv\Scripts\python.exe"); Args = $parakeetArgs; Health = "http://127.0.0.1:8010/health"; Strict = $true }
$breezeWeights = if ($Profile -eq "light") { "breeze-tts-2-q4_k.gguf" } else { "breeze-tts-2-q8_0.gguf" }
$servers["breeze"] = @{ File = (Join-Path $ModelsDir "Breeze-TTS-2.cpp\build\Release\breeze-server.exe"); Args = @((Join-Path $ModelsDir $breezeWeights), "--host", "127.0.0.1", "--port", "8080"); Health = "http://127.0.0.1:8080/"; Strict = $false }

$names = switch ($Profile) {
	"light" { @("gemma", "kev", "parakeet", "breeze") }
	"full" { @("gemma", "kev", "parakeet", "breeze") }
	"text_only" { @("gemma", "kev") }
}

$lines = @()
foreach ($name in $names) {
	$s = $servers[$name]
	$log = Join-Path $serversDir "$name.log"
	$proc = Start-Process -FilePath $s.File -ArgumentList $s.Args -WorkingDirectory $(if ($s.WorkDir) { $s.WorkDir } else { $serversDir }) `
		-RedirectStandardOutput $log -RedirectStandardError (Join-Path $serversDir "$name.err.log") -WindowStyle Hidden -PassThru
	$lines += "$name $($proc.Id)"
	Set-Content -Path $pidsFile -Value $lines
	Write-Host "waiting for $name at $($s.Health)"
	$ready = $false
	for ($i = 0; $i -lt 180 -and -not $ready; $i++) {
		if ($proc.HasExited) { throw "$name exited early; see $log" }
		try {
			$response = Invoke-WebRequest -Uri $s.Health -UseBasicParsing -TimeoutSec 2
			$ready = [bool]($response.StatusCode -eq 200 -or (-not $s.Strict -and $response.StatusCode -lt 500))
		} catch {
			# A non-2xx answer throws; a non-strict server still counts as up below 500.
			$code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
			$ready = [bool](-not $s.Strict -and $code -ge 200 -and $code -lt 500)
		}
		if (-not $ready) { Start-Sleep -Seconds 1 }
	}
	if (-not $ready) { throw "$name did not answer at $($s.Health) within 180 s; see $log" }
	Write-Host "ready: $name"
}
Write-Host "All servers for profile $Profile answer. Run the smoke check next."
