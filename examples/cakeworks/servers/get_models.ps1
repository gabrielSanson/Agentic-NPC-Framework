# Windows equivalent of get_models.sh. Prepares everything under $ModelsDir (default %USERPROFILE%\npcf-models).
# Steps are skipped when their files already exist. Breeze needs two GGUF URLs (copied from Hugging Face) in
# $env:BREEZE_Q8_URL and $env:BREEZE_Q4_URL. Gemma and Parakeet download their weights on first start.
# Usage: .\get_models.ps1 [-ModelsDir <path>]
param(
	[string]$ModelsDir = (Join-Path $env:USERPROFILE "npcf-models")
)
$ErrorActionPreference = "Stop"
$serversDir = $PSScriptRoot
New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null

Write-Host "== Kev: clone and install"
if (-not (Test-Path (Join-Path $ModelsDir "kev"))) {
	git clone https://github.com/jaredpalmer/kev (Join-Path $ModelsDir "kev")
}
Push-Location (Join-Path $ModelsDir "kev")
uv sync --extra serve
Pop-Location

Write-Host "== Parakeet: virtual environment and packages (weights download on first start, about 2.4 GB)"
$parakeetPy = Join-Path $ModelsDir "parakeet-venv\Scripts\python.exe"
if (-not (Test-Path $parakeetPy)) {
	python -m venv (Join-Path $ModelsDir "parakeet-venv")
}
& $parakeetPy -m pip install -r (Join-Path $serversDir "parakeet\requirements.txt")

Write-Host "== Breeze: source and build"
$breezeDir = Join-Path $ModelsDir "Breeze-TTS-2.cpp"
if (-not (Test-Path $breezeDir)) {
	git clone https://github.com/HoppouAI/Breeze-TTS-2.cpp $breezeDir
}
$breezeBin = Join-Path $breezeDir "build\Release\breeze-server.exe"
if (-not (Test-Path $breezeBin)) {
	cmake -S $breezeDir -B (Join-Path $breezeDir "build") -DGGML_VULKAN=ON
	cmake --build (Join-Path $breezeDir "build") --config Release
}

Write-Host "== Breeze: GGUF weights (non-commercial license, see demo\README.md)"
$files = @(
	@{ Name = "breeze-tts-2-q8_0.gguf"; Url = $env:BREEZE_Q8_URL },
	@{ Name = "breeze-tts-2-q4_k.gguf"; Url = $env:BREEZE_Q4_URL }
)
foreach ($item in $files) {
	$target = Join-Path $ModelsDir $item.Name
	if (Test-Path $target) {
		Write-Host "exists: $target"
	} elseif (-not $item.Url) {
		Write-Warning "skipped: $($item.Name) (set the matching BREEZE_*_URL variable to download it)"
	} else {
		Invoke-WebRequest -Uri $item.Url -OutFile $target
	}
}
Write-Host "== Done."
