<#
.SYNOPSIS
  Determines whether the device is already enrolled in Intune MDM and triggers auto-enrollment if not.

.DESCRIPTION
  - Validates admin context and Entra ID join state (dsregcmd)
    - Attempts to validate required MDM enrollment URLs under CloudDomainJoin\TenantInfo\<TenantGuid>
  - Detects existing Intune MDM enrollment via registry keys
  - Triggers enrollment using DeviceEnroller.exe /c /AutoEnrollMDM
  - Re-checks enrollment with retries and reports results

.NOTES
  Requires:
   - Device is Entra ID joined (AzureAdJoined = YES)
   - Tenant has MDM user scope enabled for the user (Some/All) and user is licensed for Intune
   - Run as Local Administrator
#>

[CmdletBinding()]
param(
    [switch]$VerboseOutput,
    [int]$RetryCount = 6,
    [int]$RetryDelaySeconds = 10
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO ] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[WARN ] $msg" -ForegroundColor Yellow }
function Write-Err ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Get-DsregStatusText {
    param([string]$DsregPath)
    $output = & $DsregPath /status 2>&1
    if ($VerboseOutput) {
        Write-Host "------ dsregcmd /status output (truncated) ------"
        $output | Select-Object -First 120
        Write-Host "-------------------------------------------------"
    }
    return ($output -join "`n")
}

function Get-TenantIdFromDsreg {
    param([string]$DsregText)
    $match = [regex]::Match($DsregText, 'TenantId\s*:\s*([0-9a-fA-F-]{36})')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Get-MdmUrls {
    param([string]$TenantId)
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\TenantInfo\$TenantId",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\AAD\TenantInfo\$TenantId"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $props = Get-ItemProperty -Path $path
            return [pscustomobject]@{
                MdmEnrollmentUrl = $props.MdmEnrollmentUrl
                MdmUrl           = $props.MdmUrl
                MdmComplianceUrl = $props.MdmComplianceUrl
                Path             = $path
                FoundPath        = $true
                PathCandidates   = $paths
            }
        }
    }

    return [pscustomobject]@{
        MdmEnrollmentUrl = $null
        MdmUrl           = $null
        MdmComplianceUrl = $null
        Path             = $null
        FoundPath        = $false
        PathCandidates   = $paths
    }
}

function Get-IntuneEnrollmentKeys {
    $enrollPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    if (-not (Test-Path $enrollPath)) { return @() }

    $keys = Get-ChildItem -Path $enrollPath -ErrorAction SilentlyContinue
    $results = foreach ($key in $keys) {
        # Skip non-GUID keys (Context, Status, Ownership, etc.)
        if ($key.PSChildName -notmatch '^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$') {
            continue
        }

        $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
        $discoveryUrl = $props.DiscoveryServiceFullURL
        $providerId = $props.ProviderID

        $isIntune = ($discoveryUrl -match 'manage(-beta)?\.microsoft\.com') -or
                    ($providerId -match 'Intune|MS DM Server|Microsoft MDM')

        [pscustomobject]@{
            KeyName              = $key.PSChildName
            ProviderID           = $providerId
            DiscoveryServiceUrl  = $discoveryUrl
            EnrollmentType       = $props.EnrollmentType
            EnrollmentState      = $props.EnrollmentState
            IsIntune             = $isIntune
        }
    }

    return $results
}

function Get-EnrollmentStatusKeys {
    $statusPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\Status"
    if (-not (Test-Path $statusPath)) { return @() }
    return Get-ChildItem -Path $statusPath -ErrorAction SilentlyContinue
}

try {
    # 1) Admin check
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Err "This script must be run as Local Administrator."
        exit 1
    }
    Write-Info "Running as Administrator."

    # 2) Locate required binaries
    $dsreg = Join-Path $env:WINDIR "System32\dsregcmd.exe"
    $enroller = Join-Path $env:WINDIR "System32\DeviceEnroller.exe"

    if (-not (Test-Path $dsreg)) { Write-Err "dsregcmd.exe not found at $dsreg"; exit 2 }
    if (-not (Test-Path $enroller)) { Write-Err "DeviceEnroller.exe not found at $enroller"; exit 3 }

    Write-Info "Found dsregcmd.exe and DeviceEnroller.exe."

    # 3) Check join state
    Write-Info "Checking Entra ID join state (dsregcmd /status)..."
    $dsregText = Get-DsregStatusText -DsregPath $dsreg

    $azureAdJoined = ($dsregText -match 'AzureAdJoined\s*:\s*YES')
    if (-not $azureAdJoined) {
        Write-Err "Device does not appear to be Entra ID joined (AzureAdJoined: YES not found). Enrollment will not proceed."
        exit 4
    }
    Write-Info "Device is Entra ID joined."

    $tenantId = Get-TenantIdFromDsreg -DsregText $dsregText
    if (-not $tenantId) {
        Write-Err "TenantId not found in dsregcmd output. Cannot validate MDM URLs."
        exit 5
    }

    # 4) Validate MDM enrollment URLs
    $mdmUrls = Get-MdmUrls -TenantId $tenantId
    if (-not $mdmUrls.FoundPath) {
        Write-Warn "TenantInfo registry path not found for TenantId $tenantId."
        Write-Warn "Checked: $($mdmUrls.PathCandidates -join '; ')"
        Write-Warn "Continuing without MDM URL validation."
    } else {
        $missingUrls = @()
        if (-not $mdmUrls.MdmEnrollmentUrl) { $missingUrls += "MdmEnrollmentUrl" }
        if (-not $mdmUrls.MdmUrl) { $missingUrls += "MdmUrl" }
        if (-not $mdmUrls.MdmComplianceUrl) { $missingUrls += "MdmComplianceUrl" }

        if ($missingUrls.Count -gt 0) {
            Write-Warn "Missing MDM URL values under $($mdmUrls.Path): $($missingUrls -join ', ')"
            Write-Warn "Continuing without full MDM URL validation."
        } else {
            Write-Info "MDM enrollment URLs found."
        }
    }

    # 5) Detect existing enrollment
    $enrollmentKeys = Get-IntuneEnrollmentKeys
    $intuneKeys = $enrollmentKeys | Where-Object { $_.IsIntune }
    $statusKeys = Get-EnrollmentStatusKeys

    if ($VerboseOutput -and $enrollmentKeys.Count -gt 0) {
        Write-Host "------ Enrollment keys (truncated) ------"
        $enrollmentKeys | Select-Object -First 20 | Format-Table -AutoSize
        Write-Host "-----------------------------------------"
    }

    if ($VerboseOutput -and $statusKeys.Count -gt 0) {
        Write-Host "------ Enrollment status keys (truncated) ------"
        $statusKeys | Select-Object -First 20 | Select-Object -ExpandProperty PSChildName
        Write-Host "------------------------------------------------"
    }

    if ($intuneKeys.Count -gt 0) {
        Write-Info "Intune MDM enrollment detected. No action needed."
        exit 0
    }

    if ($statusKeys.Count -gt 0) {
        Write-Warn "Enrollment status keys found, but Intune-specific identifiers were not detected."
        Write-Warn "Assuming device is already enrolled."
        exit 0
    }

    # 6) Trigger enrollment
    Write-Info "No Intune enrollment detected. Triggering DeviceEnroller.exe /c /AutoEnrollMDM..."
    $proc = Start-Process -FilePath $enroller -ArgumentList "/c", "/AutoEnrollMDM" -PassThru -Wait -WindowStyle Hidden
    if ($proc.ExitCode -ne 0) {
        Write-Err "DeviceEnroller.exe returned exit code $($proc.ExitCode)."
        exit 8
    }

    # 7) Re-check enrollment with retries
    Write-Info "Waiting for enrollment to complete..."
    $enrolled = $false
    for ($i = 1; $i -le $RetryCount; $i++) {
        Start-Sleep -Seconds $RetryDelaySeconds
        $intuneKeys = (Get-IntuneEnrollmentKeys | Where-Object { $_.IsIntune })
        if ($intuneKeys.Count -gt 0) {
            $enrolled = $true
            break
        }
        Write-Info "Enrollment not detected yet (attempt $i of $RetryCount)."
    }

    if ($enrolled) {
        Write-Info "Intune MDM enrollment detected."
        exit 0
    }

    Write-Warn "Enrollment was triggered but not detected after retries."
    Write-Warn "Check Event Viewer: Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider."
    exit 9
}
catch {
    Write-Err $_.Exception.Message
    exit 99
}
