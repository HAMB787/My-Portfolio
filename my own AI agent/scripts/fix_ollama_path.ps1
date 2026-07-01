# Fix Ollama "500 Internal Server Error" when Windows username has Cyrillic/non-English characters.
# Run this once in PowerShell, then RESTART Ollama from Start menu.

$modelsPath = "C:\ollama-models"
New-Item -ItemType Directory -Force -Path $modelsPath | Out-Null

# Set user environment variable (ASCII-only path)
[System.Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $modelsPath, "User")
$env:OLLAMA_MODELS = $modelsPath

Write-Host ""
Write-Host "Done. OLLAMA_MODELS = $modelsPath" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Quit Ollama completely (right-click tray icon -> Quit)"
Write-Host "2. Open Ollama again from Start menu"
Write-Host "3. Run in a NEW terminal:"
Write-Host '   & "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" pull qwen2.5:7b'
Write-Host "4. Test:"
Write-Host '   & "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" run qwen2.5:7b "hello"'
Write-Host ""
