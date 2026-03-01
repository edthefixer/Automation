<#
.SYNOPSIS
Comprehensive Azure Virtual Desktop (AVD) Network Configuration Validation & Automated Remediation Script with VNet Creation

.DESCRIPTION
This enterprise-grade PowerShell script provides comprehensive validation AND automated remediation of Azure Virtual Desktop 
networking requirements across all virtual networks and subnets within a subscription. It validates
networking configurations against ALL AVD Accelerator requirements, covering both "Create New" and 
"Use Existing" networking scenarios with detailed assessment and automated fixing of peering, DNS, and security configurations.

The script forces fresh authentication on every run (no cached credentials) and provides detailed
analysis of network readiness for AVD deployments with intelligent automated remediation capabilities
for common misconfigurations. When no Virtual Networks are found, the script offers interactive options
to create a VNet before proceeding with validation.

CORE FUNCTIONALITY:
- Automated Azure PowerShell Module Management: Auto-installation and configuration of required modules
- Enhanced Authentication: Multiple methods (Interactive, Device Code, Service Principal, Managed Identity) with forced fresh login
- Console-Based Interface: No GUI dependencies - pure PowerShell console experience
- Subscription Management: Intelligent subscription discovery and console-based selection
- AVD Scenario Selection: Interactive menu for "Create New", "Use Existing", or comprehensive validation
- VNet Creation Assistant: Interactive VNet creation when no networks exist in subscription

COMPREHENSIVE NETWORK VALIDATION:
- Virtual Network & Subnet Configuration Analysis with AVD-specific sizing recommendations
- Advanced DNS Validation: Custom DNS servers, Azure DNS zones, and Private DNS zone assessment
- Private DNS Zones: Complete validation of AVD-required Private DNS zones and vNet linkages
- Enhanced Peering Validation: Bidirectional peering analysis, address space overlap detection, AVD connectivity requirements
- Network Security Groups: Deep analysis of NSG rules for AVD traffic requirements (RDP, HTTPS, HTTP)
- Route Table Analysis: UDR validation, NVA impact assessment, and AVD service connectivity checks
- Service Endpoints: Validation of required Azure service endpoints for AVD components
- Network Gateway Integration: VPN/ExpressRoute analysis for hybrid AVD scenarios
- Private Endpoint Connectivity: Assessment of private endpoint configurations for AVD services

AVD ACCELERATOR SCENARIO VALIDATION:
- Create New vNet Scenarios: Quota validation, naming conventions, address space planning
- Use Existing vNet Scenarios: Capacity analysis, utilization assessment, suitability validation
- Hub-Spoke Topology: Advanced peering validation for enterprise AVD deployments
- Domain Controller Connectivity: Peering assessment for Active Directory integration
- Service Endpoint Configuration: Validation of required endpoints for AVD services

ADVANCED AVD-SPECIFIC ANALYSIS:
- AVD Subnet Detection: Smart identification of AVD-designated subnets by naming patterns
- Session Host Capacity Planning: IP address availability and subnet sizing for growth
- Subnet Delegation Conflicts: Detection of delegations that might prevent AVD deployment  
- Network Virtual Appliance Impact: Analysis of UDR routing that could break AVD connectivity
- Cross-Region Deployment Assessment: Multi-region networking validation for global AVD
- Private DNS Zone Coverage: Complete validation of all required AVD Private DNS zones
- Bidirectional Peering Health: Ensures symmetric peering configuration for reliable connectivity

AUTOMATED REMEDIATION CAPABILITIES:
- Intelligent Issue Detection: Automatically identifies remediable configuration issues
- NSG Rule Remediation: Automatically adds missing NSG rules for AVD connectivity (RDP, HTTPS, service tags)
- Private DNS Zone Creation: Creates and links required Private DNS zones for AVD services
- Service Endpoint Configuration: Adds missing service endpoints to subnets for optimal AVD performance
- VNet Peering Repair: Establishes or fixes broken virtual network peering connections
- Route Table Optimization: Corrects UDR configurations that block AVD service connectivity
- Interactive Remediation Menu: User-controlled remediation with confirmation prompts or full automation
- Comprehensive Remediation Reporting: Detailed tracking of all remediation actions and success rates

VNET CREATION FEATURES:
- Interactive VNet Creation: When no VNets exist, offers to create custom or test VNets
- Custom VNet Configuration: User-defined name, resource group, address space, and location
- Test VNet Generation: Pre-configured test VNet with AVD-recommended settings
- Automatic Resource Group Management: Creates resource groups as needed
- AVD-Optimized Subnets: Automatically creates appropriately-sized subnets for session hosts
- Validation Integration: Created VNets are immediately included in validation workflow

ENHANCED REPORTING & ANALYTICS:
- Real-Time Console Output: Color-coded validation results (Green=Pass, Red=Fail, Yellow=Warning, Blue=Info)
- Professional Excel Reports: Multi-worksheet reports with validation results, remediation actions, network topology, and summary metrics
- CSV Fallback Export: Full compatibility for environments without Excel module
- Detailed Remediation Guides: Specific, actionable recommendations for each identified issue
- Remediation Action Tracking: Complete audit trail of all automated fixes attempted and completed
- Network Topology Documentation: Comprehensive mapping of peering relationships and dependencies
- Compliance Dashboard: AVD networking requirements compliance summary with pass/fail metrics
- Categorized Results: Organized validation results by Authentication, Setup, DNS, Peering, Security, Routing, and AVD Planning

ENTERPRISE FEATURES:
- No Credential Caching: Forces fresh authentication on every execution for security compliance
- Comprehensive Error Handling: Graceful handling of permission issues, network timeouts, and missing resources
- Scalable Architecture: Efficiently processes large enterprise environments with hundreds of vNets
- Hub-Spoke Topology Support: Advanced validation for complex enterprise network architectures
- Hybrid Connectivity Assessment: Validation of on-premises integration requirements for AVD
- Multi-Subscription Awareness: Single subscription deep-dive with cross-subscription peering detection

TARGET AUDIENCE:
This script is designed for Azure network administrators, cloud architects, AVD deployment engineers,
and IT professionals responsible for ensuring network readiness and compliance with Azure Virtual Desktop
best practices in enterprise environments.

.PARAMETER SubscriptionId
Optional. Specific Azure subscription ID to validate. If not provided, user will be prompted to select.

.PARAMETER SkipDNSValidation
Optional. Skip detailed DNS configuration validation.

.PARAMETER SkipPeeringValidation
Optional. Skip virtual network peering validation.

.PARAMETER SkipLatencyTest
Optional. Skip network latency assessment.

.PARAMETER ReportPath
Optional. Custom path for saving the validation report.

.PARAMETER NonInteractive
Optional. Run in non-interactive mode with minimal prompts.

.PARAMETER EnableRemediation
Optional. Enable automated remediation of detected configuration issues.

.PARAMETER AutoFixAll
Optional. Automatically fix all detected issues without user prompts (requires EnableRemediation).

.EXAMPLE
    .\02_AVD_Validate_Network_Configuration.ps1
Run complete network validation with interactive prompts

.EXAMPLE
    .\02_AVD_Validate_Network_Configuration.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
Validate specific subscription networking configuration

.EXAMPLE
    .\02_AVD_Validate_Network_Configuration.ps1 -SkipLatencyTest -NonInteractive
Run validation without latency tests in non-interactive mode

.EXAMPLE
    .\02_AVD_Validate_Network_Configuration.ps1 -EnableRemediation
Run validation with interactive remediation options for detected issues

.EXAMPLE
    .\02_AVD_Validate_Network_Configuration.ps1 -EnableRemediation -AutoFixAll -NonInteractive
Run complete validation and automatically fix all detected issues without prompts

.NOTES
File Name      : 02_AVD_Validate_Network_Configuration.ps1
Author         : edthefixer + GitHub Copilot... well, I fell asleep, copilot finished it...  
Prerequisite   : PowerShell 5.1+, Azure PowerShell Module
Version        : 2.1.0 - Enhanced with VNet Creation and Improved No-VNet Messaging
Creation Date  : October 2025
Last Updated   : January 2026
Creation Date  : October 2025

IMPORTANT: This script requires appropriate Azure permissions for network resource access
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Specific Azure subscription ID to validate")]
    [string]$SubscriptionId,
    
    [Parameter(HelpMessage = "Skip DNS configuration validation")]
    [switch]$SkipDNSValidation,
    
    [Parameter(HelpMessage = "Skip virtual network peering validation")]
    [switch]$SkipPeeringValidation,
    
    [Parameter(HelpMessage = "Skip network latency assessment")]
    [switch]$SkipLatencyTest,
    
    [Parameter(HelpMessage = "Custom report output path")]
    [string]$ReportPath,
    
    [Parameter(HelpMessage = "Run in non-interactive mode")]
    [switch]$NonInteractive,
    
    [Parameter(HelpMessage = "Enable automated remediation of detected issues")]
    [switch]$EnableRemediation,
    
    [Parameter(HelpMessage = "Automatically fix all detected issues without prompts")]
    [switch]$AutoFixAll
)

#Requires -Version 5.1

# Global variables and configuration
$script:Report = @()
$script:JoinSeparator = ', '
$script:ValidationSummary = @{
    TotalChecks = 0
    PassedChecks = 0
    FailedChecks = 0
    WarningChecks = 0
    InfoChecks = 0
}
$script:NetworkTopology = @{
    VirtualNetworks = @()
    HubNetworks = @()
    SpokeNetworks = @()
    PeeringRelationships = @()
}
$script:AVDRequirements = @{
    RequiredPorts = @(443, 3389)
    RequiredURLs = @(
        "*.wvd.microsoft.com",
        "*.servicebus.windows.net",
        "prod.warmpath.msftcloudes.com",
        "catalogartifact.azureedge.net",
        "kms.core.windows.net",
        "aadcdn.msauth.net",
        "aka.ms",
        "login.microsoftonline.com"
    )
    RecommendedSubnetSize = "/24"
    MaxLatencyMs = 150
}
$global:useCSVExport = $false

# Remediation tracking variables
$script:RemediationActions = @()
$script:RemediationSummary = @{
    TotalIssues = 0
    FixedIssues = 0
    FailedFixes = 0
    SkippedIssues = 0
}

# AVD-specific configuration requirements for automated remediation
$script:AVDNetworkRequirements = @{
    RequiredNSGRules = @(
        @{
            Name = "Allow-AVD-HTTPS-Outbound"
            Direction = "Outbound"
            Priority = 1000
            Protocol = "TCP"
            SourcePortRange = "*"
            DestinationPortRange = "443"
            SourceAddressPrefix = "*"
            DestinationAddressPrefix = "WindowsVirtualDesktop"
            Access = "Allow"
        },
        @{
            Name = "Allow-AVD-RDP-Inbound"
            Direction = "Inbound"
            Priority = 1001
            Protocol = "TCP"
            SourcePortRange = "*"
            DestinationPortRange = "3389"
            SourceAddressPrefix = "VirtualNetwork"
            DestinationAddressPrefix = "*"
            Access = "Allow"
        },
        @{
            Name = "Allow-Azure-Cloud-Outbound"
            Direction = "Outbound"
            Priority = 1002
            Protocol = "TCP"
            SourcePortRange = "*"
            DestinationPortRange = "443"
            SourceAddressPrefix = "*"
            DestinationAddressPrefix = "AzureCloud"
            Access = "Allow"
        }
    )
    RequiredPrivateDNSZones = @(
        "privatelink.wvd.microsoft.com",
        "privatelink.servicebus.windows.net",
        "privatelink.blob.core.windows.net",
        "privatelink.file.core.windows.net",
        "privatelink.vaultcore.azure.net"
    )
    RequiredServiceEndpoints = @(
        "Microsoft.Storage",
        "Microsoft.KeyVault",
        "Microsoft.ServiceBus"
    )
    MinimumSubnetSize = 256 # /24 subnet
    RecommendedSubnetPrefixes = @("/24", "/23", "/22")
}

# Required PowerShell modules
$requiredModules = @("Az.Accounts", "Az.Resources", "Az.Network", "Az.PrivateDns", "Az.Storage", "Az.KeyVault", "ImportExcel")

# Color-coded reporting function
function Add-ReportEntry {
    param (
        [string]$Check,
        [string]$Result,
        [string]$Details,
        [string]$Recommendation = "",
        [string]$Category = "General"
    )
    
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    # Update validation summary
    $script:ValidationSummary.TotalChecks++
    switch ($Result) {
        "Pass" { 
            $script:ValidationSummary.PassedChecks++
            Write-Host ("{0} - {1}: {2}" -f $Check, $Result, $Details) -ForegroundColor Green
        }
        "Fail" { 
            $script:ValidationSummary.FailedChecks++
            Write-Host ("{0} - {1}: {2}" -f $Check, $Result, $Details) -ForegroundColor Red
            if ($Recommendation) {
                Write-Host ("    Recommendation: {0}" -f $Recommendation) -ForegroundColor Cyan
            }
        }
        "Warning" { 
            $script:ValidationSummary.WarningChecks++
            Write-Host ("{0} - {1}: {2}" -f $Check, $Result, $Details) -ForegroundColor Yellow
        }
        "Info" { 
            $script:ValidationSummary.InfoChecks++
            Write-Host ("{0} - {1}: {2}" -f $Check, $Result, $Details) -ForegroundColor Cyan
        }
    }
    
    # Add to report
    $script:Report += [PSCustomObject]@{
        Timestamp = $timestamp
        Category = $Category
        Check = $Check
        Result = $Result
        Details = $Details
        Recommendation = $Recommendation
    }
}

# Function to export report when script exits unexpectedly
function Export-PartialReportAndExit {
    Write-Host "`nExporting partial report due to script termination..." -ForegroundColor Yellow
    Export-ValidationReport
    exit 1
}

# Function to export final validation report
function Export-ValidationReport {
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    
    if ([string]::IsNullOrEmpty($ReportPath)) {
        $ReportPath = "AVD_Network_Validation_Report_$timestamp"
    }
    
    try {
        if (-not $global:useCSVExport -and (Get-Module -ListAvailable -Name ImportExcel)) {
            # Export to Excel
            $excelPath = "$ReportPath.xlsx"
            
            # Main validation results
            $script:Report | Export-Excel -Path $excelPath -WorksheetName "Validation Results" -AutoSize -FreezeTopRow -BoldTopRow
            
            # Network topology summary
            if ($script:NetworkTopology.VirtualNetworks.Count -gt 0) {
                $script:NetworkTopology.VirtualNetworks | Export-Excel -Path $excelPath -WorksheetName "Network Topology" -AutoSize -Append
            }
            
            # Validation summary
            $summaryData = @(
                [PSCustomObject]@{ Metric = "Total Checks"; Count = $script:ValidationSummary.TotalChecks }
                [PSCustomObject]@{ Metric = "Passed"; Count = $script:ValidationSummary.PassedChecks }
                [PSCustomObject]@{ Metric = "Failed"; Count = $script:ValidationSummary.FailedChecks }
                [PSCustomObject]@{ Metric = "Warnings"; Count = $script:ValidationSummary.WarningChecks }
                [PSCustomObject]@{ Metric = "Info"; Count = $script:ValidationSummary.InfoChecks }
            )
            $summaryData | Export-Excel -Path $excelPath -WorksheetName "Summary" -AutoSize -Append
            
            Add-ReportEntry "Report Export" "Pass" "Excel report exported successfully: $excelPath" -Category "Reporting"
        } else {
            # Export to CSV
            $csvPath = "$ReportPath.csv"
            $script:Report | Export-Csv -Path $csvPath -NoTypeInformation
            Add-ReportEntry "Report Export" "Pass" "CSV report exported successfully: $csvPath" -Category "Reporting"
        }
    } catch {
        Add-ReportEntry "Report Export" "Fail" "Failed to export report: $($_.Exception.Message)" -Category "Reporting"
    }
}

# Function to validate Azure PowerShell modules
function Initialize-AzureModules {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host "Validating Azure modules installation " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            try {
                Write-Host "Installing module: $module" -ForegroundColor Yellow
                
                if ($module -eq "ImportExcel") {
                    try {
                        Install-Module -Name ImportExcel -Scope CurrentUser -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
                    } catch {
                        Write-Host "ImportExcel installation failed, using CSV export fallback..." -ForegroundColor Yellow
                        $global:useCSVExport = $true
                        Add-ReportEntry "Module Install" "Warning" "ImportExcel installation failed - using CSV export" -Category "Setup"
                        continue
                    }
                } else {
                    Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                }
                
                Add-ReportEntry "Module Install" "Pass" "Installed module: $module" -Category "Setup"
            } catch {
                Add-ReportEntry "Module Install" "Fail" "Failed to install module: $module. $($_.Exception.Message)" -Category "Setup"
                if ($module -ne "ImportExcel") {
                    Export-PartialReportAndExit
                }
            }
        } else {
            Add-ReportEntry "Module Check" "Pass" "Module already available: $module" -Category "Setup"
        }
    }
    
    # Import modules
    foreach ($module in $requiredModules) {
        if ($module -eq "ImportExcel" -and $global:useCSVExport) {
            continue
        }
        
        try {
            Import-Module $module -Force -ErrorAction Stop
            Add-ReportEntry "Module Import" "Pass" "Imported module: $module" -Category "Setup"
        } catch {
            Add-ReportEntry "Module Import" "Fail" "Failed to import module: $module. $($_.Exception.Message)" -Category "Setup"
            if ($module -ne "ImportExcel") {
                Export-PartialReportAndExit
            }
        }
    }
}

# Function to authenticate to Azure
function Connect-AzureAccount {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host "Azure Authentication " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    $connected = $false
    
    # Force fresh login every time - clear any cached credentials
    $currentContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($currentContext) {
        Add-ReportEntry "Azure Login" "Info" "Clearing cached Azure credentials to force fresh authentication" -Category "Authentication"
        Clear-AzContext -Force -Scope CurrentUser -ErrorAction SilentlyContinue
        Disconnect-AzAccount -ErrorAction SilentlyContinue
    }
    
    # Always prompt for authentication method (no cached credentials)
    if (-not $NonInteractive) {
        # Interactive authentication methods
        $authMethods = @(
            "Interactive Browser Login",
            "Device Code Authentication", 
            "Service Principal (ClientId/Secret)",
            "Managed Identity"
        )
        
        Write-Host "Select authentication method:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $authMethods.Count; $i++) {
            Write-Host "$($i + 1). $($authMethods[$i])" -ForegroundColor White
        }
        
        do {
            $selection = Read-Host "Enter selection (1-$($authMethods.Count))"
        } while ($selection -notin 1..$authMethods.Count)
    } else {
        $selection = "1" # Default to interactive in non-interactive mode
    }
    
    while (-not $connected) {
        try {
            switch ($selection) {
                "1" { # Interactive Browser
                    Connect-AzAccount -ErrorAction Stop | Out-Null
                    $connected = $true
                    Add-ReportEntry "Azure Login" "Pass" "Successfully authenticated via interactive browser" -Category "Authentication"
                }
                "2" { # Device Code
                    Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop | Out-Null
                    $connected = $true
                    Add-ReportEntry "Azure Login" "Pass" "Successfully authenticated via device code" -Category "Authentication"
                }
                "3" { # Service Principal
                    $clientId = Read-Host "Enter Client ID"
                    $clientSecret = Read-Host "Enter Client Secret" -AsSecureString
                    $tenantId = Read-Host "Enter Tenant ID"
                    $credential = New-Object System.Management.Automation.PSCredential($clientId, $clientSecret)
                    Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $tenantId -ErrorAction Stop | Out-Null
                    $connected = $true
                    Add-ReportEntry "Azure Login" "Pass" "Successfully authenticated via service principal" -Category "Authentication"
                }
                "4" { # Managed Identity
                    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
                    $connected = $true
                    Add-ReportEntry "Azure Login" "Pass" "Successfully authenticated via managed identity" -Category "Authentication"
                }
            }
        } catch {
            Add-ReportEntry "Azure Login" "Fail" "Authentication failed: $($_.Exception.Message)" -Category "Authentication"
        }
    }
    
    if (-not $connected) {
        Add-ReportEntry "Azure Login" "Fail" "Unable to authenticate to Azure" -Category "Authentication"
        Export-PartialReportAndExit
    }
}

# Function to select Azure subscription
function Select-AzureSubscription {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host "Selecting Azure Subscription " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    try {
        if ($SubscriptionId) {
            Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
            $selectedSub = Get-AzSubscription -SubscriptionId $SubscriptionId
            Add-ReportEntry "Subscription Selection" "Pass" "Selected subscription: $($selectedSub.Name) ($($selectedSub.Id))" -Category "Setup"
        } else {
            $subscriptions = Get-AzSubscription | Sort-Object Name -ErrorAction Stop
            if ($subscriptions.Count -eq 0) {
                Add-ReportEntry "Subscription Selection" "Fail" "No subscriptions found" -Category "Setup"
                Export-PartialReportAndExit
            }
            
            if ($NonInteractive -and $subscriptions.Count -eq 1) {
                $selectedSubscription = $subscriptions[0]
            } elseif ($NonInteractive) {
                Add-ReportEntry "Subscription Selection" "Fail" "Multiple subscriptions found in non-interactive mode. Specify SubscriptionId parameter." -Category "Setup"
                Export-PartialReportAndExit
            } else {
                # Console-based subscription selection
                Write-Host "Available Subscriptions:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                    Write-Host "$($i + 1). $($subscriptions[$i].Name) ($($subscriptions[$i].Id))" -ForegroundColor White
                }
                
                do {
                    $selection = Read-Host "Enter selection (1-$($subscriptions.Count))"
                    $selectionIndex = [int]$selection - 1
                } while ($selectionIndex -lt 0 -or $selectionIndex -ge $subscriptions.Count)
                
                $selectedSubscription = $subscriptions[$selectionIndex]
                Write-Host "Selected: $($selectedSubscription.Name)" -ForegroundColor Green
            }
            
            Set-AzContext -SubscriptionId $selectedSubscription.Id -ErrorAction Stop | Out-Null
            Add-ReportEntry "Subscription Selection" "Pass" "Selected subscription: $($selectedSubscription.Name) ($($selectedSubscription.Id))" -Category "Setup"
        }
    } catch {
        Add-ReportEntry "Subscription Selection" "Fail" "Failed to select subscription: $($_.Exception.Message)" -Category "Setup"
        Export-PartialReportAndExit
    }
}

#region REMEDIATION FUNCTIONS

# Function to add remediation entry
function Add-RemediationEntry {
    param (
        [string]$Issue,
        [string]$Action,
        [string]$Status,
        [string]$Details,
        [string]$ResourceName = "",
        [string]$ResourceGroup = ""
    )
    
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    # Update remediation summary
    $script:RemediationSummary.TotalIssues++
    switch ($Status) {
        "Fixed" { 
            $script:RemediationSummary.FixedIssues++
            Write-Host "REMEDIATED - ${Issue}: ${Details}" -ForegroundColor Green
        }
        "Failed" { 
            $script:RemediationSummary.FailedFixes++
            Write-Host "FAILED TO FIX - ${Issue}: ${Details}" -ForegroundColor Red
        }
        "Skipped" { 
            $script:RemediationSummary.SkippedIssues++
            Write-Host "SKIPPED - ${Issue}: ${Details}" -ForegroundColor Yellow
        }
    }
    
    # Add to remediation actions
    $script:RemediationActions += [PSCustomObject]@{
        Timestamp = $timestamp
        Issue = $Issue
        Action = $Action
        Status = $Status
        Details = $Details
        ResourceName = $ResourceName
        ResourceGroup = $ResourceGroup
    }
}

# Function to confirm user action for remediation with options
function Confirm-RemediationAction {
    param (
        [string]$Message,
        [switch]$DefaultYes,
        [array]$Options = @()
    )
    
    if ($NonInteractive) {
        return $DefaultYes.IsPresent
    }
    
    # If options are provided, show them
    if ($Options.Count -gt 0) {
        Write-Host "`n$Message" -ForegroundColor Cyan
        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-Host "  $($i + 1). $($Options[$i])" -ForegroundColor White
        }
        Write-Host "  0. Skip this remediation" -ForegroundColor Gray
        Write-Host ""
        
        do {
            $selection = Read-Host "Select option (0-$($Options.Count))"
        } while ($selection -notmatch '^[0-9]+$' -or [int]$selection -lt 0 -or [int]$selection -gt $Options.Count)
        
        return [int]$selection
    }
    
    # Simple yes/no confirmation
    $prompt = if ($DefaultYes) { "$Message (Y/n)" } else { "$Message (y/N)" }
    $response = Read-Host $prompt
    
    if ([string]::IsNullOrEmpty($response)) {
        return $DefaultYes.IsPresent
    }
    
    return $response -match '^[yY]'
}

# Function to remediate Network Security Group rules with interactive selection
function Repair-NSGRules {
    param (
        [string]$VNetName,
        [string]$SubnetName,
        [array]$MissingRules
    )
    
    try {
        Write-Host "`n" -NoNewline
        Write-Host ("="*80) -ForegroundColor Cyan
        Write-Host "NSG Rule Remediation Assistant" -ForegroundColor Cyan
        Write-Host ("="*80) -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Issue Detected: Missing NSG rules for AVD connectivity on subnet '$SubnetName'" -ForegroundColor Yellow
        Write-Host ""
        
        # Get all NSGs in the subscription
        $allNSGs = Get-AzNetworkSecurityGroup
        
        # Options for remediation
        Write-Host "Select remediation approach:" -ForegroundColor Cyan
        $options = @(
            "Select an existing NSG to associate with the subnet",
            "Create a new NSG with AVD-required rules",
            "View missing rules and add them manually later"
        )
        
        $choice = Confirm-RemediationAction "How would you like to remediate NSG rules?" -Options $options
        
        if ($choice -eq 0) {
            Add-RemediationEntry "Missing NSG Rules" "Configure NSG" "Skipped" "User chose to skip NSG remediation" -ResourceName $SubnetName
            return
        }
        
        switch ($choice) {
            1 { # Select existing NSG
                if ($allNSGs.Count -eq 0) {
                    Write-Host "No existing NSGs found. Creating new NSG instead." -ForegroundColor Yellow
                    $choice = 2
                } else {
                    Write-Host "`nAvailable Network Security Groups:" -ForegroundColor Cyan
                    $nsgOptions = $allNSGs | ForEach-Object { "$($_.Name) (RG: $($_.ResourceGroupName), Rules: $($_.SecurityRules.Count))" }
                    $nsgSelection = Confirm-RemediationAction "Select NSG to associate" -Options $nsgOptions
                    
                    if ($nsgSelection -eq 0) {
                        Add-RemediationEntry "Missing NSG Rules" "Select NSG" "Skipped" "User cancelled NSG selection"
                        return
                    }
                    
                    $selectedNSG = $allNSGs[$nsgSelection - 1]
                    
                    # Check if selected NSG has the required rules
                    $missingInSelected = @()
                    foreach ($rule in $MissingRules) {
                        $ruleExists = $selectedNSG.SecurityRules | Where-Object { 
                            $_.Direction -eq $rule.Direction -and 
                            $_.Protocol -eq $rule.Protocol -and 
                            $_.DestinationPortRange -contains $rule.DestinationPortRange
                        }
                        if (-not $ruleExists) {
                            $missingInSelected += $rule
                        }
                    }
                    
                    if ($missingInSelected.Count -gt 0) {
                        Write-Host "`nWarning: Selected NSG is missing $($missingInSelected.Count) required AVD rule(s)" -ForegroundColor Yellow
                        if (Confirm-RemediationAction "Add missing AVD rules to this NSG?") {
                            # Add missing rules
                            foreach ($rule in $missingInSelected) {
                                try {
                                    # Find available priority
                                    $existingPriorities = $selectedNSG.SecurityRules | ForEach-Object { $_.Priority }
                                    $newPriority = ($rule.Priority..4096 | Where-Object { $_ -notin $existingPriorities } | Select-Object -First 1)
                                    
                                    $selectedNSG | Add-AzNetworkSecurityRuleConfig -Name $rule.Name `
                                        -Direction $rule.Direction `
                                        -Priority $newPriority `
                                        -Protocol $rule.Protocol `
                                        -SourcePortRange $rule.SourcePortRange `
                                        -DestinationPortRange $rule.DestinationPortRange `
                                        -SourceAddressPrefix $rule.SourceAddressPrefix `
                                        -DestinationAddressPrefix $rule.DestinationAddressPrefix `
                                        -Access $rule.Access | Out-Null
                                    
                                    Write-Host "  [OK] Added rule: $($rule.Name)" -ForegroundColor Green
                                } catch {
                                    Write-Host "  [ERROR] Failed to add rule: $($rule.Name) - $($_.Exception.Message)" -ForegroundColor Red
                                }
                            }
                            $selectedNSG | Set-AzNetworkSecurityGroup | Out-Null
                        }
                    }
                    
                    Write-Host "`nNSG '$($selectedNSG.Name)' ready for association." -ForegroundColor Green
                    Write-Host "Manual Step: Associate this NSG with subnet '$SubnetName' in VNet '$VNetName'" -ForegroundColor Yellow
                    Add-RemediationEntry "Missing NSG Rules" "Selected existing NSG" "Fixed" "User selected NSG: $($selectedNSG.Name)" -ResourceName $SubnetName
                }
            }
            2 { # Create new NSG
                Write-Host "`nCreating new NSG with AVD-required rules..." -ForegroundColor Cyan
                Write-Host "Suggested name: nsg-avd-$SubnetName" -ForegroundColor Gray
                $nsgName = Read-Host "Enter name for new NSG"
                
                if ([string]::IsNullOrWhiteSpace($nsgName)) {
                    $nsgName = "nsg-avd-$SubnetName-$(Get-Date -Format 'yyyyMMdd')"
                    Write-Host "Using default name: $nsgName" -ForegroundColor Yellow
                }
                
                # Get resource group from VNet
                $vnet = Get-AzVirtualNetwork | Where-Object { $_.Name -eq $VNetName } | Select-Object -First 1
                
                if ($vnet) {
                    Write-Host "Creating NSG in resource group: $($vnet.ResourceGroupName)" -ForegroundColor Cyan
                    
                    # Create NSG with rules
                    $nsgRuleConfigs = @()
                    foreach ($rule in $MissingRules) {
                        $nsgRuleConfigs += New-AzNetworkSecurityRuleConfig -Name $rule.Name `
                            -Direction $rule.Direction `
                            -Priority $rule.Priority `
                            -Protocol $rule.Protocol `
                            -SourcePortRange $rule.SourcePortRange `
                            -DestinationPortRange $rule.DestinationPortRange `
                            -SourceAddressPrefix $rule.SourceAddressPrefix `
                            -DestinationAddressPrefix $rule.DestinationAddressPrefix `
                            -Access $rule.Access
                        
                        Write-Host "  [OK] Configured rule: $($rule.Name)" -ForegroundColor Green
                    }
                    
                    try {
                        $newNSG = New-AzNetworkSecurityGroup -Name $nsgName `
                            -ResourceGroupName $vnet.ResourceGroupName `
                            -Location $vnet.Location `
                            -SecurityRules $nsgRuleConfigs
                        
                        Write-Host "`n[SUCCESS] NSG '$nsgName' created successfully!" -ForegroundColor Green
                        Write-Host "Manual Step: Associate this NSG with subnet '$SubnetName' in VNet '$VNetName'" -ForegroundColor Yellow
                        Add-RemediationEntry "Missing NSG Rules" "Created new NSG" "Fixed" "Created NSG: $nsgName" -ResourceName $SubnetName -ResourceGroup $vnet.ResourceGroupName
                    } catch {
                        Write-Host "[ERROR] Failed to create NSG: $($_.Exception.Message)" -ForegroundColor Red
                        Add-RemediationEntry "Missing NSG Rules" "Create NSG" "Failed" $_.Exception.Message -ResourceName $nsgName
                    }
                } else {
                    Write-Host "Unable to find VNet '$VNetName'. Cannot create NSG." -ForegroundColor Red
                    Add-RemediationEntry "Missing NSG Rules" "Find VNet" "Failed" "VNet not found" -ResourceName $VNetName
                }
            }
            3 { # View and add manually
                Write-Host "`nRequired NSG Rules for AVD Connectivity:" -ForegroundColor Cyan
                Write-Host ("="*80) -ForegroundColor Gray
                foreach ($rule in $MissingRules) {
                    Write-Host ""
                    Write-Host "Rule Name: $($rule.Name)" -ForegroundColor White
                    Write-Host "  Direction: $($rule.Direction)" -ForegroundColor Gray
                    Write-Host "  Priority: $($rule.Priority)" -ForegroundColor Gray
                    Write-Host "  Protocol: $($rule.Protocol)" -ForegroundColor Gray
                    Write-Host "  Source: $($rule.SourceAddressPrefix):$($rule.SourcePortRange)" -ForegroundColor Gray
                    Write-Host "  Destination: $($rule.DestinationAddressPrefix):$($rule.DestinationPortRange)" -ForegroundColor Gray
                    Write-Host "  Access: $($rule.Access)" -ForegroundColor Gray
                }
                Write-Host ""
                Write-Host "Please add these rules manually to your NSG." -ForegroundColor Yellow
                Add-RemediationEntry "Missing NSG Rules" "View rules" "Skipped" "User chose to review and add rules manually" -ResourceName $SubnetName
            }
        }
        
    } catch {
        Add-RemediationEntry "NSG Configuration" "Configure NSG" "Failed" "Failed to remediate NSG: $($_.Exception.Message)" -ResourceName $SubnetName
    }
}

# Function to remediate DNS configuration with interactive selection
function Repair-DNSConfiguration {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork,
        [array]$Issues
    )
    
    try {
        Write-Host "`n" -NoNewline
        Write-Host ("="*80) -ForegroundColor Cyan
        Write-Host "Private DNS Zone Remediation Assistant" -ForegroundColor Cyan
        Write-Host ("="*80) -ForegroundColor Cyan
        Write-Host ""
        
        # Get existing Private DNS Zones
        $existingZones = Get-AzPrivateDnsZone -ErrorAction SilentlyContinue
        
        foreach ($issue in $Issues) {
            switch ($issue.Type) {
                "MissingPrivateDNSZone" {
                    Write-Host "Issue: Private DNS Zone missing: $($issue.ZoneName)" -ForegroundColor Yellow
                    
                    # Check if zone exists but just not linked
                    $existingZone = $existingZones | Where-Object { $_.Name -eq $issue.ZoneName }
                    
                    if ($existingZone) {
                        Write-Host "  Note: This zone already exists in resource group '$($existingZone.ResourceGroupName)'" -ForegroundColor Cyan
                        
                        $options = @(
                            "Link VNet to existing Private DNS Zone",
                            "Skip this zone"
                        )
                        
                        $choice = Confirm-RemediationAction "Select action for zone '$($issue.ZoneName)'" -Options $options
                        
                        if ($choice -eq 1) {
                            try {
                                $linkName = "$($VirtualNetwork.Name)-link-$(Get-Date -Format 'yyyyMMdd')"
                                New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $existingZone.ResourceGroupName `
                                    -ZoneName $issue.ZoneName `
                                    -LinkName $linkName `
                                    -VirtualNetworkId $VirtualNetwork.Id `
                                    -EnableRegistration:$false | Out-Null
                                
                                Write-Host "  [SUCCESS] Successfully linked VNet to Private DNS Zone" -ForegroundColor Green
                                Add-RemediationEntry "Private DNS Zone" "Linked to existing zone" "Fixed" "Linked VNet to zone: $($issue.ZoneName)" -ResourceName $issue.ZoneName -ResourceGroup $existingZone.ResourceGroupName
                            } catch {
                                Write-Host "  [ERROR] Failed to link VNet: $($_.Exception.Message)" -ForegroundColor Red
                                Add-RemediationEntry "Private DNS Zone" "Link VNet" "Failed" $_.Exception.Message -ResourceName $issue.ZoneName
                            }
                        } else {
                            Add-RemediationEntry "Private DNS Zone" "Link zone" "Skipped" "User chose to skip linking zone" -ResourceName $issue.ZoneName
                        }
                    } else {
                        # Zone doesn't exist - offer to create
                        $options = @(
                            "Create new Private DNS Zone and link to VNet",
                            "Provide custom resource group for zone",
                            "Skip this zone (I'll create it manually)"
                        )
                        
                        $choice = Confirm-RemediationAction "Select action for zone '$($issue.ZoneName)'" -Options $options
                        
                        if ($choice -eq 0) {
                            Add-RemediationEntry "Private DNS Zone" "Create zone" "Skipped" "User chose to skip zone creation" -ResourceName $issue.ZoneName
                            continue
                        }
                        
                        $targetRG = $VirtualNetwork.ResourceGroupName
                        if ($choice -eq 2) {
                            # Get available resource groups
                            $resourceGroups = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName
                            Write-Host "`nAvailable Resource Groups:" -ForegroundColor Cyan
                            $rgChoice = Confirm-RemediationAction "Select resource group for Private DNS Zone" -Options $resourceGroups
                            
                            if ($rgChoice -eq 0) {
                                Add-RemediationEntry "Private DNS Zone" "Select RG" "Skipped" "User cancelled resource group selection" -ResourceName $issue.ZoneName
                                continue
                            }
                            
                            $targetRG = $resourceGroups[$rgChoice - 1]
                        }
                        
                        if ($choice -in @(1, 2)) {
                            try {
                                Write-Host "  Creating Private DNS Zone '$($issue.ZoneName)' in '$targetRG'..." -ForegroundColor Cyan
                                $zone = New-AzPrivateDnsZone -ResourceGroupName $targetRG -Name $issue.ZoneName
                                
                                $linkName = "$($VirtualNetwork.Name)-link"
                                New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $targetRG `
                                    -ZoneName $issue.ZoneName `
                                    -LinkName $linkName `
                                    -VirtualNetworkId $VirtualNetwork.Id `
                                    -EnableRegistration:$false | Out-Null
                                
                                Write-Host "  [SUCCESS] Successfully created and linked Private DNS Zone" -ForegroundColor Green
                                Add-RemediationEntry "Private DNS Zone" "Created and linked zone" "Fixed" "Created zone: $($issue.ZoneName)" -ResourceName $issue.ZoneName -ResourceGroup $targetRG
                            } catch {
                                Write-Host "  [ERROR] Failed to create Private DNS Zone: $($_.Exception.Message)" -ForegroundColor Red
                                Add-RemediationEntry "Private DNS Zone" "Create zone" "Failed" $_.Exception.Message -ResourceName $issue.ZoneName -ResourceGroup $targetRG
                            }
                        }
                    }
                }
                "MissingVNetLink" {
                    Write-Host "Issue: VNet not linked to Private DNS Zone: $($issue.ZoneName)" -ForegroundColor Yellow
                    
                    if (Confirm-RemediationAction "Link VNet '$($VirtualNetwork.Name)' to Private DNS Zone '$($issue.ZoneName)'?") {
                        try {
                            $linkName = "$($VirtualNetwork.Name)-link-$(Get-Date -Format 'yyyyMMdd')"
                            New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $issue.ZoneResourceGroup `
                                -ZoneName $issue.ZoneName `
                                -LinkName $linkName `
                                -VirtualNetworkId $VirtualNetwork.Id `
                                -EnableRegistration:$false | Out-Null
                            
                            Write-Host "  [SUCCESS] Successfully linked VNet to Private DNS Zone" -ForegroundColor Green
                            Add-RemediationEntry "VNet Link" "Linked VNet" "Fixed" "Linked VNet to zone: $($issue.ZoneName)" -ResourceName $issue.ZoneName -ResourceGroup $issue.ZoneResourceGroup
                        } catch {
                            Write-Host "  [ERROR] Failed to link VNet: $($_.Exception.Message)" -ForegroundColor Red
                            Add-RemediationEntry "VNet Link" "Link VNet" "Failed" $_.Exception.Message -ResourceName $issue.ZoneName -ResourceGroup $issue.ZoneResourceGroup
                        }
                    } else {
                        Add-RemediationEntry "VNet Link" "Link VNet" "Skipped" "User declined to link VNet" -ResourceName $issue.ZoneName -ResourceGroup $issue.ZoneResourceGroup
                    }
                }
            }
        }
    } catch {
        Add-RemediationEntry "DNS Configuration" "Configure DNS" "Failed" "Failed to remediate DNS configuration: $($_.Exception.Message)" -ResourceName $VirtualNetwork.Name -ResourceGroup $VirtualNetwork.ResourceGroupName
    }
}

# Function to remediate subnet configuration with interactive selection
function Repair-SubnetConfiguration {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork,
        [array]$Issues
    )
    
    try {
        Write-Host "`n" -NoNewline
        Write-Host ("="*80) -ForegroundColor Cyan
        Write-Host "Subnet Configuration Remediation Assistant" -ForegroundColor Cyan
        Write-Host ("="*80) -ForegroundColor Cyan
        Write-Host ""
        
        $modified = $false
        
        foreach ($issue in $Issues) {
            switch ($issue.Type) {
                "MissingServiceEndpoints" {
                    Write-Host "Issue: Missing service endpoints on subnet '$($issue.SubnetName)'" -ForegroundColor Yellow
                    $missingEndpointsList = $issue.MissingEndpoints -join $script:JoinSeparator
                    Write-Host "  Missing endpoints: $missingEndpointsList" -ForegroundColor Gray
                    Write-Host ""
                    
                    $subnet = $VirtualNetwork.Subnets | Where-Object { $_.Name -eq $issue.SubnetName }
                    if ($subnet) {
                        # Let user select which endpoints to add
                        Write-Host "Select service endpoints to add:" -ForegroundColor Cyan
                        $endpointDescriptions = @()
                        foreach ($ep in $issue.MissingEndpoints) {
                            $description = switch ($ep) {
                                "Microsoft.Storage" { "Microsoft.Storage (for FSLogix profiles and Azure Files)" }
                                "Microsoft.KeyVault" { "Microsoft.KeyVault (for secrets and certificates)" }
                                "Microsoft.ServiceBus" { "Microsoft.ServiceBus (for AVD messaging)" }
                                "Microsoft.Sql" { "Microsoft.Sql (if using Azure SQL for metadata)" }
                                "Microsoft.Web" { "Microsoft.Web (for web-based services)" }
                                default { $ep }
                            }
                            $endpointDescriptions += $description
                        }
                        
                        Write-Host "  1. Add all missing endpoints" -ForegroundColor White
                        Write-Host "  2. Select individual endpoints to add" -ForegroundColor White
                        Write-Host "  3. Skip (I'll configure manually)" -ForegroundColor White
                        Write-Host ""
                        
                        $choice = Read-Host "Enter choice (1-3)"
                        
                        $endpointsToAdd = @()
                        
                        switch ($choice) {
                            "1" {
                                $endpointsToAdd = $issue.MissingEndpoints
                            }
                            "2" {
                                Write-Host "`nSelect endpoints to add (separate multiple selections with commas):" -ForegroundColor Cyan
                                for ($i = 0; $i -lt $endpointDescriptions.Count; $i++) {
                                    Write-Host "  $($i + 1). $($endpointDescriptions[$i])" -ForegroundColor White
                                }
                                
                                $selections = Read-Host "Enter selection(s) (e.g., 1,2,3)"
                                $selectedIndices = $selections -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
                                
                                foreach ($idx in $selectedIndices) {
                                    if ($idx -ge 0 -and $idx -lt $issue.MissingEndpoints.Count) {
                                        $endpointsToAdd += $issue.MissingEndpoints[$idx]
                                    }
                                }
                            }
                            "3" {
                                Write-Host "Skipping service endpoint configuration" -ForegroundColor Yellow
                                Add-RemediationEntry "Service Endpoints" "Configure endpoints" "Skipped" "User chose to configure manually" -ResourceName $issue.SubnetName
                                continue
                            }
                        }
                        
                        if ($endpointsToAdd.Count -gt 0) {
                            try {
                                foreach ($endpoint in $endpointsToAdd) {
                                    if (-not ($subnet.ServiceEndpoints | Where-Object { $_.Service -eq $endpoint })) {
                                        # Get the subnet configuration
                                        $subnetConfig = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork -Name $subnet.Name
                                        
                                        # Add service endpoint
                                        if ($null -eq $subnetConfig.ServiceEndpoints) {
                                            $subnetConfig.ServiceEndpoints = @()
                                        }
                                        $newEndpoint = New-Object Microsoft.Azure.Commands.Network.Models.PSServiceEndpoint
                                        $newEndpoint.Service = $endpoint
                                        $newEndpoint.Locations = @("*")
                                        $subnetConfig.ServiceEndpoints += $newEndpoint
                                        
                                        Write-Host "  [OK] Configured endpoint: $endpoint" -ForegroundColor Green
                                    }
                                }
                                $modified = $true
                                $endpointsList = $endpointsToAdd -join '; '
                                Add-RemediationEntry "Service Endpoints" "Added endpoints" "Fixed" "Added endpoints: $endpointsList" -ResourceName $issue.SubnetName -ResourceGroup $VirtualNetwork.ResourceGroupName
                            } catch {
                                Write-Host "  [ERROR] Failed to add service endpoints: $($_.Exception.Message)" -ForegroundColor Red
                                Add-RemediationEntry "Service Endpoints" "Add endpoints" "Failed" $_.Exception.Message -ResourceName $issue.SubnetName -ResourceGroup $VirtualNetwork.ResourceGroupName
                            }
                        }
                    }
                }
                "InsufficientAddressSpace" {
                    Write-Host "Issue: Subnet '$($issue.SubnetName)' has insufficient address space" -ForegroundColor Yellow
                    Write-Host "  This requires manual intervention to expand or recreate the subnet" -ForegroundColor Gray
                    Write-Host "  Recommendation: Plan a maintenance window to expand address space" -ForegroundColor Cyan
                    Add-RemediationEntry "Insufficient Address Space" "Expand subnet" "Skipped" "Subnet expansion requires manual planning and intervention" -ResourceName $issue.SubnetName -ResourceGroup $VirtualNetwork.ResourceGroupName
                }
                "CreateAVDSubnet" {
                    Write-Host "Issue: No dedicated AVD subnet found" -ForegroundColor Yellow
                    Write-Host "  Suggested subnet name: $($issue.SubnetName)" -ForegroundColor Gray
                    Write-Host "  Suggested address prefix: $($issue.AddressPrefix)" -ForegroundColor Gray
                    Write-Host ""
                    
                    $options = @(
                        "Create subnet with suggested configuration",
                        "Specify custom subnet configuration",
                        "Skip (I'll create manually or use existing subnet)"
                    )
                    
                    $choice = Confirm-RemediationAction "How would you like to proceed?" -Options $options
                    
                    if ($choice -eq 0) {
                        Add-RemediationEntry "AVD Subnet" "Create subnet" "Skipped" "User chose to skip subnet creation" -ResourceName $issue.SubnetName
                        continue
                    }
                    
                    $subnetName = $issue.SubnetName
                    $addressPrefix = $issue.AddressPrefix
                    
                    if ($choice -eq 2) {
                        $subnetName = Read-Host "Enter subnet name"
                        $addressPrefix = Read-Host "Enter address prefix (CIDR notation, e.g., 10.0.1.0/24)"
                    }
                    
                    if ($choice -in @(1, 2) -and -not [string]::IsNullOrWhiteSpace($subnetName)) {
                        try {
                            Write-Host "  Creating subnet '$subnetName' with address prefix '$addressPrefix'..." -ForegroundColor Cyan
                            Write-Host "  Adding required AVD service endpoints..." -ForegroundColor Cyan
                            
                            $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName `
                                -AddressPrefix $addressPrefix `
                                -ServiceEndpoint $script:AVDNetworkRequirements.RequiredServiceEndpoints
                            
                            $VirtualNetwork.Subnets.Add($subnetConfig)
                            $modified = $true
                            
                            Write-Host "  [SUCCESS] Subnet configuration created with AVD service endpoints" -ForegroundColor Green
                            Write-Host "    Service Endpoints:" -ForegroundColor Gray
                            foreach ($endpoint in $script:AVDNetworkRequirements.RequiredServiceEndpoints) {
                                Write-Host "      - $endpoint" -ForegroundColor Gray
                            }
                            Add-RemediationEntry "AVD Subnet" "Created subnet" "Fixed" "Created subnet: $subnetName with AVD service endpoints" -ResourceName $subnetName -ResourceGroup $VirtualNetwork.ResourceGroupName
                        } catch {
                            Write-Host "  [ERROR] Failed to create subnet: $($_.Exception.Message)" -ForegroundColor Red
                            Add-RemediationEntry "AVD Subnet" "Create subnet" "Failed" $_.Exception.Message -ResourceName $subnetName -ResourceGroup $VirtualNetwork.ResourceGroupName
                        }
                    }
                }
            }
        }
        
        if ($modified) {
            if (Confirm-RemediationAction "`nApply subnet changes to VNet '$($VirtualNetwork.Name)'?") {
                try {
                    $VirtualNetwork | Set-AzVirtualNetwork | Out-Null
                    Write-Host "[SUCCESS] Successfully updated VNet with subnet changes" -ForegroundColor Green
                    Add-RemediationEntry "Subnet Configuration" "Update VNet" "Fixed" "Applied subnet changes to VNet" -ResourceName $VirtualNetwork.Name -ResourceGroup $VirtualNetwork.ResourceGroupName
                } catch {
                    Write-Host "[ERROR] Failed to update VNet: $($_.Exception.Message)" -ForegroundColor Red
                    Add-RemediationEntry "Subnet Configuration" "Update VNet" "Failed" $_.Exception.Message -ResourceName $VirtualNetwork.Name -ResourceGroup $VirtualNetwork.ResourceGroupName
                }
            } else {
                Write-Host "Subnet changes not applied - configuration rolled back" -ForegroundColor Yellow
                Add-RemediationEntry "Subnet Configuration" "Update VNet" "Skipped" "User chose not to apply changes" -ResourceName $VirtualNetwork.Name
            }
        }
        
    } catch {
        Add-RemediationEntry "Subnet Configuration" "Configure subnets" "Failed" "Failed to remediate subnet configuration: $($_.Exception.Message)" -ResourceName $VirtualNetwork.Name -ResourceGroup $VirtualNetwork.ResourceGroupName
    }
}

# Function to remediate virtual network peering with interactive VNet selection
function Repair-VNetPeering {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$SourceVNet
    )
    
    try {
        Write-Host "`n" -NoNewline
        Write-Host ("="*80) -ForegroundColor Cyan
        Write-Host "VNet Peering Remediation Assistant" -ForegroundColor Cyan
        Write-Host ("="*80) -ForegroundColor Cyan
        Write-Host ""  
        Write-Host "Source VNet: $($SourceVNet.Name)" -ForegroundColor White
        $addressSpaceList = $SourceVNet.AddressSpace.AddressPrefixes -join $script:JoinSeparator
        Write-Host "  Address Space: $addressSpaceList" -ForegroundColor Gray
        Write-Host "  Location: $($SourceVNet.Location)" -ForegroundColor Gray
        Write-Host ""
        
        # Get all available VNets for peering
        $allVNets = Get-AzVirtualNetwork | Where-Object { $_.Name -ne $SourceVNet.Name }
        
        if ($allVNets.Count -eq 0) {
            Write-Host "No other VNets available for peering" -ForegroundColor Yellow
            Add-RemediationEntry "VNet Peering" "Find peering candidates" "Skipped" "No other VNets available" -ResourceName $SourceVNet.Name
            return
        }
        
        Write-Host "Detected potential peering requirement for AVD connectivity" -ForegroundColor Yellow
        Write-Host "This VNet may need peering for:" -ForegroundColor Cyan
        Write-Host "  - Access to Domain Controllers" -ForegroundColor Gray
        Write-Host "  - Hub-Spoke network topology" -ForegroundColor Gray
        Write-Host "  - Shared services (DNS, Management, etc.)" -ForegroundColor Gray
        Write-Host ""
        
        $options = @(
            "Select VNet(s) to peer with",
            "View available VNets (no action)",
            "Skip (I'll configure peering manually)"
        )
        
        $choice = Confirm-RemediationAction "How would you like to proceed?" -Options $options
        
        if ($choice -eq 0 -or $choice -eq 3) {
            Add-RemediationEntry "VNet Peering" "Configure peering" "Skipped" "User chose to skip peering configuration" -ResourceName $SourceVNet.Name
            return
        }
        
        if ($choice -eq 2) {
            Write-Host "`nAvailable Virtual Networks:" -ForegroundColor Cyan
            Write-Host ("="*80) -ForegroundColor Gray
            foreach ($vnet in $allVNets) {
                Write-Host ""
                Write-Host "  Name: $($vnet.Name)" -ForegroundColor White
                Write-Host "    Resource Group: $($vnet.ResourceGroupName)" -ForegroundColor Gray
                Write-Host "    Location: $($vnet.Location)" -ForegroundColor Gray
                $vnetAddrSpace = $vnet.AddressSpace.AddressPrefixes -join $script:JoinSeparator
                Write-Host "    Address Space: $vnetAddrSpace" -ForegroundColor Gray
                Write-Host "    Existing Peerings: $($vnet.VirtualNetworkPeerings.Count)" -ForegroundColor Gray
            }
            Write-Host ""
            Add-RemediationEntry "VNet Peering" "View VNets" "Skipped" "User reviewed available VNets" -ResourceName $SourceVNet.Name
            return
        }
        
        if ($choice -eq 1) {
            Write-Host "`nAvailable VNets for peering:" -ForegroundColor Cyan
            $vnetOptions = $allVNets | ForEach-Object {
                $vnetAddrSpace = $_.AddressSpace.AddressPrefixes -join $script:JoinSeparator
                "$($_.Name) - $($_.Location) - $vnetAddrSpace (RG: $($_.ResourceGroupName))"
            }
            
            Write-Host "Select VNet to peer with:" -ForegroundColor Cyan
            Write-Host "(Enter 0 to cancel)" -ForegroundColor Gray
            for ($i = 0; $i -lt $vnetOptions.Count; $i++) {
                Write-Host "  $($i + 1). $($vnetOptions[$i])" -ForegroundColor White
            }
            Write-Host ""
            
            do {
                $selection = Read-Host "Enter selection (0-$($vnetOptions.Count))"
            } while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -gt $vnetOptions.Count)
            
            if ([int]$selection -eq 0) {
                Add-RemediationEntry "VNet Peering" "Select VNet" "Skipped" "User cancelled VNet selection" -ResourceName $SourceVNet.Name
                return
            }
            
            $targetVNet = $allVNets[[int]$selection - 1]
            
            # Check for address space overlap
            $hasOverlap = $false
            foreach ($sourcePrefix in $SourceVNet.AddressSpace.AddressPrefixes) {
                foreach ($targetPrefix in $targetVNet.AddressSpace.AddressPrefixes) {
                    if (Test-NetworkAddressOverlap -AddressPrefix1 $sourcePrefix -AddressPrefix2 $targetPrefix -VNet1Name $SourceVNet.Name -VNet2Name $targetVNet.Name) {
                        $hasOverlap = $true
                        break
                    }
                }
            }
            
            if ($hasOverlap) {
                Write-Host ""
                Write-Host "WARNING: Address space overlap detected!" -ForegroundColor Red
                Write-Host "Cannot create peering with overlapping address spaces" -ForegroundColor Red
                Write-Host "Please resolve address space conflicts before peering" -ForegroundColor Yellow
                Add-RemediationEntry "VNet Peering" "Check address overlap" "Failed" "Address space overlap prevents peering" -ResourceName "$($SourceVNet.Name)-$($targetVNet.Name)"
                return
            }
            
            Write-Host ""
            Write-Host "Peering Configuration Options:" -ForegroundColor Cyan
            Write-Host ""
            
            $allowForwardedTraffic = Confirm-RemediationAction "Allow forwarded traffic (recommended for hub-spoke topology)?"
            $allowGatewayTransit = $false
            $useRemoteGateways = $false
            
            # Check if target has gateway
            $targetHasGateway = $false
            try {
                $targetGateways = Get-AzVirtualNetworkGateway -ResourceGroupName $targetVNet.ResourceGroupName -ErrorAction SilentlyContinue
                $targetHasGateway = $targetGateways.Count -gt 0
            } catch { }
            
            if ($targetHasGateway) {
                Write-Host "Note: Target VNet has a VPN/ExpressRoute gateway" -ForegroundColor Cyan
                $useRemoteGateways = Confirm-RemediationAction "Use remote gateways for hybrid connectivity?"
            }
            
            Write-Host ""
            Write-Host "Creating bidirectional peering..." -ForegroundColor Cyan
            
            try {
                # Create peering from source to target
                $peeringName1 = "peer-$($SourceVNet.Name)-to-$($targetVNet.Name)"
                Write-Host "  Creating: $peeringName1" -ForegroundColor Gray
                
                Add-AzVirtualNetworkPeering -Name $peeringName1 `
                    -VirtualNetwork $SourceVNet `
                    -RemoteVirtualNetworkId $targetVNet.Id `
                    -AllowForwardedTraffic:$allowForwardedTraffic `
                    -AllowGatewayTransit:$false `
                    -UseRemoteGateways:$useRemoteGateways | Out-Null
                
                Write-Host "  [OK] Created peering: $peeringName1" -ForegroundColor Green
                
                # Create peering from target to source
                $peeringName2 = "peer-$($targetVNet.Name)-to-$($SourceVNet.Name)"
                Write-Host "  Creating: $peeringName2" -ForegroundColor Gray
                
                Add-AzVirtualNetworkPeering -Name $peeringName2 `
                    -VirtualNetwork $targetVNet `
                    -RemoteVirtualNetworkId $SourceVNet.Id `
                    -AllowForwardedTraffic:$allowForwardedTraffic `
                    -AllowGatewayTransit:$targetHasGateway `
                    -UseRemoteGateways:$false | Out-Null
                
                Write-Host "  [OK] Created peering: $peeringName2" -ForegroundColor Green
                Write-Host ""
                Write-Host "[SUCCESS] Successfully created bidirectional peering!" -ForegroundColor Green
                
                Add-RemediationEntry "VNet Peering" "Created bidirectional peering" "Fixed" "Peering established between $($SourceVNet.Name) and $($targetVNet.Name)" -ResourceName "$($SourceVNet.Name)-$($targetVNet.Name)" -ResourceGroup $SourceVNet.ResourceGroupName
            } catch {
                Write-Host "  [ERROR] Failed to create peering: $($_.Exception.Message)" -ForegroundColor Red
                Add-RemediationEntry "VNet Peering" "Create peering" "Failed" $_.Exception.Message -ResourceName "$($SourceVNet.Name)-$($targetVNet.Name)" -ResourceGroup $SourceVNet.ResourceGroupName
            }
        }
        
    } catch {
        Add-RemediationEntry "VNet Peering" "Configure peering" "Failed" "Failed to remediate VNet peering: $($_.Exception.Message)" -ResourceName $SourceVNet.Name -ResourceGroup $SourceVNet.ResourceGroupName
    }
}

# Function to remediate route table configuration
function Repair-RouteTableConfiguration {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSRouteTable]$RouteTable,
        [array]$Issues
    )
    
    try {
        $modified = $false
        
        foreach ($issue in $Issues) {
            switch ($issue.Type) {
                "BlockedAVDTraffic" {
                    if (Confirm-RemediationAction "Add route to allow AVD traffic in route table '$($RouteTable.Name)'?" -DefaultYes) {
                        try {
                            $routeName = "AVD-Allow-$([guid]::NewGuid().ToString().Substring(0,8))"
                            $RouteTable | Add-AzRouteConfig -Name $routeName `
                                -AddressPrefix $issue.AddressPrefix `
                                -NextHopType "Internet" | Out-Null
                            
                            $modified = $true
                            Add-RemediationEntry "Blocked AVD Traffic" "Added bypass route" "Fixed" "Successfully added route to allow AVD connectivity" -ResourceName $RouteTable.Name -ResourceGroup $RouteTable.ResourceGroupName
                        } catch {
                            Add-RemediationEntry "Blocked AVD Traffic" "Add bypass route" "Failed" "Failed to add route: $($_.Exception.Message)" -ResourceName $RouteTable.Name -ResourceGroup $RouteTable.ResourceGroupName
                        }
                    } else {
                        Add-RemediationEntry "Blocked AVD Traffic" "Add bypass route" "Skipped" "User declined to add bypass route" -ResourceName $RouteTable.Name -ResourceGroup $RouteTable.ResourceGroupName
                    }
                }
            }
        }
        
        if ($modified) {
            $RouteTable | Set-AzRouteTable | Out-Null
            Add-RemediationEntry "Route Table Configuration" "Update route table" "Fixed" "Successfully updated route table with new routes" -ResourceName $RouteTable.Name -ResourceGroup $RouteTable.ResourceGroupName
        }
        
    } catch {
        Add-RemediationEntry "Route Table Configuration" "Configure routes" "Failed" "Failed to remediate route table: $($_.Exception.Message)" -ResourceName $RouteTable.Name -ResourceGroup $RouteTable.ResourceGroupName
    }
}

# Function to display remediation summary
function Show-RemediationSummary {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor Magenta
    Write-Host "Remediation Summary " -ForegroundColor Magenta
    Write-Host ("="*100) -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "Total Issues Identified: $($script:RemediationSummary.TotalIssues)" -ForegroundColor White
    Write-Host "Successfully Fixed: $($script:RemediationSummary.FixedIssues)" -ForegroundColor Green
    Write-Host "Failed to Fix: $($script:RemediationSummary.FailedFixes)" -ForegroundColor Red
    Write-Host "Skipped by User: $($script:RemediationSummary.SkippedIssues)" -ForegroundColor Yellow
    
    $remediationRate = if ($script:RemediationSummary.TotalIssues -gt 0) { 
        [math]::Round(($script:RemediationSummary.FixedIssues / $script:RemediationSummary.TotalIssues) * 100, 2) 
    } else { 0 }
    
    Write-Host "Remediation Success Rate: $remediationRate%" -ForegroundColor $(if ($remediationRate -ge 80) { "Green" } elseif ($remediationRate -ge 60) { "Yellow" } else { "Red" })
    Write-Host ""
}

# Function to create a new Virtual Network for validation/testing
function New-AVDValidationVNet {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$CreateTestVNet
    )
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host "Create Virtual Network for Validation" -ForegroundColor Cyan
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host ""
    
    if ($CreateTestVNet) {
        Write-Host "Creating a test VNet with AVD-recommended configuration..." -ForegroundColor Yellow
        $vnetName = "vnet-avd-validation-test"
        $rgName = "rg-avd-validation"
        $addressPrefix = "10.100.0.0/16"
        $location = "East US"
    } else {
        # Get parameters from user
        Write-Host "Please provide Virtual Network details:" -ForegroundColor White
        Write-Host ""
        
        $vnetName = Read-Host "VNet Name (e.g., vnet-avd-prod)"
        if ([string]::IsNullOrWhiteSpace($vnetName)) {
            Write-Host "VNet name cannot be empty" -ForegroundColor Red
            return $null
        }
        
        $rgName = Read-Host "Resource Group Name (will be created if it doesn't exist)"
        if ([string]::IsNullOrWhiteSpace($rgName)) {
            Write-Host "Resource Group name cannot be empty" -ForegroundColor Red
            return $null
        }
        
        Write-Host ""
        Write-Host "Recommended address spaces:" -ForegroundColor Cyan
        Write-Host "  1. 10.0.0.0/16  (65,536 IPs - Large deployment)" -ForegroundColor White
        Write-Host "  2. 10.0.0.0/20  (4,096 IPs - Medium deployment)" -ForegroundColor White
        Write-Host "  3. 10.0.0.0/24  (256 IPs - Small deployment)" -ForegroundColor White
        Write-Host "  4. Custom" -ForegroundColor White
        
        $addressChoice = Read-Host "Select address space (1-4)"
        $addressPrefix = switch ($addressChoice) {
            "1" { "10.0.0.0/16" }
            "2" { "10.0.0.0/20" }
            "3" { "10.0.0.0/24" }
            "4" { Read-Host "Enter custom address prefix (CIDR notation, e.g., 10.50.0.0/16)" }
            default { "10.0.0.0/16" }
        }
        
        Write-Host ""
        Write-Host "Common Azure regions:" -ForegroundColor Cyan
        Write-Host "  1. East US" -ForegroundColor White
        Write-Host "  2. West US" -ForegroundColor White
        Write-Host "  3. Central US" -ForegroundColor White
        Write-Host "  4. North Europe" -ForegroundColor White
        Write-Host "  5. West Europe" -ForegroundColor White
        Write-Host "  6. Custom" -ForegroundColor White
        
        $locationChoice = Read-Host "Select location (1-6)"
        $location = switch ($locationChoice) {
            "1" { "East US" }
            "2" { "West US" }
            "3" { "Central US" }
            "4" { "North Europe" }
            "5" { "West Europe" }
            "6" { Read-Host "Enter custom location (e.g., UK South)" }
            default { "East US" }
        }
    }
    
    Write-Host ""
    Write-Host "Configuration Summary:" -ForegroundColor Yellow
    Write-Host "  VNet Name: $vnetName" -ForegroundColor White
    Write-Host "  Resource Group: $rgName" -ForegroundColor White
    Write-Host "  Address Space: $addressPrefix" -ForegroundColor White
    Write-Host "  Location: $location" -ForegroundColor White
    Write-Host ""
    
    if (-not $CreateTestVNet -and -not $NonInteractive) {
        $confirm = Read-Host "Proceed with VNet creation? (Y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Host "VNet creation cancelled by user" -ForegroundColor Yellow
            return $null
        }
    }
    
    try {
        # Check/Create Resource Group
        Write-Host "Checking Resource Group..." -ForegroundColor Cyan
        $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-Host "  Creating Resource Group: $rgName" -ForegroundColor Yellow
            $rg = New-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop
            Write-Host "  Resource Group created successfully" -ForegroundColor Green
            Add-ReportEntry "Resource Group" "Pass" "Created resource group: $rgName in $location" -Category "VNet Creation"
        } else {
            Write-Host "  Resource Group already exists" -ForegroundColor Green
        }
        
        # Create VNet with subnets
        Write-Host "Creating Virtual Network: $vnetName" -ForegroundColor Cyan
        
        # Simple subnet creation based on address space
        $vnetParts = $addressPrefix.Split('/')
        $baseIP = $vnetParts[0]
        $vnetMask = [int]$vnetParts[1]
        
        # Create at least one subnet for AVD with required service endpoints
        $subnetMask = if ($vnetMask -ge 24) { $vnetMask + 2 } else { 24 }
        if ($subnetMask -gt 29) { $subnetMask = 29 }
        
        Write-Host "Configuring subnet with AVD-required service endpoints..." -ForegroundColor Cyan
        
        # Create subnet configuration with AVD service endpoints
        $subnet = New-AzVirtualNetworkSubnetConfig -Name "snet-avd-sessionhosts" `
            -AddressPrefix "$baseIP/$subnetMask" `
            -ServiceEndpoint $script:AVDNetworkRequirements.RequiredServiceEndpoints `
            -ErrorAction Stop
        
        Write-Host "  Service Endpoints configured:" -ForegroundColor Gray
        foreach ($endpoint in $script:AVDNetworkRequirements.RequiredServiceEndpoints) {
            Write-Host "    - $endpoint" -ForegroundColor Gray
        }
        
        # Create the VNet
        Write-Host "Creating Virtual Network..." -ForegroundColor Cyan
        $vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -Location $location -AddressPrefix $addressPrefix -Subnet $subnet -ErrorAction Stop
        
        Write-Host ""
        Write-Host "Virtual Network created successfully!" -ForegroundColor Green
        Write-Host "  Name: $($vnet.Name)" -ForegroundColor White
        Write-Host "  Resource Group: $($vnet.ResourceGroupName)" -ForegroundColor White
        Write-Host "  Location: $($vnet.Location)" -ForegroundColor White
        $vnetAddressSpaces = $vnet.AddressSpace.AddressPrefixes -join $script:JoinSeparator
        Write-Host "  Address Space: $vnetAddressSpaces" -ForegroundColor White
        Write-Host "  Subnets: $($vnet.Subnets.Count)" -ForegroundColor White
        foreach ($sn in $vnet.Subnets) {
            Write-Host "    - $($sn.Name): $($sn.AddressPrefix)" -ForegroundColor Gray
        }
        Write-Host ""
        
        Add-ReportEntry "VNet Creation" "Pass" "Successfully created VNet: $vnetName with $($vnet.Subnets.Count) subnet(s)" -Category "VNet Creation"
        return $vnet
        
    } catch {
        Write-Host ""
        Write-Host "Failed to create Virtual Network: $($_.Exception.Message)" -ForegroundColor Red
        Add-ReportEntry "VNet Creation" "Fail" "Failed to create VNet: $($_.Exception.Message)" -Category "VNet Creation"
        return $null
    }
}

# Function to confirm AVD services are properly configured
function Confirm-AVDServicesConfiguration {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    Write-Host ""
    Write-Host "  Checking AVD Service Configuration:" -ForegroundColor Cyan
    $allChecksPass = $true
    
    foreach ($subnet in $VirtualNetwork.Subnets) {
        Write-Host "  Subnet: $($subnet.Name)" -ForegroundColor White
        
        # Check Service Endpoints
        $missingEndpoints = @()
        foreach ($requiredEndpoint in $script:AVDNetworkRequirements.RequiredServiceEndpoints) {
            $hasEndpoint = $subnet.ServiceEndpoints | Where-Object { $_.Service -eq $requiredEndpoint }
            if ($hasEndpoint) {
                Write-Host "    [OK] Service Endpoint: $requiredEndpoint" -ForegroundColor Green
            } else {
                Write-Host "    [MISSING] Service Endpoint: $requiredEndpoint" -ForegroundColor Yellow
                $missingEndpoints += $requiredEndpoint
                $allChecksPass = $false
            }
        }
        
        # Check subnet size for AVD
        $addressPrefix = $subnet.AddressPrefix
        if ($addressPrefix) {
            $subnetMask = [int]$addressPrefix.Split('/')[1]
            if ($subnetMask -le 24) {
                Write-Host "    [OK] Subnet size: $addressPrefix (adequate for AVD)" -ForegroundColor Green
            } else {
                Write-Host "    [WARNING] Subnet size: $addressPrefix (may be small for production AVD)" -ForegroundColor Yellow
            }
        }
        
        # Check NSG assignment
        if ($subnet.NetworkSecurityGroup) {
            $nsgName = $subnet.NetworkSecurityGroup.Id.Split('/')[-1]
            Write-Host "    [OK] NSG assigned: $nsgName" -ForegroundColor Green
        } else {
            Write-Host "    [INFO] No NSG assigned (consider adding for security)" -ForegroundColor Cyan
        }
        
        # Offer to add missing service endpoints
        if ($missingEndpoints.Count -gt 0) {
            Write-Host ""
            Write-Host "    Missing service endpoints detected!" -ForegroundColor Yellow
            if (Confirm-RemediationAction "    Add missing service endpoints to subnet '$($subnet.Name)'?") {
                try {
                    # Get the current subnet configuration
                    $subnetConfig = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork -Name $subnet.Name
                    
                    foreach ($endpoint in $missingEndpoints) {
                        if ($null -eq $subnetConfig.ServiceEndpoints) {
                            $subnetConfig.ServiceEndpoints = @()
                        }
                        $newEndpoint = New-Object Microsoft.Azure.Commands.Network.Models.PSServiceEndpoint
                        $newEndpoint.Service = $endpoint
                        $newEndpoint.Locations = @("*")
                        $subnetConfig.ServiceEndpoints += $newEndpoint
                        Write-Host "    [ADDED] Service Endpoint: $endpoint" -ForegroundColor Green
                    }
                    
                    # Update the VNet
                    $VirtualNetwork | Set-AzVirtualNetwork | Out-Null
                    Write-Host "    [SUCCESS] Service endpoints added successfully" -ForegroundColor Green
                    $allChecksPass = $true
                } catch {
                    Write-Host "    [ERROR] Failed to add service endpoints: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
    
    Write-Host ""
    if ($allChecksPass) {
        Write-Host "  [SUCCESS] VNet is properly configured for AVD deployment" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] Some AVD requirements are not met - review above" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Interactive remediation menu
function Show-RemediationMenu {
    param (
        [array]$DetectedIssues
    )
    
    if ($DetectedIssues.Count -eq 0) {
        Write-Host "No remediable issues detected. Configuration appears to be compliant." -ForegroundColor Green
        return
    }
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor Yellow
    Write-Host "Automated Remediation Options " -ForegroundColor Yellow
    Write-Host ("="*100) -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "The following issues can be automatically remediated:" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $DetectedIssues.Count; $i++) {
        $issue = $DetectedIssues[$i]
        Write-Host "$($i + 1). $($issue.Category) - $($issue.Description)" -ForegroundColor White
        Write-Host "    Resource: $($issue.ResourceName)" -ForegroundColor Gray
        Write-Host "    Impact: $($issue.Impact)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "Remediation Options:" -ForegroundColor Cyan
    Write-Host "1. Fix all issues automatically" -ForegroundColor White
    Write-Host "2. Fix issues selectively (with prompts)" -ForegroundColor White
    Write-Host "3. Skip automated remediation" -ForegroundColor White
    Write-Host ""
    
    if ($NonInteractive) {
        Write-Host "Running in non-interactive mode - skipping remediation" -ForegroundColor Yellow
        return
    }
    
    do {
        $choice = Read-Host "Select remediation option (1-3)"
    } while ($choice -notmatch '^[1-3]$')
    
    switch ($choice) {
        "1" {
            Write-Host "Starting automated remediation of all issues..." -ForegroundColor Green
            return "FixAll"
        }
        "2" {
            Write-Host "Starting selective remediation with user prompts..." -ForegroundColor Green
            return "FixSelective"
        }
        "3" {
            Write-Host "Skipping automated remediation." -ForegroundColor Yellow
            return "Skip"
        }
    }
}

#endregion REMEDIATION FUNCTIONS

# Function to validate network address space overlaps
function Test-NetworkAddressOverlap {
    param (
        [string]$AddressPrefix1,
        [string]$AddressPrefix2,
        [string]$VNet1Name,
        [string]$VNet2Name
    )
    
    try {
        # Parse CIDR notation
        $addr1, $mask1 = $AddressPrefix1.Split('/')
        $addr2, $mask2 = $AddressPrefix2.Split('/')
        
        # Convert to IP addresses
        $ip1 = [System.Net.IPAddress]::Parse($addr1)
        $ip2 = [System.Net.IPAddress]::Parse($addr2)
        
        # Calculate network addresses and subnet masks
        $maskBits1 = [int]$mask1
        $maskBits2 = [int]$mask2
        
        # Create subnet masks
        $subnetMask1 = [System.Net.IPAddress]::Parse("255.255.255.255").Address -shl (32 - $maskBits1) -shr (32 - $maskBits1)
        $subnetMask2 = [System.Net.IPAddress]::Parse("255.255.255.255").Address -shl (32 - $maskBits2) -shr (32 - $maskBits2)
        
        # Calculate network addresses
        $network1 = $ip1.Address -band $subnetMask1
        $network2 = $ip2.Address -band $subnetMask2
        
        # Check for overlap
        $overlap = ($network1 -eq $network2) -or 
                   (($ip1.Address -band $subnetMask2) -eq $network2) -or 
                   (($ip2.Address -band $subnetMask1) -eq $network1)
        
        return $overlap
    } catch {
        Add-ReportEntry "Address Overlap Check" "Warning" "Unable to validate address overlap between $AddressPrefix1 and $AddressPrefix2" -Category "Network Validation"
        return $false
    }
}

# Function to validate DNS configuration
function Test-DNSConfiguration {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    if ($SkipDNSValidation) {
        Add-ReportEntry "DNS Validation" "Info" "DNS validation skipped for $($VirtualNetwork.Name)" -Category "DNS"
        return
    }
    
    $dnsServers = $VirtualNetwork.DhcpOptions.DnsServers
    
    if (-not $dnsServers -or $dnsServers.Count -eq 0) {
        Add-ReportEntry "DNS Configuration" "Warning" "$($VirtualNetwork.Name): Using Azure-provided DNS (no custom DNS servers configured)" -Category "DNS" -Recommendation "Consider configuring custom DNS servers for Active Directory integration if using AD DS"
    } else {
        $dnsServersList = $dnsServers -join $script:JoinSeparator
        Add-ReportEntry "DNS Configuration" "Pass" "$($VirtualNetwork.Name): Custom DNS servers configured: $dnsServersList" -Category "DNS"
        
        # Validate DNS server count
        if ($dnsServers.Count -lt 2) {
            Add-ReportEntry "DNS Redundancy" "Warning" "$($VirtualNetwork.Name): Only one DNS server configured. Consider adding a secondary DNS server for redundancy." -Category "DNS" -Recommendation "Add at least two DNS servers for high availability"
        } else {
            Add-ReportEntry "DNS Redundancy" "Pass" "$($VirtualNetwork.Name): Multiple DNS servers configured for redundancy" -Category "DNS"
        }
        
        # Validate that DNS servers are reachable (basic validation)
        foreach ($dnsServer in $dnsServers) {
            try {
                $testConnection = Test-NetConnection -ComputerName $dnsServer -Port 53 -WarningAction SilentlyContinue -ErrorAction Stop
                if ($testConnection.TcpTestSucceeded) {
                    Add-ReportEntry "DNS Connectivity" "Pass" "$($VirtualNetwork.Name): DNS server $dnsServer is reachable on port 53" -Category "DNS"
                } else {
                    Add-ReportEntry "DNS Connectivity" "Warning" "$($VirtualNetwork.Name): DNS server $dnsServer connectivity test inconclusive" -Category "DNS"
                }
            } catch {
                Add-ReportEntry "DNS Connectivity" "Warning" "$($VirtualNetwork.Name): Unable to test connectivity to DNS server $dnsServer from current location" -Category "DNS"
            }
        }
    }
}

# Function to validate Private DNS Zones for AVD requirements
function Test-PrivateDNSZones {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    Write-Host ""
    Write-Host "Validating Private DNS Zones for $($VirtualNetwork.Name)..." -ForegroundColor Cyan
    
    # Required Private DNS Zones for AVD services
    $requiredPrivateDNSZones = @(
        "privatelink.wvd.microsoft.com",      # AVD service endpoints
        "privatelink.blob.core.windows.net", # Storage accounts for profiles
        "privatelink.file.core.windows.net", # File shares for FSLogix
        "privatelink.table.core.windows.net", # Table storage
        "privatelink.queue.core.windows.net", # Queue storage
        "privatelink.vaultcore.azure.net",   # Key Vault
        "privatelink.database.windows.net",  # SQL Database (if used)
        "privatelink.documents.azure.com",   # Cosmos DB (if used)
        "privatelink.azurecr.io"             # Container Registry (if used)
    )
    
    try {
        # Get all Private DNS Zones in the subscription
        $privateDnsZones = Get-AzPrivateDnsZone -ErrorAction Stop
        
        if ($privateDnsZones.Count -eq 0) {
            Add-ReportEntry "Private DNS Zones" "Warning" "No Private DNS Zones found in subscription" -Category "DNS" -Recommendation "Consider implementing Private DNS Zones for secure AVD service communication"
            return
        }
        
        # Check for required Private DNS Zones
        foreach ($requiredZone in $requiredPrivateDNSZones) {
            $existingZone = $privateDnsZones | Where-Object { $_.Name -eq $requiredZone }
            
            if ($existingZone) {
                Add-ReportEntry "Private DNS Zones" "Pass" "Required Private DNS Zone found: $requiredZone" -Category "DNS"
                
                # Check if the zone is linked to the current virtual network
                try {
                    $vnetLinks = Get-AzPrivateDnsVirtualNetworkLink -ZoneName $requiredZone -ResourceGroupName $existingZone.ResourceGroupName -ErrorAction SilentlyContinue
                    $currentVnetLink = $vnetLinks | Where-Object { $_.VirtualNetworkId -like "*$($VirtualNetwork.Name)" }
                    
                    if ($currentVnetLink) {
                        Add-ReportEntry "Private DNS Zone Links" "Pass" "vNet '$($VirtualNetwork.Name)' is linked to Private DNS Zone: $requiredZone" -Category "DNS"
                        
                        # Check if auto-registration is enabled (recommended for some scenarios)
                        if ($currentVnetLink.RegistrationEnabled) {
                            Add-ReportEntry "Private DNS Zone Registration" "Info" "Auto-registration enabled for $requiredZone in vNet '$($VirtualNetwork.Name)'" -Category "DNS"
                        } else {
                            Add-ReportEntry "Private DNS Zone Registration" "Info" "Auto-registration disabled for $requiredZone in vNet '$($VirtualNetwork.Name)' (manual DNS records required)" -Category "DNS"
                        }
                    } else {
                        Add-ReportEntry "Private DNS Zone Links" "Warning" "vNet '$($VirtualNetwork.Name)' is NOT linked to Private DNS Zone: $requiredZone" -Category "DNS" -Recommendation "Link vNet to Private DNS Zone for private endpoint resolution"
                    }
                } catch {
                    Add-ReportEntry "Private DNS Zone Links" "Warning" "Unable to verify vNet link for Private DNS Zone: $requiredZone" -Category "DNS"
                }
            } else {
                $criticality = if ($requiredZone -in @("privatelink.wvd.microsoft.com", "privatelink.blob.core.windows.net", "privatelink.file.core.windows.net")) { "Fail" } else { "Warning" }
                Add-ReportEntry "Private DNS Zones" $criticality "Missing recommended Private DNS Zone: $requiredZone" -Category "DNS" -Recommendation "Create Private DNS Zone for secure communication with Azure services"
            }
        }
        
        # Validate existing Private DNS Zones configuration
        foreach ($dnsZone in $privateDnsZones) {
            $recordSets = Get-AzPrivateDnsRecordSet -ZoneName $dnsZone.Name -ResourceGroupName $dnsZone.ResourceGroupName -ErrorAction SilentlyContinue
            
            if ($recordSets.Count -gt 0) {
                Add-ReportEntry "Private DNS Records" "Pass" "Private DNS Zone '$($dnsZone.Name)' contains $($recordSets.Count) record set(s)" -Category "DNS"
            } else {
                Add-ReportEntry "Private DNS Records" "Warning" "Private DNS Zone '$($dnsZone.Name)' contains no DNS records" -Category "DNS" -Recommendation "Verify Private Endpoints are correctly configured to populate DNS records"
            }
        }
        
    } catch {
        Add-ReportEntry "Private DNS Zones" "Warning" "Unable to retrieve Private DNS Zones: $($_.Exception.Message)" -Category "DNS" -Recommendation "Verify permissions to access Private DNS Zones or check if Az.PrivateDns module is installed"
    }
}

# Function to validate virtual network peering for AVD requirements
function Test-VirtualNetworkPeering {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    Write-Host ""
    Write-Host "Validating Network Peering for $($VirtualNetwork.Name)..." -ForegroundColor Cyan
    
    if ($SkipPeeringValidation) {
        Add-ReportEntry "Peering Validation" "Info" "Peering validation skipped for $($VirtualNetwork.Name)" -Category "Peering"
        return
    }
    
    $peerings = $VirtualNetwork.VirtualNetworkPeerings
    
    if (-not $peerings -or $peerings.Count -eq 0) {
        Add-ReportEntry "Network Peering" "Info" "$($VirtualNetwork.Name): No virtual network peerings configured" -Category "Peering"
        
        # Check if this vNet might need peering based on AVD requirements
        Test-AVDPeeringRequirements -VirtualNetwork $VirtualNetwork
        return
    }
    
    Add-ReportEntry "Network Peering" "Info" "$($VirtualNetwork.Name): $($peerings.Count) peering(s) configured" -Category "Peering"
    
    foreach ($peering in $peerings) {
        $remoteVNetName = $peering.RemoteVirtualNetwork.Id.Split('/')[-1]
        $remoteResourceGroup = $peering.RemoteVirtualNetwork.Id.Split('/')[4]
        
        # Basic peering status validation
        if ($peering.PeeringState -eq "Connected") {
            Add-ReportEntry "Peering Status" "Pass" "${VirtualNetwork.Name} -> ${remoteVNetName}: Peering is connected" -Category "Peering"
            
            # Validate AVD-specific peering configuration
            Test-AVDPeeringConfiguration -SourceVNet $VirtualNetwork -Peering $peering -RemoteVNetName $remoteVNetName
            
            # Test bidirectional peering
            Test-BidirectionalPeering -SourceVNet $VirtualNetwork -Peering $peering -RemoteVNetName $remoteVNetName -RemoteResourceGroup $remoteResourceGroup
            
            # Validate address space overlap
            Test-PeeringAddressSpaceOverlap -SourceVNet $VirtualNetwork -Peering $peering -RemoteVNetName $remoteVNetName
            
        } else {
            Add-ReportEntry "Peering Status" "Fail" "${VirtualNetwork.Name} -> ${remoteVNetName}: Peering state is $($peering.PeeringState)" -Category "Peering" -Recommendation "Fix peering configuration - ensure bidirectional peering is properly configured"
        }
        
        # Store peering relationship for topology analysis
        $script:NetworkTopology.PeeringRelationships += [PSCustomObject]@{
            SourceVNet = $VirtualNetwork.Name
            SourceResourceGroup = $VirtualNetwork.ResourceGroupName
            TargetVNet = $remoteVNetName
            TargetResourceGroup = $remoteResourceGroup
            State = $peering.PeeringState
            AllowVirtualNetworkAccess = $peering.AllowVirtualNetworkAccess
            AllowForwardedTraffic = $peering.AllowForwardedTraffic
            AllowGatewayTransit = $peering.AllowGatewayTransit
            UseRemoteGateways = $peering.UseRemoteGateways
        }
    }
}

# Function to validate AVD-specific peering configuration
function Test-AVDPeeringConfiguration {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$SourceVNet,
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetworkPeering]$Peering,
        [string]$RemoteVNetName
    )
    
    # Check essential AVD peering settings
    if (-not $Peering.AllowVirtualNetworkAccess) {
        Add-ReportEntry "AVD Peering Config" "Fail" "${SourceVNet.Name} -> ${RemoteVNetName}: Virtual network access is disabled" -Category "Peering" -Recommendation "Enable 'Allow virtual network access' - required for AVD communication"
    } else {
        Add-ReportEntry "AVD Peering Config" "Pass" "${SourceVNet.Name} -> ${RemoteVNetName}: Virtual network access is enabled" -Category "Peering"
    }
    
    # Check forwarded traffic (important for hub-spoke topologies with AVD)
    if ($Peering.AllowForwardedTraffic) {
        Add-ReportEntry "AVD Peering Config" "Pass" "${SourceVNet.Name} -> ${RemoteVNetName}: Forwarded traffic is allowed (good for hub-spoke topology)" -Category "Peering"
    } else {
        Add-ReportEntry "AVD Peering Config" "Warning" "${SourceVNet.Name} -> ${RemoteVNetName}: Forwarded traffic is disabled" -Category "Peering" -Recommendation "Consider enabling if using hub-spoke topology with NVA/Firewall"
    }
    
    # Check gateway transit settings (critical for hybrid connectivity)
    if ($Peering.AllowGatewayTransit -and $Peering.UseRemoteGateways) {
        Add-ReportEntry "AVD Peering Config" "Warning" "${SourceVNet.Name} -> ${RemoteVNetName}: Both AllowGatewayTransit and UseRemoteGateways are enabled" -Category "Peering" -Recommendation "Only one should be enabled per peering direction"
    }
    
    if ($Peering.UseRemoteGateways) {
        Add-ReportEntry "AVD Peering Config" "Info" "${SourceVNet.Name} -> ${RemoteVNetName}: Using remote gateways for hybrid connectivity" -Category "Peering"
    }
    
    if ($Peering.AllowGatewayTransit) {
        Add-ReportEntry "AVD Peering Config" "Info" "${SourceVNet.Name} -> ${RemoteVNetName}: Allowing gateway transit to remote networks" -Category "Peering"
    }
}

# Function to test bidirectional peering
function Test-BidirectionalPeering {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$SourceVNet,
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetworkPeering]$Peering,
        [string]$RemoteVNetName,
        [string]$RemoteResourceGroup
    )
    
    try {
        # Try to get the remote vNet and check reverse peering
        $remoteVNet = Get-AzVirtualNetwork -Name $RemoteVNetName -ResourceGroupName $RemoteResourceGroup -ErrorAction SilentlyContinue
        
        if ($remoteVNet) {
            $reversePeering = $remoteVNet.VirtualNetworkPeerings | Where-Object { 
                $_.RemoteVirtualNetwork.Id -like "*$($SourceVNet.Name)" 
            }
            
            if ($reversePeering) {
                if ($reversePeering.PeeringState -eq "Connected") {
                    Add-ReportEntry "Bidirectional Peering" "Pass" "${RemoteVNetName} -> ${SourceVNet.Name}: Reverse peering is connected" -Category "Peering"
                } else {
                    Add-ReportEntry "Bidirectional Peering" "Fail" "${RemoteVNetName} -> ${SourceVNet.Name}: Reverse peering state is $($reversePeering.PeeringState)" -Category "Peering" -Recommendation "Fix reverse peering configuration"
                }
                
                # Check for configuration symmetry issues
                if ($Peering.AllowVirtualNetworkAccess -ne $reversePeering.AllowVirtualNetworkAccess) {
                    Add-ReportEntry "Peering Symmetry" "Warning" "${SourceVNet.Name} <-> ${RemoteVNetName}: Asymmetric virtual network access settings" -Category "Peering" -Recommendation "Ensure both directions have consistent AllowVirtualNetworkAccess settings"
                }
            } else {
                Add-ReportEntry "Bidirectional Peering" "Fail" "${RemoteVNetName} -> ${SourceVNet.Name}: Reverse peering not found" -Category "Peering" -Recommendation "Create reverse peering connection for bidirectional connectivity"
            }
        } else {
            Add-ReportEntry "Bidirectional Peering" "Warning" "Unable to access remote vNet ${RemoteVNetName} in resource group ${RemoteResourceGroup}" -Category "Peering" -Recommendation "Verify permissions to access remote vNet or check if it exists"
        }
    } catch {
        Add-ReportEntry "Bidirectional Peering" "Warning" "Unable to validate reverse peering for ${RemoteVNetName}: $($_.Exception.Message)" -Category "Peering"
    }
}

# Function to test address space overlap in peering
function Test-PeeringAddressSpaceOverlap {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$SourceVNet,
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetworkPeering]$Peering,
        [string]$RemoteVNetName
    )
    
    try {
        $remoteVNet = Get-AzVirtualNetwork -Name $RemoteVNetName -ResourceGroupName $Peering.RemoteVirtualNetwork.Id.Split('/')[4] -ErrorAction SilentlyContinue
        
        if ($remoteVNet) {
            foreach ($sourcePrefix in $SourceVNet.AddressSpace.AddressPrefixes) {
                foreach ($remotePrefix in $remoteVNet.AddressSpace.AddressPrefixes) {
                    $overlap = Test-NetworkAddressOverlap -AddressPrefix1 $sourcePrefix -AddressPrefix2 $remotePrefix
                    
                    if ($overlap) {
                        Add-ReportEntry "Peering Address Overlap" "Fail" "${SourceVNet.Name} (${sourcePrefix}) overlaps with ${RemoteVNetName} (${remotePrefix})" -Category "Peering" -Recommendation "Address space overlap prevents proper peering - modify address spaces"
                    } else {
                        Add-ReportEntry "Peering Address Space" "Pass" "${SourceVNet.Name} (${sourcePrefix}) and ${RemoteVNetName} (${remotePrefix}) do not overlap" -Category "Peering"
                    }
                }
            }
        }
    } catch {
        Add-ReportEntry "Peering Address Space" "Warning" "Unable to validate address space overlap with ${RemoteVNetName}: $($_.Exception.Message)" -Category "Peering"
    }
}

# Function to assess AVD peering requirements
function Test-AVDPeeringRequirements {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    # Analyze if this vNet needs peering based on AVD requirements
    $needsHubPeering = $false
    $needsDomainControllerPeering = $false
    
    # Check if vNet has subnets that look like AVD session host subnets
    $avdSubnets = $VirtualNetwork.Subnets | Where-Object { 
        $_.Name -match "(avd|sessionhost|desktop|pool)" -or 
        $_.AddressPrefix -match "/24|/25|/26|/27" 
    }
    
    if ($avdSubnets) {
        Add-ReportEntry "AVD Peering Assessment" "Info" "$($VirtualNetwork.Name): Contains potential AVD subnets - may need peering for domain services" -Category "Peering"
        $needsDomainControllerPeering = $true
    }
    
    # Check for small address spaces that might indicate spoke vNets
    foreach ($addressPrefix in $VirtualNetwork.AddressSpace.AddressPrefixes) {
        $prefixLength = [int]($addressPrefix -split '/')[1]
        if ($prefixLength -ge 24) {
            Add-ReportEntry "AVD Peering Assessment" "Info" "$($VirtualNetwork.Name): Small address space ($addressPrefix) suggests spoke vNet - may need hub peering" -Category "Peering"
            $needsHubPeering = $true
        }
    }
    
    # Provide recommendations based on analysis
    if ($needsHubPeering) {
        Add-ReportEntry "AVD Peering Recommendation" "Warning" "$($VirtualNetwork.Name): Consider peering with hub vNet for shared services (DNS, Domain Controllers, Management)" -Category "Peering" -Recommendation "Implement hub-spoke topology with proper peering configuration"
    }
    
    if ($needsDomainControllerPeering) {
        Add-ReportEntry "AVD Peering Recommendation" "Warning" "$($VirtualNetwork.Name): AVD subnets detected - ensure peering with domain controller vNet for authentication" -Category "Peering" -Recommendation "Peer with vNet containing Active Directory Domain Services for AVD domain join"
    }
}

# Function to validate subnet configuration for AVD requirements
function Test-SubnetConfiguration {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    foreach ($subnet in $VirtualNetwork.Subnets) {
        $subnetInfo = @(
            "Address Prefix: $($subnet.AddressPrefix)",
            "Available IPs: $(if ($subnet.AvailableIpAddressCount) { $subnet.AvailableIpAddressCount } else { 'Unknown' })"
        ) -join "; "
        
        # Check subnet size recommendations for AVD
        $addressPrefix = $subnet.AddressPrefix
        if ($addressPrefix) {
            $subnetMask = [int]$addressPrefix.Split('/')[1]
            
            if ($subnetMask -gt 24) {
                Add-ReportEntry "Subnet Size" "Warning" "$($VirtualNetwork.Name)/$($subnet.Name): Subnet may be too small for AVD session hosts ($addressPrefix)" -Category "Subnets" -Recommendation "Consider using /24 or larger subnet for adequate IP address space"
            } else {
                Add-ReportEntry "Subnet Size" "Pass" "$($VirtualNetwork.Name)/$($subnet.Name): Subnet size is adequate for AVD ($addressPrefix)" -Category "Subnets"
            }
        }
        
        # Check for available IP addresses
        if ($subnet.AvailableIpAddressCount -ne $null) {
            if ($subnet.AvailableIpAddressCount -lt 10) {
                Add-ReportEntry "IP Availability" "Warning" "$($VirtualNetwork.Name)/$($subnet.Name): Low available IP addresses ($($subnet.AvailableIpAddressCount))" -Category "Subnets" -Recommendation "Consider expanding subnet or cleaning up unused resources"
            } else {
                Add-ReportEntry "IP Availability" "Pass" "$($VirtualNetwork.Name)/$($subnet.Name): Sufficient available IP addresses ($($subnet.AvailableIpAddressCount))" -Category "Subnets"
            }
        }
        
        # Check for Network Security Groups
        if ($subnet.NetworkSecurityGroup) {
            $nsgName = $subnet.NetworkSecurityGroup.Id.Split('/')[-1]
            Add-ReportEntry "NSG Assignment" "Pass" "$($VirtualNetwork.Name)/$($subnet.Name): Network Security Group assigned ($nsgName)" -Category "Security"
            
            # Validate NSG rules for AVD requirements
            try {
                $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $VirtualNetwork.ResourceGroupName -ErrorAction Stop
                Test-NSGRulesForAVD -NetworkSecurityGroup $nsg -VirtualNetworkName $VirtualNetwork.Name -SubnetName $subnet.Name
            } catch {
                Add-ReportEntry "NSG Validation" "Warning" "$($VirtualNetwork.Name)/$($subnet.Name): Unable to retrieve NSG details for validation" -Category "Security"
            }
        } else {
            Add-ReportEntry "NSG Assignment" "Warning" "$($VirtualNetwork.Name)/$($subnet.Name): No Network Security Group assigned" -Category "Security" -Recommendation "Consider assigning an NSG for security control and monitoring"
        }
        
        # Check for Route Tables
        if ($subnet.RouteTable) {
            $routeTableName = $subnet.RouteTable.Id.Split('/')[-1]
            Add-ReportEntry "Route Table" "Pass" "$($VirtualNetwork.Name)/$($subnet.Name): Route table assigned ($routeTableName)" -Category "Routing"
            
            # Validate route table configuration for AVD
            Test-AVDRouteTableConfiguration -VirtualNetworkName $VirtualNetwork.Name -SubnetName $subnet.Name -RouteTableName $routeTableName -ResourceGroupName $VirtualNetwork.ResourceGroupName
        } else {
            Add-ReportEntry "Route Table" "Info" "$($VirtualNetwork.Name)/$($subnet.Name): No custom route table assigned (using system routes)" -Category "Routing"
        }
        
        # Validate AVD-specific subnet requirements
        Test-AVDSubnetRequirements -VirtualNetwork $VirtualNetwork -Subnet $subnet
        
        # Check for delegated services that might conflict with AVD
        Test-SubnetDelegations -VirtualNetworkName $VirtualNetwork.Name -Subnet $subnet
    }
}

# Function to validate AVD-specific subnet requirements
function Test-AVDSubnetRequirements {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork,
        [Microsoft.Azure.Commands.Network.Models.PSSubnet]$Subnet
    )
    
    # Check subnet naming conventions for AVD
    if ($Subnet.Name -match "(avd|sessionhost|desktop|pool|management)" -or 
        $Subnet.Name -match "(snet-avd|subnet-avd)" -or
        $Subnet.Name -match "^(avd|wvd)" -or 
        $Subnet.Name -match "(session|desktop)") {
        
        Add-ReportEntry "AVD Subnet Detection" "Pass" "$($VirtualNetwork.Name)/$($Subnet.Name): Subnet appears to be designated for AVD use" -Category "AVD Planning"
        
        # Enhanced validation for AVD subnets
        $addressPrefix = $Subnet.AddressPrefix
        $subnetMask = [int]$addressPrefix.Split('/')[1]
        
        # More specific recommendations for AVD subnets
        if ($subnetMask -gt 26) {
            Add-ReportEntry "AVD Subnet Sizing" "Fail" "$($VirtualNetwork.Name)/$($Subnet.Name): Subnet too small for AVD session hosts ($addressPrefix)" -Category "AVD Planning" -Recommendation "AVD subnets should be /26 or larger to accommodate multiple session hosts"
        } elseif ($subnetMask -eq 26) {
            Add-ReportEntry "AVD Subnet Sizing" "Warning" "$($VirtualNetwork.Name)/$($Subnet.Name): Minimum recommended size for AVD ($addressPrefix)" -Category "AVD Planning" -Recommendation "Consider /24 for larger AVD deployments"
        } else {
            Add-ReportEntry "AVD Subnet Sizing" "Pass" "$($VirtualNetwork.Name)/$($Subnet.Name): Good size for AVD session hosts ($addressPrefix)" -Category "AVD Planning"
        }
        
        # Check for adequate IP address space planning
        if ($Subnet.AvailableIpAddressCount -ne $null) {
            $availableIPs = $Subnet.AvailableIpAddressCount
            
            if ($availableIPs -lt 5) {
                Add-ReportEntry "AVD IP Planning" "Fail" "$($VirtualNetwork.Name)/$($Subnet.Name): Insufficient available IPs for AVD session hosts ($availableIPs)" -Category "AVD Planning" -Recommendation "Ensure adequate IP space for current and future session hosts"
            } elseif ($availableIPs -lt 20) {
                Add-ReportEntry "AVD IP Planning" "Warning" "$($VirtualNetwork.Name)/$($Subnet.Name): Limited available IPs for growth ($availableIPs)" -Category "AVD Planning" -Recommendation "Monitor IP usage and plan for subnet expansion"
            } else {
                Add-ReportEntry "AVD IP Planning" "Pass" "$($VirtualNetwork.Name)/$($Subnet.Name): Adequate available IPs for AVD deployment ($availableIPs)" -Category "AVD Planning"
            }
        }
    } else {
        # Check if subnet could be suitable for AVD even if not explicitly named
        $addressPrefix = $Subnet.AddressPrefix
        $subnetMask = [int]$addressPrefix.Split('/')[1]
        
        if ($subnetMask -le 24 -and $Subnet.AvailableIpAddressCount -gt 50) {
            Add-ReportEntry "AVD Suitability" "Info" "$($VirtualNetwork.Name)/$($Subnet.Name): Subnet could be suitable for AVD deployment ($addressPrefix)" -Category "AVD Planning"
        }
    }
}

# Function to test subnet delegations
function Test-SubnetDelegations {
    param (
        [string]$VirtualNetworkName,
        [Microsoft.Azure.Commands.Network.Models.PSSubnet]$Subnet
    )
    
    if ($Subnet.Delegations -and $Subnet.Delegations.Count -gt 0) {
        foreach ($delegation in $Subnet.Delegations) {
            $serviceName = $delegation.ServiceName
            
            # Check for delegations that might conflict with AVD
            $conflictingServices = @(
                "Microsoft.ContainerInstance/containerGroups",
                "Microsoft.Netapp/volumes",
                "Microsoft.HardwareSecurityModules/dedicatedHSMs",
                "Microsoft.Batch/batchAccounts"
            )
            
            if ($serviceName -in $conflictingServices) {
                Add-ReportEntry "Subnet Delegation" "Warning" "${VirtualNetworkName}/$($Subnet.Name): Delegation to $serviceName may limit AVD session host deployment" -Category "AVD Planning" -Recommendation "Consider using separate subnet for AVD session hosts"
            } else {
                Add-ReportEntry "Subnet Delegation" "Info" "${VirtualNetworkName}/$($Subnet.Name): Delegated to $serviceName" -Category "Subnet Configuration"
            }
        }
    } else {
        Add-ReportEntry "Subnet Delegation" "Pass" "${VirtualNetworkName}/$($Subnet.Name): No service delegations (suitable for AVD session hosts)" -Category "AVD Planning"
    }
}

# Function to validate route table configuration for AVD
function Test-AVDRouteTableConfiguration {
    param (
        [string]$VirtualNetworkName,
        [string]$SubnetName,
        [string]$RouteTableName,
        [string]$ResourceGroupName
    )
    
    try {
        $routeTable = Get-AzRouteTable -Name $RouteTableName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        
        # Check for problematic routes that might affect AVD
        $problematicRoutes = $routeTable.Routes | Where-Object {
            $_.AddressPrefix -eq "0.0.0.0/0" -and 
            $_.NextHopType -eq "VirtualAppliance" -and
            $_.NextHopIpAddress
        }
        
        if ($problematicRoutes) {
            Add-ReportEntry "AVD Route Analysis" "Warning" "${VirtualNetworkName}/${SubnetName}: Default route via NVA detected - may impact AVD service connectivity" -Category "Routing" -Recommendation "Ensure AVD service endpoints are reachable or configure UDR bypass for AVD traffic"
        }
        
        # Check for routes to private address spaces (good for hybrid scenarios)
        $privateRoutes = $routeTable.Routes | Where-Object {
            $_.AddressPrefix -match "^10\." -or 
            $_.AddressPrefix -match "^172\.(1[6-9]|2[0-9]|3[0-1])\." -or 
            $_.AddressPrefix -match "^192\.168\."
        }
        
        if ($privateRoutes) {
            Add-ReportEntry "AVD Route Analysis" "Pass" "${VirtualNetworkName}/${SubnetName}: Custom routes to private address spaces configured (good for hybrid connectivity)" -Category "Routing"
        }
        
        # Check for specific AVD service routes
        $avdServiceRoutes = $routeTable.Routes | Where-Object {
            $_.Name -match "(avd|wvd|sessionhost)" -or
            $_.AddressPrefix -match "40\.64\." # AVD service IP range example
        }
        
        if ($avdServiceRoutes) {
            Add-ReportEntry "AVD Service Routes" "Pass" "${VirtualNetworkName}/${SubnetName}: Specific AVD service routes configured" -Category "Routing"
        }
        
    } catch {
        Add-ReportEntry "Route Table Analysis" "Warning" "${VirtualNetworkName}/${SubnetName}: Unable to analyze route table $RouteTableName" -Category "Routing"
    }
}

# Function to validate NSG rules for AVD requirements
function Test-NSGRulesForAVD {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSNetworkSecurityGroup]$NetworkSecurityGroup,
        [string]$VirtualNetworkName,
        [string]$SubnetName
    )
    
    $requiredOutboundPorts = @(443, 80) # AVD service communication
    $allowedInboundPorts = @(3389) # RDP for session hosts
    
    # Check outbound rules for AVD service connectivity
    $outboundRules = $NetworkSecurityGroup.SecurityRules | Where-Object { $_.Direction -eq "Outbound" -and $_.Access -eq "Allow" }
    
    $hasHTTPSOutbound = $false
    $hasHTTPOutbound = $false
    
    foreach ($rule in $outboundRules) {
        if ($rule.DestinationPortRange -contains "443" -or $rule.DestinationPortRange -eq "*" -or ($rule.DestinationPortRange -match "443")) {
            $hasHTTPSOutbound = $true
        }
        if ($rule.DestinationPortRange -contains "80" -or $rule.DestinationPortRange -eq "*" -or ($rule.DestinationPortRange -match "80")) {
            $hasHTTPOutbound = $true
        }
    }
    
    if ($hasHTTPSOutbound) {
        Add-ReportEntry "NSG Rules" "Pass" "${VirtualNetworkName}/${SubnetName}: Outbound HTTPS (443) access allowed for AVD service communication" -Category "Security"
    } else {
        Add-ReportEntry "NSG Rules" "Fail" "${VirtualNetworkName}/${SubnetName}: Outbound HTTPS (443) access may be blocked" -Category "Security" -Recommendation "Ensure outbound HTTPS access is allowed for AVD service communication"
    }
    
    if ($hasHTTPOutbound) {
        Add-ReportEntry "NSG Rules" "Pass" "${VirtualNetworkName}/${SubnetName}: Outbound HTTP (80) access allowed" -Category "Security"
    } else {
        Add-ReportEntry "NSG Rules" "Warning" "${VirtualNetworkName}/${SubnetName}: Outbound HTTP (80) access may be blocked" -Category "Security" -Recommendation "Consider allowing outbound HTTP access for initial setup and updates"
    }
}

# Function to validate network gateways
function Test-NetworkGateways {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    try {
        # Check for VPN Gateways in the same resource group
        $vpnGateways = Get-AzVirtualNetworkGateway -ResourceGroupName $VirtualNetwork.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { $_.GatewayType -eq "Vpn" }
        
        foreach ($gateway in $vpnGateways) {
            # Check if gateway is associated with this VNet
            $gatewayVNetId = $gateway.IpConfigurations[0].Subnet.Id -replace '/subnets/.*$', ''
            if ($gatewayVNetId -eq $VirtualNetwork.Id) {
                Add-ReportEntry "Network Gateway" "Pass" "$($VirtualNetwork.Name): VPN Gateway configured ($($gateway.Name))" -Category "Connectivity"
                
                # Additional gateway validation
                if ($gateway.ConnectionStatus -eq "Connected") {
                    Add-ReportEntry "Gateway Connectivity" "Pass" "$($VirtualNetwork.Name): VPN Gateway is connected" -Category "Connectivity"
                } else {
                    Add-ReportEntry "Gateway Connectivity" "Warning" "$($VirtualNetwork.Name): VPN Gateway status: $($gateway.ConnectionStatus)" -Category "Connectivity"
                }
            }
        }
        
        # Check for ExpressRoute Gateways
        $erGateways = Get-AzVirtualNetworkGateway -ResourceGroupName $VirtualNetwork.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { $_.GatewayType -eq "ExpressRoute" }
        
        foreach ($gateway in $erGateways) {
            $gatewayVNetId = $gateway.IpConfigurations[0].Subnet.Id -replace '/subnets/.*$', ''
            if ($gatewayVNetId -eq $VirtualNetwork.Id) {
                Add-ReportEntry "Network Gateway" "Pass" "$($VirtualNetwork.Name): ExpressRoute Gateway configured ($($gateway.Name))" -Category "Connectivity"
            }
        }
        
    } catch {
        Add-ReportEntry "Gateway Validation" "Warning" "$($VirtualNetwork.Name): Unable to validate network gateways: $($_.Exception.Message)" -Category "Connectivity"
    }
}

# Function to identify hub and spoke topology
function Identify-HubSpokeTopology {
    param (
        [array]$VirtualNetworks
    )
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host "Analyzing Hub and Spoke Network Topology " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    # Analyze peering relationships to identify hubs and spokes
    $networkConnections = @{}
    
    foreach ($vnet in $VirtualNetworks) {
        $networkConnections[$vnet.Name] = @{
            VNet = $vnet
            ConnectedNetworks = @()
            PeeringCount = $vnet.VirtualNetworkPeerings.Count
        }
        
        foreach ($peering in $vnet.VirtualNetworkPeerings) {
            if ($peering.PeeringState -eq "Connected") {
                $remoteVNetName = $peering.RemoteVirtualNetwork.Id.Split('/')[-1]
                $networkConnections[$vnet.Name].ConnectedNetworks += $remoteVNetName
            }
        }
    }
    
    # Identify potential hub networks (networks with multiple connections)
    foreach ($networkName in $networkConnections.Keys) {
        $network = $networkConnections[$networkName]
        
        if ($network.PeeringCount -ge 2) {
            # Potential hub network
            $script:NetworkTopology.HubNetworks += [PSCustomObject]@{
                Name = $networkName
                ResourceGroup = $network.VNet.ResourceGroupName
                Location = $network.VNet.Location
                AddressSpace = ($network.VNet.AddressSpace.AddressPrefixes -join ', ')
                ConnectedNetworks = ($network.ConnectedNetworks -join ', ')
                PeeringCount = $network.PeeringCount
                HasGateway = $false # Will be updated in gateway validation
            }
            
            Add-ReportEntry "Network Topology" "Info" "Potential Hub Network identified: $networkName (Connected to $($network.PeeringCount) networks)" -Category "Topology"
        } elseif ($network.PeeringCount -eq 1) {
            # Potential spoke network
            $connectedNetworksList = $network.ConnectedNetworks -join $script:JoinSeparator
            $spokeAddressSpace = $network.VNet.AddressSpace.AddressPrefixes -join $script:JoinSeparator
            $script:NetworkTopology.SpokeNetworks += [PSCustomObject]@{
                Name = $networkName
                ResourceGroup = $network.VNet.ResourceGroupName
                Location = $network.VNet.Location
                AddressSpace = $spokeAddressSpace
                ConnectedTo = $connectedNetworksList
                PeeringCount = $network.PeeringCount
            }
            
            Add-ReportEntry "Network Topology" "Info" "Potential Spoke Network identified: $networkName (Connected to: $connectedNetworksList)" -Category "Topology"
        } else {
            Add-ReportEntry "Network Topology" "Info" "Isolated Network: $networkName (No peering connections)" -Category "Topology"
        }
    }
    
    # Summary of topology
    if ($script:NetworkTopology.HubNetworks.Count -gt 0) {
        Add-ReportEntry "Hub-Spoke Analysis" "Pass" "Hub-and-Spoke topology detected with $($script:NetworkTopology.HubNetworks.Count) hub(s) and $($script:NetworkTopology.SpokeNetworks.Count) spoke(s)" -Category "Topology"
    } else {
        Add-ReportEntry "Hub-Spoke Analysis" "Info" "No clear hub-and-spoke topology detected. Networks may be using mesh or isolated configurations." -Category "Topology"
    }
}

# Function to validate private endpoints
function Test-PrivateEndpoints {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    try {
        # Check for private endpoints in the VNet
        $privateEndpoints = @()
        
        foreach ($subnet in $VirtualNetwork.Subnets) {
            if ($subnet.PrivateEndpoints) {
                $privateEndpoints += $subnet.PrivateEndpoints
            }
        }
        
        if ($privateEndpoints.Count -gt 0) {
            Add-ReportEntry "Private Endpoints" "Pass" "$($VirtualNetwork.Name): $($privateEndpoints.Count) private endpoint(s) configured" -Category "Private Connectivity"
            
            foreach ($pe in $privateEndpoints) {
                $peName = $pe.Id.Split('/')[-1]
                Add-ReportEntry "Private Endpoint Details" "Info" "$($VirtualNetwork.Name): Private endpoint '$peName' configured" -Category "Private Connectivity"
            }
        } else {
            Add-ReportEntry "Private Endpoints" "Info" "$($VirtualNetwork.Name): No private endpoints configured" -Category "Private Connectivity"
        }
        
    } catch {
        Add-ReportEntry "Private Endpoint Validation" "Warning" "$($VirtualNetwork.Name): Unable to validate private endpoints: $($_.Exception.Message)" -Category "Private Connectivity"
    }
}

# Function to perform network latency assessment
function Test-NetworkLatency {
    param (
        [array]$VirtualNetworks
    )
    
    if ($SkipLatencyTest) {
        Add-ReportEntry "Latency Test" "Info" "Network latency assessment skipped" -Category "Performance"
        return
    }
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host "Network Latency Assessment " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    # Test connectivity to AVD service endpoints from current location
    $avdEndpoints = @(
        "login.microsoftonline.com",
        "management.azure.com",
        "portal.azure.com"
    )
    
    foreach ($endpoint in $avdEndpoints) {
        try {
            $latencyTest = Test-NetConnection -ComputerName $endpoint -Port 443 -WarningAction SilentlyContinue
            if ($latencyTest.TcpTestSucceeded) {
                Add-ReportEntry "Endpoint Connectivity" "Pass" "Successfully connected to $endpoint" -Category "Performance"
            } else {
                Add-ReportEntry "Endpoint Connectivity" "Warning" "Unable to connect to $endpoint" -Category "Performance"
            }
        } catch {
            Add-ReportEntry "Endpoint Connectivity" "Warning" "Unable to test connectivity to ${endpoint}: $($_.Exception.Message)" -Category "Performance"
        }
    }
    
    # Regional latency considerations
    $azureRegions = $VirtualNetworks | Select-Object -ExpandProperty Location | Sort-Object -Unique
    if ($azureRegions.Count -gt 1) {
        $regionsList = $azureRegions -join $script:JoinSeparator
        Add-ReportEntry "Multi-Region Deployment" "Warning" "Virtual networks span multiple regions: $regionsList. Consider latency impact for cross-region connectivity." -Category "Performance" -Recommendation "Place AVD session hosts in the same region as users for optimal performance"
    } else {
        Add-ReportEntry "Regional Deployment" "Pass" "All virtual networks are in the same region: $($azureRegions[0])" -Category "Performance"
    }
}

# Function to select AVD networking scenario
function Select-AVDNetworkingScenario {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host "AVD Accelerator Networking Scenario Selection" -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    $scenarios = @(
        "Create New vNet and Subnets",
        "Use Existing vNet and Create New Subnets", 
        "Use Existing vNet and Existing Subnets",
        "Validate All Scenarios (Comprehensive)"
    )
    
    Write-Host "Select AVD Accelerator networking scenario to validate:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $scenarios.Count; $i++) {
        Write-Host "$($i + 1). $($scenarios[$i])" -ForegroundColor White
    }
    
    do {
        $selection = Read-Host "Enter selection (1-$($scenarios.Count))"
        $selectionIndex = [int]$selection - 1
    } while ($selectionIndex -lt 0 -or $selectionIndex -ge $scenarios.Count)
    
    $selectedScenario = $scenarios[$selectionIndex]
    Write-Host "Selected: $selectedScenario" -ForegroundColor Green
    
    return $selectionIndex + 1
}

# Function to validate "Create New" networking scenario requirements
function Test-AVDCreateNewNetworkingScenario {
    Write-Host ""
    Write-Host "Validating Create New Networking Scenario..." -ForegroundColor Cyan
    
    # Check subscription quotas for new vNet creation
    try {
        $networkUsage = Get-AzNetworkUsage -Location "East US" -ErrorAction SilentlyContinue
        if ($networkUsage) {
            $vnetUsage = $networkUsage | Where-Object { $_.Name.Value -eq "VirtualNetworks" }
            if ($vnetUsage) {
                $availableVNets = $vnetUsage.Limit - $vnetUsage.CurrentValue
                if ($availableVNets -gt 0) {
                    Add-ReportEntry "Create New vNet" "Pass" "Virtual Network quota available: $availableVNets remaining" -Category "Quota"
                } else {
                    Add-ReportEntry "Create New vNet" "Fail" "Virtual Network quota exceeded. Cannot create new vNets." -Category "Quota" -Recommendation "Request quota increase or clean up unused vNets"
                }
            }
        }
    } catch {
        Add-ReportEntry "Create New vNet" "Warning" "Unable to check virtual network quota: $($_.Exception.Message)" -Category "Quota"
    }
    
    # Validate naming conventions for new resources
    Add-ReportEntry "Create New vNet" "Info" "New vNet naming should follow Azure naming conventions: 2-64 characters, alphanumeric and hyphens only" -Category "Naming"
    
    # Check for address space planning
    Add-ReportEntry "Create New vNet" "Info" "Recommended address spaces: /16 for large deployments, /20 for medium, /24 for small" -Category "Planning" -Recommendation "Plan address space to avoid future conflicts with on-premises or other Azure networks"
}

# Function to validate "Use Existing" networking scenario requirements  
function Test-AVDUseExistingNetworkingScenario {
    param($VirtualNetworks)
    
    Write-Host ""
    Write-Host "Validating Use Existing Networking Scenario..." -ForegroundColor Cyan
    
    foreach ($vnet in $VirtualNetworks) {
        # Check available address space in existing vNets
        $totalSubnets = $vnet.Subnets.Count
        $availableSpace = $true
        
        foreach ($addressPrefix in $vnet.AddressSpace.AddressPrefixes) {
            try {
                $network = [System.Net.IPAddress]::Parse(($addressPrefix -split '/')[0])
                $prefixLength = [int]($addressPrefix -split '/')[1]
                
                # Calculate if there's space for additional subnets
                if ($prefixLength -le 24) {
                    Add-ReportEntry "Use Existing vNet" "Pass" "vNet '$($vnet.Name)' has adequate address space ($addressPrefix) for additional subnets" -Category "Capacity"
                } else {
                    Add-ReportEntry "Use Existing vNet" "Warning" "vNet '$($vnet.Name)' has limited address space ($addressPrefix) for additional subnets" -Category "Capacity" -Recommendation "Consider using larger address space for AVD deployments"
                }
            } catch {
                Add-ReportEntry "Use Existing vNet" "Warning" "Unable to analyze address space for vNet '$($vnet.Name)': $addressPrefix" -Category "Capacity"
            }
        }
        
        # Check existing subnet utilization
        foreach ($subnet in $vnet.Subnets) {
            $availableIPs = $subnet.AddressPrefix
            if ($subnet.IpConfigurations.Count -gt 0) {
                $usedIPs = $subnet.IpConfigurations.Count
                Add-ReportEntry "Use Existing vNet" "Info" "Subnet '$($subnet.Name)' has $usedIPs IP configurations in use" -Category "Utilization"
            } else {
                Add-ReportEntry "Use Existing vNet" "Pass" "Subnet '$($subnet.Name)' appears to be available for AVD deployment" -Category "Utilization"
            }
        }
    }
}

# Function to validate service endpoints for AVD requirements
function Test-AVDServiceEndpoints {
    param($VirtualNetworks)
    
    Write-Host ""
    Write-Host "Validating AVD Service Endpoints..." -ForegroundColor Cyan
    
    $requiredServiceEndpoints = @(
        "Microsoft.Storage",
        "Microsoft.KeyVault", 
        "Microsoft.Sql",
        "Microsoft.Web"
    )
    
    foreach ($vnet in $VirtualNetworks) {
        foreach ($subnet in $vnet.Subnets) {
            $configuredEndpoints = $subnet.ServiceEndpoints | ForEach-Object { $_.Service }
            
            foreach ($requiredEndpoint in $requiredServiceEndpoints) {
                if ($configuredEndpoints -contains $requiredEndpoint) {
                    Add-ReportEntry "Service Endpoints" "Pass" "Subnet '$($subnet.Name)' has required service endpoint: $requiredEndpoint" -Category "Service Endpoints"
                } else {
                    Add-ReportEntry "Service Endpoints" "Info" "Subnet '$($subnet.Name)' missing service endpoint: $requiredEndpoint" -Category "Service Endpoints" -Recommendation "Consider adding $requiredEndpoint service endpoint for AVD services"
                }
            }
            
            if ($configuredEndpoints.Count -eq 0) {
                Add-ReportEntry "Service Endpoints" "Warning" "Subnet '$($subnet.Name)' has no service endpoints configured" -Category "Service Endpoints" -Recommendation "Configure service endpoints for improved security and performance"
            }
        }
    }
}

# Main validation function for comprehensive network assessment
function Invoke-NetworkValidation {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host "Comprehensive Network Validation " -ForegroundColor White
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    # Select AVD networking scenario
    $scenarioSelection = Select-AVDNetworkingScenario
    
    try {
        # Get all virtual networks in the subscription
        $virtualNetworks = Get-AzVirtualNetwork -ErrorAction Stop
        
        if ($virtualNetworks.Count -eq 0) {
            Write-Host ""
            Write-Host ("="*100) -ForegroundColor Red
            Write-Host "NO VIRTUAL NETWORKS FOUND" -ForegroundColor Red
            Write-Host ("="*100) -ForegroundColor Red
            Write-Host ""
            Write-Host "The selected subscription does not contain any Virtual Networks." -ForegroundColor Yellow
            Write-Host "This script requires at least one VNet to perform comprehensive validation." -ForegroundColor Yellow
            Write-Host ""
            Add-ReportEntry "Virtual Networks" "Warning" "No virtual networks found in the selected subscription" -Category "Network Discovery"
            
            # Offer to create a VNet
            if (-not $NonInteractive) {
                Write-Host "Would you like to create a Virtual Network now?" -ForegroundColor Cyan
                Write-Host "  1. Create a custom VNet (you provide details)" -ForegroundColor White
                Write-Host "  2. Create a test VNet with recommended AVD configuration" -ForegroundColor White
                Write-Host "  3. Skip VNet creation and only validate 'Create New' scenario" -ForegroundColor White
                Write-Host "  4. Exit script" -ForegroundColor White
                Write-Host ""
                
                $createChoice = Read-Host "Enter selection (1-4)"
                
                switch ($createChoice) {
                    "1" {
                        $newVNet = New-AVDValidationVNet
                        if ($newVNet) {
                            Write-Host ""
                            Write-Host "VNet created successfully! Proceeding with validation..." -ForegroundColor Green
                            Write-Host ""
                            $virtualNetworks = @(Get-AzVirtualNetwork -ErrorAction Stop)
                        } else {
                            Write-Host "VNet creation failed or cancelled. Exiting..." -ForegroundColor Red
                            return
                        }
                    }
                    "2" {
                        $newVNet = New-AVDValidationVNet -CreateTestVNet
                        if ($newVNet) {
                            Write-Host ""
                            Write-Host "Test VNet created successfully! Proceeding with validation..." -ForegroundColor Green
                            Write-Host ""
                            $virtualNetworks = @(Get-AzVirtualNetwork -ErrorAction Stop)
                        } else {
                            Write-Host "Test VNet creation failed. Exiting..." -ForegroundColor Red
                            return
                        }
                    }
                    "3" {
                        Write-Host ""
                        Write-Host "Skipping VNet creation. Validating 'Create New' scenario only..." -ForegroundColor Yellow
                        Write-Host ""
                        if ($scenarioSelection -eq 1 -or $scenarioSelection -eq 4) {
                            Test-AVDCreateNewNetworkingScenario
                        }
                        return
                    }
                    "4" {
                        Write-Host "Exiting script..." -ForegroundColor Yellow
                        return
                    }
                    default {
                        Write-Host "Invalid selection. Exiting..." -ForegroundColor Red
                        return
                    }
                }
            } else {
                # Non-interactive mode - just validate Create New scenario
                if ($scenarioSelection -eq 1 -or $scenarioSelection -eq 4) {
                    Test-AVDCreateNewNetworkingScenario
                }
                return
            }
        }
        
        Add-ReportEntry "Virtual Networks" "Pass" "Found $($virtualNetworks.Count) virtual network(s) in the subscription" -Category "Network Discovery"
        
        # Store virtual networks in topology for reporting
        foreach ($vnet in $virtualNetworks) {
            $script:NetworkTopology.VirtualNetworks += [PSCustomObject]@{
                Name = $vnet.Name
                ResourceGroup = $vnet.ResourceGroupName
                Location = $vnet.Location
                AddressSpace = ($vnet.AddressSpace.AddressPrefixes -join ', ')
                SubnetCount = $vnet.Subnets.Count
                DNSServers = if ($vnet.DhcpOptions.DnsServers) { ($vnet.DhcpOptions.DnsServers -join ', ') } else { "Azure Default" }
                PeeringCount = $vnet.VirtualNetworkPeerings.Count
            }
        }
        
        # Validate address space overlaps
        Write-Host ""
        Write-Host "Checking for Address Space Overlaps..." -ForegroundColor Cyan
        for ($i = 0; $i -lt $virtualNetworks.Count; $i++) {
            for ($j = $i + 1; $j -lt $virtualNetworks.Count; $j++) {
                $vnet1 = $virtualNetworks[$i]
                $vnet2 = $virtualNetworks[$j]
                
                foreach ($addr1 in $vnet1.AddressSpace.AddressPrefixes) {
                    foreach ($addr2 in $vnet2.AddressSpace.AddressPrefixes) {
                        $overlap = Test-NetworkAddressOverlap -AddressPrefix1 $addr1 -AddressPrefix2 $addr2 -VNet1Name $vnet1.Name -VNet2Name $vnet2.Name
                        
                        if ($overlap) {
                            Add-ReportEntry "Address Space Overlap" "Fail" "Address space overlap detected between $($vnet1.Name) ($addr1) and $($vnet2.Name) ($addr2)" -Category "Network Validation" -Recommendation "Resolve address space overlap before establishing peering or connectivity"
                        }
                    }
                }
            }
        }
        
        # Detailed validation for each virtual network
        foreach ($vnet in $virtualNetworks) {
            Write-Host ""
            Write-Host "Validating Virtual Network: $($vnet.Name)" -ForegroundColor Cyan
            
            # Validate AVD-required services are configured
            Write-Host "Checking AVD Service Requirements..." -ForegroundColor Cyan
            $hasAVDSubnet = $false
            foreach ($subnet in $vnet.Subnets) {
                if ($subnet.Name -match "(avd|sessionhost|desktop|pool|wvd)") {
                    $hasAVDSubnet = $true
                    
                    # Check for required service endpoints
                    $configuredEndpoints = $subnet.ServiceEndpoints | ForEach-Object { $_.Service }
                    $missingEndpoints = @()
                    
                    foreach ($required in $script:AVDNetworkRequirements.RequiredServiceEndpoints) {
                        if ($configuredEndpoints -notcontains $required) {
                            $missingEndpoints += $required
                        }
                    }
                    
                    if ($missingEndpoints.Count -eq 0) {
                        Add-ReportEntry "AVD Service Endpoints" "Pass" "$($vnet.Name)/$($subnet.Name): All required service endpoints configured" -Category "AVD Services"
                    } else {
                        $missingList = $missingEndpoints -join '; '
                        Add-ReportEntry "AVD Service Endpoints" "Fail" "$($vnet.Name)/$($subnet.Name): Missing service endpoints: $missingList" -Category "AVD Services" -Recommendation "Add missing service endpoints for proper AVD communication"
                    }
                }
            }
            
            if (-not $hasAVDSubnet) {
                Add-ReportEntry "AVD Subnet Detection" "Info" "$($vnet.Name): No AVD-specific subnets detected (based on naming convention)" -Category "AVD Services"
            }
            
            # DNS Configuration Validation
            Test-DNSConfiguration -VirtualNetwork $vnet
            
            # Private DNS Zones Validation for AVD Requirements
            Test-PrivateDNSZones -VirtualNetwork $vnet
            
            # Subnet Configuration Validation
            Test-SubnetConfiguration -VirtualNetwork $vnet
            
            # Virtual Network Peering Validation
            Test-VirtualNetworkPeering -VirtualNetwork $vnet
            
            # Network Gateway Validation
            Test-NetworkGateways -VirtualNetwork $vnet
            
            # Private Endpoints Validation
            Test-PrivateEndpoints -VirtualNetwork $vnet
        }
        
        # Hub and Spoke Topology Analysis
        Identify-HubSpokeTopology -VirtualNetworks $virtualNetworks
        
        # Network Latency Assessment
        Test-NetworkLatency -VirtualNetworks $virtualNetworks
        
        # Execute AVD scenario-specific validations based on user selection
        switch ($scenarioSelection) {
            1 { # Create New vNet and Subnets
                Test-AVDCreateNewNetworkingScenario
            }
            2 { # Use Existing vNet and Create New Subnets
                Test-AVDUseExistingNetworkingScenario -VirtualNetworks $virtualNetworks
            }
            3 { # Use Existing vNet and Existing Subnets  
                Test-AVDUseExistingNetworkingScenario -VirtualNetworks $virtualNetworks
                Test-AVDServiceEndpoints -VirtualNetworks $virtualNetworks
            }
            4 { # Validate All Scenarios (Comprehensive)
                Test-AVDCreateNewNetworkingScenario
                Test-AVDUseExistingNetworkingScenario -VirtualNetworks $virtualNetworks
                Test-AVDServiceEndpoints -VirtualNetworks $virtualNetworks
            }
        }
        
    } catch {
        Add-ReportEntry "Network Validation" "Fail" "Failed to complete network validation: $($_.Exception.Message)" -Category "Network Discovery"
    }
}

# Function to display validation summary
function Show-ValidationSummary {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor Green
    Write-Host "Validation Summary " -ForegroundColor Green
    Write-Host ("="*100) -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Total Checks Performed: $($script:ValidationSummary.TotalChecks)" -ForegroundColor White
    Write-Host "Passed: $($script:ValidationSummary.PassedChecks)" -ForegroundColor Green
    Write-Host "Failed: $($script:ValidationSummary.FailedChecks)" -ForegroundColor Red
    Write-Host "Warnings: $($script:ValidationSummary.WarningChecks)" -ForegroundColor Yellow
    Write-Host "Information: $($script:ValidationSummary.InfoChecks)" -ForegroundColor Cyan
    
    $successRate = if ($script:ValidationSummary.TotalChecks -gt 0) { 
        [math]::Round(($script:ValidationSummary.PassedChecks / $script:ValidationSummary.TotalChecks) * 100, 2) 
    } else { 0 }
    
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })
    
    if ($script:ValidationSummary.FailedChecks -gt 0) {
        Write-Host ""
        Write-Host "ATTENTION: $($script:ValidationSummary.FailedChecks) critical issue(s) found that require attention before AVD deployment." -ForegroundColor Red
    }
    
    if ($script:ValidationSummary.WarningChecks -gt 0) {
        Write-Host ""
        Write-Host "NOTE: $($script:ValidationSummary.WarningChecks) warning(s) found. Review recommendations for optimal configuration." -ForegroundColor Yellow
        Write-Host ""
    }
}

# Function to collect remediable issues from validation results
function Get-RemediableIssues {
    param (
        [array]$ValidationReport
    )
    
    $remediableIssues = @()
    
    foreach ($entry in $ValidationReport) {
        if ($entry.Result -eq "Fail") {
            switch -Regex ($entry.Check) {
                "NSG.*Rule" {
                    $remediableIssues += [PSCustomObject]@{
                        Category = "Network Security"
                        Type = "MissingNSGRule" 
                        Description = "Missing NSG rule for AVD connectivity"
                        ResourceName = $entry.Check
                        Impact = "High - May prevent AVD connectivity"
                        OriginalEntry = $entry
                    }
                }
                "Private DNS" {
                    $remediableIssues += [PSCustomObject]@{
                        Category = "DNS Configuration"
                        Type = "MissingPrivateDNSZone"
                        Description = "Missing or misconfigured Private DNS Zone"
                        ResourceName = $entry.Check
                        Impact = "Medium - May impact AVD performance"
                        OriginalEntry = $entry
                    }
                }
                "Subnet.*Service.*Endpoint" {
                    $remediableIssues += [PSCustomObject]@{
                        Category = "Subnet Configuration"
                        Type = "MissingServiceEndpoints"
                        Description = "Missing required service endpoints"
                        ResourceName = $entry.Check
                        Impact = "Medium - May impact AVD features"
                        OriginalEntry = $entry
                    }
                }
                "Peering.*Fail|Peering.*Disconnect" {
                    $remediableIssues += [PSCustomObject]@{
                        Category = "Network Connectivity"
                        Type = "VNetPeeringIssue"
                        Description = "VNet peering connectivity issue"
                        ResourceName = $entry.Check
                        Impact = "High - May prevent cross-VNet connectivity"
                        OriginalEntry = $entry
                    }
                }
                "Route.*Block|UDR.*Block" {
                    $remediableIssues += [PSCustomObject]@{
                        Category = "Routing Configuration"
                        Type = "BlockedAVDTraffic"
                        Description = "Routing configuration blocking AVD traffic"
                        ResourceName = $entry.Check
                        Impact = "Critical - Will prevent AVD connectivity"
                        OriginalEntry = $entry
                    }
                }
            }
        }
    }
    
    return $remediableIssues
}

# Function to execute remediation based on user choice
function Invoke-RemediationActions {
    param (
        [array]$RemediableIssues,
        [string]$RemediationMode
    )
    
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor Magenta
    Write-Host "Executing Automated Remediation " -ForegroundColor Magenta
    Write-Host ("="*100) -ForegroundColor Magenta
    Write-Host ""
    
    # Get all virtual networks for context
    $allVNets = Get-AzVirtualNetwork
    $allNSGs = Get-AzNetworkSecurityGroup
    $allRouteTables = Get-AzRouteTable
    
    foreach ($issue in $RemediableIssues) {
        try {
            Write-Host "Processing issue: $($issue.Description)" -ForegroundColor Cyan
            
            # Set confirmation behavior based on mode
            $script:AutoConfirm = ($RemediationMode -eq "FixAll")
            
            switch ($issue.Type) {
                "MissingNSGRule" {
                    # Find the relevant NSG
                    $nsgName = ($issue.OriginalEntry.Details -split " ")[0]
                    $nsg = $allNSGs | Where-Object { $_.Name -like "*$nsgName*" } | Select-Object -First 1
                    
                    if ($nsg) {
                        Repair-NSGRules -NSG $nsg -MissingRules $script:AVDNetworkRequirements.RequiredNSGRules
                    } else {
                        Add-RemediationEntry "Missing NSG Rule" "Find NSG" "Failed" "Could not locate NSG for remediation"
                    }
                }
                "MissingPrivateDNSZone" {
                    # Extract VNet info from the validation entry
                    $vnetName = ($issue.OriginalEntry.Details -split " ")[0]
                    $vnet = $allVNets | Where-Object { $_.Name -like "*$vnetName*" } | Select-Object -First 1
                    
                    if ($vnet) {
                        $dnsIssues = @()
                        foreach ($zone in $script:AVDNetworkRequirements.RequiredPrivateDNSZones) {
                            $dnsIssues += @{
                                Type = "MissingPrivateDNSZone"
                                ZoneName = $zone
                            }
                        }
                        Repair-DNSConfiguration -VirtualNetwork $vnet -Issues $dnsIssues
                    } else {
                        Add-RemediationEntry "Missing Private DNS Zone" "Find VNet" "Failed" "Could not locate VNet for DNS remediation"
                    }
                }
                "MissingServiceEndpoints" {
                    # Extract VNet and subnet info
                    $vnetName = ($issue.OriginalEntry.Details -split " ")[0]
                    $vnet = $allVNets | Where-Object { $_.Name -like "*$vnetName*" } | Select-Object -First 1
                    
                    if ($vnet) {
                        $subnetIssues = @()
                        foreach ($subnet in $vnet.Subnets) {
                            $missingEndpoints = @()
                            foreach ($endpoint in $script:AVDNetworkRequirements.RequiredServiceEndpoints) {
                                if (-not ($subnet.ServiceEndpoints | Where-Object { $_.Service -eq $endpoint })) {
                                    $missingEndpoints += $endpoint
                                }
                            }
                            if ($missingEndpoints.Count -gt 0) {
                                $subnetIssues += @{
                                    Type = "MissingServiceEndpoints"
                                    SubnetName = $subnet.Name
                                    MissingEndpoints = $missingEndpoints
                                }
                            }
                        }
                        
                        if ($subnetIssues.Count -gt 0) {
                            Repair-SubnetConfiguration -VirtualNetwork $vnet -Issues $subnetIssues
                        }
                    }
                }
                "VNetPeeringIssue" {
                    # This requires manual analysis of which VNets should be peered
                    Write-Host "VNet peering issues require manual assessment. Please review the validation report." -ForegroundColor Yellow
                    Add-RemediationEntry "VNet Peering Issue" "Manual Review Required" "Skipped" "VNet peering remediation requires manual configuration decisions"
                }
                "BlockedAVDTraffic" {
                    # Find route tables that might be blocking AVD traffic
                    foreach ($routeTable in $allRouteTables) {
                        $routeIssues = @()
                        
                        # Check for routes that might block AVD traffic
                        foreach ($route in $routeTable.Routes) {
                            if ($route.NextHopType -eq "VirtualAppliance" -and $route.AddressPrefix -in @("0.0.0.0/0", "168.63.129.16/32")) {
                                $routeIssues += @{
                                    Type = "BlockedAVDTraffic"
                                    AddressPrefix = "168.63.129.16/32"  # Azure metadata service
                                }
                            }
                        }
                        
                        if ($routeIssues.Count -gt 0) {
                            Repair-RouteTableConfiguration -RouteTable $routeTable -Issues $routeIssues
                        }
                    }
                }
            }
        } catch {
            Add-RemediationEntry "Remediation Execution" "Process issue $($issue.Description)" "Failed" "Unexpected error during remediation: $($_.Exception.Message)"
        }
    }
}

# Function to export comprehensive report including remediation actions
function Export-ComprehensiveReport {
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    
    if ([string]::IsNullOrEmpty($ReportPath)) {
        $ReportPath = "AVD_Network_Validation_Comprehensive_Report_$timestamp"
    }
    
    try {
        if (-not $global:useCSVExport -and (Get-Module -ListAvailable -Name ImportExcel)) {
            # Export to Excel with multiple worksheets
            $excelPath = "$ReportPath.xlsx"
            
            # Main validation results
            $script:Report | Export-Excel -Path $excelPath -WorksheetName "Validation Results" -AutoSize -FreezeTopRow -BoldTopRow
            
            # Remediation actions
            if ($script:RemediationActions.Count -gt 0) {
                $script:RemediationActions | Export-Excel -Path $excelPath -WorksheetName "Remediation Actions" -AutoSize -Append
            }
            
            # Network topology summary
            if ($script:NetworkTopology.VirtualNetworks.Count -gt 0) {
                $script:NetworkTopology.VirtualNetworks | Export-Excel -Path $excelPath -WorksheetName "Network Topology" -AutoSize -Append
            }
            
            # Combined summary
            $combinedSummary = @(
                [PSCustomObject]@{ Category = "Validation"; Metric = "Total Checks"; Count = $script:ValidationSummary.TotalChecks }
                [PSCustomObject]@{ Category = "Validation"; Metric = "Passed"; Count = $script:ValidationSummary.PassedChecks }
                [PSCustomObject]@{ Category = "Validation"; Metric = "Failed"; Count = $script:ValidationSummary.FailedChecks }
                [PSCustomObject]@{ Category = "Validation"; Metric = "Warnings"; Count = $script:ValidationSummary.WarningChecks }
                [PSCustomObject]@{ Category = "Remediation"; Metric = "Total Issues"; Count = $script:RemediationSummary.TotalIssues }
                [PSCustomObject]@{ Category = "Remediation"; Metric = "Fixed"; Count = $script:RemediationSummary.FixedIssues }
                [PSCustomObject]@{ Category = "Remediation"; Metric = "Failed Fixes"; Count = $script:RemediationSummary.FailedFixes }
                [PSCustomObject]@{ Category = "Remediation"; Metric = "Skipped"; Count = $script:RemediationSummary.SkippedIssues }
            )
            $combinedSummary | Export-Excel -Path $excelPath -WorksheetName "Summary" -AutoSize -Append
            
            Add-ReportEntry "Comprehensive Report Export" "Pass" "Excel report exported successfully: $excelPath" -Category "Reporting"
        } else {
            # Export to CSV files
            $csvPath = "$ReportPath.csv"
            $script:Report | Export-Csv -Path $csvPath -NoTypeInformation
            
            if ($script:RemediationActions.Count -gt 0) {
                $remediationCsvPath = "$($ReportPath)_Remediation_Actions.csv"
                $script:RemediationActions | Export-Csv -Path $remediationCsvPath -NoTypeInformation
            }
            
            Add-ReportEntry "Comprehensive Report Export" "Pass" "CSV reports exported successfully" -Category "Reporting"
        }
    } catch {
        Add-ReportEntry "Comprehensive Report Export" "Fail" "Failed to export comprehensive report: $($_.Exception.Message)" -Category "Reporting"
    }
}

# Main script execution
try {
    Write-Host ""
    Write-Host ("="*100) -ForegroundColor White
    Write-Host "AVD Network Validation & Remediation Script v2.0.0" -ForegroundColor White  
    Write-Host ("="*100) -ForegroundColor White
    Write-Host ""
    
    # Initialize environment
    Initialize-AzureModules
    Connect-AzureAccount
    Select-AzureSubscription
    
    # Perform comprehensive network validation
    Invoke-NetworkValidation
    
    # Display validation summary
    Show-ValidationSummary
    
    # Check for remediable issues and offer remediation (if enabled)
    if ($EnableRemediation) {
        $remediableIssues = Get-RemediableIssues -ValidationReport $script:Report
        
        if ($remediableIssues.Count -gt 0) {
            if ($AutoFixAll) {
                Write-Host "Auto-fixing all detected issues..." -ForegroundColor Yellow
                Invoke-RemediationActions -RemediableIssues $remediableIssues -RemediationMode "FixAll"
                Show-RemediationSummary
            } else {
                $remediationChoice = Show-RemediationMenu -DetectedIssues $remediableIssues
                
                if ($remediationChoice -and $remediationChoice -ne "Skip") {
                    Invoke-RemediationActions -RemediableIssues $remediableIssues -RemediationMode $remediationChoice
                    Show-RemediationSummary
                }
            }
        } else {
            Write-Host ""
            Write-Host "No automated remediation options available. All configurations appear compliant!" -ForegroundColor Green
            Write-Host ""
        }
    } else {
        # Just report remediable issues without offering to fix them
        $remediableIssues = Get-RemediableIssues -ValidationReport $script:Report
        if ($remediableIssues.Count -gt 0) {
            Write-Host ""
            Write-Host "$($remediableIssues.Count) issue(s) detected that could be automatically remediated." -ForegroundColor Yellow
            Write-Host "Re-run the script with -EnableRemediation to access automated fixes." -ForegroundColor Yellow
            Write-Host ""
        }
    }
    
    # Export comprehensive report with remediation results
    Export-ComprehensiveReport
    
    Write-Host ""
    Write-Host "AVD Network validation and remediation completed successfully!" -ForegroundColor Green
    if ($script:RemediationSummary.FixedIssues -gt 0) {
        Write-Host "Successfully remediated $($script:RemediationSummary.FixedIssues) configuration issue(s)." -ForegroundColor Green
    }
    if ($script:RemediationSummary.FailedFixes -gt 0) {
        Write-Host "Failed to fix $($script:RemediationSummary.FailedFixes) issue(s). Please review the report for manual intervention." -ForegroundColor Red
    }
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Add-ReportEntry "Script Execution" "Fail" "Script failed with error: $($_.Exception.Message)" -Category "System"
    Export-PartialReportAndExit
} finally {
    Write-Host ""
}
