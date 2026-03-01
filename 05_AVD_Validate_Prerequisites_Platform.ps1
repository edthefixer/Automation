<#
.SYNOPSIS
    Comprehensive Azure Virtual Desktop (AVD) Prerequisites Confirmation Script for Pre-Deployment and Post-Deployment Readiness Assessment
    
    NOTE: AVD ACCELERATOR-SPECIFIC VALIDATION
    This script validates that every element required for the AVD Accelerator to run without failures exists and is properly configured.
    It performs deployment-specific readiness checks for the AVD Accelerator solution (https://github.com/Azure/avd-accelerator).
    For generic platform-level AVD prerequisites validation (independent of deployment method), use 03_AVD_Check_Prerequisites_Platform.ps1.
    
    Performs automated deep-dive confirmation of Azure environment infrastructure, security configurations, networking topology, 
    RBAC permissions, resource providers, storage capabilities, image management, and compliance settings to ensure successful 
    AVD Accelerator deployment with enterprise-grade reliability and optimal performance.

.DESCRIPTION
    Comprehensive confirmation script that checks all prerequisites required to run the AVD Accelerator.
    Validates Azure subscription, permissions, resource providers, network connectivity, and configuration requirements.
    
    This script performs deep validation of your Azure environment to ensure readiness for AVD deployment, including:
    - PowerShell module availability and versions
    - Azure authentication and subscription access
    - Resource provider registration status
    - Network topology analysis (including hub-and-spoke detection via UDR inspection)
    - Storage configuration for FSLogix profiles
    - Image management capabilities
    - RBAC permissions and security compliance
    
    OUTPUT: Excel workbook with color-coded validation results:
    - Summary worksheet with overall statistics
    - Detailed Results worksheet with color-coded rows (green=pass, red=fail, yellow=warning, blue=info)
    - Top 5 priority actions displayed at completion with exact remediation commands

.PARAMETER Environment
    Environment type for deployment (Development, Testing, Production)

.PARAMETER TenantId
    Azure Tenant ID or Domain Name to connect to. If not specified, user will be prompted to select from available tenants.

.PARAMETER SubscriptionId
    Azure Subscription ID to use for validation. If not specified, user will be prompted to select from available subscriptions.

.PARAMETER SkipNetworkValidation
    Skip network configuration validation

.PARAMETER SkipStorageValidation
    Skip storage configuration validation

.PARAMETER SkipImageValidation
    Skip image management validation

.PARAMETER NonInteractive
    Run in non-interactive mode (uses current Azure context or fails if not authenticated)

.PARAMETER ReportPath
    Custom report output path

.PARAMETER UseCSVExport
    Export report as CSV instead of Excel

.EXAMPLE
    .\05_AVD_Validate_Prerequisites_Platform.ps1

.EXAMPLE
    .\05_AVD_Validate_Prerequisites_Platform.ps1 -Environment "Production" -ReportPath "C:\Reports"

.EXAMPLE
    .\05_AVD_Validate_Prerequisites_Platform.ps1 -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"

.EXAMPLE
    .\05_AVD_Validate_Prerequisites_Platform.ps1 -NonInteractive

.EXAMPLE
    .\05_AVD_Validate_Prerequisites_Platform.ps1 -TenantId "your-tenant-id" -NonInteractive
    
    Use with service principal authentication in automated scenarios

.NOTES
    Version: 1.0
    Author: edthefixer + GitHub Copilot... well, I fell asleep, copilot finished it...
    Last Updated: November 20, 2025
    
    PREREQUISITES:
    - PowerShell 5.1 or later
    - Azure PowerShell modules (Az.Accounts, Az.Resources, Az.Network, Az.Compute, Az.Storage, 
      Az.KeyVault, Az.Security, Az.Monitor, Az.OperationalInsights, Az.ImageBuilder, 
      Az.DesktopVirtualization, ImportExcel)
    - Azure subscription with at least Reader permissions
    
    EXECUTION (Script is not signed):
    powershell -ExecutionPolicy Bypass -File "<path>\05_AVD_Validate_Prerequisites_Platform.ps1"
    
    OUTPUT FORMAT:
    - Excel workbook: 05_AVD_Validate_Prerequisites_Platform_YYYYMMDD_HHmmss.xlsx
    - Worksheet 1: Summary (overall statistics)
    - Worksheet 2: Detailed Results (color-coded: green=pass, red=fail, yellow=warning, blue=info)
    
    VALIDATION CHECKS:
    1. Azure PowerShell modules installation and import
    2. Authentication and subscription access (multiple login options supported)
    3. Required resource providers registration
    4. Network connectivity to AVD endpoints
    5. Virtual network and subnet configuration
    6. Hub-and-Spoke topology detection (via User-Defined Routes analysis)
    7. Storage account requirements and Azure Files enablement
    8. Image management capabilities (Azure Compute Gallery, Image Builder)
    9. RBAC permissions and role assignments
    10. Security and compliance settings (Key Vault, Security Center)
    
    NETWORK TOPOLOGY DETECTION:
    The script detects hub-and-spoke topology by analyzing User-Defined Routes (UDRs) 
    for default routes (0.0.0.0/0) pointing to Virtual Appliances or Virtual Network Gateways.
    This is more accurate than simple peering counts, as it identifies centralized routing 
    through firewalls or Network Virtual Appliances (NVAs).
    
    Authentication Methods Supported:
    1. Interactive Browser Login (Default)
    2. Device Code Authentication
    3. Service Principal with Client Secret
    4. Service Principal with Certificate
    5. Managed Identity

.LINK
    https://github.com/Azure/avd-accelerator
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Environment type for deployment")]
    [ValidateSet("Development", "Testing", "Production")]
    [string]$Environment = "Production",
    
    [Parameter(HelpMessage = "Azure Tenant ID or Domain Name")]
    [string]$TenantId,
    
    [Parameter(HelpMessage = "Azure Subscription ID")]
    [string]$SubscriptionId,
    
    [Parameter(HelpMessage = "Skip network configuration validation")]
    [switch]$SkipNetworkValidation,
    
    [Parameter(HelpMessage = "Skip storage configuration validation")]
    [switch]$SkipStorageValidation,
    
    [Parameter(HelpMessage = "Skip image management validation")]
    [switch]$SkipImageValidation,
    
    [Parameter(HelpMessage = "Run in non-interactive mode")]
    [switch]$NonInteractive,
    
    [Parameter(HelpMessage = "Custom report output path")]
    [string]$ReportPath,
    
    [Parameter(HelpMessage = "Export report as CSV instead of Excel")]
    [switch]$UseCSVExport
)

# Global variables
$script:Report = @()
$script:ValidationSummary = @{
    TotalChecks  = 0
    PassCount    = 0
    FailCount    = 0
    WarningCount = 0
    InfoCount    = 0
}

# Required Azure PowerShell modules
$RequiredModules = @(
    "Az.Accounts",
    "Az.Resources", 
    "Az.Network",
    "Az.Compute",
    "Az.Storage",
    "Az.KeyVault",
    "Az.Security",
    "Az.Monitor",
    "Az.OperationalInsights",
    "Az.ImageBuilder",
    "Az.DesktopVirtualization",
    "ImportExcel"
)

# Required Azure Resource Providers
$RequiredResourceProviders = @(
    "Microsoft.Compute",
    "Microsoft.Network", 
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.DesktopVirtualization",
    "Microsoft.Security",
    "Microsoft.Monitor",
    "Microsoft.OperationalInsights",
    "Microsoft.Authorization",
    "Microsoft.Resources",
    "Microsoft.ManagedIdentity"
)

# Function to add entries to the report
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
    
    # Display real-time results
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
}

# Function to validate PowerShell modules
function Test-PowerShellModules {
    Write-Host "Validating PowerShell Modules..." -ForegroundColor Cyan
    
    foreach ($module in $RequiredModules) {
        try {
            $installedModule = Get-Module -Name $module -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            
            if ($installedModule) {
                # Check if module is imported
                $importedModule = Get-Module -Name $module
                if (-not $importedModule) {
                    try {
                        # Suppress verbose warnings during import
                        Import-Module $module -Force -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false | Out-Null
                        Add-ReportEntry -Category "PowerShell Modules" -Check "$module Import" -Result "Pass" -Details "Module already imported (Version: $($installedModule.Version))"
                    }
                    catch {
                        Add-ReportEntry -Category "PowerShell Modules" -Check "$module Import" -Result "Fail" -Details "Failed to import module: $($_.Exception.Message)" -Recommendation "Try: Install-Module $module -Force -AllowClobber"
                    }
                }
                else {
                    Add-ReportEntry -Category "PowerShell Modules" -Check "$module Import" -Result "Pass" -Details "Module already imported (Version: $($importedModule.Version))"
                }
            }
            else {
                Add-ReportEntry -Category "PowerShell Modules" -Check "$module Installation" -Result "Fail" -Details "Module not installed" -Recommendation "Install with: Install-Module $module -Force -AllowClobber"
            }
        }
        catch {
            Add-ReportEntry -Category "PowerShell Modules" -Check "$module Validation" -Result "Fail" -Details "Error checking module: $($_.Exception.Message)" -Recommendation "Reinstall module: Install-Module $module -Force -AllowClobber"
        }
    }
}

# Function to validate Azure authentication and subscription access
# Function to select tenant interactively
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

# Function to select subscription interactively
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

# Function to establish Azure connection with tenant/subscription selection
function Connect-AzureWithSelection {
    Write-Host ""
    Write-Host "$('='*80)" -ForegroundColor White
    Write-Host " AZURE AUTHENTICATION " -ForegroundColor White
    Write-Host "$('='*80)" -ForegroundColor White
    Write-Host ""
    
    try {
        # Check if already connected
        $currentContext = Get-AzContext
        
        if ($currentContext -and -not $TenantId -and -not $SubscriptionId) {
            Write-Host "Current Azure Context:" -ForegroundColor Yellow
            Write-Host "  Account: $($currentContext.Account.Id)" -ForegroundColor White
            Write-Host "  Tenant: $($currentContext.Tenant.Id)" -ForegroundColor White
            Write-Host "  Subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))" -ForegroundColor White
            Write-Host ""
            
            if (-not $NonInteractive) {
                $useExisting = Read-Host "Use existing connection? (Y/n)"
                if ($useExisting -eq "" -or $useExisting -eq "Y" -or $useExisting -eq "y") {
                    Write-Host "Using existing Azure connection." -ForegroundColor Green
                    return $true
                }
            }
            else {
                Write-Host "Non-interactive mode: Using existing Azure connection." -ForegroundColor Green
                return $true
            }
        }
        
        # Select authentication method
        $authMethod = Select-AuthenticationMethod
        
        # Perform authentication using selected method
        $authResult = Invoke-AzureAuthentication -AuthMethod $authMethod -TenantId $TenantId
        
        if (-not $authResult) {
            throw "Failed to authenticate with Azure"
        }
        
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
        
        return $true
        
    }
    catch {
        Write-Host "Failed to establish Azure connection: $($_.Exception.Message)" -ForegroundColor Red
        
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

# Function to connect to Azure with authentication method selection
function Connect-AzureWithSelection {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor White
    Write-Host " AZURE AUTHENTICATION " -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor White
    Write-Host ""
    
    try {
        # Check if already connected and skip if non-interactive
        $currentContext = Get-AzContext
        if ($currentContext -and $NonInteractive) {
            Write-Host "Using existing Azure context (Non-Interactive mode):" -ForegroundColor Green
            Write-Host "  Account: $($currentContext.Account.Id)" -ForegroundColor White
            Write-Host "  Tenant: $($currentContext.Tenant.Id)" -ForegroundColor White
            Write-Host "  Subscription: $($currentContext.Subscription.Name)" -ForegroundColor White
            Write-Host ""
            return $true
        }
        
        # Select authentication method
        $authMethod = Select-AuthenticationMethod
        
        # Perform authentication
        $authResult = Invoke-AzureAuthentication -AuthMethod $authMethod -TenantId $TenantId
        
        if (-not $authResult) {
            throw "Failed to authenticate with Azure"
        }
        
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
        
        return $true
        
    }
    catch {
        Write-Host "Failed to establish Azure connection: $($_.Exception.Message)" -ForegroundColor Red
        
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

function Test-AzureAuthentication {
    Write-Host "Validating Azure Authentication..." -ForegroundColor Yellow
    
    try {
        $context = Get-AzContext
        
        if (-not $context) {
            Add-ReportEntry -Category "Azure Authentication" -Check "Azure Login" -Result "Fail" -Details "Not logged into Azure" -Recommendation "Run: Connect-AzAccount"
            return $false
        }
        
        Add-ReportEntry -Category "Azure Authentication" -Check "Azure Login" -Result "Pass" -Details "Logged in as: $($context.Account.Id) | Subscription: $($context.Subscription.Name)"
        
        # Test subscription access
        try {
            $subscription = Get-AzSubscription -SubscriptionId $context.Subscription.Id
            Add-ReportEntry -Category "Azure Authentication" -Check "Subscription Access" -Result "Pass" -Details "Access confirmed to subscription: $($subscription.Name) ($($subscription.Id))"
            
            # Check subscription state
            if ($subscription.State -eq "Enabled") {
                Add-ReportEntry -Category "Azure Authentication" -Check "Subscription State" -Result "Pass" -Details "Subscription is enabled and active"
            }
            else {
                Add-ReportEntry -Category "Azure Authentication" -Check "Subscription State" -Result "Fail" -Details "Subscription state: $($subscription.State)" -Recommendation "Contact subscription administrator"
            }
        }
        catch {
            Add-ReportEntry -Category "Azure Authentication" -Check "Subscription Access" -Result "Fail" -Details "Cannot access subscription: $($_.Exception.Message)" -Recommendation "Verify subscription permissions"
            return $false
        }
        
        return $true
    }
    catch {
        Add-ReportEntry -Category "Azure Authentication" -Check "Authentication Test" -Result "Fail" -Details "Authentication error: $($_.Exception.Message)" -Recommendation "Run: Connect-AzAccount"
        return $false
    }
}

# Function to validate Azure Resource Providers
function Test-AzureResourceProviders {
    Write-Host "Validating Azure Resource Providers..." -ForegroundColor Yellow
    
    try {
        $allProviders = Get-AzResourceProvider
        
        foreach ($provider in $RequiredResourceProviders) {
            $providerInfo = $allProviders | Where-Object { $_.ProviderNamespace -eq $provider }
            
            if ($providerInfo) {
                if ($providerInfo.RegistrationState -eq "Registered") {
                    Add-ReportEntry -Category "Resource Providers" -Check "$provider Registration" -Result "Pass" -Details "Provider is registered and available"
                }
                elseif ($providerInfo.RegistrationState -eq "Registering") {
                    Add-ReportEntry -Category "Resource Providers" -Check "$provider Registration" -Result "Warning" -Details "Provider is currently registering" -Recommendation "Wait for registration to complete"
                }
                else {
                    Add-ReportEntry -Category "Resource Providers" -Check "$provider Registration" -Result "Fail" -Details "Provider not registered (State: $($providerInfo.RegistrationState))" -Recommendation "Register with: Register-AzResourceProvider -ProviderNamespace $provider"
                }
            }
            else {
                Add-ReportEntry -Category "Resource Providers" -Check "$provider Availability" -Result "Fail" -Details "Provider not found in subscription" -Recommendation "Verify provider name and subscription access"
            }
        }
    }
    catch {
        Add-ReportEntry -Category "Resource Providers" -Check "Provider Enumeration" -Result "Fail" -Details "Failed to get resource providers: $($_.Exception.Message)" -Recommendation "Check subscription permissions"
    }
}

# Function to validate network connectivity and configuration
function Test-NetworkConfiguration {
    if ($SkipNetworkValidation) {
        Add-ReportEntry -Category "Network Validation" -Check "Network Tests" -Result "Info" -Details "Network validation skipped by user request"
        return
    }
    
    Write-Host "Validating Network Configuration..." -ForegroundColor Yellow
    
    # Test Azure connectivity
    $azureEndpoints = @(
        "management.azure.com",
        "login.microsoftonline.com", 
        "graph.microsoft.com"
    )
    
    foreach ($endpoint in $azureEndpoints) {
        try {
            $result = Test-NetConnection -ComputerName $endpoint -Port 443 -InformationLevel Quiet
            if ($result) {
                Add-ReportEntry -Category "Network Connectivity" -Check "$endpoint Connectivity" -Result "Pass" -Details "HTTPS connectivity successful"
            }
            else {
                Add-ReportEntry -Category "Network Connectivity" -Check "$endpoint Connectivity" -Result "Fail" -Details "Cannot reach endpoint on port 443" -Recommendation "Check firewall and proxy settings"
            }
        }
        catch {
            Add-ReportEntry -Category "Network Connectivity" -Check "$endpoint Connectivity" -Result "Fail" -Details "Connection test failed: $($_.Exception.Message)" -Recommendation "Verify network configuration"
        }
    }
    
    # Check available virtual networks
    try {
        $vnets = Get-AzVirtualNetwork
        if ($vnets) {
            Add-ReportEntry -Category "Network Resources" -Check "Virtual Networks" -Result "Pass" -Details "Found $($vnets.Count) virtual network(s) in subscription"
            
            foreach ($vnet in $vnets) {
                $subnets = $vnet.Subnets
                if ($subnets.Count -gt 0) {
                    Add-ReportEntry -Category "Network Resources" -Check "VNet Subnets ($($vnet.Name))" -Result "Pass" -Details "VNet has $($subnets.Count) subnet(s) configured"
                    
                    # Check for Hub-and-Spoke topology by examining UDRs for default route to NVA/Firewall
                    $hubSpokeDetected = $false
                    foreach ($subnet in $subnets) {
                        if ($subnet.RouteTable) {
                            try {
                                $routeTableId = $subnet.RouteTable.Id
                                $routeTableName = $routeTableId.Split('/')[-1]
                                $routeTableRG = $routeTableId.Split('/')[4]
                                
                                $routeTable = Get-AzRouteTable -ResourceGroupName $routeTableRG -Name $routeTableName -ErrorAction SilentlyContinue
                                if ($routeTable) {
                                    # Check for default route (0.0.0.0/0) pointing to Virtual Appliance
                                    $defaultRoute = $routeTable.Routes | Where-Object { 
                                        $_.AddressPrefix -eq "0.0.0.0/0" -and 
                                        $_.NextHopType -in @("VirtualAppliance", "VirtualNetworkGateway")
                                    }
                                    
                                    if ($defaultRoute) {
                                        $hubSpokeDetected = $true
                                        $nextHopType = $defaultRoute.NextHopType
                                        $nextHopIp = if ($defaultRoute.NextHopIpAddress) { $defaultRoute.NextHopIpAddress } else { "N/A" }
                                        Add-ReportEntry -Category "Network Topology" -Check "Hub-and-Spoke Detection ($($subnet.Name))" -Result "Pass" -Details "Hub-and-Spoke topology detected: Default route (0.0.0.0/0) to $nextHopType ($nextHopIp) found in subnet '$($subnet.Name)'"
                                        break
                                    }
                                }
                            }
                            catch {
                                Add-ReportEntry -Category "Network Topology" -Check "Route Table Analysis ($($subnet.Name))" -Result "Warning" -Details "Failed to analyze route table: $($_.Exception.Message)"
                            }
                        }
                    }
                    
                    if (-not $hubSpokeDetected) {
                        Add-ReportEntry -Category "Network Topology" -Check "Hub-and-Spoke Detection ($($vnet.Name))" -Result "Info" -Details "No hub-and-spoke topology detected. VNet may be using direct internet egress or peering without centralized routing." -Recommendation "For enterprise deployments, consider implementing hub-and-spoke with centralized firewall/NVA"
                    }
                }
                else {
                    Add-ReportEntry -Category "Network Resources" -Check "VNet Subnets ($($vnet.Name))" -Result "Warning" -Details "VNet has no subnets configured" -Recommendation "Create subnets for AVD deployment"
                }
            }
        }
        else {
            Add-ReportEntry -Category "Network Resources" -Check "Virtual Networks" -Result "Warning" -Details "No virtual networks found in subscription" -Recommendation "Create virtual networks for AVD deployment"
        }
    }
    catch {
        Add-ReportEntry -Category "Network Resources" -Check "Virtual Networks" -Result "Fail" -Details "Failed to enumerate virtual networks: $($_.Exception.Message)" -Recommendation "Check network read permissions"
    }
}

# Function to validate storage configuration
function Test-StorageConfiguration {
    if ($SkipStorageValidation) {
        Add-ReportEntry -Category "Storage Validation" -Check "Storage Tests" -Result "Info" -Details "Storage validation skipped by user request"
        return
    }
    
    Write-Host "Validating Storage Configuration..." -ForegroundColor Yellow
    
    try {
        $storageAccounts = Get-AzStorageAccount
        
        if ($storageAccounts) {
            Add-ReportEntry -Category "Storage Resources" -Check "Storage Accounts" -Result "Pass" -Details "Found $($storageAccounts.Count) storage account(s) in subscription"
            
            foreach ($account in $storageAccounts) {
                # Check account type and tier
                if ($account.Sku.Name -in @("Premium_LRS", "Premium_ZRS")) {
                    Add-ReportEntry -Category "Storage Configuration" -Check "Premium Storage ($($account.StorageAccountName))" -Result "Pass" -Details "Premium storage tier available for high-performance workloads"
                }
                else {
                    Add-ReportEntry -Category "Storage Configuration" -Check "Storage Tier ($($account.StorageAccountName))" -Result "Info" -Details "Standard storage tier: $($account.Sku.Name)"
                }
                
                # Check for file services (needed for FSLogix)
                try {
                    $fileService = Get-AzStorageFileServiceProperty -ResourceGroupName $account.ResourceGroupName -StorageAccountName $account.StorageAccountName -ErrorAction SilentlyContinue
                    if ($fileService) {
                        Add-ReportEntry -Category "Storage Configuration" -Check "File Services ($($account.StorageAccountName))" -Result "Pass" -Details "Azure Files enabled"
                    }
                }
                catch {
                    Add-ReportEntry -Category "Storage Configuration" -Check "File Services ($($account.StorageAccountName))" -Result "Warning" -Details "Cannot verify file services: $($_.Exception.Message)"
                }
            }
        }
        else {
            Add-ReportEntry -Category "Storage Resources" -Check "Storage Accounts" -Result "Warning" -Details "No storage accounts found in subscription" -Recommendation "Create storage accounts for AVD profiles and data"
        }
    }
    catch {
        Add-ReportEntry -Category "Storage Resources" -Check "Storage Enumeration" -Result "Fail" -Details "Failed to enumerate storage accounts: $($_.Exception.Message)" -Recommendation "Check storage read permissions"
    }
}

# Function to validate image management capabilities
function Test-ImageManagement {
    if ($SkipImageValidation) {
        Add-ReportEntry -Category "Image Validation" -Check "Image Tests" -Result "Info" -Details "Image validation skipped by user request"
        return
    }
    
    Write-Host "Validating Image Management..." -ForegroundColor Yellow
    
    # Check for Azure Compute Gallery (formerly Shared Image Gallery)
    try {
        $galleries = Get-AzGallery
        
        if ($galleries) {
            Add-ReportEntry -Category "Image Management" -Check "Azure Compute Galleries" -Result "Pass" -Details "Found $($galleries.Count) Azure Compute Gallery(s)"
            
            foreach ($gallery in $galleries) {
                try {
                    $images = Get-AzGalleryImageDefinition -ResourceGroupName $gallery.ResourceGroupName -GalleryName $gallery.Name
                    if ($images) {
                        Add-ReportEntry -Category "Image Management" -Check "Gallery Images ($($gallery.Name))" -Result "Pass" -Details "Found $($images.Count) image definition(s)"
                    }
                    else {
                        Add-ReportEntry -Category "Image Management" -Check "Gallery Images ($($gallery.Name))" -Result "Info" -Details "No image definitions found in gallery"
                    }
                }
                catch {
                    Add-ReportEntry -Category "Image Management" -Check "Gallery Images ($($gallery.Name))" -Result "Warning" -Details "Cannot enumerate images: $($_.Exception.Message)"
                }
            }
        }
        else {
            Add-ReportEntry -Category "Image Management" -Check "Azure Compute Galleries" -Result "Info" -Details "No Azure Compute Galleries found" -Recommendation "Consider creating galleries for custom images"
        }
    }
    catch {
        Add-ReportEntry -Category "Image Management" -Check "Gallery Enumeration" -Result "Fail" -Details "Failed to enumerate galleries: $($_.Exception.Message)" -Recommendation "Check compute read permissions"
    }
    
    # Check VM images available in the region
    try {
        $context = Get-AzContext
        if ($context -and $context.Subscription) {
            $location = "East US"  # Default location, should be parameterized in production
            
            # Check for Windows 11 images (common for AVD)
            $win11Images = Get-AzVMImagePublisher -Location $location | Where-Object { $_.PublisherName -eq "MicrosoftWindowsDesktop" }
            
            if ($win11Images) {
                Add-ReportEntry -Category "Image Management" -Check "Windows Desktop Images" -Result "Pass" -Details "Windows Desktop images available in $location"
            }
            else {
                Add-ReportEntry -Category "Image Management" -Check "Windows Desktop Images" -Result "Warning" -Details "Cannot find Windows Desktop images in $location" -Recommendation "Verify region selection"
            }
        }
    }
    catch {
        Add-ReportEntry -Category "Image Management" -Check "VM Images" -Result "Warning" -Details "Cannot enumerate VM images: $($_.Exception.Message)"
    }
}

# Function to validate RBAC permissions
function Test-RBACPermissions {
    Write-Host "Validating RBAC Permissions..." -ForegroundColor Yellow
    
    try {
        $context = Get-AzContext
        $currentUser = $context.Account.Id
        
        # Get current user's role assignments
        $roleAssignments = Get-AzRoleAssignment -SignInName $currentUser -ErrorAction SilentlyContinue
        
        if ($roleAssignments) {
            Add-ReportEntry -Category "RBAC Permissions" -Check "Role Assignments" -Result "Pass" -Details "Found $($roleAssignments.Count) role assignment(s) for current user"
            
            # Check for key roles needed for AVD
            $requiredRoles = @(
                "Owner", 
                "Contributor", 
                "Desktop Virtualization Contributor",
                "Virtual Machine Contributor",
                "Network Contributor"
            )
            
            $assignedRoles = $roleAssignments.RoleDefinitionName
            
            foreach ($role in $requiredRoles) {
                if ($assignedRoles -contains $role) {
                    Add-ReportEntry -Category "RBAC Permissions" -Check "$role Role" -Result "Pass" -Details "User has $role permissions"
                }
                else {
                    $hasContributorOrOwner = ($assignedRoles -contains "Owner") -or ($assignedRoles -contains "Contributor")
                    if ($hasContributorOrOwner -and $role -in @("Desktop Virtualization Contributor", "Virtual Machine Contributor", "Network Contributor")) {
                        Add-ReportEntry -Category "RBAC Permissions" -Check "$role Role" -Result "Pass" -Details "Covered by Owner/Contributor role"
                    }
                    else {
                        Add-ReportEntry -Category "RBAC Permissions" -Check "$role Role" -Result "Warning" -Details "Missing $role role" -Recommendation "Assign $role role or higher permissions"
                    }
                }
            }
        }
        else {
            Add-ReportEntry -Category "RBAC Permissions" -Check "Role Assignments" -Result "Fail" -Details "No role assignments found for current user" -Recommendation "Assign appropriate RBAC roles"
        }
    }
    catch {
        Add-ReportEntry -Category "RBAC Permissions" -Check "Permission Check" -Result "Fail" -Details "Failed to check permissions: $($_.Exception.Message)" -Recommendation "Verify user account and subscription access"
    }
}

# Function to validate compliance and security settings
function Test-ComplianceAndSecurity {
    Write-Host "Validating Compliance and Security..." -ForegroundColor Yellow
    
    # Check Azure Policy assignments
    try {
        $policyAssignments = Get-AzPolicyAssignment
        
        if ($policyAssignments) {
            Add-ReportEntry -Category "Compliance" -Check "Azure Policy" -Result "Pass" -Details "Found $($policyAssignments.Count) policy assignment(s)"
            
            # Check for common security policies
            $securityPolicies = $policyAssignments | Where-Object { 
                $_.Properties.DisplayName -like "*security*" -or 
                $_.Properties.DisplayName -like "*compliance*" -or
                $_.Properties.DisplayName -like "*CIS*"
            }
            
            if ($securityPolicies) {
                Add-ReportEntry -Category "Compliance" -Check "Security Policies" -Result "Pass" -Details "Found $($securityPolicies.Count) security-related policy assignment(s)"
            }
            else {
                Add-ReportEntry -Category "Compliance" -Check "Security Policies" -Result "Info" -Details "No explicit security policies found"
            }
        }
        else {
            Add-ReportEntry -Category "Compliance" -Check "Azure Policy" -Result "Info" -Details "No policy assignments found at subscription level"
        }
    }
    catch {
        Add-ReportEntry -Category "Compliance" -Check "Policy Check" -Result "Warning" -Details "Cannot check policy assignments: $($_.Exception.Message)"
    }
    
    # Check Key Vault access (if any key vaults exist)
    try {
        $keyVaults = Get-AzKeyVault
        
        if ($keyVaults) {
            Add-ReportEntry -Category "Security" -Check "Key Vaults" -Result "Pass" -Details "Found $($keyVaults.Count) Key Vault(s) in subscription"
            
            foreach ($kv in $keyVaults) {
                try {
                    # Test basic access to key vault
                    $kvDetails = Get-AzKeyVault -VaultName $kv.VaultName -ResourceGroupName $kv.ResourceGroupName
                    if ($kvDetails) {
                        Add-ReportEntry -Category "Security" -Check "Key Vault Access ($($kv.VaultName))" -Result "Pass" -Details "Can access Key Vault metadata"
                    }
                }
                catch {
                    Add-ReportEntry -Category "Security" -Check "Key Vault Access ($($kv.VaultName))" -Result "Warning" -Details "Limited access to Key Vault: $($_.Exception.Message)"
                }
            }
        }
        else {
            Add-ReportEntry -Category "Security" -Check "Key Vaults" -Result "Info" -Details "No Key Vaults found" -Recommendation "Consider creating Key Vaults for secrets management"
        }
    }
    catch {
        Add-ReportEntry -Category "Security" -Check "Key Vault Check" -Result "Warning" -Details "Cannot enumerate Key Vaults: $($_.Exception.Message)"
    }
}

# Function to export validation report
function Export-ValidationReport {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $scriptPath = if ($ReportPath) { $ReportPath } else { if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path } }
    
    # Ensure report directory exists
    if (-not (Test-Path $scriptPath)) {
        New-Item -ItemType Directory -Path $scriptPath -Force | Out-Null
    }
    
    if ($UseCSVExport) {
        $filename = "AVD_01_Check_Prerequisites_Confirmation_$timestamp.csv"
        $fullPath = Join-Path -Path $scriptPath -ChildPath $filename
        try {
            $script:Report | Export-Csv -Path $fullPath -NoTypeInformation -Encoding UTF8
            Write-Host "Validation report saved to: $fullPath" -ForegroundColor Green
            Add-ReportEntry -Category "Reporting" -Check "Report Export" -Result "Pass" -Details "CSV report exported to $fullPath"
        }
        catch {
            Add-ReportEntry -Category "Reporting" -Check "Report Export" -Result "Fail" -Details "Failed to export CSV report: $($_.Exception.Message)"
        }
    }
    else {
        $filename = "AVD_01_Check_Prerequisites_Confirmation_$timestamp.xlsx"
        $fullPath = Join-Path -Path $scriptPath -ChildPath $filename
        try {
            # Create summary worksheet
            $summaryData = @(
                [PSCustomObject]@{ Metric = "Total Checks"; Value = $script:ValidationSummary.TotalChecks }
                [PSCustomObject]@{ Metric = "Passed"; Value = $script:ValidationSummary.PassCount }
                [PSCustomObject]@{ Metric = "Failed"; Value = $script:ValidationSummary.FailCount }
                [PSCustomObject]@{ Metric = "Warnings"; Value = $script:ValidationSummary.WarningCount }
                [PSCustomObject]@{ Metric = "Information"; Value = $script:ValidationSummary.InfoCount }
            )
            
            # Export to Excel with multiple worksheets
            $summaryData | Export-Excel -Path $fullPath -WorksheetName "Summary" -AutoSize -BoldTopRow
            
            # Export detailed results with conditional formatting
            $script:Report | Export-Excel -Path $fullPath -WorksheetName "Detailed Results" -AutoSize -BoldTopRow -PassThru | ForEach-Object {
                $ws = $_.Workbook.Worksheets["Detailed Results"]
                $totalRows = $ws.Dimension.Rows
                
                # Apply conditional formatting to each row based on Result column (column 3)
                for ($row = 2; $row -le $totalRows; $row++) {
                    $resultCell = $ws.Cells[$row, 3]
                    $resultValue = $resultCell.Value
                    
                    # Get the entire row range
                    $rowRange = $ws.Cells["A$row`:F$row"]
                    
                    switch ($resultValue) {
                        "Fail" { 
                            $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                            $rowRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(255, 230, 230))
                        }
                        "Warning" { 
                            $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                            $rowRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(255, 249, 230))
                        }
                        "Pass" { 
                            $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                            $rowRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(230, 255, 230))
                        }
                        "Info" { 
                            $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                            $rowRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(230, 243, 255))
                        }
                    }
                }
                
                Close-ExcelPackage $_ -Show
            }
            
            Write-Host "Validation report saved to: $fullPath" -ForegroundColor Green
            Add-ReportEntry -Category "Reporting" -Check "Report Export" -Result "Pass" -Details "Excel report exported to $fullPath"
        }
        catch {
            # Fallback to CSV
            $csvFilename = "AVD_01_Check_Prerequisites_Confirmation_$timestamp.csv"
            $csvFullPath = Join-Path -Path $scriptPath -ChildPath $csvFilename
            try {
                $script:Report | Export-Csv -Path $csvFullPath -NoTypeInformation -Encoding UTF8
                Write-Host "Excel export failed. CSV report saved to: $csvFullPath" -ForegroundColor Yellow
                Add-ReportEntry -Category "Reporting" -Check "Report Export" -Result "Warning" -Details "Excel export failed, CSV report exported to $csvFullPath"
            }
            catch {
                Add-ReportEntry -Category "Reporting" -Check "Report Export" -Result "Fail" -Details "Failed to export report: $($_.Exception.Message)"
            }
        }
    }
}

# Display summary
function Show-ValidationSummary {
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host " AVD ACCELERATOR - PREREQUISITES CONFIRMATION SUMMARY " -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total Checks Performed: $($script:ValidationSummary.TotalChecks)" -ForegroundColor White
    Write-Host "Passed: $($script:ValidationSummary.PassCount)" -ForegroundColor Green
    Write-Host "Failed: $($script:ValidationSummary.FailCount)" -ForegroundColor Red
    Write-Host "Warnings: $($script:ValidationSummary.WarningCount)" -ForegroundColor Yellow
    Write-Host "Information: $($script:ValidationSummary.InfoCount)" -ForegroundColor Cyan
    Write-Host ""
}

# Function to provide specific remediation guidance
function Get-RemediationGuidance {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Details
    )
    
    $guidance = switch ($Category) {
        "PowerShell Modules" {
            switch -Wildcard ($Check) {
                "*Az.ImageBuilder*" { "Install-Module Az.ImageBuilder -Force -AllowClobber -Scope CurrentUser" }
                "*Installation" { 
                    $moduleName = ($Check -split ' ')[2]
                    "Install-Module $moduleName -Force -AllowClobber -Scope CurrentUser" 
                }
                "*Import" { 
                    $moduleName = ($Check -split ' ')[2]
                    "Import-Module $moduleName -Force" 
                }
                default { "https://docs.microsoft.com/powershell/azure/install-az-ps" }
            }
        }
        
        "Azure Authentication" {
            switch -Wildcard ($Check) {
                "*Login*" { "Connect-AzAccount -TenantId <your-tenant-id> | https://docs.microsoft.com/azure/developer/powershell/authenticate-azps" }
                "*Subscription*" { "Set-AzContext -SubscriptionId <subscription-id> | https://docs.microsoft.com/powershell/module/az.accounts/set-azcontext" }
                default { "https://docs.microsoft.com/azure/developer/powershell/authenticate-azps" }
            }
        }
        
        "Resource Providers" {
            switch -Wildcard ($Check) {
                "*Microsoft.Monitor*" { "Register-AzResourceProvider -ProviderNamespace 'Microsoft.Insights' | https://docs.microsoft.com/azure/azure-monitor/" }
                "*Microsoft.OperationalInsights*" { "Register-AzResourceProvider -ProviderNamespace 'Microsoft.OperationalInsights' | https://docs.microsoft.com/azure/azure-monitor/logs/" }
                "*Microsoft.ManagedIdentity*" { "Register-AzResourceProvider -ProviderNamespace 'Microsoft.ManagedIdentity' | https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/" }
                "*Registration" {
                    $provider = ($Check -split ' ')[0]
                    "Register-AzResourceProvider -ProviderNamespace '$provider'"
                }
                default { "https://docs.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types" }
            }
        }
        
        "Network Connectivity" {
            switch -Wildcard ($Check) {
                "*storage.azure.com*" { "Test-NetConnection storage.azure.com -Port 443 | Check firewall/proxy settings | https://docs.microsoft.com/azure/storage/common/storage-network-security" }
                "*management.azure.com*" { "Test-NetConnection management.azure.com -Port 443 | Verify Azure Management endpoint access" }
                "*login.microsoftonline.com*" { "Test-NetConnection login.microsoftonline.com -Port 443 | Check authentication endpoint access" }
                default { "https://docs.microsoft.com/azure/virtual-desktop/safe-url-list" }
            }
        }
        
        "Network Resources" {
            switch -Wildcard ($Check) {
                "*Virtual Networks*" { "New-AzVirtualNetwork -ResourceGroupName <rg> -Location <location> -Name <vnet-name> -AddressPrefix 10.0.0.0/16 | https://docs.microsoft.com/azure/virtual-desktop/create-host-pools-azure-marketplace#virtual-network" }
                "*Subnets*" { "Add-AzVirtualNetworkSubnetConfig | https://docs.microsoft.com/azure/virtual-network/virtual-network-manage-subnet" }
                default { "https://docs.microsoft.com/azure/virtual-network/" }
            }
        }
        
        "Storage Resources" {
            switch -Wildcard ($Check) {
                "*Storage Accounts*" { "New-AzStorageAccount -ResourceGroupName <rg> -Name <name> -Location <location> -SkuName Standard_LRS -Kind StorageV2 | https://docs.microsoft.com/azure/virtual-desktop/create-file-share" }
                "*File Shares*" { "New-AzStorageShare -Name <share-name> -Context <storage-context> | https://docs.microsoft.com/azure/storage/files/storage-how-to-create-file-share" }
                default { "https://docs.microsoft.com/azure/virtual-desktop/create-file-share" }
            }
        }
        
        "Image Management" {
            switch -Wildcard ($Check) {
                "*Azure Compute Galleries*" { "New-AzGallery -ResourceGroupName <rg> -Name <gallery-name> -Location <location> | https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries" }
                "*Windows Desktop Images*" { "Get-AzVMImagePublisher -Location <location> | Where-Object PublisherName -eq 'MicrosoftWindowsDesktop' | https://docs.microsoft.com/azure/virtual-desktop/set-up-customize-master-image" }
                default { "https://docs.microsoft.com/azure/virtual-desktop/set-up-customize-master-image" }
            }
        }
        
        "RBAC Permissions" {
            switch -Wildcard ($Check) {
                "*Owner*" { "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Owner' -Scope '/subscriptions/<subscription-id>' | https://docs.microsoft.com/azure/role-based-access-control/role-assignments-powershell" }
                "*Contributor*" { "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Contributor' -Scope '/subscriptions/<subscription-id>' | https://docs.microsoft.com/azure/role-based-access-control/role-assignments-powershell" }
                "*Desktop Virtualization Contributor*" { "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Desktop Virtualization Contributor' | https://docs.microsoft.com/azure/virtual-desktop/rbac" }
                "*Virtual Machine Contributor*" { "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Virtual Machine Contributor' | https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-contributor" }
                "*Network Contributor*" { "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Network Contributor' | https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#network-contributor" }
                default { "https://docs.microsoft.com/azure/virtual-desktop/rbac" }
            }
        }
        
        "Compliance" {
            switch -Wildcard ($Check) {
                "*Azure Policy*" { "New-AzPolicyAssignment | https://docs.microsoft.com/azure/governance/policy/tutorials/create-and-manage" }
                "*Security Policies*" { "Enable Azure Security Center | https://docs.microsoft.com/azure/security-center/security-center-get-started" }
                default { "https://docs.microsoft.com/azure/virtual-desktop/security-guide" }
            }
        }
        
        "Security" {
            switch -Wildcard ($Check) {
                "*Key Vaults*" { "New-AzKeyVault -VaultName <vault-name> -ResourceGroupName <rg> -Location <location> | https://docs.microsoft.com/azure/key-vault/general/quick-create-powershell" }
                "*Certificates*" { "Add-AzKeyVaultCertificate | https://docs.microsoft.com/azure/key-vault/certificates/quick-create-powershell" }
                default { "https://docs.microsoft.com/azure/virtual-desktop/security-guide" }
            }
        }
        
        default { 
            "https://docs.microsoft.com/azure/virtual-desktop/ | https://github.com/Azure/avd-accelerator" 
        }
    }
    
    return $guidance
}

# Enhanced summary function with detailed formatting matching the user's desired output
function Show-EnhancedValidationSummary {
    Write-Host ""
    
    # Show detailed failures in the exact format requested
    $failures = $script:Report | Where-Object { $_.Result -eq "Fail" }
    if ($failures.Count -gt 0) {
        Write-Host ("=" * 100) -ForegroundColor Red
        Write-Host " CRITICAL ISSUES REQUIRING ATTENTION " -ForegroundColor Red
        Write-Host ("=" * 100) -ForegroundColor Red
        Write-Host ""
        
        $groupedFailures = $failures | Group-Object Category
        foreach ($group in $groupedFailures) {
            Write-Host "[$($group.Name)] Category Issues:" -ForegroundColor Red
            foreach ($item in $group.Group) {
                Write-Host "  * $($item.Check)" -ForegroundColor White
                Write-Host "    Issue: $($item.Details)" -ForegroundColor Gray
                if ($item.Recommendation) {
                    Write-Host "    Solution: $($item.Recommendation)" -ForegroundColor Yellow
                }
                
                # Add specific guidance based on check type with enhanced formatting
                $guidance = Get-EnhancedRemediationGuidance -Category $item.Category -Check $item.Check -Details $item.Details
                if ($guidance) {
                    Write-Host "    Guide: $guidance" -ForegroundColor Cyan
                }
                Write-Host ""
            }
        }
    }
    
    # Overall Assessment
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host " OVERALL ASSESSMENT " -ForegroundColor White
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host ""
    
    if ($script:ValidationSummary.FailCount -eq 0) {
        Write-Host "[SUCCESS] All critical checks passed! Your environment appears ready for AVD Accelerator deployment." -ForegroundColor Green
    }
    elseif ($script:ValidationSummary.FailCount -le 3) {
        Write-Host "[WARNING] Minor issues detected. Review failed checks and recommendations before proceeding." -ForegroundColor Yellow
    }
    else {
        Write-Host "[ERROR] Significant issues detected. Address critical failures before attempting AVD deployment." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor White
    Write-Host "  1. Address the critical issues listed above" -ForegroundColor Gray
    Write-Host "  2. Re-run this validation script" -ForegroundColor Gray
    Write-Host "  3. Proceed with deployment once all issues are resolved" -ForegroundColor Gray
    
    # Quick Action Items Summary
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host " QUICK ACTION ITEMS SUMMARY " -ForegroundColor White
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host ""
    
    # Show top 5 most critical actions
    $criticalActions = @()
    
    # Add critical PowerShell module installations
    $moduleFailures = $script:Report | Where-Object { $_.Result -eq "Fail" -and $_.Category -eq "PowerShell Modules" }
    foreach ($module in $moduleFailures) {
        $criticalActions += [PSCustomObject]@{
            Priority    = "HIGH"
            Action      = "Install missing PowerShell module"
            Command     = "Install-Module $($module.Check.Split(' ')[0]) -Force -AllowClobber -Scope CurrentUser"
            Description = $module.Details
        }
    }
    
    # Add resource provider registrations
    $providerFailures = $script:Report | Where-Object { $_.Result -eq "Fail" -and $_.Category -eq "Resource Providers" }
    foreach ($provider in $providerFailures) {
        $providerName = switch ($provider.Check) {
            "*Microsoft.Monitor*" { "Microsoft.Insights" }
            "*Microsoft.OperationalInsights*" { "Microsoft.OperationalInsights" }
            "*Microsoft.ManagedIdentity*" { "Microsoft.ManagedIdentity" }
            default { $provider.Check.Split(' ')[0] }
        }
        $criticalActions += [PSCustomObject]@{
            Priority    = "HIGH"
            Action      = "Register Azure Resource Provider"
            Command     = "Register-AzResourceProvider -ProviderNamespace '$providerName'"
            Description = $provider.Details
        }
    }
    
    # Add network connectivity fixes
    $networkFailures = $script:Report | Where-Object { $_.Result -eq "Fail" -and $_.Category -eq "Network Connectivity" }
    foreach ($network in $networkFailures) {
        $criticalActions += [PSCustomObject]@{
            Priority    = "HIGH"
            Action      = "Fix network connectivity"
            Command     = "Test-NetConnection $($network.Check.Split(' ')[2]) -Port 443"
            Description = $network.Details
        }
    }
    
    # Add medium priority warnings
    $warningActions = $script:Report | Where-Object { $_.Result -eq "Warning" }
    $warningIndex = 0
    foreach ($warning in $warningActions) {
        if ($warningIndex -lt 3) {
            # Only first 3 warnings
            $criticalActions += [PSCustomObject]@{
                Priority    = "MEDIUM"
                Action      = "Address warning"
                Command     = "See detailed guidance above"
                Description = "$($warning.Check): $($warning.Details)"
            }
        }
        $warningIndex++
    }
    
    # Display top actions
    $topActions = $criticalActions | Sort-Object Priority, Action | Select-Object -First 5
    
    if ($topActions.Count -gt 0) {
        Write-Host "TOP PRIORITY ACTIONS:" -ForegroundColor Yellow
        Write-Host ""
        for ($i = 0; $i -lt $topActions.Count; $i++) {
            $action = $topActions[$i]
            $priorityColor = if ($action.Priority -eq "HIGH") { "Red" } else { "Yellow" }
            Write-Host "[$($i+1)] $($action.Action) [$($action.Priority)]" -ForegroundColor $priorityColor
            Write-Host "    Command: $($action.Command)" -ForegroundColor Cyan
            Write-Host "    Issue: $($action.Description)" -ForegroundColor Gray
            Write-Host ""
        }
    }
    
    # Add specific error handling for the original error mentioned
    $scriptErrors = $script:Report | Where-Object { $_.Category -eq "Script Execution" -and $_.Result -eq "Fail" }
    if ($scriptErrors.Count -gt 0) {
        foreach ($error in $scriptErrors) {
            Write-Host "Critical error during validation: $($error.Details)" -ForegroundColor Red
            Write-Host "[$($error.Result)] $($error.Category) - $($error.Check)" -ForegroundColor Red
            Write-Host "  Details: $($error.Details)" -ForegroundColor Gray
            Write-Host ""
        }
    }
    
    Write-Host ("=" * 100) -ForegroundColor White
}

# Enhanced remediation guidance function with specific examples from the user's request
function Get-EnhancedRemediationGuidance {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Details
    )
    
    # Provide enhanced guidance with specific examples that match the user's request
    $guidance = switch ($Category) {
        "PowerShell Modules" {
            switch -Wildcard ($Check) {
                "*Az.ImageBuilder*" { 
                    "Install-Module Az.ImageBuilder -Force -AllowClobber Install-Module Az.ImageBuilder -Force -AllowClobber -Scope CurrentUser Install-Module -Force -AllowClobber -Scope CurrentUser"
                }
                "*Installation" { 
                    $moduleName = ($Check -split ' ')[2]
                    "Install-Module $moduleName -Force -AllowClobber -Scope CurrentUser" 
                }
                "*Import" { 
                    $moduleName = ($Check -split ' ')[2]
                    "Import-Module $moduleName -Force" 
                }
                default { "https://docs.microsoft.com/powershell/azure/install-az-ps" }
            }
        }
        
        "Network Connectivity" {
            switch -Wildcard ($Check) {
                "*storage.azure.com*" { 
                    "Test-NetConnection storage.azure.com -Port 443 | Check firewall/proxy settings | https://docs.microsoft.com/azure/storage/common/storage-network-security"
                }
                "*management.azure.com*" { 
                    "Test-NetConnection management.azure.com -Port 443 | Verify Azure Management endpoint access" 
                }
                "*login.microsoftonline.com*" { 
                    "Test-NetConnection login.microsoftonline.com -Port 443 | Check authentication endpoint access" 
                }
                default { "https://docs.microsoft.com/azure/virtual-desktop/safe-url-list" }
            }
        }
        
        "RBAC Permissions" {
            switch -Wildcard ($Check) {
                "*Role Assignments*" { 
                    "https://docs.microsoft.com/azure/virtual-desktop/rbac"
                }
                "*Owner*" { 
                    "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Owner' -Scope '/subscriptions/<subscription-id>' | https://docs.microsoft.com/azure/role-based-access-control/role-assignments-powershell" 
                }
                "*Contributor*" { 
                    "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Contributor' -Scope '/subscriptions/<subscription-id>' | https://docs.microsoft.com/azure/role-based-access-control/role-assignments-powershell" 
                }
                "*Desktop Virtualization Contributor*" { 
                    "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Desktop Virtualization Contributor' | https://docs.microsoft.com/azure/virtual-desktop/rbac" 
                }
                "*Virtual Machine Contributor*" { 
                    "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Virtual Machine Contributor' | https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-contributor" 
                }
                "*Network Contributor*" { 
                    "New-AzRoleAssignment -SignInName <user@domain.com> -RoleDefinitionName 'Network Contributor' | https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#network-contributor" 
                }
                default { "https://docs.microsoft.com/azure/virtual-desktop/rbac" }
            }
        }
        
        default { 
            # Use the original guidance function for other categories
            Get-RemediationGuidance -Category $Category -Check $Check -Details $Details
        }
    }
    
    return $guidance
}

# Main execution
try {
    # Script header
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host " AVD ACCELERATOR - PREREQUISITES CONFIRMATION " -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Environment: $Environment" -ForegroundColor White
    Write-Host "Execution Time: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -ForegroundColor White
    if ($TenantId) { Write-Host "Target Tenant: $TenantId" -ForegroundColor White }
    if ($SubscriptionId) { Write-Host "Target Subscription: $SubscriptionId" -ForegroundColor White }
    Write-Host ""
    
    # Run validation tests
    Test-PowerShellModules
    
    # Establish Azure connection with tenant/subscription selection
    $connectionResult = Connect-AzureWithSelection
    
    if ($connectionResult) {
        # Now test the established connection
        $authResult = Test-AzureAuthentication
        
        if ($authResult) {
            Test-AzureResourceProviders
            Test-NetworkConfiguration
            Test-StorageConfiguration
            Test-ImageManagement
            Test-RBACPermissions
            Test-ComplianceAndSecurity
        }
        else {
            Write-Host "Skipping Azure-dependent tests due to authentication validation failure." -ForegroundColor Red
        }
    }
    else {
        Write-Host "Skipping Azure-dependent tests due to connection failure." -ForegroundColor Red
    }
    
    # Generate and export report
    Export-ValidationReport
    Show-ValidationSummary
    
    # Show enhanced summary with the specific formatting requested
    Show-EnhancedValidationSummary
    
}
catch {
    Write-Host "Critical error during validation: $($_.Exception.Message)" -ForegroundColor Red
    Add-ReportEntry -Category "Script Execution" -Check "Main Process" -Result "Fail" -Details "Critical error: $($_.Exception.Message)"
    
    # Still show enhanced summary even in case of errors to display what was found
    Show-EnhancedValidationSummary
}
finally {
    # Cleanup
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Green
    Write-Host " CONFIRMATION COMPLETED " -ForegroundColor Green
    Write-Host ("=" * 100) -ForegroundColor Green
    Write-Host ""
}
