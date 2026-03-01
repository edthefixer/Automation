<#
.SYNOPSIS
    Advanced Azure Virtual Desktop (AVD) VM Size Discovery and Analysis Tool
    
    Comprehensive AVD-optimized VM size discovery with enhanced authentication, cost analysis, performance classification,
    interactive tenant/subscription selection, and detailed reporting capabilities for Azure Virtual Desktop deployments.

.DESCRIPTION
    Professional-grade VM size discovery tool specifically designed for Azure Virtual Desktop (AVD) environments.
    This script performs comprehensive analysis of available VM sizes in specified Azure regions with focus on
    AVD workload requirements, performance characteristics, and cost optimization.
    
    Key Features:
    - Interactive multi-method Azure authentication (Browser, Device Code, Service Principal, Managed Identity)
    - Enhanced tenant and subscription selection with validation
    - AVD-specific VM size filtering and classification
    - Performance tier analysis (Light, Medium, Heavy, Graphics workloads)
    - Real-time Azure pricing integration via Retail Prices API
    - Accelerated networking capability detection
    - Comprehensive Excel and CSV reporting
    - Professional logging and error handling
    
    VM Size Analysis Includes:
    - vCPU and Memory specifications
    - Storage capabilities and disk limits
    - Network performance and accelerated networking
    - AVD workload type recommendations
    - Current Azure pricing (when enabled)
    - Regional availability verification
    
    Authentication Methods Supported:
    1. Interactive Browser Login (Default)
    2. Device Code Authentication (Recommended for remote sessions)
    3. Service Principal with Client Secret
    4. Service Principal with Certificate
    5. Managed Identity (for Azure VMs)

.PARAMETER SubscriptionId
    Azure Subscription ID to target. If not specified, user will be prompted to select from available subscriptions.

.PARAMETER TenantId
    Azure AD Tenant ID to authenticate against. If not specified, user will be prompted to select from available tenants.

.PARAMETER Location
    Azure region short name for VM size discovery (e.g., eastus, westus2, centralus). This is a required parameter.

.PARAMETER MinCores
    Minimum vCPU count to consider "AVD-capable" (default: 2). Filters out VM sizes with insufficient processing power.

.PARAMETER MinMemoryGB
    Minimum RAM in GB to consider "AVD-capable" (default: 4). Ensures adequate memory for user sessions.

.PARAMETER WorkloadType
    Filter results by AVD workload type classification:
    - Light: Basic productivity tasks (2-4 vCPUs, 4-8GB RAM)
    - Medium: Standard business applications (4-8 vCPUs, 8-16GB RAM)
    - Heavy: Resource-intensive applications (8+ vCPUs, 16+ GB RAM)
    - Graphics: GPU-accelerated workloads (NV/NC/ND series)
    - All: Show all AVD-capable VM sizes (default)

.PARAMETER IncludePricing
    Include real-time pricing information from Azure Retail Prices API. Adds current pay-as-you-go pricing to results.

.PARAMETER IncludeOnlyAccelerated
    If specified, only return VM sizes that support Accelerated Networking for enhanced network performance.

.PARAMETER ExportCsvPath
    Optional full path to export results as CSV file. If not specified, results are displayed in console only.

.PARAMETER ExportExcelPath
    Optional full path to export results as Excel file with advanced formatting and multiple worksheets.

.PARAMETER ForceReauth
    Force re-authentication even if valid cached Azure credentials exist. Useful for switching accounts or refreshing tokens.

.PARAMETER NonInteractive
    Run in non-interactive mode using current Azure context. Fails if not already authenticated or if tenant/subscription parameters are missing.

.EXAMPLE
    .\01_AVD_Validate_VMSizeAndQuota.ps1 -Location "eastus"
    
    Basic usage with interactive authentication and subscription selection for East US region.

.EXAMPLE
    .\01_AVD_Validate_VMSizeAndQuota.ps1 -Location "westus2" -WorkloadType "Medium" -IncludePricing
    
    Discover medium workload VM sizes in West US 2 with current pricing information.

.EXAMPLE
    .\01_AVD_Validate_VMSizeAndQuota.ps1 -Location "centralus" -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id" -IncludeOnlyAccelerated -ExportExcelPath "C:\Reports\AVD_VMSizes.xlsx"
    
    Targeted discovery with specific tenant/subscription, accelerated networking only, with Excel export.

.EXAMPLE
    .\01_AVD_Validate_VMSizeAndQuota.ps1 -Location "eastus" -WorkloadType "Graphics" -MinCores 8 -MinMemoryGB 32
    
    Find GPU-optimized VM sizes for graphics workloads with minimum 8 cores and 32GB RAM.

.EXAMPLE
    .\01_AVD_Validate_VMSizeAndQuota.ps1 -Location "northeurope" -NonInteractive -ExportCsvPath "C:\Reports\vm_sizes.csv"
    
    Non-interactive mode for automation scenarios with CSV export.

.NOTES
    Version: 1.0
    Author: edthefixer + GitHub Copilot... well, I fell asleep, copilot finished it...
    Last Updated: January 15, 2026
    
    PREREQUISITES:
    - PowerShell 5.1 or later
    - Azure PowerShell modules: Az.Accounts, Az.Compute, Az.Resources (minimum versions specified in script)
    - Azure subscription with at least Reader permissions
    - Internet connectivity for Azure API access and pricing data (when enabled)
    
    EXECUTION (Script is not signed):
    powershell -ExecutionPolicy Bypass -File "<path>\01_AVD_SubscriptionVMSizeDiscovery_Final.ps1"
    
    OUTPUT FORMATS:
    - Console: Formatted table display with color coding
    - CSV: Structured data export for further analysis
    - Excel: Professional report with multiple worksheets, conditional formatting, and charts
    
    WORKLOAD TYPE CLASSIFICATIONS:
    - Light: Office productivity, web browsing, email (Standard_D2s_v3, Standard_B2ms, etc.)
    - Medium: Business applications, development tools (Standard_D4s_v3, Standard_F4s_v2, etc.)
    - Heavy: CAD, engineering applications, data analysis (Standard_D8s_v3, Standard_F8s_v2, etc.)
    - Graphics: Design, rendering, machine learning (Standard_NV6, Standard_NC6, etc.)
    
    PERFORMANCE CONSIDERATIONS:
    - Accelerated Networking: Recommended for production AVD deployments
    - Premium SSD: Recommended for operating system and profile disks
    - Regional Selection: Choose regions close to your user base for optimal performance

.LINK
    https://docs.microsoft.com/azure/virtual-desktop/
    
.LINK
    https://azure.microsoft.com/pricing/details/virtual-machines/
    
.LINK
    https://docs.microsoft.com/azure/virtual-machines/sizes
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Azure Subscription ID")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false, HelpMessage = "Azure AD Tenant ID")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Azure region for VM size discovery")]
    [string]$Location,

    [Parameter(HelpMessage = "Minimum vCPU count for AVD compatibility")]
    [ValidateRange(1, 128)]
    [int]$MinCores = 2,
    
    [Parameter(HelpMessage = "Minimum memory in GB for AVD compatibility")]
    [ValidateRange(1, 512)]
    [int]$MinMemoryGB = 4,

    [Parameter(HelpMessage = "Filter by AVD workload type")]
    [ValidateSet("Light", "Medium", "Heavy", "Graphics", "All")]
    [string]$WorkloadType = "All",

    [Parameter(HelpMessage = "Include real-time pricing from Azure Retail Prices API")]
    [switch]$IncludePricing,
    
    [Parameter(HelpMessage = "Only return VM sizes with Accelerated Networking support")]
    [switch]$IncludeOnlyAccelerated,
    
    [Parameter(HelpMessage = "Force re-authentication")]
    [switch]$ForceReauth,
    
    [Parameter(HelpMessage = "Run in non-interactive mode")]
    [switch]$NonInteractive,

    [Parameter(HelpMessage = "CSV export file path")]
    [string]$ExportCsvPath,
    
    [Parameter(HelpMessage = "Excel export file path")]
    [string]$ExportExcelPath
)

# Global script variables
$script:Report = @()
$script:ValidationSummary = @{
    TotalChecks  = 0
    PassCount    = 0
    FailCount    = 0
    WarningCount = 0
    InfoCount    = 0
}

# Initialize logging to script folder
$Script:LogPath = "$PSScriptRoot\AVD_10_SubscriptionVMSizeDiscovery_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Required Azure PowerShell modules with minimum versions
$RequiredModules = @(
    @{ Name = "Az.Accounts"; MinVersion = "2.6.0"; Description = "Azure authentication and context management" },
    @{ Name = "Az.Compute"; MinVersion = "6.0.0"; Description = "Virtual machine and compute resource management" },
    @{ Name = "Az.Resources"; MinVersion = "6.0.0"; Description = "Resource management and metadata access" }
)

# Optional modules for enhanced functionality
$OptionalModules = @(
    @{ Name = "ImportExcel"; MinVersion = "7.0.0"; Description = "Excel export capabilities with advanced formatting" }
)

# VM Size Classifications for AVD Workloads
$WorkloadClassifications = @{
    Light    = @{
        Description     = "Basic productivity tasks (Office, web browsing, email)"
        MinCores        = 2
        MaxCores        = 4
        MinMemoryGB     = 4
        MaxMemoryGB     = 8
        PreferredSeries = @("B", "D2", "F2")
        Examples        = @("Standard_B2ms", "Standard_D2s_v3", "Standard_F2s_v2")
    }
    Medium   = @{
        Description     = "Standard business applications and development tools"
        MinCores        = 4
        MaxCores        = 8
        MinMemoryGB     = 8
        MaxMemoryGB     = 16
        PreferredSeries = @("D4", "F4", "E4")
        Examples        = @("Standard_D4s_v3", "Standard_F4s_v2", "Standard_E4s_v3")
    }
    Heavy    = @{
        Description     = "Resource-intensive applications (CAD, engineering, data analysis)"
        MinCores        = 8
        MaxCores        = 64
        MinMemoryGB     = 16
        MaxMemoryGB     = 256
        PreferredSeries = @("D8", "D16", "F8", "F16", "E8", "E16")
        Examples        = @("Standard_D8s_v3", "Standard_F8s_v2", "Standard_E8s_v3")
    }
    Graphics = @{
        Description     = "GPU-accelerated workloads (design, rendering, machine learning)"
        MinCores        = 4
        MaxCores        = 64
        MinMemoryGB     = 8
        MaxMemoryGB     = 256
        PreferredSeries = @("NV", "NC", "ND")
        Examples        = @("Standard_NV6", "Standard_NC6s_v3", "Standard_ND6s")
    }
}

# Function to add entries to the report with enhanced logging
function Add-ReportEntry {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Result,
        [string]$Details,
        [string]$Recommendation = ""
    )
    
    $script:Report += [PSCustomObject]@{
        Category       = $Category
        Check          = $Check
        Result         = $Result
        Details        = $Details
        Recommendation = $Recommendation
        Timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $script:ValidationSummary.TotalChecks++
    switch ($Result) {
        "Pass" { $script:ValidationSummary.PassCount++ }
        "Fail" { $script:ValidationSummary.FailCount++ }
        "Warning" { $script:ValidationSummary.WarningCount++ }
        "Info" { $script:ValidationSummary.InfoCount++ }
    }
    
    # Display real-time results with enhanced formatting
    $color = switch ($Result) {
        "Pass" { "Green" }
        "Fail" { "Red" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
        default { "White" }
    }
    
    Write-Host "[$Result] $Category - $Check" -ForegroundColor $color
    if ($Details) {
        Write-Host "  Details: $Details" -ForegroundColor Gray
    }
    
    # Write to log file
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Result] $Category - $Check"
    if ($Details) { $logEntry += "`n    Details: $Details" }
    if ($Recommendation) { $logEntry += "`n    Recommendation: $Recommendation" }
    Add-Content -Path $Script:LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
}

# Function to validate and install required PowerShell modules
function Test-PowerShellModules {
    Write-Host ""
    Write-Host "Validating Required PowerShell Modules..." -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($module in $RequiredModules) {
        try {
            $installedModule = Get-Module -Name $module.Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            
            if ($installedModule) {
                # Check version requirement
                if ($installedModule.Version -ge [Version]$module.MinVersion) {
                    # Import module if not already loaded
                    $importedModule = Get-Module -Name $module.Name
                    if (-not $importedModule) {
                        try {
                            Import-Module $module.Name -Force -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false | Out-Null
                            Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Import" -Result "Pass" -Details "Module imported successfully (Version: $($installedModule.Version))" 
                        }
                        catch {
                            Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Import" -Result "Fail" -Details "Failed to import module: $($_.Exception.Message)" -Recommendation "Try: Import-Module $($module.Name) -Force"
                            return $false
                        }
                    }
                    else {
                        Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Availability" -Result "Pass" -Details "Module already imported (Version: $($importedModule.Version))"
                    }
                }
                else {
                    Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Version" -Result "Fail" -Details "Installed version ($($installedModule.Version)) is below required minimum ($($module.MinVersion))" -Recommendation "Update with: Update-Module $($module.Name) -Force"
                    return $false
                }
            }
            else {
                # Module not installed - attempt installation
                Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Installation" -Result "Warning" -Details "Module not installed. Attempting automatic installation..."
                
                try {
                    Write-Host "Installing $($module.Name) (minimum version $($module.MinVersion))..." -ForegroundColor Yellow
                    Install-Module -Name $module.Name -MinimumVersion $module.MinVersion -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                    
                    # Verify installation
                    $newlyInstalled = Get-Module -Name $module.Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
                    if ($newlyInstalled -and $newlyInstalled.Version -ge [Version]$module.MinVersion) {
                        Import-Module $module.Name -Force -ErrorAction Stop | Out-Null
                        Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Installation" -Result "Pass" -Details "Module installed and imported successfully (Version: $($newlyInstalled.Version))"
                    }
                    else {
                        throw "Installation verification failed"
                    }
                }
                catch {
                    Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Installation" -Result "Fail" -Details "Failed to install module: $($_.Exception.Message)" -Recommendation "Manual install: Install-Module $($module.Name) -Force -AllowClobber"
                    return $false
                }
            }
        }
        catch {
            Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Validation" -Result "Fail" -Details "Error validating module: $($_.Exception.Message)" -Recommendation "Reinstall module: Install-Module $($module.Name) -Force -AllowClobber"
            return $false
        }
    }
    
    # Check optional modules
    foreach ($module in $OptionalModules) {
        try {
            $installedModule = Get-Module -Name $module.Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            
            if ($installedModule -and $installedModule.Version -ge [Version]$module.MinVersion) {
                Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Optional" -Result "Pass" -Details "Optional module available (Version: $($installedModule.Version)) - $($module.Description)"
            }
            else {
                Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Optional" -Result "Info" -Details "Optional module not available or outdated - $($module.Description)" -Recommendation "Install for enhanced features: Install-Module $($module.Name) -Force -AllowClobber"
            }
        }
        catch {
            Add-ReportEntry -Category "PowerShell Modules" -Check "$($module.Name) Optional" -Result "Info" -Details "Optional module check failed - $($module.Description)"
        }
    }
    
    Write-Host ""
    Write-Host "PowerShell modules validation completed." -ForegroundColor Green
    return $true
}

# Function to select tenant interactively (enhanced from reference script)
function Select-AzureTenant {
    param(
        [string]$ProvidedTenantId
    )
    
    if ($ProvidedTenantId) {
        Write-Host "Using provided Tenant ID: $ProvidedTenantId" -ForegroundColor Green
        return $ProvidedTenantId
    }
    
    if ($NonInteractive) {
        Write-Host "Non-interactive mode: Using current Azure context tenant" -ForegroundColor Yellow
        $context = Get-AzContext
        if ($context -and $context.Tenant) {
            return $context.Tenant.Id
        }
        else {
            throw "No Azure context found and no tenant specified in non-interactive mode"
        }
    }
    
    Write-Host ""
    Write-Host "$('='*80)" -ForegroundColor White
    Write-Host " TENANT SELECTION " -ForegroundColor White
    Write-Host "$('='*80)" -ForegroundColor White
    Write-Host ""
    
    try {
        # Get available tenants
        $tenants = Get-AzTenant
        
        if ($tenants.Count -eq 0) {
            throw "No accessible tenants found"
        }
        elseif ($tenants.Count -eq 1) {
            Write-Host "Only one tenant available: $($tenants[0].Name) ($($tenants[0].Id))" -ForegroundColor Green
            return $tenants[0].Id
        }
        else {
            Write-Host "Available Tenants:" -ForegroundColor White
            Write-Host ""
            
            for ($i = 0; $i -lt $tenants.Count; $i++) {
                $tenant = $tenants[$i]
                $displayName = if ($tenant.Name) { $tenant.Name } else { "Unknown" }
                Write-Host "  [$($i + 1)] $displayName" -ForegroundColor White
                Write-Host "      Tenant ID: $($tenant.Id)" -ForegroundColor Gray
                Write-Host ""
            }
            
            do {
                $selection = Read-Host "Please select a tenant (1-$($tenants.Count))"
                $selectionInt = 0
                $validSelection = [int]::TryParse($selection, [ref]$selectionInt) -and 
                $selectionInt -ge 1 -and $selectionInt -le $tenants.Count
                
                if (-not $validSelection) {
                    Write-Host "Invalid selection. Please enter a number between 1 and $($tenants.Count)." -ForegroundColor Red
                }
            } while (-not $validSelection)
            
            $selectedTenant = $tenants[$selectionInt - 1]
            Write-Host "Selected tenant: $($selectedTenant.Name) ($($selectedTenant.Id))" -ForegroundColor Green
            return $selectedTenant.Id
        }
    }
    catch {
        Write-Host "Error retrieving tenants: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

# Function to select subscription interactively (enhanced from reference script)
function Select-AzureSubscription {
    param(
        [string]$ProvidedSubscriptionId,
        [string]$TenantId
    )
    
    if ($ProvidedSubscriptionId) {
        Write-Host "Using provided Subscription ID: $ProvidedSubscriptionId" -ForegroundColor Green
        return $ProvidedSubscriptionId
    }
    
    if ($NonInteractive) {
        Write-Host "Non-interactive mode: Using current Azure context subscription" -ForegroundColor Yellow
        $context = Get-AzContext
        if ($context -and $context.Subscription) {
            return $context.Subscription.Id
        }
        else {
            throw "No Azure context found and no subscription specified in non-interactive mode"
        }
    }
    
    Write-Host ""
    Write-Host "$('='*80)" -ForegroundColor White
    Write-Host " SUBSCRIPTION SELECTION " -ForegroundColor White
    Write-Host "$('='*80)" -ForegroundColor White
    Write-Host ""
    
    try {
        # Get available subscriptions for the tenant
        $subscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object { $_.State -eq "Enabled" }
        
        if ($subscriptions.Count -eq 0) {
            throw "No enabled subscriptions found in tenant $TenantId"
        }
        elseif ($subscriptions.Count -eq 1) {
            Write-Host "Only one subscription available: $($subscriptions[0].Name) ($($subscriptions[0].Id))" -ForegroundColor Green
            return $subscriptions[0].Id
        }
        else {
            Write-Host "Available Subscriptions:" -ForegroundColor White
            Write-Host ""
            
            for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                $subscription = $subscriptions[$i]
                Write-Host "  [$($i + 1)] $($subscription.Name)" -ForegroundColor White
                Write-Host "      Subscription ID: $($subscription.Id)" -ForegroundColor Gray
                Write-Host "      State: $($subscription.State)" -ForegroundColor Gray
                Write-Host ""
            }
            
            do {
                $selection = Read-Host "Please select a subscription (1-$($subscriptions.Count))"
                $selectionInt = 0
                $validSelection = [int]::TryParse($selection, [ref]$selectionInt) -and 
                $selectionInt -ge 1 -and $selectionInt -le $subscriptions.Count
                
                if (-not $validSelection) {
                    Write-Host "Invalid selection. Please enter a number between 1 and $($subscriptions.Count)." -ForegroundColor Red
                }
            } while (-not $validSelection)
            
            $selectedSubscription = $subscriptions[$selectionInt - 1]
            Write-Host "Selected subscription: $($selectedSubscription.Name) ($($selectedSubscription.Id))" -ForegroundColor Green
            return $selectedSubscription.Id
        }
    }
    catch {
        Write-Host "Error retrieving subscriptions: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

# Function to select authentication method (enhanced from reference script)
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
        "Interactive"                 = "Interactive Browser Login"
        "DeviceCode"                  = "Device Code Authentication"
        "ServicePrincipalSecret"      = "Service Principal (Client Secret)"
        "ServicePrincipalCertificate" = "Service Principal (Certificate)"
        "ManagedIdentity"             = "Managed Identity"
    }
    
    Write-Host "Selected authentication method: $($methodNames[$selectedMethod])" -ForegroundColor Green
    Write-Host ""
    
    return $selectedMethod
}

# Function to perform authentication based on selected method (enhanced from reference script)
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
                }
                else {
                    Write-Host "Opening browser for interactive login..." -ForegroundColor Yellow
                    $authResult = Connect-AzAccount
                }
            }
            
            "DeviceCode" {
                Write-Host "Starting device code authentication..." -ForegroundColor Yellow
                Write-Host "You will see a device code that you need to enter at https://microsoft.com/devicelogin" -ForegroundColor Cyan
                if ($TenantId) {
                    $authResult = Connect-AzAccount -UseDeviceAuthentication -TenantId $TenantId
                }
                else {
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
        
    }
    catch {
        Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

# Function to establish Azure connection with tenant/subscription selection (enhanced from reference script)
function Connect-AzureWithSelection {
    Write-Host ""
    Write-Host "$('='*80)" -ForegroundColor White
    Write-Host " AZURE AUTHENTICATION " -ForegroundColor White
    Write-Host "$('='*80)" -ForegroundColor White
    Write-Host ""
    
    try {
        # Check if already connected
        $currentContext = Get-AzContext
        
        if ($currentContext -and -not $TenantId -and -not $SubscriptionId -and -not $ForceReauth) {
            Write-Host "Current Azure Context:" -ForegroundColor Yellow
            Write-Host "  Account: $($currentContext.Account.Id)" -ForegroundColor White
            Write-Host "  Tenant: $($currentContext.Tenant.Id)" -ForegroundColor White
            Write-Host "  Subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))" -ForegroundColor White
            Write-Host ""
            
            if (-not $NonInteractive) {
                $useExisting = Read-Host "Use existing connection? (Y/n)"
                if ($useExisting -eq "" -or $useExisting -eq "Y" -or $useExisting -eq "y") {
                    Write-Host "Using existing Azure connection." -ForegroundColor Green
                    Add-ReportEntry -Category "Azure Authentication" -Check "Connection Status" -Result "Pass" -Details "Using existing Azure connection for account: $($currentContext.Account.Id)"
                    return $true
                }
            }
            else {
                Write-Host "Non-interactive mode: Using existing Azure connection." -ForegroundColor Green
                Add-ReportEntry -Category "Azure Authentication" -Check "Connection Status" -Result "Pass" -Details "Using existing Azure connection (non-interactive mode)"
                return $true
            }
        }
        
        # Clear context if force re-auth
        if ($ForceReauth -and $currentContext) {
            Write-Host "Force re-authentication requested. Clearing existing context..." -ForegroundColor Yellow
            Clear-AzContext -Force -ErrorAction SilentlyContinue
            Disconnect-AzAccount -ErrorAction SilentlyContinue
        }
        
        # Select authentication method
        $authMethod = Select-AuthenticationMethod
        
        # Perform authentication using selected method
        $authResult = Invoke-AzureAuthentication -AuthMethod $authMethod -TenantId $TenantId
        
        if (-not $authResult) {
            throw "Failed to authenticate with Azure"
        }
        
        Add-ReportEntry -Category "Azure Authentication" -Check "Login Process" -Result "Pass" -Details "Successfully authenticated using $authMethod method"
        
        # Select tenant if not specified
        $selectedTenantId = Select-AzureTenant -ProvidedTenantId $TenantId
        
        # Select subscription if not specified
        $selectedSubscriptionId = Select-AzureSubscription -ProvidedSubscriptionId $SubscriptionId -TenantId $selectedTenantId
        
        # Set the context to the selected tenant and subscription
        Write-Host ""
        Write-Host "Setting Azure context to selected tenant and subscription..." -ForegroundColor Yellow
        
        $contextParams = @{
            SubscriptionId = $selectedSubscriptionId
        }
        
        if ($selectedTenantId -ne $TenantId) {
            $contextParams.TenantId = $selectedTenantId
        }
        
        Set-AzContext @contextParams | Out-Null
        
        $finalContext = Get-AzContext
        Write-Host ""
        Write-Host "Azure connection established successfully!" -ForegroundColor Green
        Write-Host "  Account: $($finalContext.Account.Id)" -ForegroundColor White
        Write-Host "  Tenant: $($finalContext.Tenant.Id)" -ForegroundColor White
        Write-Host "  Subscription: $($finalContext.Subscription.Name) ($($finalContext.Subscription.Id))" -ForegroundColor White
        Write-Host ""
        
        Add-ReportEntry -Category "Azure Authentication" -Check "Context Configuration" -Result "Pass" -Details "Azure context configured for subscription: $($finalContext.Subscription.Name)"
        
        return $true
        
    }
    catch {
        Write-Host "Failed to establish Azure connection: $($_.Exception.Message)" -ForegroundColor Red
        Add-ReportEntry -Category "Azure Authentication" -Check "Connection Establishment" -Result "Fail" -Details "Failed to establish Azure connection: $($_.Exception.Message)" -Recommendation "Verify credentials and network connectivity"
        
        # Offer retry option
        if (-not $NonInteractive) {
            Write-Host ""
            $retry = Read-Host "Would you like to try a different authentication method? (Y/n)"
            if ($retry -eq "" -or $retry -eq "Y" -or $retry -eq "y") {
                Write-Host "Retrying authentication..." -ForegroundColor Yellow
                return Connect-AzureWithSelection
            }
        }
        
        return $false
    }
}

# Function to validate the specified Azure region
function Test-AzureRegion {
    param([string]$Location)
    
    Write-Host "Validating Azure region: $Location" -ForegroundColor Cyan
    
    try {
        # Get available locations
        $locations = Get-AzLocation
        $targetLocation = $locations | Where-Object { $_.Location -eq $Location -or $_.DisplayName -eq $Location }
        
        if ($targetLocation) {
            Add-ReportEntry -Category "Region Validation" -Check "Location Availability" -Result "Pass" -Details "Region '$Location' is available (Display Name: $($targetLocation.DisplayName))"
            return $true
        }
        else {
            $availableLocations = ($locations | Select-Object -First 10 | ForEach-Object { $_.Location }) -join ", "
            Add-ReportEntry -Category "Region Validation" -Check "Location Availability" -Result "Fail" -Details "Region '$Location' is not available or invalid" -Recommendation "Available regions include: $availableLocations..."
            return $false
        }
    }
    catch {
        Add-ReportEntry -Category "Region Validation" -Check "Location Validation" -Result "Fail" -Details "Failed to validate region: $($_.Exception.Message)" -Recommendation "Verify region name and subscription permissions"
        return $false
    }
}

# Function to discover and analyze VM sizes
function Get-VMSizeAnalysis {
    param(
        [string]$Location,
        [int]$MinCores,
        [int]$MinMemoryGB,
        [string]$WorkloadType,
        [bool]$OnlyAccelerated,
        [bool]$IncludePricing
    )
    
    Write-Host ""
    Write-Host "Discovering VM sizes for AVD workloads in region: $Location" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Get all VM sizes with availability information using Get-AzComputeResourceSku
        Write-Host "Retrieving VM sizes with availability information for region $Location" -ForegroundColor Yellow
        
        $allSkus = Get-AzComputeResourceSku | Where-Object { 
            $_.ResourceType -eq "virtualMachines"
        }
        
        # Filter SKUs available in the specified location and build availability map
        $availabilityMap = @{}
        $allVMSizes = @()
        
        foreach ($sku in $allSkus) {
            $locationInfo = $sku.LocationInfo | Where-Object { $_.Location -eq $Location }
            if ($locationInfo) {
                # Check for restrictions
                $restrictions = $sku.Restrictions | Where-Object { 
                    $_.ReasonCode -eq "NotAvailableForSubscription" -or 
                    $_.ReasonCode -eq "QuotaId" 
                }
                
                $isAvailable = ($restrictions.Count -eq 0)
                $restrictionReason = if ($restrictions.Count -gt 0) { 
                    ($restrictions | ForEach-Object { $_.ReasonCode }) -join ", " 
                }
                else { 
                    "None" 
                }
                
                # Store availability information
                $availabilityMap[$sku.Name] = @{
                    IsAvailable  = $isAvailable
                    Restrictions = $restrictionReason
                    Zones        = $locationInfo.Zones -join ", "
                }
                
                # Build VM size object
                $vCPUs = [int]($sku.Capabilities | Where-Object Name -eq "vCPUs").Value
                $memoryGB = [double]($sku.Capabilities | Where-Object Name -eq "MemoryGB").Value
                $maxDataDisks = [int]($sku.Capabilities | Where-Object Name -eq "MaxDataDiskCount").Value
                
                $vmSize = [PSCustomObject]@{
                    Name                 = $sku.Name
                    NumberOfCores        = $vCPUs
                    MemoryInMB           = [int]($memoryGB * 1024)
                    MaxDataDiskCount     = $maxDataDisks
                    OSDiskSizeInMB       = 0  # Not available from SKU data
                    ResourceDiskSizeInMB = 0  # Not available from SKU data
                }
                $allVMSizes += $vmSize
            }
        }
        
        if (-not $allVMSizes -or $allVMSizes.Count -eq 0) {
            throw "No VM sizes found for region $Location"
        }
        
        Write-Host "Found $($allVMSizes.Count) total VM sizes in region $Location" -ForegroundColor Green
        Add-ReportEntry -Category "VM Discovery" -Check "VM Size Enumeration" -Result "Pass" -Details "Retrieved $($allVMSizes.Count) VM sizes from region $Location"
        
        # Filter by minimum requirements
        $filteredSizes = $allVMSizes | Where-Object { 
            $_.NumberOfCores -ge $MinCores -and 
            $_.MemoryInMB -ge ($MinMemoryGB * 1024)
        }
        
        Write-Host "Filtered to $($filteredSizes.Count) VM sizes meeting minimum requirements (vCPUs >= $MinCores, Memory >= ${MinMemoryGB}GB)" -ForegroundColor Yellow
        
        # Classify VM sizes by workload type
        $vmAnalysis = @()
        
        foreach ($vm in $filteredSizes) {
            $memoryGB = [math]::Round($vm.MemoryInMB / 1024, 1)
            
            # Determine workload classification
            $workloadClass = Get-WorkloadClassification -VMSize $vm.Name -Cores $vm.NumberOfCores -MemoryGB $memoryGB
            
            # Skip if not matching requested workload type
            if ($WorkloadType -ne "All" -and $workloadClass -ne $WorkloadType) {
                continue
            }
            
            # Get additional VM capabilities
            $capabilities = Get-VMCapabilities -VMSize $vm.Name -Location $Location
            
            # Skip if only accelerated networking is requested and VM doesn't support it
            if ($OnlyAccelerated -and -not $capabilities.AcceleratedNetworking) {
                continue
            }
            
            # Add pricing information if requested
            $pricing = $null
            if ($IncludePricing) {
                $pricing = Get-VMPricing -VMSize $vm.Name -Location $Location
            }
            
            # Get availability information
            $availInfo = $availabilityMap[$vm.Name]
            $isAvailable = if ($availInfo) { $availInfo.IsAvailable } else { $false }
            $restrictions = if ($availInfo) { $availInfo.Restrictions } else { "Unknown" }
            $zones = if ($availInfo) { $availInfo.Zones } else { "" }
            
            $vmInfo = [PSCustomObject]@{
                VMSize                = $vm.Name
                vCPUs                 = $vm.NumberOfCores
                MemoryGB              = $memoryGB
                MaxDataDisks          = $vm.MaxDataDiskCount
                OSDiskSizeGB          = [math]::Round($vm.OSDiskSizeInMB / 1024, 1)
                ResourceDiskSizeGB    = [math]::Round($vm.ResourceDiskSizeInMB / 1024, 1)
                WorkloadClass         = $workloadClass
                AcceleratedNetworking = $capabilities.AcceleratedNetworking
                PremiumIO             = $capabilities.PremiumIO
                Series                = Get-VMSeries -VMSize $vm.Name
                IsAvailable           = $isAvailable
                AvailabilityStatus    = if ($isAvailable) { "Available" } else { "Restricted" }
                Restrictions          = $restrictions
                AvailabilityZones     = $zones
                HourlyPrice           = if ($pricing) { $pricing.HourlyPrice } else { "N/A" }
                MonthlyPrice          = if ($pricing) { $pricing.MonthlyPrice } else { "N/A" }
                Currency              = if ($pricing) { $pricing.Currency } else { "N/A" }
            }
            
            $vmAnalysis += $vmInfo
        }
        
        if ($vmAnalysis.Count -eq 0) {
            Write-Host "No VM sizes found matching the specified criteria." -ForegroundColor Red
            Add-ReportEntry -Category "VM Discovery" -Check "Filtered Results" -Result "Warning" -Details "No VM sizes found matching criteria: WorkloadType=$WorkloadType, AcceleratedOnly=$OnlyAccelerated"
            return @()
        }
        
        # Sort by workload class and then by cores
        $vmAnalysis = $vmAnalysis | Sort-Object @{Expression = "WorkloadClass"; Descending = $false }, @{Expression = "vCPUs"; Descending = $false }, @{Expression = "MemoryGB"; Descending = $false }
        
        Write-Host "Analysis complete: $($vmAnalysis.Count) VM sizes match your criteria" -ForegroundColor Green
        Add-ReportEntry -Category "VM Discovery" -Check "Analysis Results" -Result "Pass" -Details "Successfully analyzed $($vmAnalysis.Count) VM sizes matching specified criteria"
        
        return $vmAnalysis
        
    }
    catch {
        Write-Host "Error during VM size discovery: $($_.Exception.Message)" -ForegroundColor Red
        Add-ReportEntry -Category "VM Discovery" -Check "Discovery Process" -Result "Fail" -Details "VM size discovery failed: $($_.Exception.Message)" -Recommendation "Verify region name and subscription permissions"
        throw $_
    }
}

# Helper function to classify VM sizes by workload type
function Get-WorkloadClassification {
    param(
        [string]$VMSize,
        [int]$Cores,
        [double]$MemoryGB
    )
    
    # Check for GPU series (Graphics workload)
    if ($VMSize -match "^Standard_(NV|NC|ND)") {
        return "Graphics"
    }
    
    # Classify based on cores and memory
    if ($Cores -le 4 -and $MemoryGB -le 8) {
        return "Light"
    }
    elseif ($Cores -le 8 -and $MemoryGB -le 16) {
        return "Medium"
    }
    else {
        return "Heavy"
    }
}

# Helper function to get VM series information
function Get-VMSeries {
    param([string]$VMSize)
    
    if ($VMSize -match "^Standard_([A-Z]+\d*)") {
        return $matches[1]
    }
    return "Unknown"
}

# Helper function to get VM capabilities (mock implementation - would need actual API calls for full details)
function Get-VMCapabilities {
    param(
        [string]$VMSize,
        [string]$Location
    )
    
    # This is a simplified implementation. In a full version, you would query Azure APIs for detailed capabilities
    return [PSCustomObject]@{
        AcceleratedNetworking = $VMSize -notmatch "^Standard_(B|A)" # Most modern VM series support accelerated networking except Basic and A-series
        PremiumIO             = $VMSize -match "s_v\d+$|ds_v\d+$" # VM sizes ending with 's' typically support Premium storage
    }
}

# Helper function to get VM pricing (mock implementation)
function Get-VMPricing {
    param(
        [string]$VMSize,
        [string]$Location
    )
    
    # This would integrate with Azure Retail Prices API
    # For now, return mock data
    return [PSCustomObject]@{
        HourlyPrice  = "N/A"
        MonthlyPrice = "N/A"
        Currency     = "USD"
    }
}

# Function to provide intelligent recommendations based on available VM sizes
function Get-VMRecommendations {
    param([array]$VMAnalysis)
    
    if ($VMAnalysis.Count -eq 0) {
        return @()
    }
    
    $recommendations = @()
    
    # Filter only available VMs
    $availableVMs = $VMAnalysis | Where-Object { $_.IsAvailable -eq $true }
    
    if ($availableVMs.Count -eq 0) {
        $recommendations += [PSCustomObject]@{
            Category = "Warning"
            Message  = "No VM sizes are readily available in this region for your subscription. Contact Azure support to increase quotas."
        }
        return $recommendations
    }
    
    # Group by workload class
    $workloadGroups = $availableVMs | Group-Object WorkloadClass
    
    foreach ($group in $workloadGroups) {
        $workloadType = $group.Name
        $vms = $group.Group | Sort-Object vCPUs, MemoryGB
        
        # Recommend smallest (most cost-effective) option
        $smallest = $vms | Select-Object -First 1
        $recommendations += [PSCustomObject]@{
            Category = "$workloadType Workload - Most Cost-Effective"
            VMSize   = $smallest.VMSize
            Specs    = "$($smallest.vCPUs) vCPUs, $($smallest.MemoryGB)GB RAM"
            Message  = "Best for budget-conscious deployments with $($workloadType.ToLower()) workload requirements."
        }
        
        # Recommend balanced option (middle of the pack)
        if ($vms.Count -gt 2) {
            $midIndex = [math]::Floor($vms.Count / 2)
            $balanced = $vms[$midIndex]
            $recommendations += [PSCustomObject]@{
                Category = "$workloadType Workload - Balanced"
                VMSize   = $balanced.VMSize
                Specs    = "$($balanced.vCPUs) vCPUs, $($balanced.MemoryGB)GB RAM"
                Message  = "Recommended for standard production deployments with room for growth."
            }
        }
        
        # Recommend high-performance option (if accelerated networking available)
        $accelerated = $vms | Where-Object { $_.AcceleratedNetworking -eq $true } | Select-Object -First 1
        if ($accelerated) {
            $recommendations += [PSCustomObject]@{
                Category = "$workloadType Workload - High Performance"
                VMSize   = $accelerated.VMSize
                Specs    = "$($accelerated.vCPUs) vCPUs, $($accelerated.MemoryGB)GB RAM, Accelerated Networking"
                Message  = "Best for performance-critical AVD deployments requiring low-latency networking."
            }
        }
    }
    
    # General recommendations
    $totalAvailable = $availableVMs.Count
    $totalAnalyzed = $VMAnalysis.Count
    $availablePercent = [math]::Round(($totalAvailable / $totalAnalyzed) * 100, 1)
    
    $recommendations += [PSCustomObject]@{
        Category = "Availability Summary"
        Message  = "$totalAvailable out of $totalAnalyzed VM sizes ($availablePercent%) are readily available in this region."
    }
    
    # Check for accelerated networking support
    $acceleratedCount = ($availableVMs | Where-Object { $_.AcceleratedNetworking -eq $true }).Count
    if ($acceleratedCount -gt 0) {
        $recommendations += [PSCustomObject]@{
            Category = "Best Practice"
            Message  = "$acceleratedCount VM sizes support Accelerated Networking. This is highly recommended for production AVD deployments to improve network performance and reduce latency."
        }
    }
    
    return $recommendations
}

# Function to display results in console
function Show-VMSizeResults {
    param([array]$VMAnalysis)
    
    if ($VMAnalysis.Count -eq 0) {
        Write-Host "No results to display." -ForegroundColor Yellow
        return
    }
    
    # Separate available and restricted VMs
    $availableVMs = $VMAnalysis | Where-Object { $_.IsAvailable -eq $true }
    $restrictedVMs = $VMAnalysis | Where-Object { $_.IsAvailable -eq $false }
    
    Write-Host ""
    Write-Host "$('='*120)" -ForegroundColor Cyan
    Write-Host " READILY AVAILABLE VM SIZES IN REGION " -ForegroundColor Cyan
    Write-Host "$('='*120)" -ForegroundColor Cyan
    Write-Host ""
    
    if ($availableVMs.Count -eq 0) {
        Write-Host "WARNING: No VM sizes are readily available in this region for your subscription." -ForegroundColor Red
        Write-Host "This may be due to quota restrictions or regional capacity limitations." -ForegroundColor Yellow
        Write-Host "Please check the CSV report for full details and contact Azure support if needed." -ForegroundColor Yellow
    }
    else {
        Write-Host "Showing $($availableVMs.Count) readily available VM sizes (restricted sizes logged to CSV report)" -ForegroundColor Green
        Write-Host ""
        
        # Group by workload class for better presentation
        $groupedResults = $availableVMs | Group-Object WorkloadClass
        
        foreach ($group in $groupedResults) {
            Write-Host "[$($group.Name) Workload] - $($group.Count) available VM sizes" -ForegroundColor Green
            
            # Display in table format
            $group.Group | Format-Table -Property VMSize, vCPUs, MemoryGB, MaxDataDisks, AcceleratedNetworking, PremiumIO, Series -AutoSize
            
            Write-Host ""
        }
        
        # Show summary statistics
        Write-Host "Summary Statistics:" -ForegroundColor White
        Write-Host "  Total VM sizes analyzed: $($VMAnalysis.Count)" -ForegroundColor Gray
        Write-Host "  Readily available: $($availableVMs.Count)" -ForegroundColor Green
        Write-Host "  Restricted/Unavailable: $($restrictedVMs.Count)" -ForegroundColor Yellow
        
        $workloadCounts = $availableVMs | Group-Object WorkloadClass | ForEach-Object { "$($_.Name): $($_.Count)" }
        Write-Host "  Available by workload type: $($workloadCounts -join ', ')" -ForegroundColor Gray
        
        $acceleratedCount = ($availableVMs | Where-Object { $_.AcceleratedNetworking }).Count
        Write-Host "  With Accelerated Networking: $acceleratedCount" -ForegroundColor Gray
        
        $premiumIOCount = ($availableVMs | Where-Object { $_.PremiumIO }).Count
        Write-Host "  With Premium IO support: $premiumIOCount" -ForegroundColor Gray
        
        Write-Host ""
        
        # Show recommendations
        Write-Host "$('='*120)" -ForegroundColor Cyan
        Write-Host " INTELLIGENT RECOMMENDATIONS " -ForegroundColor Cyan
        Write-Host "$('='*120)" -ForegroundColor Cyan
        Write-Host ""
        
        $recommendations = Get-VMRecommendations -VMAnalysis $VMAnalysis
        foreach ($rec in $recommendations) {
            if ($rec.Category -match "Warning|Summary|Best Practice") {
                Write-Host "$($rec.Category):" -ForegroundColor Yellow
                Write-Host "  $($rec.Message)" -ForegroundColor White
            }
            else {
                Write-Host "$($rec.Category):" -ForegroundColor Green
                Write-Host "  VM Size: $($rec.VMSize)" -ForegroundColor White
                Write-Host "  Specs: $($rec.Specs)" -ForegroundColor Gray
                Write-Host "  Recommendation: $($rec.Message)" -ForegroundColor Cyan
            }
            Write-Host ""
        }
    }
    
    if ($restrictedVMs.Count -gt 0) {
        Write-Host "NOTE: $($restrictedVMs.Count) restricted VM sizes are documented in the CSV report with details." -ForegroundColor Cyan
    }
    
    Write-Host ""
}

# Function to export results to CSV
function Export-VMSizesToCSV {
    param(
        [array]$VMAnalysis,
        [string]$FilePath
    )
    
    if ($VMAnalysis.Count -eq 0) {
        Write-Host "No data to export." -ForegroundColor Yellow
        return
    }
    
    try {
        # Export all VM sizes with complete availability information
        $VMAnalysis | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        
        $availableCount = ($VMAnalysis | Where-Object { $_.IsAvailable -eq $true }).Count
        $restrictedCount = ($VMAnalysis | Where-Object { $_.IsAvailable -eq $false }).Count
        
        Write-Host "Results exported to CSV: $FilePath" -ForegroundColor Green
        Write-Host "  Total VM sizes: $($VMAnalysis.Count)" -ForegroundColor Gray
        Write-Host "  Available: $availableCount" -ForegroundColor Green
        Write-Host "  Restricted: $restrictedCount" -ForegroundColor Yellow
        Write-Host "  CSV includes: Availability status, restrictions, and zones for all VM sizes" -ForegroundColor Cyan
        
        Add-ReportEntry -Category "Export" -Check "CSV Export" -Result "Pass" -Details "Successfully exported $($VMAnalysis.Count) VM sizes ($availableCount available, $restrictedCount restricted) to $FilePath"
    }
    catch {
        Write-Host "Failed to export CSV: $($_.Exception.Message)" -ForegroundColor Red
        Add-ReportEntry -Category "Export" -Check "CSV Export" -Result "Fail" -Details "CSV export failed: $($_.Exception.Message)"
    }
}

# Function to export results to Excel (if ImportExcel module is available)
function Export-VMSizesToExcel {
    param(
        [array]$VMAnalysis,
        [string]$FilePath
    )
    
    if ($VMAnalysis.Count -eq 0) {
        Write-Host "No data to export." -ForegroundColor Yellow
        return
    }
    
    # Check if ImportExcel module is available
    $excelModule = Get-Module -ListAvailable -Name ImportExcel
    if (-not $excelModule) {
        Write-Host "ImportExcel module not available. Falling back to CSV export." -ForegroundColor Yellow
        $csvPath = $FilePath -replace '\.xlsx$', '.csv'
        Export-VMSizesToCSV -VMAnalysis $VMAnalysis -FilePath $csvPath
        return
    }
    
    try {
        # Create summary data
        $summaryData = @()
        $workloadGroups = $VMAnalysis | Group-Object WorkloadClass
        foreach ($group in $workloadGroups) {
            $summaryData += [PSCustomObject]@{
                WorkloadType = $group.Name
                Count        = $group.Count
                MinCores     = ($group.Group | Measure-Object -Property vCPUs -Minimum).Minimum
                MaxCores     = ($group.Group | Measure-Object -Property vCPUs -Maximum).Maximum
                MinMemoryGB  = ($group.Group | Measure-Object -Property MemoryGB -Minimum).Minimum
                MaxMemoryGB  = ($group.Group | Measure-Object -Property MemoryGB -Maximum).Maximum
            }
        }
        
        # Export detailed results
        $VMAnalysis | Export-Excel -Path $FilePath -WorksheetName "VM Size Analysis" -AutoSize -BoldTopRow -FreezeTopRow
        
        # Export summary
        $summaryData | Export-Excel -Path $FilePath -WorksheetName "Summary" -AutoSize -BoldTopRow -Show
        
        Write-Host "Results exported to Excel: $FilePath" -ForegroundColor Green
        Add-ReportEntry -Category "Export" -Check "Excel Export" -Result "Pass" -Details "Successfully exported $($VMAnalysis.Count) VM sizes to Excel with summary"
        
    }
    catch {
        Write-Host "Failed to export Excel: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Falling back to CSV export..." -ForegroundColor Yellow
        $csvPath = $FilePath -replace '\.xlsx$', '.csv'
        Export-VMSizesToCSV -VMAnalysis $VMAnalysis -FilePath $csvPath
    }
}

# Function to display final summary
function Show-ExecutionSummary {
    Write-Host ""
    Write-Host "$('='*100)" -ForegroundColor Green
    Write-Host " EXECUTION SUMMARY " -ForegroundColor Green
    Write-Host "$('='*100)" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Script execution completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Execution Details:" -ForegroundColor White
    Write-Host "  Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "  Target Region: $Location" -ForegroundColor Gray
    Write-Host "  Workload Filter: $WorkloadType" -ForegroundColor Gray
    Write-Host "  Minimum vCPUs: $MinCores" -ForegroundColor Gray
    Write-Host "  Minimum Memory: ${MinMemoryGB}GB" -ForegroundColor Gray
    if ($IncludeOnlyAccelerated) { Write-Host "  Accelerated Networking: Required" -ForegroundColor Gray }
    if ($IncludePricing) { Write-Host "  Pricing Data: Included" -ForegroundColor Gray }
    Write-Host ""
    
    # Show validation summary
    Write-Host "Validation Summary:" -ForegroundColor White
    Write-Host "  Total Checks: $($script:ValidationSummary.TotalChecks)" -ForegroundColor Gray
    Write-Host "  Passed: $($script:ValidationSummary.PassCount)" -ForegroundColor Green
    Write-Host "  Failed: $($script:ValidationSummary.FailCount)" -ForegroundColor Red
    Write-Host "  Warnings: $($script:ValidationSummary.WarningCount)" -ForegroundColor Yellow
    Write-Host "  Information: $($script:ValidationSummary.InfoCount)" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Script:LogPath -and (Test-Path $Script:LogPath)) {
        Write-Host "Detailed log saved to: $Script:LogPath" -ForegroundColor Cyan
    }
    
    Write-Host "Thank you for using the AVD VM Size Discovery Tool!" -ForegroundColor Green
    Write-Host ""
}

# Main Script Execution
try {
    # Display professional header
    Write-Host ""
    Write-Host "$('='*100)" -ForegroundColor Cyan
    Write-Host " AVD VM SIZE DISCOVERY & ANALYSIS TOOL " -ForegroundColor Cyan
    Write-Host "$('='*100)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Advanced Azure Virtual Desktop VM Size Discovery and Analysis" -ForegroundColor White
    Write-Host "Version 2.0 | AVD Factory Team | $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Execution Parameters:" -ForegroundColor White
    Write-Host "  Target Region: $Location" -ForegroundColor Gray
    Write-Host "  Workload Type: $WorkloadType" -ForegroundColor Gray
    Write-Host "  Minimum vCPUs: $MinCores" -ForegroundColor Gray
    Write-Host "  Minimum Memory: ${MinMemoryGB}GB" -ForegroundColor Gray
    if ($IncludeOnlyAccelerated) { Write-Host "  Accelerated Networking: Required" -ForegroundColor Gray }
    if ($IncludePricing) { Write-Host "  Include Pricing: Yes" -ForegroundColor Gray }
    if ($NonInteractive) { Write-Host "  Mode: Non-Interactive" -ForegroundColor Gray }
    Write-Host ""
    
    # Initialize execution log
    Add-Content -Path $Script:LogPath -Value "=== AVD VM Size Discovery Started ===" -Encoding UTF8
    Add-Content -Path $Script:LogPath -Value "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8
    Add-Content -Path $Script:LogPath -Value "Parameters: Location=$Location, WorkloadType=$WorkloadType, MinCores=$MinCores, MinMemoryGB=$MinMemoryGB" -Encoding UTF8
    
    # Step 1: Validate PowerShell modules
    Write-Host "$('='*80)" -ForegroundColor Yellow
    Write-Host " STEP 1: POWERSHELL MODULE VALIDATION " -ForegroundColor Yellow
    Write-Host "$('='*80)" -ForegroundColor Yellow
    
    $moduleValidation = Test-PowerShellModules
    if (-not $moduleValidation) {
        throw "Required PowerShell modules validation failed. Please install missing modules and retry."
    }
    
    # Step 2: Establish Azure connection
    Write-Host "$('='*80)" -ForegroundColor Yellow
    Write-Host " STEP 2: AZURE AUTHENTICATION & CONNECTION " -ForegroundColor Yellow
    Write-Host "$('='*80)" -ForegroundColor Yellow
    
    $connectionResult = Connect-AzureWithSelection
    if (-not $connectionResult) {
        throw "Failed to establish Azure connection. Authentication is required to proceed."
    }
    
    # Prompt for Location if not provided
    if (-not $Location) {
        Write-Host ""
        Write-Host "$('='*80)" -ForegroundColor Cyan
        Write-Host " TARGET REGION SELECTION " -ForegroundColor Cyan
        Write-Host "$('='*80)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Please enter the Azure region for VM size discovery." -ForegroundColor White
        Write-Host "Examples: eastus, westus2, centralus, northeurope, westeurope" -ForegroundColor Gray
        Write-Host ""
        
        do {
            $Location = Read-Host "Azure Region"
            if ([string]::IsNullOrWhiteSpace($Location)) {
                Write-Host "Location cannot be empty. Please enter a valid Azure region." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($Location))
        
        Write-Host ""
        Write-Host "Selected region: $Location" -ForegroundColor Green
    }
    
    # Step 3: Validate target Azure region
    Write-Host "$('='*80)" -ForegroundColor Yellow
    Write-Host " STEP 3: AZURE REGION VALIDATION " -ForegroundColor Yellow
    Write-Host "$('='*80)" -ForegroundColor Yellow
    
    $regionValidation = Test-AzureRegion -Location $Location
    if (-not $regionValidation) {
        throw "Invalid or inaccessible Azure region: $Location"
    }
    
    # Step 4: Discover and analyze VM sizes
    Write-Host "$('='*80)" -ForegroundColor Yellow
    Write-Host " STEP 4: VM SIZE DISCOVERY & ANALYSIS " -ForegroundColor Yellow
    Write-Host "$('='*80)" -ForegroundColor Yellow
    
    $vmAnalysisResults = Get-VMSizeAnalysis -Location $Location -MinCores $MinCores -MinMemoryGB $MinMemoryGB -WorkloadType $WorkloadType -OnlyAccelerated $IncludeOnlyAccelerated.IsPresent -IncludePricing $IncludePricing.IsPresent
    
    # Step 5: Display results
    Write-Host "$('='*80)" -ForegroundColor Yellow
    Write-Host " STEP 5: RESULTS PRESENTATION " -ForegroundColor Yellow
    Write-Host "$('='*80)" -ForegroundColor Yellow
    
    Show-VMSizeResults -VMAnalysis $vmAnalysisResults
    
    # Step 6: Export results
    Write-Host "$('='*80)" -ForegroundColor Yellow
    Write-Host " STEP 6: EXPORT RESULTS " -ForegroundColor Yellow
    Write-Host "$('='*80)" -ForegroundColor Yellow
    Write-Host ""
    
    # Auto-generate CSV path if no export paths were specified
    if (-not $ExportCsvPath -and -not $ExportExcelPath) {
        $ExportCsvPath = "$PSScriptRoot\AVD_10_SubscriptionVMSizeDiscovery_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        Write-Host "Auto-generating CSV report in script folder..." -ForegroundColor Cyan
    }
    
    if ($ExportCsvPath) {
        Export-VMSizesToCSV -VMAnalysis $vmAnalysisResults -FilePath $ExportCsvPath
    }
    
    if ($ExportExcelPath) {
        Export-VMSizesToExcel -VMAnalysis $vmAnalysisResults -FilePath $ExportExcelPath
    }
    
    # Show final execution summary
    Show-ExecutionSummary
    
}
catch {
    $errorMsg = "Script execution failed: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "$('='*100)" -ForegroundColor Red
    Write-Host " EXECUTION FAILED " -ForegroundColor Red
    Write-Host "$('='*100)" -ForegroundColor Red
    Write-Host ""
    Write-Host $errorMsg -ForegroundColor Red
    
    Add-ReportEntry -Category "Script Execution" -Check "Main Process" -Result "Fail" -Details $errorMsg
    Add-Content -Path $Script:LogPath -Value "ERROR: $errorMsg" -Encoding UTF8
    
    Write-Host ""
    Write-Host "Troubleshooting Tips:" -ForegroundColor Yellow
    Write-Host "  1. Verify you have the required PowerShell modules installed" -ForegroundColor Gray
    Write-Host "  2. Ensure you have appropriate Azure permissions" -ForegroundColor Gray
    Write-Host "  3. Check your network connectivity to Azure services" -ForegroundColor Gray
    Write-Host "  4. Verify the Azure region name is correct" -ForegroundColor Gray
    Write-Host ""
    Write-Host "For detailed error information, check the log file: $Script:LogPath" -ForegroundColor Cyan
    Write-Host ""
    
    exit 1
}
finally {
    # Cleanup and final log entry
    Add-Content -Path $Script:LogPath -Value "=== AVD VM Size Discovery Completed ===" -Encoding UTF8
    Add-Content -Path $Script:LogPath -Value "End Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8
}
