# Start FastAPI backend (run from project root)
Set-Location $PSScriptRoot\..
pip install fastapi "uvicorn[standard]" python-multipart -q
uvicorn src.api:app --reload --host 127.0.0.1 --port 8000
