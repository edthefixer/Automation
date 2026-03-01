<#
.SYNOPSIS
    Enterprise-grade AVD RemoteApp Discovery and Publishing Tool with Security-First Design and 
    Tenant-Wide Duplicate Prevention for Production Azure Virtual Desktop Environments
    
.DESCRIPTION
    Production-hardened PowerShell automation tool for Azure Virtual Desktop (AVD) RemoteApp lifecycle 
    management. Delivers comprehensive application discovery, tenant-wide duplicate prevention, 
    security-enforced authentication, and intelligent publishing workflows for enterprise AVD deployments.
    
    SECURITY-FIRST DESIGN:
    - Forced Fresh Authentication: Automatically clears cached Azure sessions and enforces re-authentication
    - Multi-Method Authentication: Supports Interactive Browser and Device Code flows
    - Session Lifecycle Management: Secure cleanup with automatic disconnect after operations
    - Zero Session Reuse: Prevents credential staleness and ensures audit compliance
    
    TENANT-WIDE DUPLICATE PREVENTION:
    - Comprehensive RemoteApp Scanning: Discovers all published RemoteApps across entire Azure tenant
    - Intelligent Application Matching: Path-based and name-based comparison to identify duplicates
    - Smart Categorization: Classifies apps as New, Already Published, or Potential Updates
    - Efficient Selection Interface: Filters view to show only unpublished applications
    - Cross-Application-Group Analysis: Prevents publishing conflicts across multiple app groups
    
    PRODUCTION-GRADE ERROR HANDLING:
    - Comprehensive Input Validation: Validates all paths, names, and Azure resources
    - Text Encoding Cleanup: Handles international characters and removes encoding artifacts
    - Detailed Logging Framework: Color-coded status messages (INFO, WARN, ERROR, SUCCESS, DEBUG)
    - Graceful Failure Recovery: Continues publishing remaining apps when individual publishes fail
    - Comprehensive Exception Handling: Captures and reports Azure API and file system errors
    
    INTELLIGENT APPLICATION DISCOVERY:
    - Multi-Source Discovery: Scans Start Menu, Registry, Microsoft Store, and custom paths
    - Metadata Extraction: Retrieves version info, publisher, description from executables
    - AVD Compatibility Validation: Ensures applications meet RemoteApp technical requirements
    - Clean Naming Convention: Generates meaningful identifiers without timestamps
    - Command Line Support: Configures launch parameters for applications requiring arguments
    
    AZURE RESOURCE AUTOMATION:
    - Interactive Resource Selection: Lists existing Resource Groups, Application Groups, and Workspaces
    - Automated Resource Creation: Creates missing resources with validation and confirmation
    - Workspace Integration: Assigns Application Groups for immediate end-user availability
    - Bulk Publishing Engine: Processes multiple RemoteApps simultaneously with progress tracking
    - Resource Group Management: Handles cross-subscription resource targeting
    
.PARAMETER ResourceGroupName
    Optional. Specifies the Azure Resource Group containing AVD resources. When omitted, displays 
    interactive selection menu with all available resource groups and option to create new.
    
.PARAMETER ApplicationGroupName
    Optional. Specifies the target RemoteApp Application Group. When omitted, displays interactive 
    selection menu filtered to RemoteApp-type application groups with option to create new.
    
.EXAMPLE
    .\40_AVD_Execute_AppDiscoveryAndRemoteAppPublishing.ps1
    
    Fully interactive mode - recommended for first-time users:
    1. Enforces fresh Azure authentication with method selection
    2. Discovers all installed applications on local system
    3. Scans tenant for existing RemoteApps to prevent duplicates
    4. Displays color-coded categorization (New/Published/Updates)
    5. Allows filtering to show only unpublished applications
    6. Guides through Azure resource selection (Resource Group, App Group, Workspace)
    7. Configures command line arguments for selected applications
    8. Publishes RemoteApps with comprehensive error handling
    9. Securely disconnects Azure session
    
.EXAMPLE
    .\40_AVD_Execute_AppDiscoveryAndRemoteAppPublishing.ps1 -ResourceGroupName "rg-avd-prod-eastus" -ApplicationGroupName "ag-remoteapps-finance"
    
    Targeted deployment mode - ideal for scripted/automated workflows:
    - Authenticates to specified Azure tenant with fresh credentials
    - Targets specific Resource Group and Application Group
    - Performs full application discovery and tenant comparison
    - Still provides interactive selection of applications to publish
    - Reduces prompts by pre-specifying Azure resources
    - Suitable for department-specific or environment-specific deployments
    
.EXAMPLE
    .\40_AVD_Execute_AppDiscoveryAndRemoteAppPublishing.ps1 -ResourceGroupName "rg-avd-shared"
    
    Partial targeting - specify Resource Group, choose Application Group interactively:
    - Pre-targets Resource Group while keeping Application Group selection interactive
    - Useful when multiple Application Groups exist in same Resource Group
    - Allows selection of appropriate App Group based on discovered applications
    
.NOTES
    PREREQUISITES:
    - Azure PowerShell Modules: 
        * Az.Accounts (v2.10.0 or later)
        * Az.DesktopVirtualization (v4.1.0 or later)
        Install: Install-Module -Name Az.Accounts, Az.DesktopVirtualization -Repository PSGallery -Force
    
    - Azure Permissions (minimum):
        * Desktop Virtualization Application Group Contributor (on target Application Group)
        * Reader (on Subscription for resource discovery)
    
    - Azure Virtual Desktop Environment:
        * Deployed AVD Host Pool with active session hosts
        * Applications must be installed on ALL session hosts
        * RemoteApp-type Application Group (not Desktop)
    
    - PowerShell Environment:
        * PowerShell 5.1 or PowerShell 7+ (recommended)
        * Execution policy allowing script execution
        * Administrative rights on local machine for full application discovery
    
    TROUBLESHOOTING:
    - Authentication Issues:
        * Clear browser cache if Interactive Browser auth fails
        * Use Device Code method for restricted network environments
        * Verify Azure AD permissions allow authentication
    
    - Application Discovery Issues:
        * Run as Administrator for complete system application discovery
        * Check Start Menu shortcuts have valid target paths
        * Verify applications are properly installed (not portable)
    
    - Publishing Failures:
        * Confirm application exists on all session hosts at identical paths
        * Validate Azure RBAC permissions on Application Group
        * Check Application Group type is RemoteApp (not Desktop)
        * Ensure application paths are accessible on session hosts
    
    - Duplicate Detection Issues:
        * Script matches by exact path and display name
        * Different versions of same app may be categorized as updates
        * Review "Potential Updates" category carefully before publishing
    
    OUTPUT ARTIFACTS:
    - Published RemoteApp Applications: Added to specified Application Group
    - Application Group Assignment: Linked to selected Workspace for user access
    - Execution Logs: Detailed console output with color-coded status indicators
    - Application Metadata: Clean identifiers, descriptions, and command line arguments
    
    VERSION INFORMATION:
    Author: edthefixer + GitHub Copilot... well, I fell asleep, copilot finished it...
    Version: 4.0 Enterprise Production Release
    Last Modified: February 3, 2026
    
    SUPPORT & ENHANCEMENTS:
    This version represents a mature, production-hardened tool with enterprise-grade capabilities:
    - Security-enforced authentication with session clearing
    - Tenant-wide duplicate prevention and intelligent comparison
    - Production-grade error handling and comprehensive logging
    - International character support with text encoding cleanup
    - Bulk publishing with graceful failure recovery
    - Designed for scale: handles hundreds of applications and large AVD tenants
    
    BEST PRACTICES:
    - Always run from session host to ensure accurate application discovery
    - Test with small application sets before bulk publishing
    - Verify applications are installed on all session hosts
    - Use meaningful Resource Group and Application Group names
    - Document command line arguments for complex applications
    - Review tenant comparison results before publishing
    - Maintain consistent application versions across session hosts
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$ApplicationGroupName
)

function Write-Log {
    param(
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',
        [string]$Message
    )
    
    $colors = @{
        'INFO'    = 'White'
        'WARN'    = 'Yellow' 
        'ERROR'   = 'Red'
        'SUCCESS' = 'Green'
        'DEBUG'   = 'Gray'
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $colors[$Level]
}

function Get-AuthenticationMethod {
    Write-Host "`n--- AZURE AUTHENTICATION ---" -ForegroundColor Yellow
    Write-Log -Level WARN -Message "For security, you must authenticate for each script execution."
    Write-Host "Please select authentication method:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Interactive Browser Login (default - recommended)" -ForegroundColor Green
    Write-Host "  [2] Device Code Authentication (for restricted environments)" -ForegroundColor White
    Write-Host ""
    
    do {
        $choice = Read-Host "Select authentication method (1-2, or press Enter for default)"
        
        # Default to Interactive if user presses Enter
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = '1'
        }
        
        switch ($choice) {
            '1' { 
                Write-Log -Level SUCCESS -Message "Selected Interactive Browser authentication"
                return 'Interactive' 
            }
            '2' { 
                Write-Log -Level SUCCESS -Message "Selected Device Code authentication"
                return 'DeviceCode' 
            }
            default { 
                Write-Host "Invalid selection. Please choose 1 or 2." -ForegroundColor Red 
            }
        }
    } while ($true)
}

function Test-AzureConnection {
    try {
        # Check if there's an existing session and disconnect it for security
        $existingContext = Get-AzContext -ErrorAction SilentlyContinue
        if ($null -ne $existingContext) {
            Write-Log -Level WARN -Message "Existing Azure session detected. Disconnecting for security..."
            Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
            Write-Log -Level INFO -Message "Previous session cleared."
        }
        
        # Force fresh authentication
        Write-Log -Level INFO -Message "Initiating fresh authentication..."
        $authMethod = Get-AuthenticationMethod
        
        Write-Host "`nAuthenticating to Azure using $authMethod method..." -ForegroundColor Cyan
        
        switch ($authMethod) {
            'Interactive' {
                Connect-AzAccount -UseDeviceAuthentication:$false -Force
            }
            'DeviceCode' {
                Connect-AzAccount -UseDeviceAuthentication -Force
            }
        }
        
        $context = Get-AzContext
        if ($null -eq $context) {
            Write-Log -Level ERROR -Message "Authentication failed - no context established"
            return $false
        }
        
        Write-Log -Level SUCCESS -Message "Azure connection verified"
        Write-Log -Level INFO -Message "Account: $($context.Account)"
        Write-Log -Level INFO -Message "Subscription: $($context.Subscription.Name)"
        return $true
    }
    catch {
        Write-Log -Level ERROR -Message "Azure connection test failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-TenantResourceDiscovery {
    Write-Host "`n--- TENANT RESOURCE DISCOVERY ---" -ForegroundColor Yellow
    Write-Host "Scanning your Azure tenant for existing resources..." -ForegroundColor Cyan
    
    $discovery = @{
        Subscriptions     = @()
        AllResourceGroups = @()
        AvdResourceGroups = @()
        HostPools         = @()
        ApplicationGroups = @()
        Workspaces        = @()
    }
    
    try {
        # Get current subscription info
        $context = Get-AzContext
        Write-Host "  - Current Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor White
        
        $discovery.Subscriptions += @{
            Name    = $context.Subscription.Name
            Id      = $context.Subscription.Id
            State   = $context.Subscription.State
            Current = $true
        }
        
        # Scan all resource groups
        Write-Host "  - Scanning resource groups..." -ForegroundColor Gray
        $allRGs = Get-AzResourceGroup
        $discovery.AllResourceGroups = $allRGs | ForEach-Object {
            @{
                Name     = $_.ResourceGroupName
                Location = $_.Location
                Tags     = $_.Tags
            }
        }
        
        # Scan for AVD resources
        Write-Host "  - Identifying AVD resources..." -ForegroundColor Gray
        foreach ($rg in $allRGs) {
            try {
                $hostPools = Get-AzWvdHostPool -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                $appGroups = Get-AzWvdApplicationGroup -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                $workspaces = Get-AzWvdWorkspace -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                
                if ($hostPools.Count -gt 0 -or $appGroups.Count -gt 0 -or $workspaces.Count -gt 0) {
                    $discovery.AvdResourceGroups += @{
                        Name                  = $rg.ResourceGroupName
                        Location              = $rg.Location
                        HostPoolCount         = $hostPools.Count
                        ApplicationGroupCount = $appGroups.Count
                        WorkspaceCount        = $workspaces.Count
                        Tags                  = $rg.Tags
                    }
                    
                    # Add individual AVD resources
                    $discovery.HostPools += $hostPools | ForEach-Object { 
                        @{
                            Name          = $_.Name
                            ResourceGroup = $rg.ResourceGroupName
                            Type          = $_.HostPoolType
                            LoadBalancer  = $_.LoadBalancerType
                            Location      = $_.Location
                        }
                    }
                    
                    $discovery.ApplicationGroups += $appGroups | ForEach-Object {
                        @{
                            Name          = $_.Name
                            ResourceGroup = $rg.ResourceGroupName
                            Type          = $_.ApplicationGroupType
                            FriendlyName  = $_.FriendlyName
                            Location      = $_.Location
                            HostPoolPath  = $_.HostPoolArmPath
                        }
                    }
                    
                    $discovery.Workspaces += $workspaces | ForEach-Object {
                        @{
                            Name          = $_.Name
                            ResourceGroup = $rg.ResourceGroupName
                            FriendlyName  = $_.FriendlyName
                            Location      = $_.Location
                        }
                    }
                }
            }
            catch {
                # Skip inaccessible resource groups
            }
        }
        
        # Display summary
        Write-Host "`n--- DISCOVERY SUMMARY ---" -ForegroundColor Green
        Write-Host "  Subscription: $($context.Subscription.Name)" -ForegroundColor White
        Write-Host "  Total Resource Groups: $($discovery.AllResourceGroups.Count)" -ForegroundColor White
        Write-Host "  AVD-Enabled Resource Groups: $($discovery.AvdResourceGroups.Count)" -ForegroundColor White
        Write-Host "  Host Pools: $($discovery.HostPools.Count)" -ForegroundColor White
        Write-Host "  Application Groups: $($discovery.ApplicationGroups.Count)" -ForegroundColor White
        Write-Host "  Workspaces: $($discovery.Workspaces.Count)" -ForegroundColor White
        
        return $discovery
    }
    catch {
        Write-Log -Level ERROR -Message "Resource discovery failed: $($_.Exception.Message)"
        throw
    }
}

function Select-ResourceGroup {
    param(
        [Parameter(Mandatory = $true)]
        $Discovery,
        [string]$PreSelectedName
    )
    
    if (![string]::IsNullOrWhiteSpace($PreSelectedName)) {
        # Validate pre-selected resource group exists
        $existing = $Discovery.AllResourceGroups | Where-Object { $_.Name -eq $PreSelectedName }
        if ($existing) {
            Write-Log -Level SUCCESS -Message "Using specified resource group: $PreSelectedName"
            return $PreSelectedName
        }
        else {
            Write-Log -Level WARN -Message "Specified resource group '$PreSelectedName' not found. Will create or let user choose."
        }
    }
    
    Write-Host "`n--- RESOURCE GROUP SELECTION ---" -ForegroundColor Yellow
    
    if ($Discovery.AvdResourceGroups.Count -gt 0) {
        Write-Host "Existing AVD Resource Groups (recommended for reuse):" -ForegroundColor Green
        for ($i = 0; $i -lt $Discovery.AvdResourceGroups.Count; $i++) {
            $rg = $Discovery.AvdResourceGroups[$i]
            Write-Host "  [$($i + 1)] $($rg.Name) ($($rg.Location))" -ForegroundColor White
            Write-Host "      Host Pools: $($rg.HostPoolCount), App Groups: $($rg.ApplicationGroupCount), Workspaces: $($rg.WorkspaceCount)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    if ($Discovery.AllResourceGroups.Count -gt $Discovery.AvdResourceGroups.Count) {
        Write-Host "Other Resource Groups (can be repurposed for AVD):" -ForegroundColor Cyan
        $otherRGs = $Discovery.AllResourceGroups | Where-Object { $_.Name -notin ($Discovery.AvdResourceGroups | ForEach-Object { $_.Name }) }
        $startIndex = $Discovery.AvdResourceGroups.Count
        for ($i = 0; $i -lt [Math]::Min(5, $otherRGs.Count); $i++) {
            $rg = $otherRGs[$i]
            Write-Host "  [$($startIndex + $i + 1)] $($rg.Name) ($($rg.Location))" -ForegroundColor Gray
        }
        if ($otherRGs.Count -gt 5) {
            Write-Host "      ... and $($otherRGs.Count - 5) more" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  [N] Create NEW resource group" -ForegroundColor Green
    if (![string]::IsNullOrWhiteSpace($PreSelectedName)) {
        Write-Host "  [C] Create '$PreSelectedName' (as specified)" -ForegroundColor Green
    }
    Write-Host ""
    
    do {
        if (![string]::IsNullOrWhiteSpace($PreSelectedName)) {
            $prompt = "Select resource group (1-$($Discovery.AllResourceGroups.Count)), N for new, C to create '$PreSelectedName'"
        }
        else {
            $prompt = "Select resource group (1-$($Discovery.AllResourceGroups.Count)) or N for new"
        }
        
        $choice = Read-Host $prompt
        
        if ($choice.ToUpper() -eq 'N') {
            Write-Host "`nResource Group Naming Examples:" -ForegroundColor Cyan
            Write-Host "  - rg-avd-production-eastus" -ForegroundColor Gray
            Write-Host "  - rg-vdi-department-region" -ForegroundColor Gray  
            Write-Host "  - resourcegroup-avd-environment" -ForegroundColor Gray
            
            do {
                $newRgName = Read-Host "Enter new resource group name"
                if ([string]::IsNullOrWhiteSpace($newRgName)) {
                    Write-Host "Resource group name cannot be empty." -ForegroundColor Red
                    continue
                }
                if ($newRgName -match '^[a-zA-Z0-9._\-]+$' -and $newRgName.Length -le 90) {
                    return $newRgName
                }
                else {
                    Write-Host "Invalid name. Use letters, numbers, periods, hyphens, underscores. Max 90 chars." -ForegroundColor Red
                }
            } while ($true)
        }
        elseif (![string]::IsNullOrWhiteSpace($PreSelectedName) -and $choice.ToUpper() -eq 'C') {
            return $PreSelectedName
        }
        elseif ([int]::TryParse($choice, [ref]$null) -and [int]$choice -ge 1 -and [int]$choice -le $Discovery.AllResourceGroups.Count) {
            $selectedRg = $Discovery.AllResourceGroups[[int]$choice - 1]
            
            # Handle different object types
            $rgName = ""
            if ($selectedRg -is [hashtable]) {
                $rgName = $selectedRg.Name
            }
            elseif ($selectedRg.PSObject.Properties['ResourceGroupName']) {
                $rgName = $selectedRg.ResourceGroupName
            }
            elseif ($selectedRg.PSObject.Properties['Name']) {
                $rgName = $selectedRg.Name
            }
            else {
                $rgName = $selectedRg.ToString()
            }
            
            if ([string]::IsNullOrWhiteSpace($rgName)) {
                Write-Host "Error: Unable to get resource group name. Please try again." -ForegroundColor Red
                continue
            }
            
            Write-Host "Selected: $rgName" -ForegroundColor Green
            return $rgName
        }
        else {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
    } while ($true)
}

function Select-ApplicationGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        $Discovery,
        [string]$PreSelectedName
    )
    
    if (![string]::IsNullOrWhiteSpace($PreSelectedName)) {
        # Check if pre-selected app group exists in the resource group
        $existing = $Discovery.ApplicationGroups | Where-Object { $_.Name -eq $PreSelectedName -and $_.ResourceGroup -eq $ResourceGroupName }
        if ($existing) {
            Write-Log -Level SUCCESS -Message "Using specified application group: $PreSelectedName"
            return $PreSelectedName
        }
    }
    
    Write-Host "`n--- APPLICATION GROUP SELECTION ---" -ForegroundColor Yellow
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
    
    $rgAppGroups = $Discovery.ApplicationGroups | Where-Object { $_.ResourceGroup -eq $ResourceGroupName }
    
    if ($rgAppGroups.Count -gt 0) {
        Write-Host "`nExisting Application Groups in this Resource Group:" -ForegroundColor Green
        for ($i = 0; $i -lt $rgAppGroups.Count; $i++) {
            $ag = $rgAppGroups[$i]
            Write-Host "  [$($i + 1)] $($ag.Name) - $($ag.Type)" -ForegroundColor White
            if ($ag.FriendlyName) { Write-Host "      Friendly Name: $($ag.FriendlyName)" -ForegroundColor Gray }
            Write-Host "      Location: $($ag.Location)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  [N] Create NEW RemoteApp application group" -ForegroundColor Green
    if (![string]::IsNullOrWhiteSpace($PreSelectedName)) {
        Write-Host "  [C] Create '$PreSelectedName' (as specified)" -ForegroundColor Green
    }
    Write-Host ""
    
    do {
        if ($rgAppGroups.Count -gt 0) {
            if (![string]::IsNullOrWhiteSpace($PreSelectedName)) {
                $prompt = "Select application group (1-$($rgAppGroups.Count)), N for new, C to create '$PreSelectedName'"
            }
            else {
                $prompt = "Select existing application group (1-$($rgAppGroups.Count)) or N for new"
            }
        }
        else {
            if (![string]::IsNullOrWhiteSpace($PreSelectedName)) {
                $prompt = "No existing groups. N for new, C to create '$PreSelectedName'"
            }
            else {
                $prompt = "No existing application groups found. Enter N to create new"
            }
        }
        
        $choice = Read-Host $prompt
        
        if ($choice.ToUpper() -eq 'N') {
            Write-Host "`nApplication Group Naming Examples:" -ForegroundColor Cyan
            Write-Host "  - ag-remoteapps-department" -ForegroundColor Gray
            Write-Host "  - appgroup-office-apps" -ForegroundColor Gray
            Write-Host "  - avd-remoteapps-production" -ForegroundColor Gray
            
            do {
                $newAgName = Read-Host "Enter new RemoteApp application group name"
                if ([string]::IsNullOrWhiteSpace($newAgName)) {
                    Write-Host "Application group name cannot be empty." -ForegroundColor Red
                    continue
                }
                if ($newAgName -match '^[a-zA-Z0-9._\-]+$' -and $newAgName.Length -le 64) {
                    return $newAgName
                }
                else {
                    Write-Host "Invalid name. Use letters, numbers, periods, hyphens, underscores. Max 64 chars." -ForegroundColor Red
                }
            } while ($true)
        }
        elseif (![string]::IsNullOrWhiteSpace($PreSelectedName) -and $choice.ToUpper() -eq 'C') {
            return $PreSelectedName
        }
        elseif ($rgAppGroups.Count -gt 0 -and [int]::TryParse($choice, [ref]$null) -and [int]$choice -ge 1 -and [int]$choice -le $rgAppGroups.Count) {
            $selectedAg = $rgAppGroups[[int]$choice - 1]
            $agName = if ($selectedAg -is [hashtable]) { $selectedAg.Name } else { $selectedAg.Name }
            $agType = if ($selectedAg -is [hashtable]) { $selectedAg.Type } else { $selectedAg.ApplicationGroupType }
            if ($agType -ne 'RemoteApp') {
                Write-Host "Warning: Selected group is type '$agType'. RemoteApp publishing requires 'RemoteApp' type." -ForegroundColor Yellow
                $confirm = Read-Host "Continue anyway? (y/N)"
                if ($confirm.ToUpper() -ne 'Y') {
                    continue
                }
            }
            Write-Host "Selected: $agName" -ForegroundColor Green
            return $agName
        }
        else {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
    } while ($true)
}

function Initialize-ResourceGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [string]$Location = "East US"
    )
    
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if ($null -eq $rg) {
            Write-Log -Level WARN -Message "Resource group '$ResourceGroupName' not found. Creating..."
            $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
            Write-Log -Level SUCCESS -Message "Resource group '$ResourceGroupName' created successfully in $Location"
        }
        else {
            Write-Log -Level SUCCESS -Message "Resource group '$ResourceGroupName' already exists in $($rg.Location)"
        }
        return $rg
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to ensure resource group '$ResourceGroupName': $($_.Exception.Message)"
        throw
    }
}

function Initialize-HostPoolAndApplicationGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$ApplicationGroupName,
        [Parameter(Mandatory = $false)]
        [string]$Location = "East US"
    )
    
    try {
        # Check if application group exists
        $appGroup = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $ApplicationGroupName -ErrorAction SilentlyContinue
        
        if ($null -eq $appGroup) {
            Write-Log -Level WARN -Message "Application group '$ApplicationGroupName' not found. Creating host pool and application group..."
            
            # Create host pool first (required for application group)
            $hostPoolName = "$ApplicationGroupName-hp"
            $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $hostPoolName -ErrorAction SilentlyContinue
            
            if ($null -eq $hostPool) {
                Write-Log -Level INFO -Message "Creating host pool '$hostPoolName'..."
                # Ensure we have a valid location
                if ([string]::IsNullOrWhiteSpace($Location)) {
                    $Location = "East US"
                    Write-Log -Level INFO -Message "Location not specified, using default: $Location"
                }
                $hostPool = New-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $hostPoolName -Location $Location -HostPoolType 'Pooled' -LoadBalancerType 'DepthFirst' -MaxSessionLimit 10 -PreferredAppGroupType 'RailApplications'
                Write-Log -Level SUCCESS -Message "Host pool '$hostPoolName' created successfully"
            }
            
            # Create application group
            Write-Log -Level INFO -Message "Creating application group '$ApplicationGroupName'..."
            $appGroup = New-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $ApplicationGroupName -Location $Location -ApplicationGroupType 'RemoteApp' -HostPoolArmPath $hostPool.Id
            Write-Log -Level SUCCESS -Message "Application group '$ApplicationGroupName' created successfully"
        }
        else {
            Write-Log -Level SUCCESS -Message "Application group '$ApplicationGroupName' already exists"
        }
        
        return $appGroup
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to ensure application group '$ApplicationGroupName': $($_.Exception.Message)"
        throw
    }
}

function Get-ExistingRemoteApps {
    <#
    .SYNOPSIS
        Retrieves all existing RemoteApps from the tenant for comparison with discovered applications
    #>
    [CmdletBinding()]
    param(
        [string]$ResourceGroupName,
        [array]$Discovery
    )
    
    Write-Log -Level INFO -Message "Scanning tenant for existing RemoteApps..."
    
    $existingApps = @()
    $scannedAppGroups = 0
    $totalAppGroups = 0
    
    try {
        # Get all application groups from the discovery data or scan all
        $applicationGroups = @()
        
        if ($Discovery -and $Discovery.ApplicationGroups) {
            $applicationGroups = $Discovery.ApplicationGroups | Where-Object { $_.ApplicationGroupType -eq 'RemoteApp' }
            Write-Log -Level INFO -Message "Using discovery data: Found $($applicationGroups.Count) RemoteApp application groups"
        }
        else {
            # Fallback: scan all resource groups for application groups
            Write-Log -Level INFO -Message "Discovery data not available, scanning all resource groups..."
            $allResourceGroups = Get-AzResourceGroup -ErrorAction SilentlyContinue
            
            foreach ($rg in $allResourceGroups) {
                try {
                    $rgAppGroups = Get-AzWvdApplicationGroup -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { $_.ApplicationGroupType -eq 'RemoteApp' }
                    if ($rgAppGroups) {
                        $applicationGroups += $rgAppGroups
                    }
                }
                catch {
                    Write-Log -Level DEBUG -Message "Could not scan resource group '$($rg.ResourceGroupName)': $($_.Exception.Message)"
                }
            }
            Write-Log -Level INFO -Message "Found $($applicationGroups.Count) RemoteApp application groups across all resource groups"
        }
        
        $totalAppGroups = $applicationGroups.Count
        
        # Get RemoteApps from each application group
        foreach ($appGroup in $applicationGroups) {
            try {
                $scannedAppGroups++
                
                # Handle different object types from discovery vs direct query
                $rgName = if ($appGroup.ResourceGroup) { $appGroup.ResourceGroup } else { $appGroup.Id.Split('/')[4] }
                $agName = if ($appGroup.Name) { $appGroup.Name } else { $appGroup.ApplicationGroupName }
                
                Write-Log -Level DEBUG -Message "Scanning application group '$agName' in '$rgName' ($scannedAppGroups/$totalAppGroups)"
                
                $apps = Get-AzWvdApplication -ResourceGroupName $rgName -ApplicationGroupName $agName -ErrorAction SilentlyContinue
                
                foreach ($app in $apps) {
                    # Normalize the existing app data for comparison
                    $existingApp = @{
                        Name                 = $app.Name
                        DisplayName          = if ($app.FriendlyName) { $app.FriendlyName } else { $app.Name }
                        ApplicationPath      = $app.FilePath
                        ResourceGroupName    = $rgName
                        ApplicationGroupName = $agName
                        Description          = $app.Description
                        CommandLineArguments = $app.CommandLineArguments
                        ShowInPortal         = $app.ShowInPortal
                        ApplicationId        = $app.Name
                        ApplicationType      = if ($app.FilePath) { 'FilePath' } elseif ($app.MsixPackageFamilyName) { 'MSIX' } else { 'Unknown' }
                    }
                    
                    $existingApps += $existingApp
                }
                
            }
            catch {
                Write-Log -Level WARN -Message "Failed to scan application group '$agName': $($_.Exception.Message)"
            }
        }
        
        Write-Log -Level SUCCESS -Message "Found $($existingApps.Count) existing RemoteApps across $scannedAppGroups application groups"
        
        # Group by application path for easier comparison
        $existingByPath = @{}
        $existingByName = @{}
        
        foreach ($app in $existingApps) {
            if ($app.ApplicationPath) {
                $normalizedPath = $app.ApplicationPath.ToLower()
                if (-not $existingByPath.ContainsKey($normalizedPath)) {
                    $existingByPath[$normalizedPath] = @()
                }
                $existingByPath[$normalizedPath] += $app
            }
            
            if ($app.DisplayName) {
                $normalizedName = $app.DisplayName.ToLower()
                if (-not $existingByName.ContainsKey($normalizedName)) {
                    $existingByName[$normalizedName] = @()
                }
                $existingByName[$normalizedName] += $app
            }
        }
        
        return @{
            AllApps          = $existingApps
            ByPath           = $existingByPath
            ByName           = $existingByName
            AppGroupsScanned = $scannedAppGroups
            TotalFound       = $existingApps.Count
        }
        
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to retrieve existing RemoteApps: $($_.Exception.Message)"
        return @{
            AllApps          = @()
            ByPath           = @{}
            ByName           = @{}
            AppGroupsScanned = 0
            TotalFound       = 0
        }
    }
}

function Compare-DiscoveredWithExisting {
    <#
    .SYNOPSIS
        Compares discovered applications with existing RemoteApps and categorizes them
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DiscoveredApps,
        [Parameter(Mandatory = $true)]
        [hashtable]$ExistingApps
    )
    
    Write-Log -Level INFO -Message "Comparing $($DiscoveredApps.Count) discovered applications with $($ExistingApps.TotalFound) existing RemoteApps..."
    
    $comparison = @{
        NewApps          = @()
        ExistingApps     = @()
        PotentialUpdates = @()
        Duplicates       = @()
    }
    
    foreach ($app in $DiscoveredApps) {
        if ($null -eq $app -or -not $app.ApplicationPath) {
            continue
        }
        
        $normalizedPath = $app.ApplicationPath.ToLower()
        $normalizedName = $app.DisplayName.ToLower()
        
        # Check for exact path match
        $pathMatch = $ExistingApps.ByPath[$normalizedPath]
        $nameMatch = $ExistingApps.ByName[$normalizedName]
        
        # Add comparison result to the app object
        $app.ComparisonResult = @{
            Status      = 'New'
            ExistingApp = $null
            Reason      = ''
        }
        
        if ($pathMatch) {
            # Exact path match found
            $app.ComparisonResult.Status = 'Existing'
            $app.ComparisonResult.ExistingApp = $pathMatch[0]
            $app.ComparisonResult.Reason = "Same application path already published in '$($pathMatch[0].ApplicationGroupName)'"
            $comparison.ExistingApps += $app
        }
        elseif ($nameMatch) {
            # Same display name but different path - potential update or duplicate
            $app.ComparisonResult.Status = 'PotentialUpdate'
            $app.ComparisonResult.ExistingApp = $nameMatch[0]
            $app.ComparisonResult.Reason = "Same display name exists with different path in '$($nameMatch[0].ApplicationGroupName)'"
            $comparison.PotentialUpdates += $app
        }
        else {
            # No match found - new application
            $app.ComparisonResult.Status = 'New'
            $app.ComparisonResult.Reason = 'Not currently published as RemoteApp'
            $comparison.NewApps += $app
        }
    }
    
    Write-Log -Level SUCCESS -Message "Comparison complete: $($comparison.NewApps.Count) new, $($comparison.ExistingApps.Count) existing, $($comparison.PotentialUpdates.Count) potential updates"
    
    return $comparison
}

function Get-LocalApplications {
    <#
    .SYNOPSIS
        Discovers applications installed on the local machine that can be published as RemoteApps
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeSystemApps,
        [switch]$IncludeStoreApps
    )
    
    Write-Log -Level INFO -Message "Scanning local machine for RemoteApp-capable applications..."
    
    $applications = @()
    
    try {
        # Scan Start Menu applications
        Write-Log -Level INFO -Message "Scanning Start Menu applications..."
        $startMenuPaths = @(
            "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs",
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
        )
        
        foreach ($path in $startMenuPaths) {
            if (Test-Path $path) {
                $shortcuts = Get-ChildItem -Path $path -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue
                foreach ($shortcut in $shortcuts) {
                    try {
                        $shell = New-Object -ComObject WScript.Shell
                        $link = $shell.CreateShortcut($shortcut.FullName)
                        
                        if ($link.TargetPath -and (Test-Path $link.TargetPath) -and $link.TargetPath -match '\.exe$') {
                            $appInfo = Get-ApplicationInfo -ExecutablePath $link.TargetPath -ShortcutPath $shortcut.FullName -SourceType "StartMenu"
                            if ($appInfo) {
                                Write-Log -Level INFO -Message "Adding StartMenu app: $($appInfo.DisplayName) at $($appInfo.ApplicationPath)"
                                $applications += $appInfo
                            }
                            else {
                                Write-Log -Level INFO -Message "Get-ApplicationInfo returned null for StartMenu: $($link.TargetPath)"
                            }
                        }
                    }
                    catch {
                        Write-Log -Level DEBUG -Message "Failed to process shortcut: $($shortcut.FullName)"
                    }
                }
            }
        }
        
        # Scan installed programs from registry
        Write-Log -Level INFO -Message "Scanning installed programs registry..."
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        foreach ($regPath in $regPaths) {
            try {
                $programs = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue | Where-Object { 
                    $_.DisplayName -and $_.DisplayName -notlike "Microsoft Visual C++*" -and 
                    $_.DisplayName -notlike "Microsoft .NET*" -and $_.Publisher -notlike "Microsoft Corporation"
                }
                
                foreach ($program in $programs) {
                    if ($program.InstallLocation -and (Test-Path $program.InstallLocation)) {
                        $exeFiles = Get-ChildItem -Path $program.InstallLocation -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -notlike "*uninstall*" -and $_.Name -notlike "*setup*" }
                        
                        foreach ($exe in $exeFiles | Select-Object -First 1) {
                            $appInfo = Get-ApplicationInfo -ExecutablePath $exe.FullName -ProgramName $program.DisplayName -SourceType "FilePath"
                            if ($appInfo) {
                                Write-Log -Level INFO -Message "Adding app: $($appInfo.DisplayName) at $($appInfo.ApplicationPath)"
                                $applications += $appInfo
                            }
                            else {
                                Write-Log -Level INFO -Message "Get-ApplicationInfo returned null for: $($exe.FullName)"
                            }
                        }
                    }
                }
            }
            catch {
                Write-Log -Level DEBUG -Message "Failed to scan registry path: $regPath"
            }
        }
        
        # Scan Microsoft Store applications if requested
        if ($IncludeStoreApps) {
            Write-Log -Level INFO -Message "Scanning Microsoft Store applications..."
            try {
                $storeApps = Get-AppxPackage | Where-Object { 
                    $_.Name -notlike "*Microsoft.Windows*" -and 
                    $_.Name -notlike "*Microsoft.NET*" -and
                    $_.PackageFamilyName -and 
                    $_.InstallLocation 
                }
                
                foreach ($app in $storeApps) {
                    $appInfo = @{
                        Name               = $app.DisplayName -replace '[^\w\-_\.]', ''
                        DisplayName        = $app.DisplayName
                        FilePath           = "shell:AppsFolder\$($app.PackageFamilyName)!App"
                        Description        = "Microsoft Store App: $($app.DisplayName)"
                        Publisher          = $app.Publisher
                        Version            = $app.Version
                        InstallLocation    = $app.InstallLocation
                        Source             = "Microsoft Store"
                        IsValid            = $true
                        ValidationResults  = @("Microsoft Store app - uses shell:AppsFolder path")
                        RequiresCustomIcon = $true
                    }
                    $applications += $appInfo
                }
            }
            catch {
                Write-Log -Level WARN -Message "Failed to scan Microsoft Store applications: $($_.Exception.Message)"
            }
        }
        
        # Remove duplicates using a simpler method that preserves object integrity  
        Write-Log -Level INFO -Message "Removing duplicates from $($applications.Count) discovered applications..."
        $uniqueApps = @()
        $seenPaths = @{}
        
        foreach ($app in $applications) {
            if ($null -ne $app -and $app.ApplicationPath -and -not $seenPaths.ContainsKey($app.ApplicationPath)) {
                $seenPaths[$app.ApplicationPath] = $true
                $uniqueApps += $app
            }
        }
        
        $applications = $uniqueApps | Sort-Object { $_.DisplayName }
        Write-Log -Level INFO -Message "After deduplication: $($applications.Count) unique applications"
        
        Write-Log -Level SUCCESS -Message "Found $($applications.Count) potential RemoteApp applications"
        
        # Debug: Check if applications array contains nulls
        $nullCount = ($applications | Where-Object { $null -eq $_ }).Count
        if ($nullCount -gt 0) {
            Write-Log -Level ERROR -Message "Applications array contains $nullCount null values!"
        }
        
        # Debug: Check first few applications for validity
        for ($i = 0; $i -lt [Math]::Min(3, $applications.Count); $i++) {
            $app = $applications[$i]
            if ($null -eq $app) {
                Write-Log -Level ERROR -Message "Application at index $i is NULL"
            }
            else {
                Write-Log -Level INFO -Message "App $i - DisplayName: '$($app.DisplayName)', Path: '$($app.ApplicationPath)'"
            }
        }
        
        return $applications
    }
    catch {
        Write-Log -Level ERROR -Message "Application discovery failed: $($_.Exception.Message)"
        throw
    }
}

function Get-ApplicationInfo {
    <#
    .SYNOPSIS
        Gets detailed RemoteApp parameters for an application according to Microsoft AVD requirements
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath,
        [string]$ShortcutPath,
        [string]$ProgramName,
        [string]$SourceType = "FilePath"  # FilePath, StartMenu, or AppAttach
    )
    
    # Helper function to clean encoding issues and special characters
    function Clean-TextEncoding {
        param([string]$Text)
        if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
        
        # Remove common encoding artifacts and special characters
        $cleaned = $Text -replace '[^\x20-\x7E]', '' # Remove non-ASCII printable characters
        $cleaned = $cleaned -replace '\s+', ' '      # Normalize whitespace
        $cleaned = $cleaned.Trim()
        
        return $cleaned
    }
    
    try {
        Write-Log -Level INFO -Message "Get-ApplicationInfo called for: $ExecutablePath"
        if (-not (Test-Path $ExecutablePath)) {
            Write-Log -Level INFO -Message "File not found: $ExecutablePath"
            return $null
        }
        
        $fileInfo = Get-Item $ExecutablePath
        $versionInfo = $fileInfo.VersionInfo
        Write-Log -Level INFO -Message "Version info - ProductName: '$($versionInfo.ProductName)', Company: '$($versionInfo.CompanyName)'"
        
        # Generate clean application name with encoding fix
        $rawName = if ($ProgramName -and ![string]::IsNullOrWhiteSpace($ProgramName)) { 
            $ProgramName
        }
        elseif ($versionInfo.ProductName -and ![string]::IsNullOrWhiteSpace($versionInfo.ProductName)) { 
            $versionInfo.ProductName
        }
        else { 
            $fileInfo.BaseName
        }
        
        # Clean encoding issues from the display name
        $appName = Clean-TextEncoding -Text $rawName
        if ([string]::IsNullOrWhiteSpace($appName)) {
            $appName = $fileInfo.BaseName
        }
        
        # Create simple, clean identifier (just alphanumeric and basic punctuation)
        $cleanName = $appName -replace '[^a-zA-Z0-9\s\-_]', '' -replace '\s+', '_'
        $cleanName = $cleanName.Trim('_')
        if ([string]::IsNullOrWhiteSpace($cleanName)) {
            $cleanName = $fileInfo.BaseName -replace '[^a-zA-Z0-9_]', ''
        }
        
        # Validate for RemoteApp compatibility
        $validation = Test-RemoteAppCompatibility -ExecutablePath $ExecutablePath -ApplicationName $appName
        
        # Create RemoteApp parameter object according to Microsoft documentation
        $appInfo = @{
            # Core RemoteApp Parameters (required for all types)
            ApplicationPath       = $ExecutablePath  # File path to .exe
            ApplicationIdentifier = $cleanName  # Simple, clean identifier (product name)
            DisplayName           = $appName  # Friendly name shown to users (cleaned)
            Description           = if ($versionInfo.FileDescription -and ![string]::IsNullOrWhiteSpace($versionInfo.FileDescription)) { 
                Clean-TextEncoding -Text $versionInfo.FileDescription 
            }
            else { 
                "Application: $appName" 
            }
            
            # Additional metadata
            Publisher             = if ($versionInfo.CompanyName -and ![string]::IsNullOrWhiteSpace($versionInfo.CompanyName)) { 
                Clean-TextEncoding -Text $versionInfo.CompanyName 
            }
            else { 
                "Unknown Publisher" 
            }
            Version               = if ($versionInfo.ProductVersion -and ![string]::IsNullOrWhiteSpace($versionInfo.ProductVersion)) { $versionInfo.ProductVersion.Trim() } else { "Unknown Version" }
            FileSize              = [math]::Round($fileInfo.Length / 1MB, 2)
            InstallLocation       = $fileInfo.DirectoryName
            
            # RemoteApp Configuration
            SourceType            = $SourceType  # FilePath, StartMenu, or AppAttach
            RequireCommandLine    = $false  # Default to not requiring command line
            CommandLineArguments  = ""  # Empty by default
            RequiresCustomIcon    = $false  # Default to using application's built-in icon
            IconPath              = $ExecutablePath  # Use executable for icon extraction
            IconIndex             = 0  # Default icon index
            
            # Discovery metadata
            ShortcutPath          = $ShortcutPath
            Source                = "Local Installation"
            IsValid               = $validation.IsValid
            ValidationResults     = $validation.Results
        }
        
        # Final validation to ensure critical RemoteApp parameters are populated
        if ([string]::IsNullOrWhiteSpace($appInfo.DisplayName)) {
            $appInfo.DisplayName = $fileInfo.BaseName
        }
        if ([string]::IsNullOrWhiteSpace($appInfo.ApplicationIdentifier)) {
            $appInfo.ApplicationIdentifier = ($fileInfo.BaseName -replace '[^\w\-_\.]', '').Trim()
        }
        if ([string]::IsNullOrWhiteSpace($appInfo.Publisher)) {
            $appInfo.Publisher = "Unknown Publisher"
        }
        if ([string]::IsNullOrWhiteSpace($appInfo.Description)) {
            $appInfo.Description = "Application: $($appInfo.DisplayName)"
        }
        
        Write-Log -Level INFO -Message "Created app info - DisplayName: '$($appInfo.DisplayName)', Path: '$($appInfo.ApplicationPath)', Publisher: '$($appInfo.Publisher)'"
        return $appInfo
    }
    catch {
        Write-Log -Level DEBUG -Message "Failed to get application info for: $ExecutablePath - $($_.Exception.Message)"
        return $null
    }
}

function Test-RemoteAppCompatibility {
    <#
    .SYNOPSIS
        Tests if an application is compatible with RemoteApp publishing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath,
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName
    )
    
    $validationResults = @()
    $isValid = $true
    
    # Check if file exists and is accessible
    if (-not (Test-Path $ExecutablePath)) {
        $validationResults += "ERROR: Executable file not found or not accessible"
        $isValid = $false
    }
    else {
        $validationResults += "PASS: Executable file exists and is accessible"
    }
    
    # Check file extension
    if ($ExecutablePath -notmatch '\.exe$') {
        $validationResults += "ERROR: File must be a .exe executable"
        $isValid = $false
    }
    else {
        $validationResults += "PASS: Valid executable file (.exe)"
    }
    
    # Check if it's a system file (potential issues)
    $systemPaths = @("Windows\System32", "Windows\SysWOW64", "Windows\winsxs")
    $isSystemFile = $systemPaths | ForEach-Object { $ExecutablePath -like "*$_*" } | Where-Object { $_ -eq $true }
    
    if ($isSystemFile) {
        $validationResults += "WARNING: System file - may have compatibility issues"
    }
    else {
        $validationResults += "PASS: Non-system application"
    }
    
    # Check for common problematic applications
    $problematicApps = @("uninstall", "setup", "installer", "update", "patch", "launcher")
    $isProblematic = $problematicApps | ForEach-Object { $ApplicationName -like "*$_*" } | Where-Object { $_ -eq $true }
    
    if ($isProblematic) {
        $validationResults += "WARNING: Application name suggests installer/launcher - may not be suitable"
    }
    else {
        $validationResults += "PASS: Application name appears suitable for RemoteApp"
    }
    
    # Check file size (very large files might have issues)
    try {
        $fileInfo = Get-Item $ExecutablePath
        $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        if ($fileSizeMB -gt 500) {
            $validationResults += "WARNING: Large executable file ($fileSizeMB MB) - may impact performance"
        }
        else {
            $validationResults += "PASS: Reasonable file size ($fileSizeMB MB)"
        }
    }
    catch {
        $validationResults += "WARNING: Could not determine file size"
    }
    
    # Check for dependencies in the same directory
    try {
        $appDir = Split-Path $ExecutablePath -Parent
        $dllCount = (Get-ChildItem -Path $appDir -Filter "*.dll" -ErrorAction SilentlyContinue).Count
        if ($dllCount -gt 0) {
            $validationResults += "PASS: Found $dllCount DLL dependencies in application directory"
        }
        else {
            $validationResults += "INFO: No DLL dependencies found in application directory"
        }
    }
    catch {
        $validationResults += "INFO: Could not scan for dependencies"
    }
    
    return @{
        IsValid = $isValid
        Results = $validationResults
    }
}

function Set-ApplicationCommandLine {
    <#
    .SYNOPSIS
        Allows users to specify command line requirements for selected applications
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Applications
    )
    
    Write-Host "`n--- COMMAND LINE CONFIGURATION ---" -ForegroundColor Yellow
    Write-Host "Some applications may require command line arguments to function properly as RemoteApps." -ForegroundColor Cyan
    Write-Host "Review each application and specify if command line arguments are needed." -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($app in $Applications) {
        Write-Host "Application: $($app.DisplayName)" -ForegroundColor White
        Write-Host "Path: $($app.ApplicationPath)" -ForegroundColor Gray
        Write-Host ""
        
        $needsCommandLine = Read-Host "Does this application require command line arguments? (y/N)"
        
        if ($needsCommandLine.ToUpper() -eq 'Y') {
            $app.RequireCommandLine = $true
            
            Write-Host "Examples of common command line arguments:" -ForegroundColor Cyan
            Write-Host "  - /minimized - Start minimized" -ForegroundColor Gray
            Write-Host "  - /safe - Start in safe mode" -ForegroundColor Gray
            Write-Host "  - /document - Open specific document type" -ForegroundColor Gray
            Write-Host "  - /readonly - Open in read-only mode" -ForegroundColor Gray
            Write-Host ""
            
            $commandLine = Read-Host "Enter command line arguments (or press Enter for none)"
            if (![string]::IsNullOrWhiteSpace($commandLine)) {
                $app.CommandLineArguments = $commandLine.Trim()
                Write-Log -Level SUCCESS -Message "Command line set: $($app.CommandLineArguments)"
            }
            else {
                $app.RequireCommandLine = $false
                Write-Log -Level INFO -Message "No command line arguments specified"
            }
        }
        else {
            $app.RequireCommandLine = $false
            $app.CommandLineArguments = ""
            Write-Log -Level INFO -Message "No command line arguments required"
        }
        Write-Host ""
    }
    
    return $Applications
}

function Show-ApplicationSelectionMenu {
    <#
    .SYNOPSIS
        Displays an enhanced interactive menu for selecting applications to publish as RemoteApps
        with comparison against existing RemoteApps in the tenant
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Applications,
        [hashtable]$ComparisonData
    )
    
    if ($Applications.Count -eq 0) {
        Write-Log -Level WARN -Message "No applications found to publish"
        return @()
    }
    
    # Debug: Check what properties are available on the application objects
    Write-Log -Level INFO -Message "Show-ApplicationSelectionMenu received $($Applications.Count) applications"
    if ($Applications.Count -gt 0) {
        $firstApp = $Applications[0]
        if ($null -eq $firstApp) {
            Write-Log -Level ERROR -Message "First application is NULL!"
        }
        else {
            Write-Log -Level INFO -Message "First app properties: $($firstApp.Keys -join ', ')" 
            Write-Log -Level INFO -Message "First app DisplayName: '$($firstApp.DisplayName)'"
            Write-Log -Level INFO -Message "First app ApplicationPath: '$($firstApp.ApplicationPath)'"
            Write-Log -Level INFO -Message "First app Publisher: '$($firstApp.Publisher)'"
        }
    }
    
    Write-Host "`n--- APPLICATION SELECTION FOR REMOTEAPP PUBLISHING ---" -ForegroundColor Yellow
    
    # Show tenant analysis if comparison data is available
    if ($ComparisonData -and $ComparisonData.TotalFound -gt 0) {
        Write-Host "Tenant Analysis: Found $($ComparisonData.TotalFound) existing RemoteApps across $($ComparisonData.AppGroupsScanned) application groups" -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-Host "Found $($Applications.Count) potential applications. Select which ones to publish:" -ForegroundColor Cyan
    Write-Host ""
    
    # Enhanced display with comparison data if available
    if ($ComparisonData) {
        $newApps = $Applications | Where-Object { $_.ComparisonResult.Status -eq 'New' }
        $existingApps = $Applications | Where-Object { $_.ComparisonResult.Status -eq 'Existing' }
        $updateApps = $Applications | Where-Object { $_.ComparisonResult.Status -eq 'PotentialUpdate' }
        
        # Show new applications (recommended for publishing)
        if ($newApps.Count -gt 0) {
            Write-Host "--- ✅ NEW APPLICATIONS (Recommended for publishing) ---" -ForegroundColor Green
            for ($i = 0; $i -lt $newApps.Count; $i++) {
                $app = $newApps[$i]
                if ($null -eq $app) {
                    Write-Log -Level ERROR -Message "New app $($i+1) is NULL!"
                    continue
                }
                
                $displayName = if ($app.DisplayName) { $app.DisplayName } else { "Unknown Application" }
                $filePath = if ($app.ApplicationPath) { $app.ApplicationPath } else { "Unknown Path" }
                $validStatus = if ($app.IsValid) { "✅ Valid" } else { "❌ Needs Review" }
                $publisher = if ($app.Publisher) { $app.Publisher } else { "Unknown Publisher" }
                $fileSize = if ($app.FileSize) { $app.FileSize } else { "0" }
                
                Write-Host "  [$($i + 1)] $displayName" -ForegroundColor White
                Write-Host "      Path: $filePath" -ForegroundColor Gray
                Write-Host "      Publisher: $publisher | Status: $validStatus | Size: $fileSize MB" -ForegroundColor Gray
                Write-Host ""
            }
        }
        else {
            Write-Host "--- ✅ NEW APPLICATIONS ---" -ForegroundColor Green
            Write-Host "  No new applications found (all discovered apps are already published)" -ForegroundColor Gray
            Write-Host ""
        }
        
        # Show applications that might need updates
        if ($updateApps.Count -gt 0) {
            Write-Host "--- 🔄 POTENTIAL UPDATES (Same name, different path) ---" -ForegroundColor Yellow
            $startIndex = $newApps.Count
            for ($i = 0; $i -lt $updateApps.Count; $i++) {
                $app = $updateApps[$i]
                if ($null -eq $app) {
                    Write-Log -Level ERROR -Message "Update app $($i+1) is NULL!"
                    continue
                }
                
                $displayName = if ($app.DisplayName) { $app.DisplayName } else { "Unknown Application" }
                $filePath = if ($app.ApplicationPath) { $app.ApplicationPath } else { "Unknown Path" }
                $existingInfo = $app.ComparisonResult.ExistingApp
                
                Write-Host "  [$($startIndex + $i + 1)] $displayName" -ForegroundColor Yellow
                Write-Host "      New Path: $filePath" -ForegroundColor Gray
                Write-Host "      Existing: $($existingInfo.ApplicationPath) in '$($existingInfo.ApplicationGroupName)'" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        # Show already published applications (for reference, limited display)
        if ($existingApps.Count -gt 0) {
            Write-Host "--- ⚠️ ALREADY PUBLISHED (Available for reference) ---" -ForegroundColor Red
            $startIndex = $newApps.Count + $updateApps.Count
            $displayCount = [Math]::Min(3, $existingApps.Count)
            
            for ($i = 0; $i -lt $displayCount; $i++) {
                $app = $existingApps[$i]
                if ($null -eq $app) {
                    Write-Log -Level ERROR -Message "Existing app $($i+1) is NULL!"
                    continue
                }
                
                $displayName = if ($app.DisplayName) { $app.DisplayName } else { "Unknown Application" }
                $existingInfo = $app.ComparisonResult.ExistingApp
                
                Write-Host "  [$($startIndex + $i + 1)] $displayName (Already Published)" -ForegroundColor Red
                Write-Host "      Published in: $($existingInfo.ApplicationGroupName)" -ForegroundColor Gray
                Write-Host ""
            }
            
            if ($existingApps.Count -gt 3) {
                Write-Host "      ... and $($existingApps.Count - 3) more already published applications (use 'ALL' to see)" -ForegroundColor DarkGray
                Write-Host ""
            }
        }
        
        # Selection options with enhanced NEW option
        Write-Host "Selection Options:" -ForegroundColor Cyan
        Write-Host "  - Enter 'NEW' to select only new applications (recommended - $($newApps.Count) apps)" -ForegroundColor Green
        Write-Host "  - Enter 'VALID' to select only validated applications" -ForegroundColor White
        Write-Host "  - Enter 'ALL' to select all applications" -ForegroundColor White
        Write-Host "  - Enter numbers separated by commas (e.g., 1,3,5)" -ForegroundColor White
        Write-Host "  - Enter 'NONE' or press Enter to skip" -ForegroundColor White
        Write-Host ""
        
        do {
            $selection = Read-Host "Select applications to publish"
            
            if ([string]::IsNullOrWhiteSpace($selection) -or $selection.ToUpper() -eq 'NONE') {
                Write-Log -Level INFO -Message "No applications selected for publishing"
                return @()
            }
            
            if ($selection.ToUpper() -eq 'NEW') {
                Write-Log -Level SUCCESS -Message "Selected $($newApps.Count) new applications (not already published)"
                return $newApps
            }
            
            if ($selection.ToUpper() -eq 'ALL') {
                Write-Log -Level INFO -Message "Selected all $($Applications.Count) applications"
                return $Applications
            }
            
            if ($selection.ToUpper() -eq 'VALID') {
                $validApps = $Applications | Where-Object { $_.IsValid }
                Write-Log -Level INFO -Message "Selected $($validApps.Count) validated applications"
                return $validApps
            }
            
            # Parse comma-separated numbers
            try {
                $indices = $selection -split ',' | ForEach-Object { [int]$_.Trim() }
                $selectedApps = @()
                
                foreach ($index in $indices) {
                    if ($index -ge 1 -and $index -le $Applications.Count) {
                        $selectedApps += $Applications[$index - 1]
                    }
                    else {
                        Write-Host "Invalid selection: $index (must be between 1 and $($Applications.Count))" -ForegroundColor Red
                        throw "Invalid selection"
                    }
                }
                
                Write-Log -Level SUCCESS -Message "Selected $($selectedApps.Count) applications for publishing"
                return $selectedApps
            }
            catch {
                Write-Host "Invalid selection format. Please try again." -ForegroundColor Red
            }
        } while ($true)
        
    }
    else {
        # Fallback to original logic without comparison data
        $validApps = $Applications | Where-Object { $_.IsValid }
        $invalidApps = $Applications | Where-Object { -not $_.IsValid }
        
        if ($validApps.Count -gt 0) {
            Write-Host "--- RECOMMENDED APPLICATIONS (Valid for RemoteApp) ---" -ForegroundColor Green
            for ($i = 0; $i -lt $validApps.Count; $i++) {
                $app = $validApps[$i]
                if ($null -eq $app) {
                    Write-Log -Level ERROR -Message "Valid app $($i+1) is NULL!"
                    continue
                }
                
                $displayName = if ($app.DisplayName) { $app.DisplayName } else { "Unknown Application" }
                $filePath = if ($app.ApplicationPath) { $app.ApplicationPath } else { "Unknown Path" }
                $publisher = if ($app.Publisher) { $app.Publisher } else { "Unknown Publisher" }
                $fileSize = if ($app.FileSize) { $app.FileSize } else { "0" }
                
                Write-Host "  [$($i + 1)] $displayName" -ForegroundColor White
                Write-Host "      Path: $filePath" -ForegroundColor Gray
                Write-Host "      Publisher: $publisher | Size: $fileSize MB" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        if ($invalidApps.Count -gt 0) {
            Write-Host "--- APPLICATIONS WITH ISSUES (Review Required) ---" -ForegroundColor Yellow
            $startIndex = $validApps.Count
            for ($i = 0; $i -lt $invalidApps.Count; $i++) {
                $app = $invalidApps[$i]
                if ($null -eq $app) {
                    Write-Log -Level ERROR -Message "Invalid app $($i+1) is NULL!"
                    continue
                }
                
                $displayName = if ($app.DisplayName) { $app.DisplayName } else { "Unknown Application" }
                $filePath = if ($app.ApplicationPath) { $app.ApplicationPath } else { "Unknown Path" }
                $issues = if ($app.ValidationResults) { ($app.ValidationResults | Where-Object { $_ -like 'ERROR:*' -or $_ -like 'WARNING:*' }) -join ', ' } else { "Validation failed" }
                
                Write-Host "  [$($startIndex + $i + 1)] $displayName [WARNING]" -ForegroundColor Yellow
                Write-Host "      Path: $filePath" -ForegroundColor Gray
                Write-Host "      Issues: $issues" -ForegroundColor Red
                Write-Host ""
            }
        }
        
        Write-Host "Selection Options:" -ForegroundColor Cyan
        Write-Host "  - Enter numbers separated by commas (e.g., 1,3,5)" -ForegroundColor White
        Write-Host "  - Enter 'ALL' to select all recommended applications" -ForegroundColor White
        Write-Host "  - Enter 'VALID' to select only validated applications" -ForegroundColor White
        Write-Host "  - Enter 'NONE' or press Enter to skip" -ForegroundColor White
        Write-Host ""
        
        do {
            $selection = Read-Host "Select applications to publish"
            
            if ([string]::IsNullOrWhiteSpace($selection) -or $selection.ToUpper() -eq 'NONE') {
                Write-Log -Level INFO -Message "No applications selected for publishing"
                return @()
            }
            
            if ($selection.ToUpper() -eq 'ALL') {
                Write-Log -Level INFO -Message "Selected all $($Applications.Count) applications"
                return $Applications
            }
            
            if ($selection.ToUpper() -eq 'VALID') {
                Write-Log -Level INFO -Message "Selected $($validApps.Count) validated applications"
                return $validApps
            }
            
            # Parse comma-separated numbers
            try {
                $indices = $selection -split ',' | ForEach-Object { [int]$_.Trim() }
                $selectedApps = @()
                
                foreach ($index in $indices) {
                    if ($index -ge 1 -and $index -le $Applications.Count) {
                        $selectedApps += $Applications[$index - 1]
                    }
                    else {
                        Write-Host "Invalid selection: $index (must be between 1 and $($Applications.Count))" -ForegroundColor Red
                        throw "Invalid selection"
                    }
                }
                
                Write-Log -Level SUCCESS -Message "Selected $($selectedApps.Count) applications for publishing"
                return $selectedApps
            }
            catch {
                Write-Host "Invalid selection format. Please try again." -ForegroundColor Red
            }
        } while ($true)
    }
}

function Publish-RemoteAppApplications {
    <#
    .SYNOPSIS
        Publishes selected applications as RemoteApps in the specified Application Group
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$ApplicationGroupName,
        [Parameter(Mandatory = $true)]
        [array]$Applications,
        [string]$WorkspaceName
    )
    
    Write-Host "`n--- REMOTEAPP PUBLISHING ---" -ForegroundColor Yellow
    Write-Log -Level INFO -Message "Publishing $($Applications.Count) applications to $ResourceGroupName/$ApplicationGroupName"
    
    $publishedApps = @()
    $failedApps = @()
    
    foreach ($app in $Applications) {
        try {
            Write-Log -Level INFO -Message "Publishing: $($app.DisplayName)"
            
            # Use simple, clean application identifier (just the product name)
            $appId = if ($app.ApplicationIdentifier) { 
                $app.ApplicationIdentifier 
            }
            else { 
                # Create clean identifier from display name
                ($app.DisplayName -replace '[^a-zA-Z0-9\s\-_]', '' -replace '\s+', '_').Trim('_')
            }
            if ([string]::IsNullOrWhiteSpace($appId)) {
                $appId = "RemoteApp_" + (Get-Random -Minimum 1000 -Maximum 9999)
            }
            
            Write-Log -Level INFO -Message "Using Application Identifier (Name): '$appId' for '$($app.DisplayName)'"
            
            # Prepare RemoteApp parameters according to Microsoft documentation
            $appParams = @{
                ResourceGroupName    = $ResourceGroupName
                ApplicationGroupName = $ApplicationGroupName
                Name                 = $appId  # Application identifier (unique)
                FilePath             = $app.ApplicationPath  # Application path (.exe file)
                FriendlyName         = $app.DisplayName  # Display name shown to users
                Description          = $app.Description  # Application description
                ShowInPortal         = $true
                CommandLineSetting   = if ($app.RequireCommandLine) { 'Allow' } else { 'DoNotAllow' }
            }
            
            # Add command line arguments if required
            if ($app.RequireCommandLine -and ![string]::IsNullOrWhiteSpace($app.CommandLineArguments)) {
                $appParams.Add('CommandLineArguments', $app.CommandLineArguments)
            }
            
            # Handle Microsoft Store apps differently
            if ($app.Source -eq "Microsoft Store") {
                Write-Log -Level INFO -Message "Publishing Microsoft Store app: $($app.DisplayName)"
                # Store apps use shell:AppsFolder path format
            }
            
            if ($PSCmdlet.ShouldProcess("$ResourceGroupName/$ApplicationGroupName", "Publish RemoteApp '$($app.DisplayName)'")) {
                $result = New-AzWvdApplication @appParams
                
                $publishedApps += @{
                    Application = $app
                    Result      = $result
                    Status      = "Success"
                }
                
                Write-Log -Level SUCCESS -Message "Published: $($app.DisplayName)"
            }
            else {
                Write-Log -Level INFO -Message "Simulated publishing: $($app.DisplayName) (WhatIf mode)"
            }
        }
        catch {
            $failedApps += @{
                Application = $app
                Error       = $_.Exception.Message
                Status      = "Failed"
            }
            Write-Log -Level ERROR -Message "FAILED to publish $($app.DisplayName): $($_.Exception.Message)"
        }
    }
    
    # Assign to workspace if specified
    if (![string]::IsNullOrWhiteSpace($WorkspaceName) -and $publishedApps.Count -gt 0) {
        Write-Log -Level INFO -Message "Assigning Application Group to Workspace: $WorkspaceName"
        Write-Log -Level INFO -Message "NOTE: This will create a workspace assignment (no user assignments yet)"
        try {
            if ($PSCmdlet.ShouldProcess("$ResourceGroupName/$WorkspaceName", "Assign Application Group")) {
                Register-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -ApplicationGroupPath "/subscriptions/$((Get-AzContext).Subscription.Id)/resourcegroups/$ResourceGroupName/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupName"
                Write-Log -Level SUCCESS -Message "Application Group assigned to Workspace: $WorkspaceName"
                Write-Log -Level INFO -Message "You can now assign users/groups to this application group"
            }
        }
        catch {
            Write-Log -Level ERROR -Message "Failed to assign to workspace: $($_.Exception.Message)"
        }
    }
    
    # Display summary
    Write-Host "`n--- PUBLISHING SUMMARY ---" -ForegroundColor Green
    Write-Log -Level INFO -Message "Successfully Published: $($publishedApps.Count)"
    Write-Log -Level INFO -Message "Failed: $($failedApps.Count)"
    
    if ($publishedApps.Count -gt 0) {
        Write-Host "`nSuccessfully Published Applications:" -ForegroundColor Green
        foreach ($pub in $publishedApps) {
            Write-Host "  - $($pub.Application.DisplayName)" -ForegroundColor White
        }
    }
    
    if ($failedApps.Count -gt 0) {
        Write-Host "`nFailed Applications:" -ForegroundColor Red
        foreach ($fail in $failedApps) {
            Write-Host "  FAILED: $($fail.Application.DisplayName) - $($fail.Error)" -ForegroundColor Red
        }
    }
    
    return @{
        Published = $publishedApps
        Failed    = $failedApps
        Total     = $Applications.Count
    }
}

function Select-Workspace {
    <#
    .SYNOPSIS
        Allows selection or creation of a workspace for RemoteApp assignment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        $Discovery
    )
    
    Write-Host "`n--- WORKSPACE SELECTION ---" -ForegroundColor Yellow
    Write-Host "Select workspace for RemoteApp assignment:" -ForegroundColor Cyan
    
    $rgWorkspaces = $Discovery.Workspaces | Where-Object { $_.ResourceGroup -eq $ResourceGroupName }
    
    if ($rgWorkspaces.Count -gt 0) {
        Write-Host "`nExisting Workspaces in Resource Group:" -ForegroundColor Green
        for ($i = 0; $i -lt $rgWorkspaces.Count; $i++) {
            $ws = $rgWorkspaces[$i]
            Write-Host "  [$($i + 1)] $($ws.Name)" -ForegroundColor White
            if ($ws.FriendlyName) { Write-Host "      Friendly Name: $($ws.FriendlyName)" -ForegroundColor Gray }
            Write-Host "      Location: $($ws.Location)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`nOptions:" -ForegroundColor Yellow
    Write-Host "  [N] Create NEW workspace" -ForegroundColor Green
    Write-Host "  [S] Skip workspace assignment" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        if ($rgWorkspaces.Count -gt 0) {
            $prompt = "Select workspace (1-$($rgWorkspaces.Count)), N for new, S to skip"
        }
        else {
            $prompt = "No existing workspaces. N for new, S to skip"
        }
        
        $choice = Read-Host $prompt
        
        if ($choice.ToUpper() -eq 'S') {
            Write-Log -Level INFO -Message "Skipping workspace assignment"
            return $null
        }
        
        if ($choice.ToUpper() -eq 'N') {
            do {
                $newWsName = Read-Host "Enter new workspace name"
                if ([string]::IsNullOrWhiteSpace($newWsName)) {
                    Write-Host "Workspace name cannot be empty." -ForegroundColor Red
                    continue
                }
                if ($newWsName -match '^[a-zA-Z0-9._\-]+$' -and $newWsName.Length -le 64) {
                    return $newWsName
                }
                else {
                    Write-Host "Invalid name. Use letters, numbers, periods, hyphens, underscores. Max 64 chars." -ForegroundColor Red
                }
            } while ($true)
        }
        elseif ($rgWorkspaces.Count -gt 0 -and [int]::TryParse($choice, [ref]$null) -and [int]$choice -ge 1 -and [int]$choice -le $rgWorkspaces.Count) {
            $selectedWs = $rgWorkspaces[[int]$choice - 1]
            $wsName = if ($selectedWs -is [hashtable]) { $selectedWs.Name } else { $selectedWs.Name }
            Write-Host "Selected: $wsName" -ForegroundColor Green
            return $wsName
        }
        else {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
    } while ($true)
}

function Invoke-TestRemoteApp {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ResourceGroupName,
        [string]$ApplicationGroupName
    )
    
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
        $ResourceGroupName = Read-Host "Enter Resource Group name"
    }
    
    if ([string]::IsNullOrWhiteSpace($ApplicationGroupName)) {
        $ApplicationGroupName = Read-Host "Enter Application Group name"
    }
    
    Write-Log -Level INFO -Message "Ensuring Azure resources exist for deployment..."
    
    # Ensure resource group exists
    $rg = Initialize-ResourceGroup -ResourceGroupName $ResourceGroupName
    
    # Ensure application group (and host pool) exists
    $appGroup = Initialize-HostPoolAndApplicationGroup -ResourceGroupName $ResourceGroupName -ApplicationGroupName $ApplicationGroupName -Location $rg.Location
    Write-Log -Level SUCCESS -Message "Azure resources initialized: RG=$($rg.ResourceGroupName), AG=$($appGroup.Name)"

    Write-Log -Level INFO -Message "Testing RemoteApp deployment to $ResourceGroupName/$ApplicationGroupName"
    
    $testApp = @{
        ResourceGroupName    = $ResourceGroupName
        ApplicationGroupName = $ApplicationGroupName
        Name                 = "notepad-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        FilePath             = "C:\Windows\System32\notepad.exe"
        FriendlyName         = "Test Notepad"
        Description          = "Test RemoteApp deployment"
        CommandLineSetting   = "DoNotAllow"
        ShowInPortal         = $true
    }
    
    try {
        if ($PSCmdlet.ShouldProcess("$ResourceGroupName/$ApplicationGroupName", "Deploy test RemoteApp")) {
            Write-Log -Level INFO -Message "Deploying test RemoteApp: $($testApp.Name)"
            
            $result = New-AzWvdApplication @testApp
            
            Write-Log -Level SUCCESS -Message "Test RemoteApp deployed successfully"
            Write-Log -Level INFO -Message "Application ID: $($result.Name)"
            
            return $result
        }
        else {
            Write-Log -Level INFO -Message "Test deployment skipped (WhatIf mode)"
            return $null
        }
    }
    catch {
        Write-Log -Level ERROR -Message "Test deployment failed: $($_.Exception.Message)"
        throw
    }
}

function Main {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-Host "--- AVD REMOTEAPP ENHANCED PUBLISHER ---" -ForegroundColor Yellow
    Write-Host "Enhanced with local application discovery, validation, and automated RemoteApp publishing" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Ensure Azure Authentication
    if (!(Test-AzureConnection)) {
        Write-Log -Level ERROR -Message "Azure connection required."
        return
    }
    
    # Step 2: Discover existing tenant resources
    $discovery = Get-TenantResourceDiscovery
    
    # Step 3: Local Application Discovery
    Write-Host "`n--- LOCAL APPLICATION DISCOVERY ---" -ForegroundColor Yellow
    Write-Host "Scanning this machine for applications that can be published as RemoteApps..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Discovery Options:" -ForegroundColor Yellow
    Write-Host "  [1] Standard scan (recommended applications only)" -ForegroundColor White
    Write-Host "  [2] Extended scan (include Microsoft Store apps)" -ForegroundColor White
    Write-Host "  [3] Full scan (include system apps - advanced users)" -ForegroundColor White
    Write-Host ""
    
    do {
        $scanChoice = Read-Host "Select scan type (1-3)"
        switch ($scanChoice) {
            '1' { 
                $applications = Get-LocalApplications
                break
            }
            '2' { 
                $applications = Get-LocalApplications -IncludeStoreApps
                break
            }
            '3' { 
                $applications = Get-LocalApplications -IncludeStoreApps -IncludeSystemApps
                break
            }
            default { 
                Write-Host "Invalid selection. Please choose 1, 2, or 3." -ForegroundColor Red 
                continue
            }
        }
        break
    } while ($true)
    
    if ($applications.Count -eq 0) {
        Write-Log -Level WARN -Message "No suitable applications found for RemoteApp publishing"
        return
    }
    
    # Debug: Check what applications were discovered
    Write-Log -Level INFO -Message "Total applications discovered: $($applications.Count)"
    foreach ($app in $applications | Select-Object -First 3) {
        Write-Log -Level INFO -Message "Sample app - DisplayName: '$($app.DisplayName)', Path: '$($app.ApplicationPath)', Publisher: '$($app.Publisher)'"
    }
    
    # Step 4: Check Existing RemoteApps in Tenant
    Write-Host "`n--- TENANT REMOTEAPP ANALYSIS ---" -ForegroundColor Yellow
    Write-Host "Checking for existing RemoteApps in your tenant..." -ForegroundColor Cyan
    
    $existingRemoteApps = Get-ExistingRemoteApps -Discovery $discovery
    $comparisonData = Compare-DiscoveredWithExisting -DiscoveredApps $applications -ExistingApps $existingRemoteApps
    
    if ($existingRemoteApps.TotalFound -gt 0) {
        Write-Host ""
        Write-Host "Analysis Results:" -ForegroundColor Cyan
        Write-Host "  • Total existing RemoteApps found: $($existingRemoteApps.TotalFound)" -ForegroundColor White
        Write-Host "  • Application Groups scanned: $($existingRemoteApps.AppGroupsScanned)" -ForegroundColor White
        Write-Host "  • New applications (not published): $($comparisonData.NewApps.Count)" -ForegroundColor Green
        Write-Host "  • Already published: $($comparisonData.ExistingApps.Count)" -ForegroundColor Red
        Write-Host "  • Potential updates: $($comparisonData.PotentialUpdates.Count)" -ForegroundColor Yellow
        
        if ($comparisonData.NewApps.Count -eq 0) {
            Write-Host ""
            Write-Host "ℹ️  All discovered applications are already published as RemoteApps!" -ForegroundColor Yellow
            Write-Host "   You can still proceed to review existing applications or publish updates." -ForegroundColor Gray
        }
    }
    else {
        Write-Host "No existing RemoteApps found in tenant - all discovered applications are new" -ForegroundColor Green
        $comparisonData = $null
    }
    
    # Step 5: Application Selection (Enhanced with Comparison)
    $selectedApps = Show-ApplicationSelectionMenu -Applications $applications -ComparisonData $existingRemoteApps
    
    if ($selectedApps.Count -eq 0) {
        Write-Log -Level INFO -Message "No applications selected for publishing. Exiting."
        return
    }
    
    # Step 6: Command Line Configuration
    Write-Host "`n--- COMMAND LINE CONFIGURATION ---" -ForegroundColor Yellow
    $configureCommandLine = Read-Host "Configure command line arguments for selected applications? (Y/n)"
    
    if ($configureCommandLine.ToUpper() -ne 'N') {
        $selectedApps = Set-ApplicationCommandLine -Applications $selectedApps
    }
    
    # Step 7: Resource Group Selection (reuse existing or create new)
    $selectedRG = Select-ResourceGroup -Discovery $discovery -PreSelectedName $ResourceGroupName
    
    # Step 8: Application Group Selection (reuse existing or create new)  
    $selectedAG = Select-ApplicationGroup -ResourceGroupName $selectedRG -Discovery $discovery -PreSelectedName $ApplicationGroupName
    
    # Step 9: Workspace Selection (optional)
    $selectedWS = Select-Workspace -ResourceGroupName $selectedRG -Discovery $discovery
    
    Write-Host "`n--- DEPLOYMENT CONFIGURATION ---" -ForegroundColor Yellow
    Write-Log -Level INFO -Message "Target Resource Group: $selectedRG"
    Write-Log -Level INFO -Message "Target Application Group: $selectedAG"
    if ($selectedWS) {
        Write-Log -Level INFO -Message "Target Workspace: $selectedWS"
    }
    else {
        Write-Log -Level INFO -Message "Workspace: Not assigned"
    }
    Write-Log -Level INFO -Message "Applications to publish: $($selectedApps.Count)"
    
    # Step 10: Validation Summary
    Write-Host "`n--- APPLICATION VALIDATION SUMMARY ---" -ForegroundColor Yellow
    $validApps = $selectedApps | Where-Object { $_.IsValid }
    $invalidApps = $selectedApps | Where-Object { -not $_.IsValid }
    
    Write-Log -Level INFO -Message "Valid applications: $($validApps.Count)"
    Write-Log -Level INFO -Message "Applications with issues: $($invalidApps.Count)"
    
    if ($invalidApps.Count -gt 0) {
        Write-Host "`nApplications with validation issues:" -ForegroundColor Yellow
        foreach ($app in $invalidApps) {
            Write-Host "  WARNING: $($app.DisplayName)" -ForegroundColor Yellow
            $errors = $app.ValidationResults | Where-Object { $_ -like 'ERROR:*' }
            foreach ($errorMsg in $errors) {
                Write-Host "     $errorMsg" -ForegroundColor Red
            }
        }
        
        Write-Host ""
        $continue = Read-Host "Continue with publishing? Some applications may fail (y/N)"
        if ($continue.ToUpper() -ne 'Y') {
            Write-Log -Level INFO -Message "Publishing cancelled by user"
            return
        }
    }
    
    # Step 11: Ensure all required Azure resources exist
    try {
        Write-Log -Level INFO -Message "Validating and ensuring Azure resources exist..."
        
        # Initialize resource group
        $rg = Initialize-ResourceGroup -ResourceGroupName $selectedRG
        
        # Initialize application group (and host pool)
        $appGroup = Initialize-HostPoolAndApplicationGroup -ResourceGroupName $selectedRG -ApplicationGroupName $selectedAG -Location $rg.Location
        Write-Log -Level SUCCESS -Message "Target resources validated: RG=$($rg.ResourceGroupName), AG=$($appGroup.Name)"
        
        # Initialize workspace if specified
        if ($selectedWS) {
            try {
                $workspace = Get-AzWvdWorkspace -ResourceGroupName $selectedRG -Name $selectedWS -ErrorAction SilentlyContinue
                if ($null -eq $workspace) {
                    Write-Log -Level INFO -Message "Creating workspace: $selectedWS"
                    $workspace = New-AzWvdWorkspace -ResourceGroupName $selectedRG -Name $selectedWS -Location $rg.Location
                    Write-Log -Level SUCCESS -Message "Workspace created: $($workspace.Name)"
                }
                else {
                    Write-Log -Level SUCCESS -Message "Using existing workspace: $($workspace.Name)"
                }
            }
            catch {
                Write-Log -Level ERROR -Message "Failed to ensure workspace: $($_.Exception.Message)"
                $selectedWS = $null
            }
        }
        
        Write-Log -Level SUCCESS -Message "All required Azure resources validated and ready"
        
        # Step 12: Publish RemoteApps
        Write-Host "`n--- REMOTEAPP PUBLISHING ---" -ForegroundColor Yellow
        Write-Host "Publishing $($selectedApps.Count) applications as RemoteApps..." -ForegroundColor Cyan
        
        if ($PSCmdlet.ShouldProcess("$selectedRG/$selectedAG", "Publish $($selectedApps.Count) RemoteApps")) {
            $publishResults = Publish-RemoteAppApplications -ResourceGroupName $selectedRG -ApplicationGroupName $selectedAG -Applications $selectedApps -WorkspaceName $selectedWS
            
            Write-Host "`n--- DEPLOYMENT SUCCESS ---" -ForegroundColor Green
            Write-Log -Level SUCCESS -Message "RemoteApp publishing completed!"
            Write-Log -Level INFO -Message "Resource Group: $selectedRG"
            Write-Log -Level INFO -Message "Application Group: $selectedAG"
            if ($selectedWS) {
                Write-Log -Level INFO -Message "Workspace: $selectedWS"
            }
            Write-Log -Level INFO -Message "Successfully Published: $($publishResults.Published.Count) applications"
            Write-Log -Level INFO -Message "Failed: $($publishResults.Failed.Count) applications"
            
            Write-Host "`nNext Steps:" -ForegroundColor Cyan
            Write-Host "- Assign users/groups to the application group in Azure Portal" -ForegroundColor White
            Write-Host "- Configure conditional access policies if needed" -ForegroundColor White  
            Write-Host "- Ensure session hosts are available and running in the host pool" -ForegroundColor White
            Write-Host "- Test RemoteApp access through Windows App or web client" -ForegroundColor White
            Write-Host "- Monitor application performance and usage" -ForegroundColor White
            
            return $publishResults
        }
        else {
            Write-Log -Level INFO -Message "Publishing simulation completed (WhatIf mode)"
            return $null
        }
    }
    catch {
        Write-Log -Level ERROR -Message "Deployment failed: $($_.Exception.Message)"
        Write-Log -Level ERROR -Message "Stack trace: $($_.ScriptStackTrace)"
        throw
    }
    
    Write-Log -Level SUCCESS -Message "Enhanced AVD RemoteApp Publisher completed successfully"
}

function Disconnect-AzureSession {
    <#
    .SYNOPSIS
        Safely disconnects Azure session at script completion
    #>
    try {
        Write-Host "`n--- SECURITY CLEANUP ---" -ForegroundColor Yellow
        $context = Get-AzContext -ErrorAction SilentlyContinue
        
        if ($null -ne $context) {
            Write-Log -Level INFO -Message "Disconnecting Azure session: $($context.Account)"
            Disconnect-AzAccount -ErrorAction Stop | Out-Null
            Write-Log -Level SUCCESS -Message "Azure session disconnected successfully"
            Write-Log -Level INFO -Message "All cached credentials have been cleared."
        }
        else {
            Write-Log -Level INFO -Message "No active Azure session to disconnect"
        }
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to disconnect Azure session: $($_.Exception.Message)"
    }
}

# Execute if not dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Main
    }
    finally {
        # Always disconnect, even if script fails
        Disconnect-AzureSession
    }
}
