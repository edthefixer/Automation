<#
.SYNOPSIS
Comprehensive Azure Virtual Desktop (AVD) Prerequisites Validation and Configuration Tool with Advanced VM SKU Intelligence

NOTE: PLATFORM-LEVEL VALIDATION FOR GENERIC AVD DEPLOYMENTS
This script validates the entire Azure tenant ecosystem for AVD requirements, independent of any specific deployment methodology.
It performs platform-level readiness checks suitable for ANY AVD deployment approach (manual, ARM templates, Bicep, Terraform, etc.).
For AVD Accelerator-specific prerequisites, use 04_AVD_Check_Prerequisites_Confirmation_Final.ps1 instead.

.DESCRIPTION
This advanced PowerShell script provides a complete end-to-end validation and preparation toolkit for Azure Virtual Desktop deployments. 
It consolidates multiple validation processes into a single, intelligent tool that guides users through the entire AVD prerequisite 
assessment process with enhanced user experience, detailed reporting capabilities, and sophisticated VM SKU selection and analysis.

CORE FUNCTIONALITY:
- Azure Environment Validation: Automated module installation with intelligent version conflict resolution
  * CRITICAL: Az.Accounts (foundation), Az.Resources (resource management)
  * OPTIONAL: Az.Network, Az.Compute, Az.Storage, Az.Security (graceful degradation if unavailable)
  * OPTIONAL: ImportExcel (falls back to CSV if unavailable)
- Comprehensive Authentication: 5 authentication methods (Interactive Browser, Device Code, Service Principal with Secret/Certificate, Managed Identity)
- Subscription Management: Interactive subscription selection and validation with multi-tenant support
- Resource Provider Management: Automated registration of all required AVD resource providers with status monitoring
- Service Principal Validation: AVD service principal discovery and RBAC verification with role assignment checking
- Advanced Region Selection: Smart region picker with top 10 popular regions + expandable full list ('more'/'less' navigation)
- Zone Redundancy Analysis: Comprehensive availability zone support validation (requires Az.Compute)
- Active Directory Integration: DNS resolution, domain controller discovery, and LDAP connectivity testing
- Identity Provisioning Models: Support for ADDS (On-premises), Entra ID Only, and Entra ID Kerberos hybrid configurations
- Advanced VM SKU Intelligence: Smart SKU selection, restriction analysis, and quota validation (requires Az.Compute)

ADVANCED VM SKU CAPABILITIES:
- Smart Auto-Complete Selection: Interactive VM SKU picker with partial name matching and auto-suggestions
- Comprehensive Restriction Analysis: Real-time detection of Azure policy restrictions, capacity limits, and deployment blockers
- Quota & Limits Validation: Multi-layered quota analysis including Regional vCPUs, VM Family quotas, and resource limits
- Deployment Readiness Assessment: Critical quota validation with deployment success/failure predictions
- Alternative SKU Recommendations: Intelligent suggestions for unrestricted SKU alternatives in the selected region
- Enhanced Capabilities Analysis: Detailed VM specifications including vCPUs, memory, storage, and networking capabilities

ENHANCED FEATURES:
- Intelligent Logging System: Color-coded console output with detailed validation logging and component tracking
- Professional Reporting: Dual-format reporting (Excel with conditional formatting or CSV fallback) with comprehensive execution summaries
- Interactive User Experience: Smart prompts, progressive disclosure, auto-completion, and user-friendly navigation
- Advanced Error Handling: Comprehensive error management with actionable remediation recommendations and recovery strategies
- Flexible Authentication: Support for corporate environments with MFA, conditional access, and service principal automation
- Real-time Progress Tracking: Live validation status with pass/fail/warning/info categorization and detailed statistics
- Configuration Summary: Pre-validation configuration review with user confirmation before proceeding

VALIDATION COMPONENTS:
1. Module Management - Automated installation and import of required PowerShell modules
2. Azure Authentication - Multi-method authentication with corporate MFA/SSO compatibility and fallback options
3. Subscription Validation - Subscription access verification and interactive selection
4. Resource Provider Registration - Automated registration of Microsoft.DesktopVirtualization and dependencies
5. AVD Service Principal Validation - Service principal discovery and Desktop Virtualization Contributor role verification
6. Region Selection & Validation - Smart region selection with compute capability verification
7. Zone Redundancy Assessment - Availability zone support analysis for VMs, disks, networking, and load balancers
8. Active Directory Connectivity - Domain resolution, DC discovery, and LDAP port testing (supports multiple identity models)
9. Advanced VM SKU Analysis - Smart SKU selection with restriction detection, quota validation, and deployment readiness
10. Comprehensive Quota Assessment - Multi-tier quota analysis with deployment impact predictions and recommendations

VM SKU INTELLIGENCE FEATURES:
- Interactive SKU Selection: Auto-complete functionality with partial matching (e.g., typing "D4" shows all D4 variants)
- Real-time Restriction Detection: Identifies policy-based, capacity, and geographic restrictions with detailed explanations
- Comprehensive Quota Analysis: Validates Total Regional vCPUs, VM Family quotas, Standard vCPUs, and supporting resource quotas
- Deployment Impact Assessment: Predicts deployment success/failure based on current quota utilization and requirements
- Alternative Recommendations: Suggests unrestricted SKU alternatives when preferred SKU has limitations
- Detailed Capability Analysis: Memory, CPU, storage, networking, and specialized feature support breakdown

.PARAMETER TargetRegion
Azure region for AVD deployment validation. If not specified, displays interactive region selection menu 
with top 10 popular regions and expandable full list. Validates region supports required resource types.

.PARAMETER Environment  
Environment classification for deployment context and reporting. Accepts: Development, Testing, Production.
Used for validation context and report categorization. Defaults to "Production" for strict validation.

.PARAMETER DomainName
Fully qualified domain name (FQDN) for Active Directory integration validation. Enables DNS resolution 
testing, domain controller discovery, and LDAP connectivity verification. Prompted interactively if not provided.

.PARAMETER SkipADValidation
Bypass Active Directory connectivity and domain validation checks. Use when deploying AVD with 
Entra ID-only authentication or when domain validation is not required for the deployment scenario.

.PARAMETER SkipHybridIdentity  
Skip Entra ID Kerberos hybrid identity prerequisites validation. Use when not implementing hybrid 
authentication or when Kerberos authentication setup is not part of the current deployment phase.

.PARAMETER NonInteractive
Execute in automated mode with minimal user prompts. Uses default selections where possible and 
reduces interactive components for CI/CD integration. Still prompts for required missing parameters.

.PARAMETER ReportPath
Custom directory path for saving validation reports. If not specified, saves reports to script location 
or current working directory. Creates directory if it doesn't exist. Supports both Excel and CSV formats.

EXAMPLE
.\03_AVD_Check_Prerequisites_Platform_Final.ps1
Run complete interactive validation with guided prompts, smart region selection, VM SKU auto-complete picker, and comprehensive quota analysis

EXAMPLE  
.\03_AVD_Check_Prerequisites_Platform_Final.ps1 -TargetRegion "West US 2" -Environment "Production" -DomainName "contoso.com"
Run with pre-configured settings for production environment with specific domain validation and advanced SKU analysis

EXAMPLE
.\03_AVD_Check_Prerequisites_Platform_Final.ps1 -SkipADValidation -NonInteractive -ReportPath "C:\Reports"
Run automated validation without Active Directory checks, includes VM SKU restriction and quota analysis, save reports to custom location

EXAMPLE
.\03_AVD_Check_Prerequisites_Platform_Final.ps1 -SkipHybridIdentity -Environment "Development"
Run validation for development environment without Entra ID Kerberos checks, includes comprehensive VM SKU intelligence

EXAMPLE
.\03_AVD_Check_Prerequisites_Platform_Final.ps1 -NonInteractive -TargetRegion "East US" -SkipADValidation -SkipHybridIdentity
Run fully automated validation with minimal user interaction, VM SKU auto-selection, and quota validation for CI/CD pipeline integration

.NOTES
File Name      : 03_AVD_Check_Prerequisites_Platform_Final.ps1
Author         : edthefixer + GitHub Copilot... well, I fell asleep, copilot finished it...
Prerequisite   : PowerShell 5.1+, Internet connectivity for module installation
Version        : 3.1.0
Creation Date  : 2025
Last Updated   : February 2026

RECENT ENHANCEMENTS (v3.1.0):
- Intelligent Module Conflict Resolution: Automatic detection and recovery from Az module version conflicts
- Graceful Module Degradation: Critical vs. non-critical module classification with smart fallback
- Enhanced Retry Logic: Aggressive module cleanup and reinstallation for persistent compatibility issues
- Module Health Checks: Pre-flight validation of Az module versions and conflict detection
- Smart Feature Skipping: Continues with reduced functionality when optional modules fail to load
- Smart VM SKU Selection: Auto-complete functionality with partial matching and intelligent filtering
- Comprehensive Restriction Analysis: Real-time policy and capacity restriction detection with detailed explanations  
- Advanced Quota Validation: Multi-layer quota analysis with deployment readiness predictions
- Enhanced Authentication: 5 authentication methods including Service Principal and Managed Identity support
- Identity Model Support: ADDS, Entra ID Only, and Entra ID Kerberos configuration validation
- Professional Output: Clean, color-coded console output without emojis for enterprise environments

PERMISSIONS REQUIRED:
- Azure Subscription Contributor or higher for resource provider registration and quota analysis
- Azure AD/Entra ID permissions for service principal and application registration validation
- Network access to domain controllers (TCP 389) for Active Directory validation (when enabled)
- PowerShell execution policy allowing script execution
- Azure resource read permissions for VM SKU and quota information retrieval

OUTPUT FILES:
- Excel Report: 03_AVD_Check_Prerequisites_Platform_Final_YYYYMMDD-HHMMSS.xlsx (with color-coded results)
- CSV Report: 03_AVD_Check_Prerequisites_Platform_Final_YYYYMMDD-HHMMSS.csv (fallback format)
- Console Output: Real-time color-coded validation progress and summary

SUPPORTED ENVIRONMENTS:
- Windows PowerShell 5.1+ and PowerShell 7+
- Azure Commercial and Government clouds
- Multi-tenant Azure environments with proper authentication
- Corporate environments with MFA and conditional access policies

TROUBLESHOOTING AZ MODULE CONFLICTS:
If you encounter "Register-AzModule" or "GetTokenAsync" errors, the script includes automatic recovery.
However, if issues persist after automatic retry, manually resolve with these steps:

1. Update all Az modules to latest versions (RECOMMENDED):
   Update-Module Az -Force -AllowClobber

2. If update fails, uninstall and reinstall Az modules:
   Uninstall-Module Az -AllVersions -Force
   Install-Module Az -Force -AllowClobber -Scope CurrentUser

3. Clear PowerShell module cache:
   Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\ModuleAnalysisCache" -Force

4. Restart PowerShell and re-run this script

The script now includes:
- Automatic module version conflict detection
- Module cache cleanup on errors  
- Retry logic with intelligent recovery
- Priority-based module loading (Az.Accounts first)
- Clean session state initialization
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Primary Azure region for AVD deployment")]
    [string]$TargetRegion,
    
    [Parameter(HelpMessage = "Environment type for deployment")]
    [ValidateSet("Development", "Testing", "Production")]
    [string]$Environment = "Production",
    
    [Parameter(HelpMessage = "Active Directory domain name")]
    [string]$DomainName,
    
    [Parameter(HelpMessage = "Skip Active Directory validation")]
    [switch]$SkipADValidation,
    
    [Parameter(HelpMessage = "Skip Entra ID hybrid identity validation")]
    [switch]$SkipHybridIdentity,
    
    [Parameter(HelpMessage = "Run in non-interactive mode")]
    [switch]$NonInteractive,
    
    [Parameter(HelpMessage = "Custom report output path")]
    [string]$ReportPath
)

#Requires -Version 5.1

# Global variables
$script:Report = @()
$script:ValidationSummary = @{
    TotalChecks = 0
    PassCount = 0
    FailCount = 0
    WarningCount = 0
    InfoCount = 0
    StartTime = Get-Date
    EndTime = $null
}
$script:UseCSVExport = $false
$script:AzureContext = $null
$script:SelectedSubscription = $null
$script:SelectedRegion = $null
$script:SelectedVMSku = $null
# Always reset identity model to null - no caching allowed
$script:SelectedIdentityModel = $null

# Function to check Az module health before loading
function Test-AzModuleHealth {
    Write-Host "Performing Az module health check..." -ForegroundColor Cyan
    
    # Check for conflicting module versions
    $azModules = Get-Module Az.* -ListAvailable | Group-Object Name
    $hasConflicts = $false
    
    foreach ($moduleGroup in $azModules) {
        $versions = $moduleGroup.Group | Select-Object -ExpandProperty Version -Unique
        if ($versions.Count -gt 1) {
            Write-Host "  Warning: Multiple versions detected for $($moduleGroup.Name): $($versions -join ', ')" -ForegroundColor Yellow
            $hasConflicts = $true
        }
    }
    
    # Check if Az.Accounts exists (foundation module)
    $azAccounts = Get-Module Az.Accounts -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $azAccounts) {
        Write-Host "  Az.Accounts not found - will be installed" -ForegroundColor Yellow
        return $true  # Continue with installation
    }
    
    Write-Host "  Az.Accounts version: $($azAccounts.Version)" -ForegroundColor Green
    
    if ($hasConflicts) {
        Write-Host ""
        Write-Host "  Multiple Az module versions detected. This can cause compatibility issues." -ForegroundColor Yellow
        Write-Host "  Recommendation: After this script completes, run 'Update-Module Az -Force' to sync all versions." -ForegroundColor Yellow
        Write-Host ""
    }
    
    return $true
}

# Enhanced logging function
function Write-ValidationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [string]$Check,
        
        [Parameter()]
        [ValidateSet("Pass", "Fail", "Warning", "Info")]
        [string]$Result = "Info",
        
        [Parameter()]
        [string]$Component = "General",
        
        [Parameter()]
        [string]$Details = "",
        
        [Parameter()]
        [string]$Recommendation = ""
    )
    
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    # Console output with colors
    $color = switch ($Result) {
        "Pass" { "Green" }
        "Fail" { "Red" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
    }
    
    $displayMessage = "[$Component] $Check - $Result"
    if ($Details) { $displayMessage += ": $Details" }
    Write-Host "[$timestamp] $displayMessage" -ForegroundColor $color
    
    # Add to report
    $reportEntry = [PSCustomObject]@{
        Timestamp = $timestamp
        Component = $Component
        Check = $Check
        Result = $Result
        Message = $Message
        Details = $Details
        Recommendation = $Recommendation
    }
    $script:Report += $reportEntry
    
    # Update summary
    $script:ValidationSummary.TotalChecks++
    switch ($Result) {
        "Pass" { $script:ValidationSummary.PassCount++ }
        "Fail" { $script:ValidationSummary.FailCount++ }
        "Warning" { $script:ValidationSummary.WarningCount++ }
        "Info" { $script:ValidationSummary.InfoCount++ }
    }
}

# Helper function to aggressively remove module versions
function Remove-ModuleVersions {
    param([string]$ModuleName)
    
    try {
        # Get all installed versions
        $allVersions = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending
        
        if ($allVersions.Count -gt 0) {
            Write-Host "  Found $($allVersions.Count) version(s) of $ModuleName" -ForegroundColor Yellow
            
            # Try to uninstall all versions
            foreach ($version in $allVersions) {
                try {
                    Write-Host "  Attempting to remove $ModuleName version $($version.Version)..." -ForegroundColor Gray
                    Uninstall-Module -Name $ModuleName -RequiredVersion $version.Version -Force -ErrorAction Stop
                    Write-Host "  Successfully removed version $($version.Version)" -ForegroundColor Green
                } catch {
                    # If uninstall fails, try manual removal
                    Write-Host "  Uninstall-Module failed, attempting manual removal..." -ForegroundColor Yellow
                    $modulePath = $version.ModuleBase
                    if (Test-Path $modulePath) {
                        try {
                            Remove-Item -Path $modulePath -Recurse -Force -ErrorAction Stop
                            Write-Host "  Manually removed from: $modulePath" -ForegroundColor Green
                        } catch {
                            Write-Host "  Manual removal also failed: $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "  Error during version cleanup: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Module management function with enhanced version conflict handling
function Initialize-RequiredModules {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " Validate - Azure modules installation " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    # Import Az.Accounts first as it's the foundation module - CRITICAL for avoiding version conflicts
    $requiredModules = @(
        @{Name="Az.Accounts"; Description="Azure authentication and context management"; Priority=1; Critical=$true},
        @{Name="Az.Resources"; Description="Azure resource management"; Priority=2; Critical=$true},
        @{Name="Az.Network"; Description="Azure networking operations"; Priority=3; Critical=$false},
        @{Name="Az.Compute"; Description="Azure compute resources"; Priority=4; Critical=$false},
        @{Name="Az.Storage"; Description="Azure storage operations"; Priority=5; Critical=$false},
        @{Name="Az.Security"; Description="Azure security center integration"; Priority=6; Critical=$false},
        @{Name="ImportExcel"; Description="Excel report generation"; Optional=$true; Priority=7; Critical=$false}
    )
    
    # Sort by priority to ensure correct loading order
    $requiredModules = $requiredModules | Sort-Object Priority
    
    foreach ($moduleInfo in $requiredModules) {
        $moduleName = $moduleInfo.Name
        $isOptional = $moduleInfo.Optional -eq $true
        $retryCount = 0
        $maxRetries = 2
        $moduleImported = $false
        
        while (-not $moduleImported -and $retryCount -le $maxRetries) {
            try {
                Write-ValidationLog -Message "Checking module availability" -Check "Module: $moduleName" -Result "Info" -Component "Module Management"
                
                # Check if module is already loaded in session
                $loadedModule = Get-Module -Name $moduleName
                if ($loadedModule) {
                    Write-ValidationLog -Message "Module already loaded in session" -Check "Module: $moduleName" -Result "Pass" -Component "Module Management" -Details "Version: $($loadedModule.Version)"
                    $moduleImported = $true
                    break
                }
                
                # Check if module is available
                $availableModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
                
                if (-not $availableModule) {
                    Write-ValidationLog -Message "Installing required module" -Check "Module: $moduleName" -Result "Info" -Component "Module Management"
                    
                    if ($moduleName -eq "ImportExcel") {
                        try {
                            Install-Module -Name ImportExcel -Scope CurrentUser -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
                        } catch {
                            Install-Module -Name ImportExcel -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
                        }
                    } else {
                        # For Az modules, install latest version to avoid compatibility issues
                        Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                    }
                    
                    Write-ValidationLog -Message "Successfully installed module" -Check "Module: $moduleName" -Result "Pass" -Component "Module Management"
                    
                    # Refresh available modules after installation
                    $availableModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
                }
                
                # Import module with enhanced compatibility options
                $importParams = @{
                    Name = $moduleName
                    ErrorAction = 'Stop'
                    WarningAction = 'SilentlyContinue'
                    Scope = 'Local'
                }
                
                # Add -SkipEditionCheck for PowerShell 7+ to bypass some compatibility issues
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    $importParams['SkipEditionCheck'] = $true
                }
                
                # Try importing with specific version to avoid conflicts
                if ($availableModule) {
                    $importParams['RequiredVersion'] = $availableModule.Version
                }
                
                Import-Module @importParams
                
                Write-ValidationLog -Message "Successfully imported module" -Check "Module: $moduleName" -Result "Pass" -Component "Module Management" -Details "Version: $($availableModule.Version)"
                $moduleImported = $true
                
            } catch {
                $retryCount++
                $errorMessage = $_.Exception.Message
                
                # Check for type initialization errors (common with version conflicts)
                if ($errorMessage -like "*type initializer*" -or $errorMessage -like "*GetTokenAsync*") {
                    Write-Host "Detected version conflict in $moduleName. Attempting recovery (Retry $retryCount/$maxRetries)..." -ForegroundColor Yellow
                    
                    # Remove all loaded Az modules to clear the conflict
                    Get-Module Az.* | Remove-Module -Force -ErrorAction SilentlyContinue
                    
                    # Clear module analysis cache (can cause persistent errors)
                    $cacheFile = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\PowerShell\ModuleAnalysisCache"
                    if (Test-Path $cacheFile) {
                        try {
                            Remove-Item -Path $cacheFile -Force -ErrorAction SilentlyContinue
                            Write-Host "Cleared PowerShell module cache" -ForegroundColor Yellow
                        } catch {
                            # Cache file may be in use, continue anyway
                        }
                    }
                    
                    # On second retry, try aggressive cleanup and reinstall
                    if ($retryCount -eq 2) {
                        Write-Host "Attempting aggressive cleanup and reinstall of $moduleName..." -ForegroundColor Yellow
                        
                        # Try to remove all versions of this module
                        Remove-ModuleVersions -ModuleName $moduleName
                        
                        # Try to install fresh
                        try {
                            Write-Host "Installing fresh version of $moduleName..." -ForegroundColor Yellow
                            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                            Write-Host "Fresh installation completed" -ForegroundColor Green
                            
                            # Refresh available modules
                            $availableModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
                        } catch {
                            Write-Host "Fresh installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                    
                    # Wait briefly before retry
                    Start-Sleep -Seconds 2
                } else {
                    # Non-version-conflict error, exit retry loop
                    $retryCount = $maxRetries + 1
                }
                
                # If we've exhausted retries
                if ($retryCount -gt $maxRetries) {
                    # Check if module is critical
                    $isCritical = $moduleInfo.Critical -eq $true
                    
                    if ($isOptional -or -not $isCritical) {
                        # For non-critical modules, just warn and continue
                        $warningMsg = if ($isOptional) { 
                            "Optional module installation failed - will use CSV export" 
                        } else { 
                            "Non-critical module installation failed - some features may be limited" 
                        }
                        
                        Write-ValidationLog -Message $warningMsg -Check "Module: $moduleName" -Result "Warning" -Component "Module Management" -Details $errorMessage -Recommendation "Some features may be limited. The script will continue with available modules."
                        
                        if ($moduleName -eq "ImportExcel") { 
                            $script:UseCSVExport = $true 
                        }
                        
                        Write-Host ""
                        Write-Host "WARNING: $moduleName could not be loaded, but it's not critical." -ForegroundColor Yellow
                        Write-Host "The script will continue with reduced functionality." -ForegroundColor Yellow
                        Write-Host ""
                        
                        $moduleImported = $true  # Mark as handled to exit loop
                    } else {
                        # For critical modules, fail
                        Write-ValidationLog -Message "Critical module installation failed after retries" -Check "Module: $moduleName" -Result "Fail" -Component "Module Management" -Details $errorMessage -Recommendation "Manual fix required: 1) Close PowerShell 2) Run as Admin: Uninstall-Module Az -AllVersions -Force 3) Install-Module Az -Force 4) Restart PowerShell 5) Re-run this script"
                        throw "Required CRITICAL module $moduleName could not be installed after $maxRetries retries. Error: $errorMessage"
                    }
                }
            }
        }
    }
    
    # Verify Az.Accounts was loaded successfully
    $azAccountsModule = Get-Module -Name Az.Accounts
    if (-not $azAccountsModule) {
        throw "Critical error: Az.Accounts module failed to load. This is required for all Azure operations. Please run 'Update-Module Az -Force' and restart PowerShell."
    }
    
    Write-Host ""
    Write-Host "All required modules loaded successfully" -ForegroundColor Green
    Write-Host ""
}

# Function to select authentication method
function Select-AuthenticationMethod {
    if ($NonInteractive) {
        Write-Host "Non-interactive mode: Using default authentication method" -ForegroundColor Yellow
        return "Interactive"
    }
    
    Write-Host ""
    Write-Host "Please select your preferred Azure authentication method:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Interactive Browser Login (Default)" -ForegroundColor White
    Write-Host "      - Opens browser for authentication" -ForegroundColor Gray
    Write-Host "      - Best for most users" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Device Code Authentication (Recommended)" -ForegroundColor White
    Write-Host "      - Use when browser login is not available" -ForegroundColor Gray
    Write-Host "      - Good for remote sessions or restricted environments" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Service Principal (Client Secret)" -ForegroundColor White
    Write-Host "      - For automated scenarios" -ForegroundColor Gray
    Write-Host "      - Requires Application ID and Secret" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Service Principal (Certificate)" -ForegroundColor White
    Write-Host "      - For automated scenarios with certificate authentication" -ForegroundColor Gray
    Write-Host "      - Requires Application ID and Certificate" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  5. Managed Identity" -ForegroundColor White
    Write-Host "      - For Azure VMs with managed identity enabled" -ForegroundColor Gray
    Write-Host "      - No credentials required" -ForegroundColor Gray
    Write-Host ""
    
    do {
        $selection = Read-Host "Please select an authentication method (1-5) [Default: 1]"
        
        if ([string]::IsNullOrWhiteSpace($selection)) {
            $selection = "1"
        }
        
        $selectionInt = 0
        $validSelection = [int]::TryParse($selection, [ref]$selectionInt) -and 
                          $selectionInt -ge 1 -and $selectionInt -le 5
        
        if (-not $validSelection) {
            Write-Host "Invalid selection. Please enter a number between 1 and 5." -ForegroundColor Red
        }
    } while (-not $validSelection)
    
    $authMethods = @{
        1 = "Interactive"
        2 = "DeviceCode"
        3 = "ServicePrincipalSecret"
        4 = "ServicePrincipalCertificate"
        5 = "ManagedIdentity"
    }
    
    $selectedMethod = $authMethods[$selectionInt]
    
    $methodNames = @{
        "Interactive" = "Interactive Browser Login"
        "DeviceCode" = "Device Code Authentication"
        "ServicePrincipalSecret" = "Service Principal (Client Secret)"
        "ServicePrincipalCertificate" = "Service Principal (Certificate)"
        "ManagedIdentity" = "Managed Identity"
    }
    
    Write-Host "Selected authentication method: $($methodNames[$selectedMethod])" -ForegroundColor Green
    Write-Host ""
    
    return $selectedMethod
}

# Function to perform authentication based on selected method
function Invoke-AzureAuthentication {
    param(
        [string]$AuthMethod,
        [string]$TenantId
    )
    
    Write-Host "Initiating Azure authentication using: $AuthMethod" -ForegroundColor Yellow
    Write-Host ""
    
    try {
        switch ($AuthMethod) {
            "Interactive" {
                if ($TenantId) {
                    Write-Host "Opening browser for interactive login to tenant: $TenantId" -ForegroundColor Yellow
                    $authResult = Connect-AzAccount -TenantId $TenantId
                } else {
                    Write-Host "Opening browser for interactive login..." -ForegroundColor Yellow
                    $authResult = Connect-AzAccount
                }
            }
            
            "DeviceCode" {
                Write-Host "Starting device code authentication..." -ForegroundColor Yellow
                Write-Host "You will see a device code that you need to enter at https://microsoft.com/devicelogin" -ForegroundColor Cyan
                if ($TenantId) {
                    $authResult = Connect-AzAccount -UseDeviceAuthentication -TenantId $TenantId
                } else {
                    $authResult = Connect-AzAccount -UseDeviceAuthentication
                }
            }
            
            "ServicePrincipalSecret" {
                Write-Host "Service Principal authentication with client secret..." -ForegroundColor Yellow
                $appId = Read-Host "Enter Application (Client) ID"
                $clientSecret = Read-Host "Enter Client Secret" -AsSecureString
                $tenantForAuth = if ($TenantId) { $TenantId } else { Read-Host "Enter Tenant ID" }
                
                $credential = New-Object System.Management.Automation.PSCredential($appId, $clientSecret)
                $authResult = Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $tenantForAuth
            }
            
            "ServicePrincipalCertificate" {
                Write-Host "Service Principal authentication with certificate..." -ForegroundColor Yellow
                $appId = Read-Host "Enter Application (Client) ID"
                $certThumbprint = Read-Host "Enter Certificate Thumbprint"
                $tenantForAuth = if ($TenantId) { $TenantId } else { Read-Host "Enter Tenant ID" }
                
                $authResult = Connect-AzAccount -ServicePrincipal -ApplicationId $appId -CertificateThumbprint $certThumbprint -TenantId $tenantForAuth
            }
            
            "ManagedIdentity" {
                Write-Host "Authenticating using Managed Identity..." -ForegroundColor Yellow
                $authResult = Connect-AzAccount -Identity
            }
            
            default {
                throw "Unknown authentication method: $AuthMethod"
            }
        }
        
        if (-not $authResult) {
            throw "Authentication failed - no result returned"
        }
        
        Write-Host "Authentication successful!" -ForegroundColor Green
        return $authResult
        
    } catch {
        Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

# Azure authentication function with comprehensive method selection
function Connect-AzureWithRetry {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " Azure Authentication " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    Write-Host "Clearing any cached Azure credentials..." -ForegroundColor Yellow
    Write-Host "Fresh authentication required for this session." -ForegroundColor Yellow
    Write-Host ""
    
    # Clear existing contexts - Force fresh authentication every time
    try {
        Clear-AzContext -Force -ErrorAction SilentlyContinue
        Disconnect-AzAccount -ErrorAction SilentlyContinue
    } catch { }
    
    # Select authentication method
    $selectedAuthMethod = Select-AuthenticationMethod
    
    Write-ValidationLog -Message "Authentication method selected" -Check "Azure Authentication" -Result "Info" -Component "Authentication" -Details "Method: $selectedAuthMethod"
    
    try {
        # Attempt authentication with selected method
        $authResult = Invoke-AzureAuthentication -AuthMethod $selectedAuthMethod
        
        # Verify connection
        $script:AzureContext = Get-AzContext
        if ($script:AzureContext) {
            Write-ValidationLog -Message "Successfully authenticated to Azure" -Check "Azure Authentication" -Result "Pass" -Component "Authentication" -Details "Account: $($script:AzureContext.Account.Id), Tenant: $($script:AzureContext.Tenant.Id)"
            return $true
        } else {
            throw "Authentication succeeded but no context was established"
        }
        
    } catch {
        Write-ValidationLog -Message "Authentication failed" -Check "Azure Authentication" -Result "Fail" -Component "Authentication" -Details $_.Exception.Message -Recommendation "Verify credentials and network connectivity, or try a different authentication method"
        
        # Offer retry with different method if not in non-interactive mode
        if (-not $NonInteractive) {
            Write-Host ""
            Write-Host "Authentication failed. Would you like to try a different method?" -ForegroundColor Yellow
            $retry = Read-Host "Enter 'y' to retry with different method, or any other key to exit"
            
            if ($retry.ToLower() -eq 'y') {
                return Connect-AzureWithRetry
            }
        }
        
        throw "Failed to authenticate to Azure: $_"
    }
}

# Subscription validation function
function Test-AzureSubscription {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " Subscription Selection " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    try {
        $subscriptions = Get-AzSubscription
        
        if ($subscriptions.Count -eq 0) {
            Write-ValidationLog -Message "No accessible subscriptions found" -Check "Subscription Access" -Result "Fail" -Component "Subscription" -Recommendation "Ensure your account has access to at least one Azure subscription"
            return $false
        }
        
        if ($subscriptions.Count -eq 1) {
            $subscription = $subscriptions[0]
            Set-AzContext -SubscriptionId $subscription.Id | Out-Null
            Write-ValidationLog -Message "Using single available subscription" -Check "Subscription Selection" -Result "Pass" -Component "Subscription" -Details "Name: $($subscription.Name), ID: $($subscription.Id)"
        } else {
            Write-ValidationLog -Message "Multiple subscriptions available" -Check "Subscription Access" -Result "Info" -Component "Subscription" -Details "Count: $($subscriptions.Count)"
            
            # Always show subscription selection menu (even in non-interactive mode for this requirement)
            Write-Host "`nAvailable Subscriptions:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                Write-Host "  $($i+1). $($subscriptions[$i].Name)" -ForegroundColor White
                Write-Host "      ID: $($subscriptions[$i].Id)" -ForegroundColor Gray
                Write-Host "      State: $($subscriptions[$i].State)" -ForegroundColor Gray
                Write-Host ""
            }
            
            do {
                Write-Host "Please select a subscription for AVD validation:" -ForegroundColor Yellow
                $selection = Read-Host "Enter selection (1-$($subscriptions.Count))"
                if ([int]::TryParse($selection, [ref]$null)) {
                    $selectedIndex = [int]$selection - 1
                    if ($selectedIndex -ge 0 -and $selectedIndex -lt $subscriptions.Count) {
                        break
                    }
                }
                Write-Host "Invalid selection. Please enter a number between 1 and $($subscriptions.Count)." -ForegroundColor Red
            } while ($true)
            
            $subscription = $subscriptions[$selectedIndex]
            Set-AzContext -SubscriptionId $subscription.Id | Out-Null
            Write-ValidationLog -Message "User selected subscription" -Check "Subscription Selection" -Result "Pass" -Component "Subscription" -Details "Name: $($subscription.Name)"
        }
        
        # Store selected subscription globally for use in other functions
        $script:SelectedSubscription = $subscription
        return $true
        
    } catch {
        Write-ValidationLog -Message "Failed to validate subscription access" -Check "Subscription Validation" -Result "Fail" -Component "Subscription" -Details $_.Exception.Message
        return $false
    }
}

# Resource provider registration function
function Register-RequiredProviders {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " AVD - Resource Provider Registration " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    $requiredProviders = @(
        "Microsoft.DesktopVirtualization",
        "Microsoft.Compute", 
        "Microsoft.Network",
        "Microsoft.Storage",
        "Microsoft.KeyVault",
        "Microsoft.Insights",
        "Microsoft.Security"
    )
    
    foreach ($provider in $requiredProviders) {
        try {
            $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider
            $registrationState = $providerStatus.RegistrationState
            
            if ($registrationState -eq "Registered") {
                Write-ValidationLog -Message "Resource provider already registered" -Check "Provider: $provider" -Result "Pass" -Component "Resource Providers"
            } else {
                Write-ValidationLog -Message "Registering resource provider" -Check "Provider: $provider" -Result "Info" -Component "Resource Providers"
                Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
                
                # Wait for registration (with timeout)
                $timeout = 30
                $timer = 0
                do {
                    Start-Sleep -Seconds 2
                    $timer += 2
                    $status = (Get-AzResourceProvider -ProviderNamespace $provider).RegistrationState
                } while ($status -ne "Registered" -and $timer -lt $timeout)
                
                if ($status -eq "Registered") {
                    Write-ValidationLog -Message "Resource provider successfully registered" -Check "Provider: $provider" -Result "Pass" -Component "Resource Providers"
                } else {
                    Write-ValidationLog -Message "Resource provider registration pending" -Check "Provider: $provider" -Result "Warning" -Component "Resource Providers" -Details "Registration initiated but not completed within timeout" -Recommendation "Check registration status later with: Get-AzResourceProvider -ProviderNamespace $provider"
                }
            }
        } catch {
            Write-ValidationLog -Message "Failed to register resource provider" -Check "Provider: $provider" -Result "Fail" -Component "Resource Providers" -Details $_.Exception.Message -Recommendation "Try registering manually via Azure portal or with elevated permissions"
        }
    }
}

# AVD Service Principal validation function
function Test-AVDServicePrincipal {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " AVD - Service Principal Validation " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    try {
        $avdSpDisplayNames = @("Azure Virtual Desktop", "Windows Virtual Desktop", "aadapp_AzureVirtualDesktop")
        $avdSp = $null
        
        foreach ($displayName in $avdSpDisplayNames) {
            try {
                $avdSp = Get-AzADServicePrincipal -DisplayName $displayName -ErrorAction SilentlyContinue
                if ($avdSp) {
                    Write-ValidationLog -Message "Found AVD service principal" -Check "AVD Service Principal Discovery" -Result "Pass" -Component "Service Principal" -Details "Display Name: $displayName, Object ID: $($avdSp.Id)"
                    break
                }
            } catch { }
        }
        
        if (-not $avdSp) {
            Write-ValidationLog -Message "AVD service principal not found" -Check "AVD Service Principal Discovery" -Result "Fail" -Component "Service Principal" -Recommendation "Register AVD resource provider or manually add service principal"
            return $false
        }
        
        # Check role assignments
        $currentSubscription = (Get-AzContext).Subscription.Id
        $roleAssignments = Get-AzRoleAssignment -ObjectId $avdSp.Id -Scope "/subscriptions/$currentSubscription" -ErrorAction SilentlyContinue
        
        $requiredRole = "Desktop Virtualization Contributor"
        $hasRequiredRole = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq $requiredRole }
        
        if ($hasRequiredRole) {
            Write-ValidationLog -Message "AVD service principal has required role assignment" -Check "AVD Service Principal Role" -Result "Pass" -Component "Service Principal" -Details "Role: $requiredRole"
        } else {
            Write-ValidationLog -Message "AVD service principal missing required role" -Check "AVD Service Principal Role" -Result "Warning" -Component "Service Principal" -Details "Missing role: $requiredRole" -Recommendation "Assign 'Desktop Virtualization Contributor' role to the AVD service principal"
        }
        
        return $true
        
    } catch {
        Write-ValidationLog -Message "Failed to validate AVD service principal" -Check "AVD Service Principal Validation" -Result "Fail" -Component "Service Principal" -Details $_.Exception.Message
        return $false
    }
}

# Region selection function
function Select-AzureRegion {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " AVD - Region Selection " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    try {
        Write-ValidationLog -Message "Loading available Azure regions" -Check "Region Discovery" -Result "Info" -Component "Region Selection"
        
        # Get locations that support Virtual Machines (good indicator of AVD support)
        $locations = Get-AzLocation | Where-Object { 
            $_.Providers -contains "Microsoft.Compute" 
        } | Sort-Object DisplayName
        
        if (-not $locations) {
            Write-ValidationLog -Message "No available regions found" -Check "Region Discovery" -Result "Fail" -Component "Region Selection"
            return $null
        }
        
        # If TargetRegion parameter was provided and is not the default, validate it
        if ($TargetRegion -and $TargetRegion -ne "East US" -and $NonInteractive) {
            $selectedLocation = $locations | Where-Object { $_.DisplayName -eq $TargetRegion -or $_.Location -eq $TargetRegion }
            if ($selectedLocation) {
                Write-ValidationLog -Message "Using specified target region (non-interactive mode)" -Check "Region Selection" -Result "Pass" -Component "Region Selection" -Details "Region: $($selectedLocation.DisplayName)"
                $script:SelectedRegion = $selectedLocation.Location
                return $selectedLocation.Location
            } else {
                Write-ValidationLog -Message "Specified target region not found, showing selection menu" -Check "Region Validation" -Result "Warning" -Component "Region Selection" -Details "Invalid region: $TargetRegion"
            }
        }
        
        # Show region selection menu
        Write-Host "`nAvailable Azure Regions:" -ForegroundColor Yellow
        Write-Host "(Showing regions that support Azure Virtual Desktop)" -ForegroundColor Gray
        Write-Host ""
        
        # Group regions by general area for better readability
        $popularRegions = @(
            "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "South Central US",
            "North Europe", "West Europe", "UK South", "UK West",
            "Southeast Asia", "East Asia", "Australia East", "Australia Southeast",
            "Canada Central", "Canada East", "Japan East", "Japan West"
        )
        
        $displayRegions = @()
        $showAllRegions = $false
        
        do {
            # Clear previous display
            $displayRegions = @()
            $displayCount = 0
            
            if (-not $showAllRegions) {
                # Show only first 10 regions (mix of popular and others)
                Write-Host "Top 10 Recommended Regions:" -ForegroundColor Green
                
                # First show available popular regions (up to 7)
                $popularCount = 0
                foreach ($regionName in $popularRegions) {
                    if ($displayCount -ge 10) { break }
                    $region = $locations | Where-Object { $_.DisplayName -eq $regionName }
                    if ($region) {
                        $displayCount++
                        Write-Host "  $displayCount. $($region.DisplayName)" -ForegroundColor White
                        $displayRegions += $region
                        $popularCount++
                    }
                }
                
                # Fill remaining slots with other regions
                if ($displayCount -lt 10) {
                    $otherRegions = $locations | Where-Object { $_.DisplayName -notin $popularRegions } | Select-Object -First (10 - $displayCount)
                    foreach ($region in $otherRegions) {
                        $displayCount++
                        Write-Host "  $displayCount. $($region.DisplayName)" -ForegroundColor White
                        $displayRegions += $region
                    }
                }
                
                Write-Host ""
                Write-Host "Options:" -ForegroundColor Yellow
                Write-Host "  Enter 1-$displayCount to select a region" -ForegroundColor Gray
                Write-Host "  Enter 'more' to see all available regions" -ForegroundColor Gray
                
            } else {
                # Show all regions
                Write-Host "All Available Regions:" -ForegroundColor Green
                
                # First show popular regions
                Write-Host "`nPopular Regions:" -ForegroundColor Cyan
                foreach ($regionName in $popularRegions) {
                    $region = $locations | Where-Object { $_.DisplayName -eq $regionName }
                    if ($region) {
                        $displayCount++
                        Write-Host "  $displayCount. $($region.DisplayName)" -ForegroundColor White
                        $displayRegions += $region
                    }
                }
                
                # Then show remaining regions
                Write-Host "`nOther Regions:" -ForegroundColor Cyan
                $otherRegions = $locations | Where-Object { $_.DisplayName -notin $popularRegions }
                foreach ($region in $otherRegions) {
                    $displayCount++
                    Write-Host "  $displayCount. $($region.DisplayName)" -ForegroundColor White
                    $displayRegions += $region
                }
                
                Write-Host ""
                Write-Host "Options:" -ForegroundColor Yellow
                Write-Host "  Enter 1-$displayCount to select a region" -ForegroundColor Gray
                Write-Host "  Enter 'less' to return to top 10 view" -ForegroundColor Gray
            }
        
            Write-Host ""
            Write-Host "Please select an Azure region for AVD deployment:" -ForegroundColor Yellow
            $selection = Read-Host "Enter your choice"
            
            # Handle special commands
            if ($selection -eq "more" -and -not $showAllRegions) {
                $showAllRegions = $true
                continue
            } elseif ($selection -eq "less" -and $showAllRegions) {
                $showAllRegions = $false
                continue
            } elseif ([int]::TryParse($selection, [ref]$null)) {
                $selectedIndex = [int]$selection - 1
                if ($selectedIndex -ge 0 -and $selectedIndex -lt $displayRegions.Count) {
                    break
                } else {
                    Write-Host "Invalid selection. Please enter a number between 1 and $($displayRegions.Count)." -ForegroundColor Red
                }
            } else {
                if (-not $showAllRegions) {
                    Write-Host "Invalid input. Please enter a number (1-$($displayRegions.Count)) or 'more' to see all regions." -ForegroundColor Red
                } else {
                    Write-Host "Invalid input. Please enter a number (1-$($displayRegions.Count)) or 'less' to return to top 10." -ForegroundColor Red
                }
            }
        } while ($true)
        
        $selectedLocation = $displayRegions[$selectedIndex]
        Write-ValidationLog -Message "User selected region" -Check "Region Selection" -Result "Pass" -Component "Region Selection" -Details "Region: $($selectedLocation.DisplayName) ($($selectedLocation.Location))"
        
        # Store selected region globally
        $script:SelectedRegion = $selectedLocation.Location
        return $selectedLocation.Location
        
    } catch {
        Write-ValidationLog -Message "Failed to select Azure region" -Check "Region Selection" -Result "Fail" -Component "Region Selection" -Details $_.Exception.Message
        return $null
    }
}

# Helper function to check if Az.Compute module is available
function Test-AzComputeAvailable {
    $computeModule = Get-Module -Name Az.Compute
    if (-not $computeModule) {
        Write-Host ""
        Write-Host "WARNING: Az.Compute module is not loaded due to version conflicts." -ForegroundColor Yellow
        Write-Host "         Some features (VM SKU analysis, zone redundancy checks) will be skipped." -ForegroundColor Yellow
        Write-Host "         To fix: Close PowerShell, run as Admin:" -ForegroundColor Yellow
        Write-Host "         Uninstall-Module Az -AllVersions -Force" -ForegroundColor Gray
        Write-Host "         Install-Module Az -Force -AllowClobber" -ForegroundColor Gray
        Write-Host ""
        return $false
    }
    return $true
}

# Zone redundancy validation function
function Test-ZoneRedundancy {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " AVD - Zone Redundancy Validation " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    # Check if Az.Compute is available
    if (-not (Test-AzComputeAvailable)) {
        Write-ValidationLog -Message "Zone redundancy check skipped - Az.Compute module not available" -Check "Zone Redundancy Analysis" -Result "Warning" -Component "Zone Redundancy" -Details "Az.Compute module failed to load" -Recommendation "Manually verify zone redundancy support in Azure Portal"
        return
    }
    
    try {
        $regionToTest = if ($script:SelectedRegion) { $script:SelectedRegion } else { $TargetRegion }
        Write-ValidationLog -Message "Analyzing zone redundancy for selected region" -Check "Zone Redundancy Analysis" -Result "Info" -Component "Zone Redundancy" -Details "Region: $regionToTest"
        
        # Get available zones for the region
        $zones = Get-AzComputeResourceSku | Where-Object {
            $_.Locations -contains $regionToTest -and 
            $_.ResourceType -eq "virtualMachines" -and
            $_.LocationInfo.Zones -ne $null
        } | Select-Object -First 1
        
        if (-not $zones -or -not $zones.LocationInfo.Zones) {
            Write-ValidationLog -Message "No availability zones found in selected region" -Check "Availability Zones" -Result "Warning" -Component "Zone Redundancy" -Details "Region: $regionToTest" -Recommendation "Consider using a region with availability zone support for high availability"
            return $false
        }
        
        $availableZones = $zones.LocationInfo[0].Zones
        Write-ValidationLog -Message "Availability zones detected" -Check "Availability Zones" -Result "Pass" -Component "Zone Redundancy" -Details "Zones: $($availableZones -join ', ') in $regionToTest"
        
        # Test key resource types for zone support
        $resourceTypes = @(
            @{Type="virtualMachines"; Name="Virtual Machines"},
            @{Type="disks"; Name="Managed Disks"},
            @{Type="publicIPAddresses"; Name="Public IP Addresses"},
            @{Type="loadBalancers"; Name="Load Balancers"}
        )
        
        foreach ($resourceType in $resourceTypes) {
            $zoneSupportedSkus = Get-AzComputeResourceSku | Where-Object {
                $_.Locations -contains $regionToTest -and 
                $_.ResourceType -eq $resourceType.Type -and
                $_.LocationInfo.Zones -ne $null
            }
            
            if ($zoneSupportedSkus) {
                $supportedCount = ($zoneSupportedSkus | Measure-Object).Count
                Write-ValidationLog -Message "Zone-redundant SKUs available" -Check "$($resourceType.Name) Zone Support" -Result "Pass" -Component "Zone Redundancy" -Details "$supportedCount SKUs support availability zones"
            } else {
                Write-ValidationLog -Message "No zone-redundant SKUs found" -Check "$($resourceType.Name) Zone Support" -Result "Warning" -Component "Zone Redundancy" -Recommendation "Verify specific SKU requirements for your deployment"
            }
        }
        
        return $true
        
    } catch {
        Write-ValidationLog -Message "Failed to validate zone redundancy" -Check "Zone Redundancy Validation" -Result "Fail" -Component "Zone Redundancy" -Details $_.Exception.Message
        return $false
    }
}

# Active Directory validation function
function Test-ActiveDirectoryConnectivity {
    # Check if AD validation is needed based on FRESH identity model selection
    if ($SkipADValidation -or $script:SelectedIdentityModel -eq "EntraIDJoin" -or $script:SelectedIdentityModel -eq "HybridJoin") {
        $reason = if ($SkipADValidation) { "user request" } 
                  elseif ($script:SelectedIdentityModel -eq "EntraIDJoin") { "Entra ID Join selected (fresh choice)" }
                  else { "Hybrid Join selected (fresh choice)" }
        Write-ValidationLog -Message "Active Directory validation skipped ($reason)" -Check "AD Validation Skip" -Result "Info" -Component "Active Directory"
        return $true
    }
    
    # Only validate AD for ADDS identity model (based on fresh selection)
    if ($script:SelectedIdentityModel -ne "ADDS") {
        Write-ValidationLog -Message "Active Directory validation not required for selected identity model" -Check "AD Validation Skip" -Result "Info" -Component "Active Directory" -Details "Fresh Identity Selection: $($script:SelectedIdentityModel)"
        return $true
    }
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " Active Directory Validation " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""

    # Get domain name if not provided
    if (-not $DomainName) {
        if (-not $NonInteractive) {
            $DomainName = Read-Host "Enter your Active Directory domain name (e.g., contoso.com)"
        } else {
            Write-ValidationLog -Message "Domain name required for AD validation" -Check "Domain Name Input" -Result "Warning" -Component "Active Directory" -Recommendation "Provide -DomainName parameter or run interactively"
            return $false
        }
    }
    
    if (-not $DomainName) {
        Write-ValidationLog -Message "No domain name provided" -Check "Domain Name Validation" -Result "Warning" -Component "Active Directory"
        return $false
    }
    
    try {
        # DNS resolution test
        Write-ValidationLog -Message "Testing DNS resolution for domain" -Check "DNS Resolution" -Result "Info" -Component "Active Directory" -Details "Domain: $DomainName"
        
        $dnsTest = Resolve-DnsName -Name $DomainName -Type A -ErrorAction SilentlyContinue
        if ($dnsTest) {
            Write-ValidationLog -Message "Domain DNS resolution successful" -Check "DNS Resolution" -Result "Pass" -Component "Active Directory" -Details "Resolved to: $($dnsTest[0].IPAddress)"
        } else {
            Write-ValidationLog -Message "Domain DNS resolution failed" -Check "DNS Resolution" -Result "Fail" -Component "Active Directory" -Recommendation "Verify DNS configuration and domain name spelling"
            return $false
        }
        
        # Domain controller discovery
        Write-ValidationLog -Message "Discovering domain controllers" -Check "Domain Controller Discovery" -Result "Info" -Component "Active Directory"
        
        $dcSrvRecords = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -ErrorAction SilentlyContinue
        if ($dcSrvRecords) {
            $dcCount = ($dcSrvRecords | Measure-Object).Count
            Write-ValidationLog -Message "Domain controllers discovered via DNS SRV records" -Check "Domain Controller Discovery" -Result "Pass" -Component "Active Directory" -Details "$dcCount domain controllers found"
            
            # Test connectivity to first DC
            $firstDC = $dcSrvRecords[0].NameTarget
            $dcIP = (Resolve-DnsName -Name $firstDC -Type A -ErrorAction SilentlyContinue)[0].IPAddress
            
            if ($dcIP) {
                $ldapConnTest = Test-NetConnection -ComputerName $dcIP -Port 389 -WarningAction SilentlyContinue
                if ($ldapConnTest.TcpTestSucceeded) {
                    Write-ValidationLog -Message "LDAP connectivity test successful" -Check "Domain Controller Connectivity" -Result "Pass" -Component "Active Directory" -Details "DC: $firstDC ($dcIP)"
                } else {
                    Write-ValidationLog -Message "LDAP connectivity test failed" -Check "Domain Controller Connectivity" -Result "Fail" -Component "Active Directory" -Details "DC: $firstDC ($dcIP)" -Recommendation "Check network connectivity and firewall rules for port 389"
                }
            }
        } else {
            Write-ValidationLog -Message "No domain controllers found via DNS SRV records" -Check "Domain Controller Discovery" -Result "Fail" -Component "Active Directory" -Recommendation "Verify domain name and DNS configuration"
            return $false
        }
        
        return $true
        
    } catch {
        Write-ValidationLog -Message "Active Directory validation failed" -Check "Active Directory Validation" -Result "Fail" -Component "Active Directory" -Details $_.Exception.Message
        return $false
    }
}

# VM SKU selection function
function Select-VMSku {
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " AVD - VM SKU Selection " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    # Check if Az.Compute is available
    if (-not (Test-AzComputeAvailable)) {
        Write-ValidationLog -Message "VM SKU selection skipped - Az.Compute module not available" -Check "VM SKU Selection" -Result "Warning" -Component "VM SKU Selection" -Details "Az.Compute module failed to load" -Recommendation "Manually select and validate VM SKU in Azure Portal"
        Write-Host "You can manually verify VM SKU availability at: https://azure.microsoft.com/en-us/pricing/details/virtual-machines/" -ForegroundColor Cyan
        return $null
    }
        
    try {
        $regionToTest = if ($script:SelectedRegion) { $script:SelectedRegion } else { $TargetRegion }
        Write-ValidationLog -Message "VM SKU selection for selected region" -Check "VM SKU Selection" -Result "Info" -Component "VM SKU Selection" -Details "Region: $regionToTest"
        
        # Get all available VM SKUs in the selected region for validation
        $allVMSkus = Get-AzComputeResourceSku | Where-Object {
            $_.Locations -contains $regionToTest -and 
            $_.ResourceType -eq "virtualMachines" -and
            $_.Restrictions.Count -eq 0  # No restrictions (available)
        } | Sort-Object Name
        
        if (-not $allVMSkus) {
            Write-ValidationLog -Message "No VM SKUs found in selected region" -Check "VM SKU Discovery" -Result "Fail" -Component "VM SKU Selection"
            return $null
        }
        
        # Show some popular AVD VM SKU examples
        Write-Host "Popular VM SKUs for Azure Virtual Desktop:" -ForegroundColor Green
        Write-Host "  General Purpose: " -NoNewline -ForegroundColor Yellow
        Write-Host "Standard_D2s_v3, Standard_D4s_v3, Standard_D8s_v3, Standard_B2ms, Standard_B4ms" -ForegroundColor White
        Write-Host "  Compute Optimized: " -NoNewline -ForegroundColor Yellow  
        Write-Host "Standard_F2s_v2, Standard_F4s_v2, Standard_F8s_v2" -ForegroundColor White
        Write-Host "  Memory Optimized: " -NoNewline -ForegroundColor Yellow
        Write-Host "Standard_E2s_v3, Standard_E4s_v3, Standard_E8s_v3" -ForegroundColor White
        Write-Host "  GPU Enabled: " -NoNewline -ForegroundColor Yellow
        Write-Host "Standard_NV6, Standard_NV12, Standard_NV24" -ForegroundColor White
        Write-Host ""
        Write-Host "Note: The script will validate if your chosen SKU is available in the selected region." -ForegroundColor Gray
        Write-Host ""
        
        # Enhanced VM SKU selection with auto-suggestion
        Write-Host "Smart SKU Selection Available!" -ForegroundColor Cyan
        Write-Host "You can use partial matching and get suggestions. Examples:" -ForegroundColor Gray
        Write-Host "  Type 'D4' to see all D4-series SKUs" -ForegroundColor DarkGray
        Write-Host "  Type 'Standard_B' to see all B-series SKUs" -ForegroundColor DarkGray
        Write-Host "  Type '?' to see all available SKUs in this region" -ForegroundColor DarkGray
        Write-Host ""
        
        # Allow user to input specific VM SKU with smart suggestions
        do {
            Write-Host "Please enter the VM SKU you want to use (or partial name for suggestions):" -ForegroundColor Yellow
            Write-Host "(Example: Standard_D4s_v3 or just 'D4' for suggestions)" -ForegroundColor Gray
            $userInput = Read-Host "VM SKU"
            
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                Write-Host "Please enter a valid VM SKU name or partial match." -ForegroundColor Red
                continue
            }
            
            # Clean up the input (remove any extra spaces)
            $userInput = $userInput.Trim()
            
            # Handle special commands
            if ($userInput -eq "?") {
                Write-Host "`nAll Available VM SKUs in ${regionToTest}:" -ForegroundColor Green
                $categorizedSkus = @{}
                foreach ($sku in $allVMSkus) {
                    $series = if ($sku.Name -match "Standard_([A-Z]+)") { $matches[1] } else { "Other" }
                    if (-not $categorizedSkus[$series]) { $categorizedSkus[$series] = @() }
                    $categorizedSkus[$series] += $sku
                }
                
                foreach ($series in ($categorizedSkus.Keys | Sort-Object)) {
                    Write-Host "`n  $series-Series:" -ForegroundColor Cyan
                    $categorizedSkus[$series] | Sort-Object Name | Select-Object -First 10 | ForEach-Object {
                        $capabilities = $_.Capabilities
                        $vcpus = ($capabilities | Where-Object { $_.Name -eq "vCPUs" }).Value
                        $memory = ($capabilities | Where-Object { $_.Name -eq "MemoryGB" }).Value
                        if ($vcpus -and $memory) {
                            Write-Host "    $($_.Name) ($vcpus vCPUs, $memory GB)" -ForegroundColor White
                        } else {
                            Write-Host "    $($_.Name)" -ForegroundColor White
                        }
                    }
                    if ($categorizedSkus[$series].Count -gt 10) {
                        Write-Host "    ... and $($categorizedSkus[$series].Count - 10) more $series-series SKUs" -ForegroundColor DarkGray
                    }
                }
                Write-Host ""
                continue
            }
            
            # Check for exact match first
            $selectedSku = $allVMSkus | Where-Object { $_.Name -eq $userInput }
            
            if ($selectedSku) {
                # Exact match found
                break
            }
            
            # Look for partial matches if exact match not found
            $partialMatches = $allVMSkus | Where-Object { $_.Name -like "*$userInput*" } | Sort-Object Name
            
            if ($partialMatches.Count -eq 0) {
                Write-Host "No VM SKUs found matching '$userInput'" -ForegroundColor Red
                Write-Host "Try a partial match like 'D4', 'Standard_B', or 'F2' for suggestions" -ForegroundColor Yellow
                continue
            }
            elseif ($partialMatches.Count -eq 1) {
                # Single partial match - ask for confirmation
                $match = $partialMatches[0]
                $capabilities = $match.Capabilities
                $vcpus = ($capabilities | Where-Object { $_.Name -eq "vCPUs" }).Value
                $memory = ($capabilities | Where-Object { $_.Name -eq "MemoryGB" }).Value
                
                Write-Host "Found single match:" -ForegroundColor Green
                Write-Host "  Name: $($match.Name)" -ForegroundColor White
                if ($vcpus -and $memory) {
                    Write-Host "  Specs: $vcpus vCPUs, $memory GB RAM" -ForegroundColor Gray
                }
                
                $confirm = Read-Host "Use this SKU? (y/n)"
                if ($confirm.ToLower() -in @('y', 'yes')) {
                    $selectedSku = $match
                    $userInput = $match.Name
                    break
                }
                continue
            }
            else {
                # Multiple partial matches - show suggestions
                Write-Host "Found $($partialMatches.Count) SKUs matching '$userInput':" -ForegroundColor Cyan
                
                # Group matches for better display
                $displayCount = [Math]::Min($partialMatches.Count, 15)
                for ($i = 0; $i -lt $displayCount; $i++) {
                    $match = $partialMatches[$i]
                    $capabilities = $match.Capabilities
                    $vcpus = ($capabilities | Where-Object { $_.Name -eq "vCPUs" }).Value
                    $memory = ($capabilities | Where-Object { $_.Name -eq "MemoryGB" }).Value
                    
                    $number = $i + 1
                    Write-Host "  [$number] " -NoNewline -ForegroundColor Yellow
                    if ($vcpus -and $memory) {
                        Write-Host "$($match.Name) " -NoNewline -ForegroundColor White
                        Write-Host "($vcpus vCPUs, $memory GB)" -ForegroundColor Gray
                    } else {
                        Write-Host "$($match.Name)" -ForegroundColor White
                    }
                }
                
                if ($partialMatches.Count -gt 15) {
                    Write-Host "  ... and $($partialMatches.Count - 15) more matches" -ForegroundColor DarkGray
                }
                
                Write-Host ""
                Write-Host "Options:" -ForegroundColor Yellow
                Write-Host "  • Enter 1-$displayCount to select a SKU from the list" -ForegroundColor Gray
                Write-Host "  • Type a more specific name to narrow results" -ForegroundColor Gray
                Write-Host "  • Press Enter to try a different search" -ForegroundColor Gray
                
                $selection = Read-Host "Your choice"
                
                if ([string]::IsNullOrWhiteSpace($selection)) {
                    continue
                }
                
                # Check if user selected a number
                if ([int]::TryParse($selection, [ref]$null)) {
                    $selectedIndex = [int]$selection - 1
                    if ($selectedIndex -ge 0 -and $selectedIndex -lt $displayCount) {
                        $selectedSku = $partialMatches[$selectedIndex]
                        $userInput = $selectedSku.Name
                        break
                    } else {
                        Write-Host "Invalid selection. Please enter a number between 1 and $displayCount." -ForegroundColor Red
                        continue
                    }
                } else {
                    # User entered a new search term
                    $userInput = $selection.Trim()
                    continue
                }
            }
            
        } while (-not $selectedSku)
        
        # At this point we have a valid selectedSku
        Write-ValidationLog -Message "User selected VM SKU validated successfully" -Check "VM SKU Selection" -Result "Pass" -Component "VM SKU Selection" -Details "SKU: $userInput"
        
        # Show comprehensive SKU details
        $capabilities = $selectedSku.Capabilities
        $vcpus = ($capabilities | Where-Object { $_.Name -eq "vCPUs" }).Value
        $memory = ($capabilities | Where-Object { $_.Name -eq "MemoryGB" }).Value
        $maxDataDisks = ($capabilities | Where-Object { $_.Name -eq "MaxDataDiskCount" }).Value
        $premiumIO = ($capabilities | Where-Object { $_.Name -eq "PremiumIO" }).Value
        $acceleratedNetworking = ($capabilities | Where-Object { $_.Name -eq "AcceleratedNetworkingEnabled" }).Value
        
        Write-Host ""
        Write-Host "Selected VM SKU Details:" -ForegroundColor Green
        Write-Host "  Name: $userInput" -ForegroundColor White
        Write-Host "  vCPUs: $vcpus" -ForegroundColor White
        Write-Host "  Memory: $memory GB" -ForegroundColor White
        
        if ($maxDataDisks) {
            Write-Host "  Max Data Disks: $maxDataDisks" -ForegroundColor White
        }
        if ($premiumIO) {
            $premiumSupport = if ($premiumIO -eq "True") { "Supported" } else { "Not Supported" }
            Write-Host "  Premium Storage: $premiumSupport" -ForegroundColor $(if ($premiumIO -eq "True") { "Green" } else { "Yellow" })
        }
        if ($acceleratedNetworking) {
            $accelNet = if ($acceleratedNetworking -eq "True") { "Supported" } else { "Not Supported" }
            Write-Host "  Accelerated Networking: $accelNet" -ForegroundColor $(if ($acceleratedNetworking -eq "True") { "Green" } else { "Yellow" })
        }
        
        # Check for zone support
        if ($selectedSku.LocationInfo.Zones) {
            $zones = $selectedSku.LocationInfo[0].Zones -join ', '
            Write-Host "  Availability Zones: Zones $zones" -ForegroundColor Green
        } else {
            Write-Host "  Availability Zones: Not supported" -ForegroundColor Yellow
        }
        
        # Store selected SKU globally
        $script:SelectedVMSku = $userInput
        return $userInput
        
    } catch {
        Write-ValidationLog -Message "Failed to select VM SKU" -Check "VM SKU Selection" -Result "Fail" -Component "VM SKU Selection" -Details $_.Exception.Message
        return $null
    }
}

# VM SKU availability validation function with comprehensive restriction analysis
function Test-VMSKUAvailability {
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " AVD - VM SKU Availability & Restriction Analysis " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""

    # Check if Az.Compute is available
    if (-not (Test-AzComputeAvailable)) {
        Write-ValidationLog -Message "VM SKU availability check skipped - Az.Compute module not available" -Check "VM SKU Validation" -Result "Warning" -Component "VM SKU" -Details "Az.Compute module failed to load" -Recommendation "Manually verify VM SKU availability in Azure Portal"
        return $true  # Return true to not block the script
    }

    try {
        $regionToTest = if ($script:SelectedRegion) { $script:SelectedRegion } else { $TargetRegion }
        $skuToTest = if ($script:SelectedVMSku) { $script:SelectedVMSku } else { "Standard_D4s_v3" }
        
        Write-ValidationLog -Message "Starting comprehensive SKU availability and restriction analysis" -Check "VM SKU Validation" -Result "Info" -Component "VM SKU" -Details "SKU: $skuToTest, Region: $regionToTest"
        
        # Get comprehensive SKU information including restrictions
        $selectedSkuInfo = Get-AzComputeResourceSku | Where-Object {
            $_.Locations -contains $regionToTest -and 
            $_.ResourceType -eq "virtualMachines" -and
            $_.Name -eq $skuToTest
        }
        
        if (-not $selectedSkuInfo) {
            Write-ValidationLog -Message "Selected VM SKU not found in region" -Check "Selected VM SKU Availability" -Result "Fail" -Component "VM SKU" -Details "SKU: $skuToTest, Region: $regionToTest"
            return $false
        }
        
        Write-Host "Analyzing VM SKU: $skuToTest in $regionToTest" -ForegroundColor Cyan
        Write-Host ""
        
        # Detailed restriction analysis
        $restrictionAnalysis = @{
            HasRestrictions = $false
            RestrictionsDetails = @()
            BlockingRestrictions = @()
            WarningRestrictions = @()
            PolicyRestrictions = @()
            QuotaRestrictions = @()
            ZoneRestrictions = @()
        }
        
        if ($selectedSkuInfo.Restrictions.Count -gt 0) {
            $restrictionAnalysis.HasRestrictions = $true
            Write-Host ""
            Write-Host ("="*100) -ForegroundColor Yellow
            Write-Host "RESTRICTIONS DETECTED for $skuToTest" -ForegroundColor Yellow
            Write-Host ("="*100) -ForegroundColor Yellow 
            Write-Host

            foreach ($restriction in $selectedSkuInfo.Restrictions) {
                $restrictionDetail = @{
                    Type = $restriction.Type
                    ReasonCode = $restriction.ReasonCode
                    Values = $restriction.Values
                    RestrictionsInfo = $restriction.RestrictionInfo
                    Severity = "Unknown"
                    Impact = "Unknown"
                    Recommendation = "Review restriction details"
                }
                
                # Analyze restriction type and severity
                switch ($restriction.ReasonCode) {
                    "NotAvailableForSubscription" {
                        $restrictionDetail.Severity = "Critical"
                        $restrictionDetail.Impact = "Complete blocking - SKU cannot be used"
                        $restrictionDetail.Recommendation = "Contact Azure support to enable this SKU for your subscription, or choose an alternative SKU"
                        $restrictionAnalysis.BlockingRestrictions += $restrictionDetail
                        Write-Host "  CRITICAL: Not Available for Subscription" -ForegroundColor Red
                        Write-Host "     Impact: This SKU is completely blocked for your subscription" -ForegroundColor Red
                        Write-Host "     Action: Contact Azure support or use alternative SKU" -ForegroundColor Red
                    }
                    "QuotaId" {
                        $restrictionDetail.Severity = "High"
                        $restrictionDetail.Impact = "Quota limitations may prevent deployment"
                        $restrictionDetail.Recommendation = "Check current quota usage and request increase if needed"
                        $restrictionAnalysis.QuotaRestrictions += $restrictionDetail
                        Write-Host "  HIGH: Quota Restrictions" -ForegroundColor Yellow
                        Write-Host "     Impact: Deployment may fail due to quota limits" -ForegroundColor Yellow
                        Write-Host "     Action: Check quota usage and request increase if needed" -ForegroundColor Yellow
                    }
                    "Location" {
                        $restrictionDetail.Severity = "Critical"
                        $restrictionDetail.Impact = "SKU not available in selected region"
                        $restrictionDetail.Recommendation = "Choose a different region or alternative SKU"
                        $restrictionAnalysis.BlockingRestrictions += $restrictionDetail
                        Write-Host "  CRITICAL: Location Restriction" -ForegroundColor Red
                        Write-Host "     Impact: SKU not available in region $regionToTest" -ForegroundColor Red
                        Write-Host "     Action: Select different region or alternative SKU" -ForegroundColor Red
                    }
                    "Zone" {
                        $restrictionDetail.Severity = "Medium"
                        $restrictionDetail.Impact = "Limited availability zone support"
                        $restrictionDetail.Recommendation = "Deployment possible but with zone limitations"
                        $restrictionAnalysis.ZoneRestrictions += $restrictionDetail
                        Write-Host "  MEDIUM: Zone Restrictions" -ForegroundColor Yellow
                        Write-Host "     Impact: Limited to specific availability zones" -ForegroundColor Yellow
                        if ($restriction.Values) {
                            Write-Host "     Restricted Zones: $($restriction.Values -join ', ')" -ForegroundColor Yellow
                        }
                    }
                    "Policy" {
                        $restrictionDetail.Severity = "High"
                        $restrictionDetail.Impact = "Blocked by Azure Policy"
                        $restrictionDetail.Recommendation = "Review and modify Azure Policy assignments"
                        $restrictionAnalysis.PolicyRestrictions += $restrictionDetail
                        Write-Host "  HIGH: Policy Restriction" -ForegroundColor Red
                        Write-Host "     Impact: Deployment blocked by Azure Policy" -ForegroundColor Red
                        Write-Host "     Action: Review policy assignments and exemptions" -ForegroundColor Red
                    }
                    default {
                        $restrictionDetail.Severity = "Medium"
                        $restrictionDetail.Impact = "Unknown restriction type - investigate further"
                        $restrictionDetail.Recommendation = "Contact Azure support for clarification"
                        $restrictionAnalysis.WarningRestrictions += $restrictionDetail
                        Write-Host "  UNKNOWN: $($restriction.ReasonCode)" -ForegroundColor Magenta
                        Write-Host "     Impact: Unknown restriction - requires investigation" -ForegroundColor Magenta
                        Write-Host "     Action: Contact Azure support for details" -ForegroundColor Magenta
                    }
                }
                
                # Additional details if available
                if ($restriction.Values -and $restriction.Values.Count -gt 0) {
                    Write-Host "     Details: $($restriction.Values -join ', ')" -ForegroundColor Gray
                }
                
                if ($restriction.RestrictionInfo) {
                    Write-Host "     Info: $($restriction.RestrictionInfo)" -ForegroundColor Gray
                }
                
                $restrictionAnalysis.RestrictionsDetails += $restrictionDetail
                Write-Host ""
            }
            
            # Summary of restriction impact
            write-host ""
            Write-Host ("="*100) -ForegroundColor Yellow
            Write-Host "Restrictions Summary:" -ForegroundColor Yellow
            Write-Host ("="*100) -ForegroundColor Yellow
            Write-Host
            Write-Host "  Blocking Restrictions: $($restrictionAnalysis.BlockingRestrictions.Count)" -ForegroundColor $(if ($restrictionAnalysis.BlockingRestrictions.Count -gt 0) { "Red" } else { "Green" })
            Write-Host "  Policy Restrictions: $($restrictionAnalysis.PolicyRestrictions.Count)" -ForegroundColor $(if ($restrictionAnalysis.PolicyRestrictions.Count -gt 0) { "Red" } else { "Green" })
            Write-Host "  Quota Restrictions: $($restrictionAnalysis.QuotaRestrictions.Count)" -ForegroundColor $(if ($restrictionAnalysis.QuotaRestrictions.Count -gt 0) { "Yellow" } else { "Green" })
            Write-Host "  Zone Restrictions: $($restrictionAnalysis.ZoneRestrictions.Count)" -ForegroundColor $(if ($restrictionAnalysis.ZoneRestrictions.Count -gt 0) { "Yellow" } else { "Green" })
            Write-Host ""
            
            # Determine overall recommendation
            $overallResult = "Warning"
            $overallRecommendation = "Review restrictions and plan accordingly"
            
            if ($restrictionAnalysis.BlockingRestrictions.Count -gt 0) {
                $overallResult = "Fail"
                $overallRecommendation = "Critical restrictions prevent deployment - choose alternative SKU or resolve restrictions"
                Write-Host "DEPLOYMENT RECOMMENDATION: DO NOT PROCEED" -ForegroundColor Red
                Write-Host "   Critical restrictions will prevent successful deployment" -ForegroundColor Red
            }
            elseif ($restrictionAnalysis.PolicyRestrictions.Count -gt 0) {
                $overallResult = "Fail" 
                $overallRecommendation = "Policy restrictions may prevent deployment - review policies first"
                Write-Host "DEPLOYMENT RECOMMENDATION: REVIEW POLICIES FIRST" -ForegroundColor Yellow
                Write-Host "   Policy restrictions may cause deployment failures" -ForegroundColor Yellow
            }
            else {
                Write-Host "DEPLOYMENT RECOMMENDATION: PROCEED WITH CAUTION" -ForegroundColor Yellow
                Write-Host "   Non-blocking restrictions detected - monitor deployment" -ForegroundColor Yellow
            }
            
            # Log comprehensive restriction details
            $restrictionSummary = "Total: $($selectedSkuInfo.Restrictions.Count), Blocking: $($restrictionAnalysis.BlockingRestrictions.Count), Policy: $($restrictionAnalysis.PolicyRestrictions.Count), Quota: $($restrictionAnalysis.QuotaRestrictions.Count), Zone: $($restrictionAnalysis.ZoneRestrictions.Count)"
            Write-ValidationLog -Message "VM SKU has restrictions detected" -Check "VM SKU Restrictions Analysis" -Result $overallResult -Component "VM SKU" -Details $restrictionSummary -Recommendation $overallRecommendation
            
            # Individual restriction logging for detailed reporting
            foreach ($restrictionDetail in $restrictionAnalysis.RestrictionsDetails) {
                $restrictionLog = "Type: $($restrictionDetail.ReasonCode), Severity: $($restrictionDetail.Severity), Impact: $($restrictionDetail.Impact)"
                Write-ValidationLog -Message "Specific restriction detected" -Check "SKU Restriction: $($restrictionDetail.ReasonCode)" -Result $(if ($restrictionDetail.Severity -eq "Critical") { "Fail" } else { "Warning" }) -Component "VM SKU Restrictions" -Details $restrictionLog -Recommendation $restrictionDetail.Recommendation
            }
            
        } else {
            write-host ""
            Write-Host ("="*100) -ForegroundColor Green
            Write-Host "NO RESTRICTIONS DETECTED" -ForegroundColor Green  
            Write-Host ("="*100) -ForegroundColor Green
            write-host ""
            Write-Host "SKU $skuToTest is fully available in $regionToTest" -ForegroundColor Green
            Write-Host "   No policy, quota, or regional restrictions detected" -ForegroundColor Green
            Write-Host ""
            
            Write-ValidationLog -Message "Selected VM SKU is available without restrictions" -Check "Selected VM SKU Availability" -Result "Pass" -Component "VM SKU" -Details "SKU: $skuToTest"
        }
                
        # Get detailed capabilities analysis
        Write-Host ""
        Write-Host ("="*100) -ForegroundColor White
        Write-Host "AVD - SKU Capabilities Analysis:" -ForegroundColor White
        Write-Host ("="*100) -ForegroundColor White
        Write-Host ""

        $capabilities = $selectedSkuInfo.Capabilities
        $vcpus = ($capabilities | Where-Object { $_.Name -eq "vCPUs" }).Value
        $memory = ($capabilities | Where-Object { $_.Name -eq "MemoryGB" }).Value  
        $maxDataDisks = ($capabilities | Where-Object { $_.Name -eq "MaxDataDiskCount" }).Value
        $premiumIO = ($capabilities | Where-Object { $_.Name -eq "PremiumIO" }).Value
        $acceleratedNetworking = ($capabilities | Where-Object { $_.Name -eq "AcceleratedNetworkingEnabled" }).Value
        $ephemeralOSDisk = ($capabilities | Where-Object { $_.Name -eq "EphemeralOSDiskSupported" }).Value
        $encryptionAtHost = ($capabilities | Where-Object { $_.Name -eq "EncryptionAtHostSupported" }).Value
        
        # Core specifications
        Write-Host "  Compute Resources:" -ForegroundColor White
        Write-Host "     vCPUs: $vcpus" -ForegroundColor Gray
        Write-Host "     Memory: $memory GB" -ForegroundColor Gray
        if ($maxDataDisks) { Write-Host "     Max Data Disks: $maxDataDisks" -ForegroundColor Gray }
        
        # Storage capabilities
        Write-Host "  Storage Capabilities:" -ForegroundColor White
        $premiumSupport = if ($premiumIO -eq "True") { "Supported" } else { "Not Supported" }
        Write-Host "     Premium Storage: $premiumSupport" -ForegroundColor $(if ($premiumIO -eq "True") { "Green" } else { "Yellow" })
        
        if ($ephemeralOSDisk) {
            $ephemeralSupport = if ($ephemeralOSDisk -eq "True") { "Supported" } else { "Not Supported" }
            Write-Host "     Ephemeral OS Disk: $ephemeralSupport" -ForegroundColor $(if ($ephemeralOSDisk -eq "True") { "Green" } else { "Gray" })
        }
        
        # Network and security capabilities  
        Write-Host "  Network & Security:" -ForegroundColor White
        if ($acceleratedNetworking) {
            $accelNet = if ($acceleratedNetworking -eq "True") { "Supported" } else { "Not Supported" }
            Write-Host "     Accelerated Networking: $accelNet" -ForegroundColor $(if ($acceleratedNetworking -eq "True") { "Green" } else { "Yellow" })
        }
        
        if ($encryptionAtHost) {
            $encryptionSupport = if ($encryptionAtHost -eq "True") { "Supported" } else { "Not Supported" }  
            Write-Host "     Encryption at Host: $encryptionSupport" -ForegroundColor $(if ($encryptionAtHost -eq "True") { "Green" } else { "Gray" })
        }
        
        # Availability zone analysis
        Write-Host "  Availability & Resilience:" -ForegroundColor White
        if ($selectedSkuInfo.LocationInfo.Zones) {
            $supportedZones = $selectedSkuInfo.LocationInfo[0].Zones -join ', '
            Write-Host "     Availability Zones: Zones $supportedZones" -ForegroundColor Green
            Write-ValidationLog -Message "Selected VM SKU supports availability zones" -Check "VM SKU Zone Support" -Result "Pass" -Component "VM SKU" -Details "Zones: $supportedZones"
        } else {
            Write-Host "     Availability Zones: Not supported" -ForegroundColor Yellow
            Write-ValidationLog -Message "Selected VM SKU does not support availability zones" -Check "VM SKU Zone Support" -Result "Warning" -Component "VM SKU" -Recommendation "Consider a zone-redundant SKU for high availability"
        }
        
        # Log comprehensive capability details
        $capabilityDetails = "vCPUs: $vcpus, Memory: $memory GB, Premium IO: $premiumIO, Accelerated Networking: $acceleratedNetworking"
        if ($maxDataDisks) { $capabilityDetails += ", Max Data Disks: $maxDataDisks" }
        Write-ValidationLog -Message "VM SKU comprehensive capabilities analyzed" -Check "VM SKU Capabilities" -Result "Info" -Component "VM SKU" -Details $capabilityDetails
        
        Write-Host ""
        
        # Comprehensive alternative SKU analysis
        Write-Host ""
        Write-Host ("="*100) -ForegroundColor White  
        Write-Host "AVD - Alternative SKUs Analysis:" -ForegroundColor White
        Write-Host ("="*100) -ForegroundColor White
        
        $commonAVDSizes = @("Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3", "Standard_B2ms", "Standard_B4ms", "Standard_F2s_v2", "Standard_F4s_v2", "Standard_E2s_v3", "Standard_E4s_v3")
        
        # Get all alternative SKUs with detailed analysis
        $allAlternativeSkus = Get-AzComputeResourceSku | Where-Object {
            $_.Locations -contains $regionToTest -and 
            $_.ResourceType -eq "virtualMachines" -and
            $_.Name -in $commonAVDSizes -and
            $_.Name -ne $skuToTest
        }
        
        $unrestricted = @()
        $restricted = @()
        
        foreach ($altSku in $allAlternativeSkus) {
            $skuAnalysis = @{
                Name = $altSku.Name
                HasRestrictions = $altSku.Restrictions.Count -gt 0
                Restrictions = $altSku.Restrictions
                Capabilities = $altSku.Capabilities
                ZoneSupport = $altSku.LocationInfo.Zones -ne $null
            }
            
            if ($skuAnalysis.HasRestrictions) {
                $restricted += $skuAnalysis
            } else {
                $unrestricted += $skuAnalysis
            }
        }
        
        # Display unrestricted alternatives
        if ($unrestricted.Count -gt 0) {
            write-host ""
            Write-Host "  AVAILABLE ALTERNATIVES (No Restrictions):" -ForegroundColor Green
            Write-Host ""
            foreach ($sku in $unrestricted | Sort-Object Name) {
                $caps = $sku.Capabilities
                $vcpus = ($caps | Where-Object { $_.Name -eq "vCPUs" }).Value
                $memory = ($caps | Where-Object { $_.Name -eq "MemoryGB" }).Value  
                $zoneText = if ($sku.ZoneSupport) { "Zone Support" } else { "No Zones" }
                
                Write-Host "     $($sku.Name) " -NoNewline -ForegroundColor White
                Write-Host "($vcpus vCPUs, $memory GB) " -NoNewline -ForegroundColor Gray
                Write-Host "$zoneText" -ForegroundColor $(if ($sku.ZoneSupport) { "Green" } else { "Yellow" })
            }
            
            $unrestrictedNames = $unrestricted | ForEach-Object { $_.Name } | Sort-Object
            Write-ValidationLog -Message "Unrestricted alternative AVD SKUs available" -Check "Alternative VM SKUs - Available" -Result "Pass" -Component "VM SKU" -Details "Count: $($unrestricted.Count), SKUs: $($unrestrictedNames -join ', ')"
        } else {
            Write-Host "  NO UNRESTRICTED ALTERNATIVES FOUND" -ForegroundColor Yellow
            Write-ValidationLog -Message "No unrestricted alternative AVD SKUs found" -Check "Alternative VM SKUs - Available" -Result "Warning" -Component "VM SKU" -Recommendation "Review SKU selection or regional deployment strategy"
        }
        
        # Display restricted alternatives with detailed restriction analysis
        if ($restricted.Count -gt 0) {
            Write-Host ""
            Write-Host "  RESTRICTED ALTERNATIVES:" -ForegroundColor Yellow
            Write-Host ""
              
            foreach ($sku in $restricted | Sort-Object Name) {
                $caps = $sku.Capabilities
                $vcpus = ($caps | Where-Object { $_.Name -eq "vCPUs" }).Value
                $memory = ($caps | Where-Object { $_.Name -eq "MemoryGB" }).Value
                $restrictionCodes = $sku.Restrictions | ForEach-Object { $_.ReasonCode } | Join-String -Separator ', '
                
                Write-Host "     $($sku.Name) " -NoNewline -ForegroundColor White
                Write-Host "($vcpus vCPUs, $memory GB) " -NoNewline -ForegroundColor Gray  
                Write-Host "Restrictions: $restrictionCodes" -ForegroundColor Red
            }
            
            $restrictedNames = $restricted | ForEach-Object { $_.Name } | Sort-Object
            Write-ValidationLog -Message "Restricted alternative AVD SKUs found" -Check "Alternative VM SKUs - Restricted" -Result "Warning" -Component "VM SKU" -Details "Count: $($restricted.Count), SKUs: $($restrictedNames -join ', ')"
        }
        
        # Overall region and SKU recommendation
        Write-Host ""
        Write-Host ("="*100) -ForegroundColor Cyan
        Write-Host "OVERALL RECOMMENDATION:" -ForegroundColor Cyan
        Write-Host ("="*100) -ForegroundColor Cyan
        Write-Host ""
        
        $totalAvailableSkus = $unrestricted.Count
        if (-not $restrictionAnalysis.HasRestrictions -and $totalAvailableSkus -gt 0) {
            Write-Host "  EXCELLENT: Your selected SKU is optimal" -ForegroundColor Green
            Write-Host "     No restrictions on selected SKU" -ForegroundColor Green  
            Write-Host "     $totalAvailableSkus additional alternatives available" -ForegroundColor Green
            $recommendationResult = "Pass"
            $recommendationDetails = "Optimal SKU selection with $totalAvailableSkus alternatives"
        }
        elseif ($restrictionAnalysis.HasRestrictions -and $totalAvailableSkus -gt 0) {
            Write-Host "  CAUTION: Consider alternatives" -ForegroundColor Yellow
            Write-Host "     Selected SKU has restrictions" -ForegroundColor Yellow
            Write-Host "     $totalAvailableSkus unrestricted alternatives available" -ForegroundColor Yellow
            $recommendationResult = "Warning"  
            $recommendationDetails = "Selected SKU restricted, $totalAvailableSkus alternatives available"
        }
        else {
            Write-Host "  CONCERN: Limited options in this region" -ForegroundColor Red
            Write-Host "     Selected SKU has restrictions" -ForegroundColor Red
            Write-Host "     No unrestricted alternatives found" -ForegroundColor Red
            Write-Host "     Consider different region or SKU series" -ForegroundColor Yellow
            $recommendationResult = "Fail"
            $recommendationDetails = "Selected SKU restricted, no alternatives available in region"
        }
        
        Write-ValidationLog -Message "Overall SKU availability analysis completed" -Check "Regional SKU Analysis" -Result $recommendationResult -Component "VM SKU" -Details $recommendationDetails
        
        # Comprehensive Quota and Limits Analysis
        Write-Host ""
        Write-Host ("="*100) -ForegroundColor Cyan
        Write-Host "QUOTA AND LIMITS ANALYSIS:" -ForegroundColor Cyan
        Write-Host ("="*100) -ForegroundColor Cyan
        Write-Host ""
        
        try {
            Write-ValidationLog -Message "Starting comprehensive quota analysis for selected SKU" -Check "Quota Analysis" -Result "Info" -Component "Quota & Limits" -Details "SKU: $skuToTest, Region: $regionToTest"
            
            # Check if Az.Compute is available for quota checks
            if (-not (Test-AzComputeAvailable)) {
                Write-Host "  Quota analysis skipped - Az.Compute module not available" -ForegroundColor Yellow
                Write-ValidationLog -Message "Quota analysis skipped - Az.Compute module not available" -Check "Quota Analysis" -Result "Warning" -Component "Quota & Limits" -Details "Az.Compute module failed to load"
                Write-Host ""
            } else {
                # Get VM usage and limits for the selected region
                $vmUsage = Get-AzVMUsage -Location $regionToTest
            
            if (-not $vmUsage) {
                Write-Host "  Could not retrieve quota information for region $regionToTest" -ForegroundColor Red
                Write-ValidationLog -Message "Failed to retrieve quota information" -Check "Quota Retrieval" -Result "Fail" -Component "Quota & Limits" -Details "Region: $regionToTest"
                Write-Host ""
            } else {
                Write-Host "  Retrieved quota information for $($vmUsage.Count) resource types" -ForegroundColor Green
                Write-ValidationLog -Message "Successfully retrieved quota information" -Check "Quota Retrieval" -Result "Pass" -Component "Quota & Limits" -Details "Resource types: $($vmUsage.Count)"
                
                # Analyze SKU-specific quota requirements
                $skuVcpus = [int]$vcpus
                $quotaAnalysis = @{
                    TotalRegionalvCPUs = $null
                    SkuFamilyvCPUs = $null
                    StandardvCPUs = $null
                    QuotaCritical = @()
                    QuotaWarning = @()
                    QuotaHealthy = @()
                }
                
                Write-Host ""
                Write-Host "-------------------------" -ForegroundColor White
                Write-Host "CRITICAL QUOTA ANALYSIS:" -ForegroundColor White
                Write-Host "-------------------------" -ForegroundColor White
                Write-Host ""
                
                # 1. Total Regional vCPUs (most critical)
                $totalvCPUsQuota = $vmUsage | Where-Object { $_.Name.Value -eq "cores" -or $_.Name.LocalizedValue -like "*Total Regional vCPUs*" } | Select-Object -First 1
                if ($totalvCPUsQuota) {
                    $currentUsage = [int]$totalvCPUsQuota.CurrentValue
                    $limit = [int]$totalvCPUsQuota.Limit
                    $available = $limit - $currentUsage
                    $utilizationPercent = [math]::Round(($currentUsage / $limit) * 100, 1)
                    
                    $quotaAnalysis.TotalRegionalvCPUs = @{
                        Name = "Total Regional vCPUs"
                        Current = $currentUsage
                        Limit = $limit
                        Available = $available
                        UtilizationPercent = $utilizationPercent
                        RequiredForSKU = $skuVcpus
                        CanDeploy = $available -ge $skuVcpus
                    }
                    
                    Write-Host "     Total Regional vCPUs:" -ForegroundColor White
                    Write-Host "       Current Usage: $currentUsage / $limit ($utilizationPercent%)" -ForegroundColor Gray
                    Write-Host "       Available: $available vCPUs" -ForegroundColor $(if ($available -gt $skuVcpus * 2) { "Green" } elseif ($available -ge $skuVcpus) { "Yellow" } else { "Red" })
                    Write-Host "       Required for $skuToTest`: $skuVcpus vCPUs" -ForegroundColor Gray
                    
                    if ($available -ge $skuVcpus) {
                        Write-Host "       Status: SUFFICIENT QUOTA" -ForegroundColor Green
                        $quotaAnalysis.QuotaHealthy += $quotaAnalysis.TotalRegionalvCPUs
                        Write-ValidationLog -Message "Regional vCPU quota sufficient for deployment" -Check "Total Regional vCPUs Quota" -Result "Pass" -Component "Quota & Limits" -Details "Available: $available, Required: $skuVcpus, Utilization: $utilizationPercent%"
                    } else {
                        Write-Host "       Status: INSUFFICIENT QUOTA - DEPLOYMENT WILL FAIL" -ForegroundColor Red
                        $quotaAnalysis.QuotaCritical += $quotaAnalysis.TotalRegionalvCPUs
                        Write-ValidationLog -Message "Regional vCPU quota insufficient for deployment" -Check "Total Regional vCPUs Quota" -Result "Fail" -Component "Quota & Limits" -Details "Available: $available, Required: $skuVcpus, Utilization: $utilizationPercent%" -Recommendation "Request quota increase for Total Regional vCPUs"
                    }
                } else {
                    Write-Host "     Total Regional vCPUs: Could not retrieve quota information" -ForegroundColor Red
                    Write-ValidationLog -Message "Could not retrieve Total Regional vCPUs quota" -Check "Total Regional vCPUs Quota" -Result "Warning" -Component "Quota & Limits"
                }
                
                # 2. VM Family-specific vCPUs (e.g., Standard Dv3 Family vCPUs)
                $skuFamily = ""
                if ($skuToTest -match "Standard_([A-Z]+)") {
                    $skuFamily = $matches[1]
                    $familyQuotaPatterns = @(
                        "*$skuFamily* Family vCPUs*",
                        "*Standard $skuFamily Family vCPUs*",
                        "*$skuFamily*vCPUs*"
                    )
                    
                    $familyvCPUsQuota = $null
                    foreach ($pattern in $familyQuotaPatterns) {
                        $familyvCPUsQuota = $vmUsage | Where-Object { $_.Name.LocalizedValue -like $pattern } | Select-Object -First 1
                        if ($familyvCPUsQuota) { break }
                    }
                    
                    if ($familyvCPUsQuota) {
                        $currentUsage = [int]$familyvCPUsQuota.CurrentValue
                        $limit = [int]$familyvCPUsQuota.Limit
                        $available = $limit - $currentUsage
                        $utilizationPercent = [math]::Round(($currentUsage / $limit) * 100, 1)
                        
                        $quotaAnalysis.SkuFamilyvCPUs = @{
                            Name = $familyvCPUsQuota.Name.LocalizedValue
                            Current = $currentUsage
                            Limit = $limit
                            Available = $available
                            UtilizationPercent = $utilizationPercent
                            RequiredForSKU = $skuVcpus
                            CanDeploy = $available -ge $skuVcpus
                        }
                        
                        Write-Host "     $($familyvCPUsQuota.Name.LocalizedValue):" -ForegroundColor White
                        Write-Host "       Current Usage: $currentUsage / $limit ($utilizationPercent%)" -ForegroundColor Gray
                        Write-Host "       Available: $available vCPUs" -ForegroundColor $(if ($available -gt $skuVcpus * 2) { "Green" } elseif ($available -ge $skuVcpus) { "Yellow" } else { "Red" })
                        Write-Host "       Required for $skuToTest`: $skuVcpus vCPUs" -ForegroundColor Gray
                        
                        if ($available -ge $skuVcpus) {
                            Write-Host "       Status: SUFFICIENT QUOTA" -ForegroundColor Green
                            $quotaAnalysis.QuotaHealthy += $quotaAnalysis.SkuFamilyvCPUs
                            Write-ValidationLog -Message "VM family vCPU quota sufficient for deployment" -Check "$skuFamily Family vCPUs Quota" -Result "Pass" -Component "Quota & Limits" -Details "Available: $available, Required: $skuVcpus, Utilization: $utilizationPercent%"
                        } elseif ($available -gt 0 -and $available -lt $skuVcpus) {
                            Write-Host "       Status: INSUFFICIENT QUOTA - DEPLOYMENT WILL FAIL" -ForegroundColor Red
                            $quotaAnalysis.QuotaCritical += $quotaAnalysis.SkuFamilyvCPUs
                            Write-ValidationLog -Message "VM family vCPU quota insufficient for deployment" -Check "$skuFamily Family vCPUs Quota" -Result "Fail" -Component "Quota & Limits" -Details "Available: $available, Required: $skuVcpus, Utilization: $utilizationPercent%" -Recommendation "Request quota increase for $skuFamily Family vCPUs"
                        } else {
                            Write-Host "       Status: QUOTA EXHAUSTED - DEPLOYMENT WILL FAIL" -ForegroundColor Red
                            $quotaAnalysis.QuotaCritical += $quotaAnalysis.SkuFamilyvCPUs
                            Write-ValidationLog -Message "VM family vCPU quota exhausted" -Check "$skuFamily Family vCPUs Quota" -Result "Fail" -Component "Quota & Limits" -Details "Available: $available, Required: $skuVcpus, Utilization: $utilizationPercent%" -Recommendation "Request quota increase for $skuFamily Family vCPUs"
                        }
                    } else {
                        Write-Host "     $skuFamily Family vCPUs: No specific family quota found" -ForegroundColor Yellow
                        Write-ValidationLog -Message "No specific VM family quota found" -Check "$skuFamily Family vCPUs Quota" -Result "Warning" -Component "Quota & Limits" -Details "Family: $skuFamily"
                    }
                }
                
                # 3. Standard vCPUs (general quota)
                $standardvCPUsQuota = $vmUsage | Where-Object { 
                    $_.Name.LocalizedValue -like "*Standard*vCPUs*" -and 
                    $_.Name.LocalizedValue -notlike "*Family*" -and
                    $_.Name.LocalizedValue -notlike "*Spot*"
                } | Select-Object -First 1
                
                if ($standardvCPUsQuota) {
                    $currentUsage = [int]$standardvCPUsQuota.CurrentValue
                    $limit = [int]$standardvCPUsQuota.Limit
                    $available = $limit - $currentUsage
                    $utilizationPercent = [math]::Round(($currentUsage / $limit) * 100, 1)
                    
                    $quotaAnalysis.StandardvCPUs = @{
                        Name = $standardvCPUsQuota.Name.LocalizedValue
                        Current = $currentUsage
                        Limit = $limit
                        Available = $available
                        UtilizationPercent = $utilizationPercent
                        RequiredForSKU = $skuVcpus
                        CanDeploy = $available -ge $skuVcpus
                    }
                    
                    Write-Host "     $($standardvCPUsQuota.Name.LocalizedValue):" -ForegroundColor White
                    Write-Host "       Current Usage: $currentUsage / $limit ($utilizationPercent%)" -ForegroundColor Gray
                    Write-Host "       Available: $available vCPUs" -ForegroundColor $(if ($available -gt $skuVcpus * 2) { "Green" } elseif ($available -ge $skuVcpus) { "Yellow" } else { "Red" })
                    
                    if ($available -ge $skuVcpus) {
                        Write-Host "       Status: SUFFICIENT QUOTA" -ForegroundColor Green
                        $quotaAnalysis.QuotaHealthy += $quotaAnalysis.StandardvCPUs
                    } else {
                        Write-Host "       Status: INSUFFICIENT QUOTA" -ForegroundColor Red
                        $quotaAnalysis.QuotaCritical += $quotaAnalysis.StandardvCPUs
                    }
                }
                
                Write-Host ""
                Write-Host "------------------------------" -ForegroundColor White
                Write-Host "ADDITIONAL QUOTA INFORMATION:" -ForegroundColor White
                Write-Host "------------------------------" -ForegroundColor White
                Write-Host ""
                
                # 4. Other relevant quotas
                $otherQuotas = @(
                    @{Pattern="*Virtual Machines*"; Name="Virtual Machines"},
                    @{Pattern="*Network Interfaces*"; Name="Network Interfaces"}, 
                    @{Pattern="*Public IP*"; Name="Public IP Addresses"},
                    @{Pattern="*Network Security Groups*"; Name="Network Security Groups"},
                    @{Pattern="*Load Balancers*"; Name="Load Balancers"}
                )
                
                foreach ($quota in $otherQuotas) {
                    $quotaInfo = $vmUsage | Where-Object { $_.Name.LocalizedValue -like $quota.Pattern } | Select-Object -First 1
                    if ($quotaInfo) {
                        $currentUsage = [int]$quotaInfo.CurrentValue
                        $limit = [int]$quotaInfo.Limit
                        $available = $limit - $currentUsage
                        $utilizationPercent = [math]::Round(($currentUsage / $limit) * 100, 1)
                        
                        $status = if ($utilizationPercent -gt 90) { "High Usage" }
                                 elseif ($utilizationPercent -gt 70) { "Moderate Usage" }
                                 else { "Healthy" }
                        
                        $color = if ($utilizationPercent -gt 90) { "Red" }
                                elseif ($utilizationPercent -gt 70) { "Yellow" }
                                else { "Green" }
                        
                        Write-Host "     $($quota.Name): $currentUsage / $limit ($utilizationPercent%) - $status" -ForegroundColor $color
                        
                        if ($utilizationPercent -gt 80) {
                            $quotaAnalysis.QuotaWarning += @{
                                Name = $quota.Name
                                UtilizationPercent = $utilizationPercent
                                Available = $available
                            }
                        }
                    }
                }
                
                # Overall quota assessment and recommendations
                Write-Host ""
                Write-Host "----------------------------" -ForegroundColor White
                Write-Host "QUOTA DEPLOYMENT ASSESSMENT:" -ForegroundColor White
                Write-Host "----------------------------" -ForegroundColor White
                Write-Host ""
                
                $canDeploy = $true
                $deploymentBlockers = @()
                $deploymentWarnings = @()
                
                # Check critical quotas
                if ($quotaAnalysis.TotalRegionalvCPUs -and -not $quotaAnalysis.TotalRegionalvCPUs.CanDeploy) {
                    $canDeploy = $false
                    $deploymentBlockers += "Total Regional vCPUs quota exceeded"
                }
                
                if ($quotaAnalysis.SkuFamilyvCPUs -and -not $quotaAnalysis.SkuFamilyvCPUs.CanDeploy) {
                    $canDeploy = $false
                    $deploymentBlockers += "$skuFamily Family vCPUs quota exceeded"
                }
                
                if ($quotaAnalysis.StandardvCPUs -and -not $quotaAnalysis.StandardvCPUs.CanDeploy) {
                    $canDeploy = $false
                    $deploymentBlockers += "Standard vCPUs quota exceeded"
                }
                
                # Assessment results
                if ($canDeploy) {
                    Write-Host "     DEPLOYMENT STATUS: CAN PROCEED" -ForegroundColor Green
                    Write-Host "     All critical quotas have sufficient capacity for deployment" -ForegroundColor Green
                    
                    # Check for warnings (high utilization)
                    $highUtilizationQuotas = @()
                    if ($quotaAnalysis.TotalRegionalvCPUs -and $quotaAnalysis.TotalRegionalvCPUs.UtilizationPercent -gt 80) {
                        $highUtilizationQuotas += "Total Regional vCPUs ($($quotaAnalysis.TotalRegionalvCPUs.UtilizationPercent)%)"
                    }
                    if ($quotaAnalysis.SkuFamilyvCPUs -and $quotaAnalysis.SkuFamilyvCPUs.UtilizationPercent -gt 80) {
                        $highUtilizationQuotas += "$skuFamily Family vCPUs ($($quotaAnalysis.SkuFamilyvCPUs.UtilizationPercent)%)"
                    }
                    
                    if ($highUtilizationQuotas.Count -gt 0) {
                        Write-Host "     CAUTION: High quota utilization detected:" -ForegroundColor Yellow
                        foreach ($warning in $highUtilizationQuotas) {
                            Write-Host "       $warning" -ForegroundColor Yellow
                        }
                        Write-Host "     Consider requesting quota increases for future scalability" -ForegroundColor Yellow
                        $quotaResult = "Warning"
                        $quotaDetails = "Deployment possible but high quota utilization: $($highUtilizationQuotas -join ', ')"
                    } else {
                        $quotaResult = "Pass" 
                        $quotaDetails = "All quotas healthy for deployment"
                    }
                } else {
                    Write-Host "     DEPLOYMENT STATUS: BLOCKED" -ForegroundColor Red
                    Write-Host "     The following quota limits will prevent deployment:" -ForegroundColor Red
                    foreach ($blocker in $deploymentBlockers) {
                        Write-Host "       $blocker" -ForegroundColor Red
                    }
                    Write-Host ""
                    Write-Host "     REQUIRED ACTIONS:" -ForegroundColor Yellow
                    Write-Host "       1. Request quota increases via Azure Portal" -ForegroundColor Yellow
                    Write-Host "       2. Or select a smaller VM SKU with fewer vCPUs" -ForegroundColor Yellow
                    Write-Host "       3. Or choose a different region with more available quota" -ForegroundColor Yellow
                    
                    $quotaResult = "Fail"
                    $quotaDetails = "Deployment blocked by quota limits: $($deploymentBlockers -join ', ')"
                }
                
                Write-ValidationLog -Message "Comprehensive quota analysis completed" -Check "Overall Quota Assessment" -Result $quotaResult -Component "Quota & Limits" -Details $quotaDetails
            }
            }  # End of Az.Compute availability check
            
        } catch {
            Write-Host "  Error occurred during quota analysis: $($_.Exception.Message)" -ForegroundColor Red
            Write-ValidationLog -Message "Error during quota analysis" -Check "Quota Analysis" -Result "Fail" -Component "Quota & Limits" -Details $_.Exception.Message
        }
        
        return $true
        
    } catch {
        Write-ValidationLog -Message "Failed to validate VM SKU availability" -Check "VM SKU Validation" -Result "Fail" -Component "VM SKU" -Details $_.Exception.Message
        return $false
    }
}

# ALWAYS-FRESH Identity provisioning selection function (NO CACHING)
function Select-IdentityProvisioningModel {
    # EXPLICITLY clear any cached value to ensure fresh selection every time
    $script:SelectedIdentityModel = $null
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " AVD Identity Provisioning Model Selection " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    Write-Host "FRESH SELECTION REQUIRED - No cached choices allowed" -ForegroundColor Yellow
    Write-Host "Select the identity provisioning model for your AVD deployment:" -ForegroundColor Cyan
    Write-Host ""
    
    # Define identity models with descriptions and requirements
    $identityModels = @(
        @{
            Number = 1
            Name = "AD DS"
            DisplayName = "Active Directory Domain Services (AD DS)"
            Description = "Traditional domain-joined VMs with on-premises AD"
            Requirements = "On-premises AD infrastructure Domain controllers accessible VMs will be domain-joined to existing AD"
            Validations = "Active Directory connectivity Domain controller discovery LDAP connectivity testing"
            UseCase = "Best for: Organizations with existing on-premises AD infrastructure"
        },
        @{
            Number = 2  
            Name = "Entra ID Join"
            DisplayName = "Entra ID Join"
            Description = "Cloud-native identity with Entra ID-joined VMs"
            Requirements = "Entra ID tenant No on-premises AD dependency VMs will be Entra ID-joined only"
            Validations = "Azure subscription and Entra ID access Service principal validation no AD connectivity required"
            UseCase = "Best for: Cloud-first organizations, new deployments, simplified management"
        },
        @{
            Number = 3
            Name = "Hybrid Join"
            DisplayName = "Entra ID Hybrid Join"  
            Description = "Hybrid identity with Entra ID Kerberos authentication"
            Requirements = "Entra ID tenant with hybrid setup Entra ID Kerberos authentication Key Vault for Kerberos keys"
            Validations = "Entra ID hybrid prerequisites Key Vault access verification Application registration permissions"
            UseCase = "Best for: Organizations transitioning to cloud, need both cloud and on-premises identity"
        }
    )
    
    # Display options
    foreach ($model in $identityModels) {
        Write-Host "[$($model.Number)] " -NoNewline -ForegroundColor Yellow
        Write-Host "$($model.DisplayName)" -ForegroundColor White
        Write-Host "    Description: " -NoNewline -ForegroundColor Gray
        Write-Host $model.Description -ForegroundColor Cyan
        Write-Host "    Requirements:" -ForegroundColor Gray  
        Write-Host "    $($model.Requirements)" -ForegroundColor DarkGray
        Write-Host "    Validations:" -ForegroundColor Gray
        Write-Host "    $($model.Validations)" -ForegroundColor DarkGray
        Write-Host "    $($model.UseCase)" -ForegroundColor Green
        Write-Host ""
    }
    
    # FORCE fresh selection every time - no defaults, no caching
    $selectedModel = $null
    do {
        $selection = Read-Host "Enter your choice (1-3) [Required - No defaults]"
        
        # Validate input and ensure fresh selection
        switch ($selection.Trim()) {
            "1" { 
                $selectedModel = "ADDS"
                $selectedDisplay = "Active Directory Domain Services (AD DS)"
                $valid = $true 
            }
            "2" { 
                $selectedModel = "EntraIDJoin"
                $selectedDisplay = "Entra ID Join"
                $valid = $true 
            }
            "3" { 
                $selectedModel = "HybridJoin" 
                $selectedDisplay = "Entra ID Hybrid Join"
                $valid = $true 
            }
            "" {
                Write-Host "⚠️  Empty selection not allowed. You must choose 1, 2, or 3." -ForegroundColor Red
                $valid = $false
            }
            default { 
                Write-Host "Invalid selection '$selection'. Please enter 1, 2, or 3." -ForegroundColor Red
                $valid = $false 
            }
        }
    } while (-not $valid)
    
    Write-Host ""
    Write-Host "Selected Identity Model: " -NoNewline -ForegroundColor Yellow
    Write-Host $selectedDisplay -ForegroundColor Green
    Write-Host ""
    
    # Store FRESH selection (explicitly no caching from previous runs)
    $script:SelectedIdentityModel = $selectedModel
    Write-ValidationLog -Message "Fresh identity provisioning model selected (no caching)" -Check "Identity Model Selection" -Result "Pass" -Component "Identity" -Details "Model: $selectedDisplay"
    
    # Configure validation behavior based on FRESH selection
    switch ($selectedModel) {
        "ADDS" {
            # For ADDS, we need AD validation but not hybrid identity
            Write-ValidationLog -Message "Configuring for AD DS: AD validation enabled, Hybrid validation disabled" -Check "Validation Configuration" -Result "Info" -Component "Identity"
        }
        "EntraIDJoin" {
            # For Entra ID Join, skip AD validations
            Write-ValidationLog -Message "Configuring for Entra ID Join: AD validation disabled, Cloud-native validation enabled" -Check "Validation Configuration" -Result "Info" -Component "Identity"
        }
        "HybridJoin" {
            # For Hybrid Join, enable hybrid validations
            Write-ValidationLog -Message "Configuring for Hybrid Join: Hybrid validation enabled, Traditional AD disabled" -Check "Validation Configuration" -Result "Info" -Component "Identity"
        }
    }
    
    return $selectedModel
}

# Entra ID-only validation function
function Test-EntraIDOnlyPrerequisites {
    if ($script:SelectedIdentityModel -ne "EntraIDJoin") {
        return $true
    }
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " Entra ID Join Prerequisites " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""

    try {
        # Validate Entra ID access
        Write-ValidationLog -Message "Checking Entra ID tenant access" -Check "Entra ID Access" -Result "Info" -Component "Entra ID"
        
        $context = Get-AzContext
        if ($context) {
            $tenantId = $context.Tenant.Id
            Write-ValidationLog -Message "Entra ID tenant access verified" -Check "Entra ID Access" -Result "Pass" -Component "Entra ID" -Details "Tenant ID: $tenantId"
        } else {
            Write-ValidationLog -Message "No Azure context found" -Check "Entra ID Access" -Result "Fail" -Component "Entra ID" -Recommendation "Ensure you are properly authenticated to Azure"
            return $false
        }
        
        # Check for device management permissions (optional but recommended)
        try {
            Write-ValidationLog -Message "Checking device management capabilities" -Check "Device Management" -Result "Info" -Component "Entra ID"
            Write-ValidationLog -Message "Device management prerequisites check completed" -Check "Device Management" -Result "Pass" -Component "Entra ID" -Details "Entra ID Join will handle device registration automatically"
        } catch {
            Write-ValidationLog -Message "Could not fully validate device management permissions" -Check "Device Management" -Result "Warning" -Component "Entra ID" -Details $_.Exception.Message -Recommendation "Ensure proper Entra ID device management permissions"
        }
        
        # Validate subscription for VM deployment
        Write-ValidationLog -Message "Entra ID Join model selected - VMs will be cloud-native" -Check "Identity Model Validation" -Result "Pass" -Component "Entra ID" -Details "No on-premises AD dependency required"
        
        return $true
        
    } catch {
        Write-ValidationLog -Message "Entra ID prerequisites validation failed" -Check "Entra ID Validation" -Result "Fail" -Component "Entra ID" -Details $_.Exception.Message
        return $false
    }
}

# Hybrid identity validation function
function Test-HybridIdentityPrerequisites {
    # Check if hybrid identity validation is needed based on FRESH identity model selection
    if ($SkipHybridIdentity -or $script:SelectedIdentityModel -eq "ADDS" -or $script:SelectedIdentityModel -eq "EntraIDJoin") {
        $reason = if ($SkipHybridIdentity) { "user request" }
                  elseif ($script:SelectedIdentityModel -eq "ADDS") { "AD DS selected (fresh choice)" }
                  else { "Entra ID Join selected (fresh choice)" }
        Write-ValidationLog -Message "Hybrid identity validation skipped ($reason)" -Check "Hybrid Identity Skip" -Result "Info" -Component "Hybrid Identity"
        return $true
    }
    
    # Only validate hybrid identity for HybridJoin model (based on fresh selection)
    if ($script:SelectedIdentityModel -ne "HybridJoin") {
        Write-ValidationLog -Message "Hybrid identity validation not required for selected identity model" -Check "Hybrid Identity Skip" -Result "Info" -Component "Hybrid Identity" -Details "Fresh Identity Selection: $($script:SelectedIdentityModel)"
        return $true
    }
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " Entra ID Kerberos Hybrid Identity Prerequisites " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""

    try {
        # Check for Entra ID Connect/Azure AD Connect
        Write-ValidationLog -Message "Checking Entra ID Connect prerequisites" -Check "Entra ID Connect" -Result "Info" -Component "Hybrid Identity"
        
        # Validate necessary permissions for Kerberos authentication setup
        $currentUser = Get-AzContext
        if ($currentUser) {
            Write-ValidationLog -Message "Current Azure context verified" -Check "Azure Context" -Result "Pass" -Component "Hybrid Identity" -Details "User: $($currentUser.Account.Id)"
        }
        
        # Check for Key Vault access (needed for Kerberos setup)
        try {
            $keyVaults = Get-AzKeyVault -ErrorAction SilentlyContinue
            if ($keyVaults) {
                Write-ValidationLog -Message "Key Vault access validated" -Check "Key Vault Access" -Result "Pass" -Component "Hybrid Identity" -Details "Can access existing Key Vaults"
            } else {
                Write-ValidationLog -Message "No existing Key Vaults found" -Check "Key Vault Access" -Result "Info" -Component "Hybrid Identity" -Details "New Key Vault will be needed for Kerberos authentication"
            }
        } catch {
            Write-ValidationLog -Message "Key Vault access check failed" -Check "Key Vault Access" -Result "Warning" -Component "Hybrid Identity" -Details $_.Exception.Message
        }
        
        # Validate permissions for application registration
        try {
            $context = Get-AzContext
            $tenantId = $context.Tenant.Id
            Write-ValidationLog -Message "Tenant access verified for application registration" -Check "App Registration Prerequisites" -Result "Pass" -Component "Hybrid Identity" -Details "Tenant ID: $tenantId"
        } catch {
            Write-ValidationLog -Message "Cannot verify application registration permissions" -Check "App Registration Prerequisites" -Result "Warning" -Component "Hybrid Identity" -Details $_.Exception.Message -Recommendation "Ensure you have permission to create app registrations in Entra ID"
        }
        
        return $true
        
    } catch {
        Write-ValidationLog -Message "Hybrid identity prerequisites validation failed" -Check "Hybrid Identity Validation" -Result "Fail" -Component "Hybrid Identity" -Details $_.Exception.Message
        return $false
    }
}

# Report generation function
function Export-ConsolidatedReport {
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host " Generating Platform Prerequisites Report " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""

    try {
        $script:ValidationSummary.EndTime = Get-Date
        $duration = $script:ValidationSummary.EndTime - $script:ValidationSummary.StartTime
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $scriptPath = if ($ReportPath) { $ReportPath } else { $PSScriptRoot }
        if (-not $scriptPath) { $scriptPath = Get-Location }
        
        # Generate summary information
        $summaryInfo = [PSCustomObject]@{
            ScriptName = "AVD Platform Prerequisites Checker"
            Version = "1.0.0"
            ExecutionDate = $script:ValidationSummary.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
            Duration = "$($duration.Minutes)m $($duration.Seconds)s"
            TargetRegion = $TargetRegion
            Environment = $Environment
            TotalChecks = $script:ValidationSummary.TotalChecks
            PassCount = $script:ValidationSummary.PassCount
            FailCount = $script:ValidationSummary.FailCount
            WarningCount = $script:ValidationSummary.WarningCount
            InfoCount = $script:ValidationSummary.InfoCount
            OverallStatus = if ($script:ValidationSummary.FailCount -eq 0) { 
                if ($script:ValidationSummary.WarningCount -eq 0) { "READY" } else { "READY WITH WARNINGS" }
            } else { "ISSUES FOUND" }
        }
        
        if ($script:UseCSVExport) {
            # CSV Export
            $reportPath = Join-Path $scriptPath "AVD_01_Check_Prerequisites_Platform_$timestamp.csv"
            
            # Combine summary and detailed results
            $combinedReport = @()
            $combinedReport += [PSCustomObject]@{
                Type = "SUMMARY"
                Timestamp = $summaryInfo.ExecutionDate
                Component = "Script Information"
                Check = "Overall Status"
                Result = $summaryInfo.OverallStatus
                Message = "Pass: $($summaryInfo.PassCount), Fail: $($summaryInfo.FailCount), Warning: $($summaryInfo.WarningCount), Info: $($summaryInfo.InfoCount)"
                Details = "Duration: $($summaryInfo.Duration), Region: $($summaryInfo.TargetRegion)"
                Recommendation = ""
            }
            
            $combinedReport += $script:Report | ForEach-Object {
                $_ | Add-Member -NotePropertyName "Type" -NotePropertyValue "DETAIL" -PassThru
            }
            
            $combinedReport | Export-Csv -Path $reportPath -NoTypeInformation
            Write-ValidationLog -Message "CSV report generated successfully" -Check "Report Generation" -Result "Pass" -Component "Reporting" -Details "Path: $reportPath"
            
        } else {
            # Excel Export
            $reportPath = Join-Path $scriptPath "AVD_01_Check_Prerequisites_Platform_Report_$timestamp.xlsx"
            
            # Create multiple worksheets
            $summaryInfo | Export-Excel -Path $reportPath -WorksheetName "Summary" -AutoSize -TableStyle Light1
            $script:Report | Export-Excel -Path $reportPath -WorksheetName "Detailed Results" -AutoSize -TableStyle Light1
            
            # Add conditional formatting for results
            $excelPackage = Open-ExcelPackage -Path $reportPath
            $worksheet = $excelPackage.Workbook.Worksheets["Detailed Results"]
            
            # Color code results
            $lastRow = $worksheet.Dimension.End.Row
            for ($row = 2; $row -le $lastRow; $row++) {
                $result = $worksheet.Cells[$row, 4].Value  # Result column
                switch ($result) {
                    "Pass" { $worksheet.Cells[$row, 1, $row, $worksheet.Dimension.End.Column].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid; $worksheet.Cells[$row, 1, $row, $worksheet.Dimension.End.Column].Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGreen) }
                    "Fail" { $worksheet.Cells[$row, 1, $row, $worksheet.Dimension.End.Column].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid; $worksheet.Cells[$row, 1, $row, $worksheet.Dimension.End.Column].Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightCoral) }
                    "Warning" { $worksheet.Cells[$row, 1, $row, $worksheet.Dimension.End.Column].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid; $worksheet.Cells[$row, 1, $row, $worksheet.Dimension.End.Column].Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightYellow) }
                }
            }
            
            Close-ExcelPackage $excelPackage
            Write-ValidationLog -Message "Excel report generated successfully" -Check "Report Generation" -Result "Pass" -Component "Reporting" -Details "Path: $reportPath"
        }
        
        return $reportPath
        
    } catch {
        Write-ValidationLog -Message "Failed to generate report" -Check "Report Generation" -Result "Fail" -Component "Reporting" -Details $_.Exception.Message
        return $null
    }
}

# Display summary function
function Show-ValidationSummary {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host " AVD - PLATFORM PREREQUISITES VALIDATION SUMMARY " -ForegroundColor Cyan
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host ""
    
    $duration = $script:ValidationSummary.EndTime - $script:ValidationSummary.StartTime
    
    Write-Host "Execution Time: " -NoNewline
    Write-Host "$($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor White
    
    Write-Host "Target Region: " -NoNewline  
    Write-Host $TargetRegion -ForegroundColor White
    
    Write-Host "Environment: " -NoNewline
    Write-Host $Environment -ForegroundColor White
    
    Write-Host "Validation Results:" -ForegroundColor Yellow
    Write-Host "  Total Checks: " -NoNewline
    Write-Host $script:ValidationSummary.TotalChecks -ForegroundColor White
    
    Write-Host "  Passed: " -NoNewline
    Write-Host $script:ValidationSummary.PassCount -ForegroundColor Green
    
    Write-Host "  Failed: " -NoNewline  
    Write-Host $script:ValidationSummary.FailCount -ForegroundColor Red
    
    Write-Host "  Warnings: " -NoNewline
    Write-Host $script:ValidationSummary.WarningCount -ForegroundColor Yellow
    
    Write-Host "  Info: " -NoNewline
    Write-Host $script:ValidationSummary.InfoCount -ForegroundColor Cyan
    
    Write-Host "Overall Status: " -NoNewline
    if ($script:ValidationSummary.FailCount -eq 0) {
        if ($script:ValidationSummary.WarningCount -eq 0) {
            Write-Host "ENVIRONMENT READY FOR AVD DEPLOYMENT" -ForegroundColor Green
        } else {
            Write-Host "READY WITH WARNINGS - REVIEW RECOMMENDATIONS" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ISSUES FOUND - REMEDIATION REQUIRED" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
}

# Main execution flow
function Start-AVDPrerequisitesValidation {
    try {
        # Clean up any already-loaded Az modules to prevent version conflicts
        $loadedAzModules = Get-Module Az.* 
        if ($loadedAzModules) {
            Write-Host "Removing previously loaded Az modules to ensure clean state..." -ForegroundColor Yellow
            $loadedAzModules | Remove-Module -Force -ErrorAction SilentlyContinue
            Write-Host "Clean state established" -ForegroundColor Green
            Write-Host ""
        }
        
        Write-Host ""
        Write-Host ("="*100) -ForegroundColor White
        Write-Host " AVD - Platform Prerequisites Validation" -ForegroundColor White  
        Write-Host ("="*100) -ForegroundColor White
        Write-Host ""
        
        Write-ValidationLog -Message "Starting AVD prerequisites validation - NO CACHING MODE" -Check "Script Initialization" -Result "Info" -Component "Initialization" -Details "Environment: $Environment, Fresh Selection Mode: Enabled"
        
        # EXPLICITLY clear any cached identity choices to ensure fresh selection
        $script:SelectedIdentityModel = $null
        Write-ValidationLog -Message "Identity model cache explicitly cleared" -Check "Cache Management" -Result "Info" -Component "Initialization" -Details "Fresh selection will be required"
        
        # Az module health check
        Test-AzModuleHealth | Out-Null
        
        # Module initialization
        Initialize-RequiredModules
        
        # Azure authentication
        Connect-AzureWithRetry
        
        # Subscription selection
        if (-not (Test-AzureSubscription)) {
            throw "Subscription validation failed"
        }
        
        # ALWAYS-FRESH Identity provisioning model selection (NO CACHING EVER)
        $selectedIdentityModel = Select-IdentityProvisioningModel
        if (-not $selectedIdentityModel) {
            throw "Identity provisioning model selection failed"
        }
        
        # Region selection
        $selectedRegion = Select-AzureRegion
        if (-not $selectedRegion) {
            throw "Region selection failed"
        }
        
        # VM SKU selection
        $selectedVMSku = Select-VMSku
        if (-not $selectedVMSku) {
            throw "VM SKU selection failed"
        }
        
        Write-Host ""
        Write-Host ("="*100) -ForegroundColor Green
        Write-Host " CONFIGURATION SUMMARY" -ForegroundColor Green
        Write-Host ("="*100) -ForegroundColor Green
        Write-Host "Subscription: " -NoNewline -ForegroundColor Yellow
        Write-Host $script:SelectedSubscription.Name -ForegroundColor White
        Write-Host "Identity Model: " -NoNewline -ForegroundColor Yellow
        $identityDisplay = switch ($selectedIdentityModel) {
            "ADDS" { "Active Directory Domain Services (AD DS)" }
            "EntraIDJoin" { "Entra ID Join" }  
            "HybridJoin" { "Entra ID Hybrid Join" }
            default { $selectedIdentityModel }
        }
        Write-Host $identityDisplay -ForegroundColor White
        Write-Host "Region: " -NoNewline -ForegroundColor Yellow
        Write-Host $selectedRegion -ForegroundColor White
        Write-Host "VM SKU: " -NoNewline -ForegroundColor Yellow
        Write-Host $selectedVMSku -ForegroundColor White
        Write-Host ("="*100) -ForegroundColor Green
        
        if (-not $NonInteractive) {
            Write-Host "Press Enter to continue with validation, or Ctrl+C to cancel..." -ForegroundColor Gray
            Read-Host
        }
        
        # Resource provider registration
        Register-RequiredProviders
        
        # AVD Service Principal validation
        Test-AVDServicePrincipal
        
        # Zone redundancy validation
        Test-ZoneRedundancy
        
        # Identity-specific validations (based on FRESH selection - no caching)
        Test-ActiveDirectoryConnectivity
        Test-EntraIDOnlyPrerequisites
        Test-HybridIdentityPrerequisites
        
        # VM SKU availability validation
        Test-VMSKUAvailability
        
        Write-ValidationLog -Message "All validations completed" -Check "Validation Complete" -Result "Pass" -Component "Completion"
        
    } catch {
        Write-ValidationLog -Message "Critical error during validation" -Check "Script Execution" -Result "Fail" -Component "Execution" -Details $_.Exception.Message
        Write-Host "Critical Error: $_" -ForegroundColor Red
        Write-Host "Check the detailed report for more information." -ForegroundColor Yellow
    } finally {
        # Generate report regardless of success/failure
        $reportPath = Export-ConsolidatedReport
        
        # Show summary
        Show-ValidationSummary
        
        if ($reportPath) {
            Write-Host "Detailed report saved to: " -NoNewline -ForegroundColor Yellow
            Write-Host $reportPath -ForegroundColor White
        }
        
        Write-Host "Validation complete. Press Enter to exit..." -ForegroundColor Gray
        if (-not $NonInteractive) {
            Read-Host
        }
    }
}

# Script entry point

Start-AVDPrerequisitesValidation
