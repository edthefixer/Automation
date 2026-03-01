<#
.SYNOPSIS
Assigns "Desktop Virtualization Contributor" to the Azure Virtual Desktop service principal
at the Host Pool scope or Subscription scope (user is prompted to choose).

.PREREQS

.DESCRIPTION
This script assigns the Desktop Virtualization Contributor role to the Azure Virtual Desktop service principal.
It provides multiple authentication methods and prompts for scope selection interactively.

.PARAMETER SubscriptionId
The Azure subscription ID where the assignment will be created.

.PARAMETER ResourceGroupName
The resource group containing the host pool.

.PARAMETER HostPoolName
The name of the host pool for scope assignment.

.PARAMETER NonInteractive
Run in non-interactive mode with default selections.

.EXAMPLE
.\20_AVD_ScallingPlanRBACRoleAssign.ps1 -SubscriptionId "xxx-xxx" -ResourceGroupName "rg-avd" -HostPoolName "hp-prod"

.NOTES
 Author     : edthefixer + GitHub Copilot... well, I fell asleep, copilot finished it...
Version: 1.0
Last Updated: February 2026
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$HostPoolName,

    [Parameter(HelpMessage = "Run in non-interactive mode")]
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"
$roleName = "Desktop Virtualization Contributor"

#region Authentication Functions

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

# Azure authentication function with comprehensive method selection
function Connect-AzureWithRetry {
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host " Azure Authentication " -ForegroundColor White
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host ""
    
    Write-Host "Clearing any cached Azure credentials..." -ForegroundColor Yellow
    Write-Host "Fresh authentication required for this session." -ForegroundColor Yellow
    Write-Host ""
    
    # Clear existing contexts - Force fresh authentication every time
    try {
        Clear-AzContext -Force -ErrorAction SilentlyContinue
        Disconnect-AzAccount -ErrorAction SilentlyContinue
    }
    catch { }
    
    # Select authentication method
    $selectedAuthMethod = Select-AuthenticationMethod
    
    Write-Host "[INFO] Authentication method selected: $selectedAuthMethod" -ForegroundColor Cyan
    
    try {
        # Attempt authentication with selected method
        $authResult = Invoke-AzureAuthentication -AuthMethod $selectedAuthMethod
        
        # Verify connection
        $context = Get-AzContext
        if ($context) {
            Write-Host "[SUCCESS] Authenticated to Azure" -ForegroundColor Green
            Write-Host "  Account: $($context.Account.Id)" -ForegroundColor Gray
            Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
            return $true
        }
        else {
            throw "Authentication succeeded but no context was established"
        }
        
    }
    catch {
        Write-Host "[ERROR] Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        
        # Offer retry with different method if not in non-interactive mode
        if (-not $NonInteractive) {
            Write-Host ""
            Write-Host "Would you like to try a different authentication method?" -ForegroundColor Yellow
            $retry = Read-Host "Enter 'y' to retry, or any other key to exit"
            
            if ($retry.ToLower() -eq 'y') {
                return Connect-AzureWithRetry
            }
        }
        
        throw "Failed to authenticate to Azure: $_"
    }
}

#endregion

#region Main Script

# Force authentication with comprehensive method selection
Connect-AzureWithRetry | Out-Null

# Get available subscriptions and prompt if not provided
if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host " Subscription Selection " -ForegroundColor White
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host ""
    
    $subscriptions = Get-AzSubscription
    
    if ($subscriptions.Count -eq 0) {
        throw "No subscriptions found for the authenticated account."
    }
    
    if ($subscriptions.Count -eq 1) {
        $SubscriptionId = $subscriptions[0].Id
        Write-Host "Using subscription: $($subscriptions[0].Name) ($SubscriptionId)" -ForegroundColor Green
    }
    else {
        Write-Host "Available subscriptions:" -ForegroundColor Cyan
        Write-Host ""
        
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            Write-Host "  $($i + 1). $($subscriptions[$i].Name)" -ForegroundColor White
            Write-Host "      ID: $($subscriptions[$i].Id)" -ForegroundColor Gray
            Write-Host ""
        }
        
        do {
            $selection = Read-Host "Select subscription (1-$($subscriptions.Count))"
            $selectionInt = 0
            $validSelection = [int]::TryParse($selection, [ref]$selectionInt) -and 
            $selectionInt -ge 1 -and $selectionInt -le $subscriptions.Count
            
            if (-not $validSelection) {
                Write-Host "Invalid selection. Please enter a number between 1 and $($subscriptions.Count)." -ForegroundColor Red
            }
        } while (-not $validSelection)
        
        $SubscriptionId = $subscriptions[$selectionInt - 1].Id
        Write-Host ""
        Write-Host "Selected: $($subscriptions[$selectionInt - 1].Name)" -ForegroundColor Green
    }
}

Set-AzContext -Subscription $SubscriptionId | Out-Null

# Prompt for Resource Group if not provided
if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host " Resource Group Selection " -ForegroundColor White
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host ""
    Write-Host "Retrieving available resource groups..." -ForegroundColor Cyan
    
    $resourceGroups = Get-AzResourceGroup | Sort-Object ResourceGroupName
    
    if ($resourceGroups.Count -eq 0) {
        throw "No resource groups found in the selected subscription."
    }
    
    Write-Host ""
    Write-Host "Available resource groups:" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
        Write-Host "  $($i + 1). $($resourceGroups[$i].ResourceGroupName)" -ForegroundColor White
        Write-Host "      Location: $($resourceGroups[$i].Location)" -ForegroundColor Gray
    }
    
    Write-Host ""
    do {
        $selection = Read-Host "Select resource group (1-$($resourceGroups.Count))"
        $selectionInt = 0
        $validSelection = [int]::TryParse($selection, [ref]$selectionInt) -and 
        $selectionInt -ge 1 -and $selectionInt -le $resourceGroups.Count
        
        if (-not $validSelection) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($resourceGroups.Count)." -ForegroundColor Red
        }
    } while (-not $validSelection)
    
    $ResourceGroupName = $resourceGroups[$selectionInt - 1].ResourceGroupName
    Write-Host ""
    Write-Host "Selected: $ResourceGroupName" -ForegroundColor Green
}

# Prompt for Host Pool Name if not provided
if ([string]::IsNullOrWhiteSpace($HostPoolName)) {
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host " Host Pool Selection " -ForegroundColor White
    Write-Host ("=" * 100) -ForegroundColor White
    Write-Host ""
    Write-Host "Retrieving available host pools..." -ForegroundColor Cyan
    
    $hostPools = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DesktopVirtualization/hostPools" | 
    Sort-Object Name
    
    if ($hostPools.Count -eq 0) {
        throw "No host pools found in resource group '$ResourceGroupName'."
    }
    
    Write-Host ""
    Write-Host "Available host pools in '$ResourceGroupName':" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $hostPools.Count; $i++) {
        Write-Host "  $($i + 1). $($hostPools[$i].Name)" -ForegroundColor White
        Write-Host "      Location: $($hostPools[$i].Location)" -ForegroundColor Gray
    }
    
    Write-Host ""
    do {
        $selection = Read-Host "Select host pool (1-$($hostPools.Count))"
        $selectionInt = 0
        $validSelection = [int]::TryParse($selection, [ref]$selectionInt) -and 
        $selectionInt -ge 1 -and $selectionInt -le $hostPools.Count
        
        if (-not $validSelection) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($hostPools.Count)." -ForegroundColor Red
        }
    } while (-not $validSelection)
    
    $HostPoolName = $hostPools[$selectionInt - 1].Name
    Write-Host ""
    Write-Host "Selected: $HostPoolName" -ForegroundColor Green
}

# Prompt user for scope selection
Write-Host ""
Write-Host ("=" * 100) -ForegroundColor White
Write-Host " RBAC Assignment Scope Selection " -ForegroundColor White
Write-Host ("=" * 100) -ForegroundColor White
Write-Host ""
Write-Host "AVD Scaling Plans Prerequisites:" -ForegroundColor Yellow
Write-Host "  - Azure Virtual Desktop service principal requires 'Desktop Virtualization Contributor' role" -ForegroundColor Gray
Write-Host "  - Role can be assigned at Subscription, Resource Group, or Host Pool level" -ForegroundColor Gray
Write-Host "  - Scaling plan must have permissions on all host pools it manages" -ForegroundColor Gray
Write-Host ""
Write-Host "Please select the scope for the role assignment:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Host Pool Scope (Most Restrictive - Recommended)" -ForegroundColor White
Write-Host "      - Grants permissions to specific host pool only" -ForegroundColor Gray
Write-Host "      - Best practice for least-privilege access" -ForegroundColor Gray
Write-Host "      - Use when: Scaling plan targets single host pool" -ForegroundColor Gray
Write-Host "      - Scope: /subscriptions/.../hostPools/$HostPoolName" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. Resource Group Scope (Moderate)" -ForegroundColor White
Write-Host "      - Grants permissions to all host pools in resource group" -ForegroundColor Gray
Write-Host "      - Balanced approach for multiple host pools in same RG" -ForegroundColor Gray
Write-Host "      - Use when: Multiple host pools in same resource group share scaling plan" -ForegroundColor Gray
Write-Host "      - Scope: /subscriptions/.../resourceGroups/$ResourceGroupName" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. Subscription Scope (Broadest Access)" -ForegroundColor White
Write-Host "      - Grants permissions to all host pools in subscription" -ForegroundColor Gray
Write-Host "      - Maximum flexibility but broader permissions" -ForegroundColor Gray
Write-Host "      - Use when: Enterprise-wide scaling plan manages host pools across multiple RGs" -ForegroundColor Gray
Write-Host "      - Scope: /subscriptions/$SubscriptionId" -ForegroundColor DarkGray
Write-Host ""

do {
    $choice = Read-Host "Select scope (1, 2, or 3) [Default: 1]"
    
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = "1"
    }
    
    $validChoice = $choice -in @('1', '2', '3')
    if (-not $validChoice) {
        Write-Host "Invalid selection. Please enter 1, 2, or 3." -ForegroundColor Red
    }
} while (-not $validChoice)

# Build scope based on user choice
$hostPoolScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName"
$resourceGroupScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
$subscriptionScope = "/subscriptions/$SubscriptionId"

$scopeName = switch ($choice) {
    '1' { "Host Pool" }
    '2' { "Resource Group" }
    '3' { "Subscription" }
}

$scope = switch ($choice) {
    '1' { $hostPoolScope }
    '2' { $resourceGroupScope }
    '3' { $subscriptionScope }
}

Write-Host ""
Write-Host "Selected Scope: $scopeName" -ForegroundColor Green
Write-Host "Scope Path: $scope" -ForegroundColor Gray
Write-Host ""

# Try to locate the AVD service principal in common ways
Write-Host ""
Write-Host ("=" * 100) -ForegroundColor White
Write-Host " Service Principal Discovery " -ForegroundColor White
Write-Host ("=" * 100) -ForegroundColor White
Write-Host ""
Write-Host "Searching for Azure Virtual Desktop service principal..." -ForegroundColor Cyan

$sp = $null

# 1) DisplayName "Azure Virtual Desktop"
$sp = Get-AzADServicePrincipal -DisplayName "Azure Virtual Desktop" -ErrorAction SilentlyContinue

# 2) If not found, try "aadapp_AzureVirtualDesktop" (common in some tenants)
if (-not $sp) {
    $sp = Get-AzADServicePrincipal -DisplayName "aadapp_AzureVirtualDesktop" -ErrorAction SilentlyContinue
}

# 3) If still not found, try partial match
if (-not $sp) {
    $sp = Get-AzADServicePrincipal -All |
    Where-Object { $_.DisplayName -match "Azure Virtual Desktop|aadapp_AzureVirtualDesktop" } |
    Select-Object -First 1
}

if (-not $sp) {
    throw "Could not find the Azure Virtual Desktop service principal. Check Enterprise Applications / Managed Identities and confirm its name."
}

# If multiple returned, pick first (you can refine if needed)
if ($sp -is [System.Array]) { $sp = $sp[0] }

Write-Host "[SUCCESS] Found service principal" -ForegroundColor Green
Write-Host "  Display Name: $($sp.DisplayName)" -ForegroundColor Gray
Write-Host "  Object ID: $($sp.Id)" -ForegroundColor Gray
Write-Host ""

# Check if assignment already exists
Write-Host ("=" * 100) -ForegroundColor White
Write-Host " Role Assignment " -ForegroundColor White
Write-Host ("=" * 100) -ForegroundColor White
Write-Host ""

$existing = Get-AzRoleAssignment -ObjectId $sp.Id -Scope $scope -ErrorAction SilentlyContinue |
Where-Object { $_.RoleDefinitionName -eq $roleName }

if ($existing) {
    Write-Host "[INFO] Role assignment already exists" -ForegroundColor Yellow
    Write-Host "  Role: $roleName" -ForegroundColor Gray
    Write-Host "  Scope: $scope" -ForegroundColor Gray
    Write-Host ""
    Write-Host "No action required. The service principal already has the necessary permissions." -ForegroundColor Yellow
}
else {
    Write-Host "Creating role assignment..." -ForegroundColor Cyan
    Write-Host "  Role: $roleName" -ForegroundColor Gray
    Write-Host "  Principal: $($sp.DisplayName)" -ForegroundColor Gray
    Write-Host "  Scope: $scope" -ForegroundColor Gray
    Write-Host ""
    
    New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $roleName -Scope $scope | Out-Null
    
    Write-Host "[SUCCESS] Role assignment created successfully!" -ForegroundColor Green
}

# Verification output
Write-Host ""
Write-Host ("=" * 100) -ForegroundColor White
Write-Host " Verification - Current Role Assignments " -ForegroundColor White
Write-Host ("=" * 100) -ForegroundColor White
Write-Host ""

$assignments = Get-AzRoleAssignment -ObjectId $sp.Id -Scope $scope |
Select-Object RoleDefinitionName, Scope, DisplayName, ObjectId

if ($assignments) {
    $assignments | Format-Table -AutoSize
}
else {
    Write-Host "No assignments found at this scope." -ForegroundColor Yellow
}

Write-Host ""
Write-Host ("=" * 100) -ForegroundColor White
Write-Host " Script Completed " -ForegroundColor White
Write-Host ("=" * 100) -ForegroundColor White

#endregion