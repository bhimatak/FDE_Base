<#
=====================================================================
 create_env.ps1 - creates the project-root .env file for the legacy
 MySQL system on WINDOWS. Works in Windows PowerShell 5.1 and in
 PowerShell 7. (On a Mac or Linux use create_env.sh instead.)

 Run from the project folder:
   powershell -NoProfile -ExecutionPolicy Bypass -File .\legacy_system\create_env.ps1

 - Asks for two passwords without showing them on screen.
 - Never prints the passwords and never overwrites an existing .env.
 - Writes plain UTF-8 (no BOM) with Unix line endings, which Docker
   Compose, MySQL and Python all read the same way on every OS.
 - Restricts .env so that only your Windows user can open it.

 Allowed password characters: letters, digits and  _ @ % + = . -
 (so they work unchanged in Docker Compose, MySQL and Python later on).
=====================================================================
#>
$ErrorActionPreference = 'Stop'

$RootDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $RootDir '.env'

if (Test-Path -LiteralPath $EnvFile) {
    Write-Host "INFO: $EnvFile already exists - nothing was changed."
    Write-Host "      To start again, rename it first, e.g.  Rename-Item .env .env.old"
    exit 0
}

function ConvertTo-PlainText([System.Security.SecureString]$Secure) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Read-NewPassword([string]$Purpose) {
    while ($true) {
        $first  = ConvertTo-PlainText (Read-Host -AsSecureString "New password for $Purpose (hidden)")
        $second = ConvertTo-PlainText (Read-Host -AsSecureString "Type it again")
        if ($first -cne $second) {
            Write-Host "  x The two entries are different. Please try again."
            continue
        }
        if ($first.Length -lt 8) {
            Write-Host "  x Use at least 8 characters. Please try again."
            continue
        }
        if ($first -cnotmatch '^[A-Za-z0-9_@%+=.-]+$') {
            Write-Host "  x Use only letters, digits and  _ @ % + = . -  Please try again."
            continue
        }
        return $first
    }
}

Write-Host "Creating $EnvFile"
Write-Host ""
$rootPw = Read-NewPassword "the MySQL admin user 'root'"
Write-Host ""
$biPw = Read-NewPassword "the read-only login 'bi_analyst'"
if ($rootPw -ceq $biPw) {
    Write-Host "  ! Note: both passwords are the same. That works, but different ones are safer."
}

$lines = @(
    '# =====================================================================',
    '# FDE Cold-Chain project - private settings. NEVER commit this file.',
    '# Created by legacy_system/create_env.ps1',
    '# =====================================================================',
    '',
    '# ---- Step 1: legacy system (MySQL 8.4 in Docker) ----',
    'DB_ENGINE=MYSQL',
    'MYSQL_HOST=127.0.0.1',
    'MYSQL_PORT=3306',
    'MYSQL_ADMIN_USER=root',
    "MYSQL_ROOT_PASSWORD=$rootPw",
    'LEGACY_DB=legacy_fleet',
    'LEGACY_TABLE=TBL_SC_FLEET_HIST_RAW',
    'BI_ANALYST_USER=bi_analyst',
    "BI_ANALYST_PASSWORD=$biPw"
)
$content = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($EnvFile, $content, (New-Object System.Text.UTF8Encoding($false)))
Remove-Variable rootPw, biPw, content, lines -ErrorAction SilentlyContinue

# Only your Windows user may open .env (best effort: .env is created either way).
try {
    $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $EnvFile /inheritance:r /grant:r "${me}:(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "icacls exit code $LASTEXITCODE" }
}
catch {
    Write-Host "  ! .env was created, but access could not be limited to your user: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "OK: .env created (passwords not shown). Settings in the file:"
Get-Content -LiteralPath $EnvFile |
    Where-Object { $_ -cmatch '^[A-Z_]+=' } |
    ForEach-Object { $_ -creplace '^([A-Z_]*PASSWORD)=.+$', '$1=******** (set)' }
