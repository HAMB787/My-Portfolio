# Start the web chat interface (checks Ollama + model first)
Set-Location $PSScriptRoot\..

$ollama = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
$modelsPath = [System.Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "User")
if (-not $modelsPath) { $modelsPath = "C:\ollama-models" }

Write-Host "Checking Ollama models..." -ForegroundColor Cyan
$list = & $ollama list 2>&1 | Out-String

if ($list -notmatch "qwen2.5:3b") {
    Write-Host ""
    Write-Host "PROBLEM: qwen2.5:3b not found by Ollama." -ForegroundColor Red
    Write-Host ""
    Write-Host "Fix:" -ForegroundColor Yellow
    Write-Host "  1. Open Ollama app -> Settings -> Model location"
    Write-Host "  2. Set to: C:\ollama-models"
    Write-Host "  3. Quit Ollama (tray icon -> Quit), reopen from Start menu"
    Write-Host "  4. Run this script again"
    Write-Host ""
    Write-Host "Current models Ollama sees:" -ForegroundColor Yellow
    & $ollama list
    exit 1
}

Write-Host "Model qwen2.5:3b found. Starting web UI..." -ForegroundColor Green
streamlit run src/ui/app.py
