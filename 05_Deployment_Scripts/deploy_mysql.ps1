param (
    [string]$MySqlUser = "root",
    [string]$MySqlPassword = ""
)

$SqlFile = "$PSScriptRoot\..\03_Database_MySQL\init_bpcl_dw.sql"

if (-not (Test-Path $SqlFile)) {
    Write-Error "SQL initialization script not found at: $SqlFile"
    exit
}

Write-Host "Deploying MySQL Database 'bpcl_dallirajhara_db'..." -ForegroundColor Cyan

if ($MySqlPassword -eq "") {
    & mysql -u $MySqlUser -e "source $SqlFile"
} else {
    & mysql -u $MySqlUser -p$MySqlPassword -e "source $SqlFile"
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "MySQL Database, Tables, Procedures, and Seed Data deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "Deployment failed. Ensure MySQL is running and accessible in your PATH environment variable." -ForegroundColor Red
}
