param(
    [string]$ServerInstance = "MSI\MSSQLSERVER01",
    [switch]$UseSqlAuth,
    [string]$Username = "",
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

$scripts = @(
    (Join-Path $basePath "01_create_database.sql")
    (Join-Path $basePath "02_create_tables.sql")
    (Join-Path $basePath "03_views.sql")
    (Join-Path $basePath "04_create_app_login.sql")
)

foreach ($script in $scripts) {
    if (-not (Test-Path $script)) {
        throw "Khong tim thay script: $script"
    }
}

Write-Host "Dang thuc thi SQL scripts tren server $ServerInstance ..." -ForegroundColor Cyan

foreach ($script in $scripts) {
    Write-Host "-> $([System.IO.Path]::GetFileName($script))" -ForegroundColor Yellow

    if ($UseSqlAuth) {
        if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
            throw "Khi dung -UseSqlAuth, ban phai truyen -Username va -Password"
        }
        sqlcmd -S $ServerInstance -U $Username -P $Password -i $script -b
    } else {
        sqlcmd -S $ServerInstance -E -i $script -b
    }
}

Write-Host "Hoan tat khoi tao database VotingDApp." -ForegroundColor Green
