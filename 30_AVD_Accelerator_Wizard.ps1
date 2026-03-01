#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys and configures a complete Azure Virtual Desktop (AVD) environment in Azure, automating all required infrastructure and settings via an interactive PowerShell 7+ wizard.

.DESCRIPTION
    This script is a comprehensive automation tool for building Azure Virtual Desktop (AVD) environments from scratch or integrating with existing Azure resources. It interactively guides the user through all required steps for a production-ready AVD deployment, including:
    - Authenticating to Azure using multiple supported methods (interactive, device code, service principal, managed identity)
    - Selecting Azure subscription and region
    - Choosing and configuring identity provider (Active Directory DS, Entra ID, Entra Kerberos, etc.)
    - Creating or reusing resource groups, virtual networks, subnets, and network security groups
    - Setting up storage accounts and Azure Files/FSLogix for user profile containers
    - Defining and deploying host pools, session hosts (VMs), and configuring VM sizing, quotas, and images
    - Automating RBAC assignments, scaling plans, and monitoring/log analytics integration
    - Configuring resource naming conventions and tagging for governance
    - Handling all error checking, quota validation, and best practices for secure, scalable AVD deployments
    The script uses the Az PowerShell modules to provision and configure all Azure resources, and supports both new and existing infrastructure. It is modular, menu-driven, and provides detailed feedback and diagnostics at each step, ensuring a repeatable and auditable deployment process for enterprise AVD environments.

.LINK
    https://github.com/Azure/avd-accelerator
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# SKU mapping tables
# ---------------------------------------------------------------------------
$Script:StorageSkuMap = @{
    'LRS'  = 'Standard_LRS'
    'ZRS'  = 'Standard_ZRS'
    'GZRS' = 'Standard_GZRS'
}

$Script:DiskSkuMap = @{
    'StandardSSD_LRS' = 'StandardSSD_LRS'
    'PremiumSSD_LRS'  = 'Premium_LRS'
    'StandardHDD_LRS' = 'Standard_LRS'
    'UltraSSD_LRS'    = 'UltraSSD_LRS'
}

# ---------------------------------------------------------------------------
# Get-VMFamily
# ---------------------------------------------------------------------------
function Get-VMFamily {
    param([string]$SkuName)
    if ($SkuName -match '^Standard_([A-Za-z]+)') { return $Matches[1].ToUpper() }
    return $null
}

# ---------------------------------------------------------------------------
# Get-VMQuotaFamilyName — precise Azure quota family name per SKU series
# ---------------------------------------------------------------------------
function Get-VMQuotaFamilyName {
    param([string]$SkuName)
    switch -Regex ($SkuName) {
        '^Standard_D\d+as_v5'  { return 'standardDASv5Family' }
        '^Standard_D\d+s_v5'   { return 'standardDSv5Family'  }
        '^Standard_D\d+as_v4'  { return 'standardDASv4Family' }
        '^Standard_D\d+s_v4'   { return 'standardDSv4Family'  }
        '^Standard_D\d+s_v3'   { return 'standardDSv3Family'  }
        '^Standard_E\d+s_v5'   { return 'standardESv5Family'  }
        '^Standard_E\d+s_v4'   { return 'standardESv4Family'  }
        '^Standard_E\d+s_v3'   { return 'standardESv3Family'  }
        '^Standard_F\d+s_v2'   { return 'standardFSv2Family'  }
        '^Standard_B\d+'        { return 'standardBSFamily'    }
        '^Standard_NV\d+s_v3'  { return 'standardNVSv3Family' }
        '^Standard_NV\d+'       { return 'standardNVFamily'    }
        '^Standard_NC\d+s_v3'  { return 'standardNCSv3Family' }
        '^Standard_NC\d+'       { return 'standardNCFamily'    }
        '^Standard_ND\d+'       { return 'standardNDFamily'    }
        default                 { return $null                 }
    }
}

# ---------------------------------------------------------------------------
# Initialize-RequiredModules
# ---------------------------------------------------------------------------
function Initialize-RequiredModules {
    $env:AZUREPS_SURVEY_OPT_OUT = 'true'
    $requiredModules = @(
        @{ Name = 'Az.Accounts';              MinVersion = '2.6.0' },
        @{ Name = 'Az.Compute';               MinVersion = '6.0.0' },
        @{ Name = 'Az.Resources';             MinVersion = '6.0.0' },
        @{ Name = 'Az.Network';               MinVersion = '6.0.0' },
        @{ Name = 'Az.Storage';               MinVersion = '5.0.0' },
        @{ Name = 'Az.KeyVault';              MinVersion = '4.0.0' },
        @{ Name = 'Az.OperationalInsights';   MinVersion = '3.0.0' },
        @{ Name = 'Az.DesktopVirtualization'; MinVersion = '2.0.0' },
        @{ Name = 'Az.PrivateDns';            MinVersion = '1.0.0' }
    )
    foreach ($mod in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $mod.Name |
                     Sort-Object Version -Descending | Select-Object -First 1
        if (-not $installed -or $installed.Version -lt [Version]$mod.MinVersion) {
            Write-Host "Installing $($mod.Name) (min $($mod.MinVersion))..." -ForegroundColor Yellow
            try   { Install-Module -Name $mod.Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop }
            catch { Write-Host "Failed to install $($mod.Name): $($_.Exception.Message)" -ForegroundColor Red; throw }
        }
        try   { Import-Module $mod.Name -MinimumVersion $mod.MinVersion -ErrorAction Stop }
        catch { Write-Host "Failed to import $($mod.Name): $($_.Exception.Message)" -ForegroundColor Red; throw }
    }
    $rdMod = Get-Module -ListAvailable -Name 'Microsoft.RDInfra.RDPowerShell'
    if ($rdMod) {
        try   { Import-Module 'Microsoft.RDInfra.RDPowerShell' -ErrorAction Stop }
        catch { Write-Warning 'Microsoft.RDInfra.RDPowerShell found but failed to import. Continuing.' }
    }
    Write-Host 'All required modules installed and imported.' -ForegroundColor Green
    Write-Host '[Diagnostics] Module check complete.' -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------
function Select-AuthenticationMethod {
    Write-Host ''
    Write-Host 'Please select your preferred Azure authentication method:' -ForegroundColor White
    Write-Host '  1. Interactive Browser Login (Default)' -ForegroundColor White
    Write-Host '  2. Device Code Authentication'          -ForegroundColor White
    Write-Host '  3. Service Principal (Client Secret)'   -ForegroundColor White
    Write-Host '  4. Service Principal (Certificate)'     -ForegroundColor White
    Write-Host '  5. Managed Identity'                    -ForegroundColor White
    Write-Host ''
    $selInt = 0
    do {
        $sel   = Read-Host 'Select method (1-5) [Default: 1]'
        if ([string]::IsNullOrWhiteSpace($sel)) { $sel = '1' }
        $valid = $sel -match '^[1-5]$' -and [int]::TryParse($sel, [ref]$selInt)
        if (-not $valid) { Write-Host 'Please enter 1-5.' -ForegroundColor Red }
    } while (-not $valid)
    $map = @{
        1 = 'Interactive'
        2 = 'DeviceCode'
        3 = 'ServicePrincipalSecret'
        4 = 'ServicePrincipalCertificate'
        5 = 'ManagedIdentity'
    }
    Write-Host "Selected: $($map[$selInt])" -ForegroundColor Green
    return $map[$selInt]
}

function Invoke-AzureAuthentication {
    param([Parameter(Mandatory)][string]$AuthMethod)
    Write-Host "Authenticating via: $AuthMethod" -ForegroundColor Yellow
    try {
        switch ($AuthMethod) {
            'Interactive' {
                Connect-AzAccount -UseDeviceAuthentication:$false -ErrorAction Stop | Out-Null
            }
            'DeviceCode' {
                Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop | Out-Null
            }
            'ServicePrincipalSecret' {
                $appId = Read-Host 'App (client) ID'
                $tid   = Read-Host 'Tenant ID'
                $sec   = Read-Host 'Client Secret' -AsSecureString
                if (-not $appId -or -not $tid -or -not $sec) {
                    Write-Host 'Missing credentials.' -ForegroundColor Red; return $false
                }
                $cred = [System.Management.Automation.PSCredential]::new($appId, $sec)
                Connect-AzAccount -ServicePrincipal -ApplicationId $appId `
                    -TenantId $tid -Credential $cred -ErrorAction Stop | Out-Null
            }
            'ServicePrincipalCertificate' {
                $appId = Read-Host 'App (client) ID'
                $tid   = Read-Host 'Tenant ID'
                $thumb = Read-Host 'Cert Thumbprint'
                if (-not $appId -or -not $tid -or -not $thumb) {
                    Write-Host 'Missing credentials.' -ForegroundColor Red; return $false
                }
                Connect-AzAccount -ServicePrincipal -ApplicationId $appId `
                    -TenantId $tid -CertificateThumbprint $thumb -ErrorAction Stop | Out-Null
            }
            'ManagedIdentity' {
                Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
            }
        }
        Write-Host 'Authentication successful!' -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ---------------------------------------------------------------------------
# Helper: generic console list picker
# ---------------------------------------------------------------------------
function Select-FromList {
    param(
        [Parameter(Mandatory)][System.Collections.IEnumerable]$Items,
        [string]$DisplayProperty = 'Name',
        [string]$Title           = 'Select item'
    )
    $list = @($Items)
    if ($list.Count -eq 0) { throw 'No items to select from.' }
    Write-Host "`n$Title`n" -ForegroundColor Cyan
    for ($i = 0; $i -lt $list.Count; $i++) {
        $entry = $list[$i]
        $label = if ($entry -is [string]) { $entry } `
                 else { $entry | Select-Object -ExpandProperty $DisplayProperty -ErrorAction SilentlyContinue }
        Write-Host "[$($i+1)] $label"
    }
    $idx = 0
    do {
        $raw = Read-Host "Enter number (1-$($list.Count))"
        $ok  = $raw -match '^[0-9]+$' -and [int]::TryParse($raw, [ref]$idx) -and
               $idx -ge 1 -and $idx -le $list.Count
        if (-not $ok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($ok)
    return $list[$idx - 1]
}

# ---------------------------------------------------------------------------
# Helper: Resolve-OrCreate
# Returns @{ Name; IsNew; Skip }
# -AllowSkip adds a [3] Skip option
# ---------------------------------------------------------------------------
function Resolve-OrCreate {
    param(
        [Parameter(Mandatory)][string]$ResourceType,
        [Parameter(Mandatory)][string]$DefaultName,
        [string]$ExtraHint = '',
        [switch]$AllowSkip
    )
    Write-Host "`n--- $ResourceType ---" -ForegroundColor Cyan
    if ($ExtraHint) { Write-Host $ExtraHint -ForegroundColor Gray }

    $maxOpt = if ($AllowSkip) { 3 } else { 2 }
    Write-Host "  [1] Use existing $ResourceType"  -ForegroundColor White
    Write-Host "  [2] Create a new $ResourceType"  -ForegroundColor White
    if ($AllowSkip) { Write-Host '  [3] Skip (not needed)' -ForegroundColor White }

    $choice = 0
    do {
        $raw = Read-Host "Select option (1-$maxOpt)"
        $ok  = $raw -match "^[1-$maxOpt]$" -and [int]::TryParse($raw, [ref]$choice)
        if (-not $ok) { Write-Host "Please enter a number between 1 and $maxOpt." -ForegroundColor Yellow }
    } until ($ok)

    switch ($choice) {
        1 {
            $name = (Read-Host "Enter the name of the existing $ResourceType").Trim()
            return @{ Name = $name; IsNew = $false; Skip = $false }
        }
        2 {
            $suggested = (Read-Host "Enter a name for the new $ResourceType [Default: $DefaultName]").Trim()
            $finalName = if ([string]::IsNullOrWhiteSpace($suggested)) { $DefaultName } else { $suggested }
            return @{ Name = $finalName; IsNew = $true; Skip = $false }
        }
        3 {
            Write-Host "  $ResourceType skipped." -ForegroundColor Gray
            return @{ Name = $null; IsNew = $false; Skip = $true }
        }
    }
}

# ---------------------------------------------------------------------------
# Helper: safe storage account name (max 24 chars, lowercase alphanumeric)
# ---------------------------------------------------------------------------
function New-SafeStorageAccountName {
    param([Parameter(Mandatory)][string]$RawName)
    $clean = ($RawName.ToLower() -replace '[^a-z0-9]', '')
    return $clean.Substring(0, [Math]::Min(24, $clean.Length))
}

# ---------------------------------------------------------------------------
# Helper: RBAC assignment with duplicate check
# ---------------------------------------------------------------------------
function Set-StartVMOnConnectRBAC {
    param(
        [Parameter(Mandatory)][string]$EnterpriseAppId,
        [Parameter(Mandatory)][string]$SubscriptionId
    )
    try {
        $spnObj = Get-AzADServicePrincipal -ApplicationId $EnterpriseAppId -ErrorAction SilentlyContinue
        if (-not $spnObj) {
            Write-Host '  Note: Enterprise App service principal not found. Skipping RBAC.' -ForegroundColor Yellow
            return
        }
        $scope    = "/subscriptions/$SubscriptionId"
        $roleName = 'Desktop Virtualization Power On Off Contributor'
        $existing = Get-AzRoleAssignment -ObjectId $spnObj.Id `
            -RoleDefinitionName $roleName -Scope $scope -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host '  RBAC: Desktop Virtualization Power On Off Contributor already assigned.' -ForegroundColor Yellow
        }
        else {
            New-AzRoleAssignment -ObjectId $spnObj.Id `
                -RoleDefinitionName $roleName -Scope $scope -ErrorAction Stop | Out-Null
            Write-Host '  RBAC: Desktop Virtualization Power On Off Contributor assigned.' -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  Note: RBAC assignment failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Helper: create AVD Scaling Plan + pooled schedule
# ---------------------------------------------------------------------------
function New-AVDScalingPlan {
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][string]$HostPoolType,
        [Parameter(Mandatory)][string]$HostPoolArmPath
    )
    try {
        # Present valid Windows time zone IDs for user selection
        $tzList = [System.TimeZoneInfo]::GetSystemTimeZones() | Select-Object -ExpandProperty Id
        $selectedTZ = Select-FromList -Items $tzList -DisplayProperty '' -Title 'Select Time Zone for Scaling Plan'

        New-AzWvdScalingPlan -ResourceGroupName $ResourceGroupName -Name $Name `
            -Location $Location -FriendlyName $Name -Description 'AVD Scaling Plan' `
            -HostPoolType $HostPoolType `
            -HostPoolReference @(@{ HostPoolArmPath = $HostPoolArmPath; ScalingPlanEnabled = $true }) `
            -TimeZone $selectedTZ `
            -ErrorAction Stop | Out-Null
        Write-Host "  Scaling Plan created: $Name" -ForegroundColor Green

        New-AzWvdScalingPlanPooledSchedule `
            -ResourceGroupName              $ResourceGroupName `
            -ScalingPlanName                $Name `
            -ScalingPlanScheduleName        'Weekdays' `
            -DaysOfWeek                     @('Monday','Tuesday','Wednesday','Thursday','Friday') `
            -RampUpStartTimeHour            7   `
            -RampUpStartTimeMinute          0   `
            -PeakStartTimeHour              9   `
            -PeakStartTimeMinute            0   `
            -RampDownStartTimeHour          18  `
            -RampDownStartTimeMinute        0   `
            -OffPeakStartTimeHour           20  `
            -OffPeakStartTimeMinute         0   `
            -RampUpLoadBalancingAlgorithm   'BreadthFirst' `
            -PeakLoadBalancingAlgorithm     'BreadthFirst' `
            -RampDownLoadBalancingAlgorithm 'DepthFirst'   `
            -OffPeakLoadBalancingAlgorithm  'DepthFirst'   `
            -RampUpMinimumHostsPct          20  `
            -PeakMinimumHostsPct            100 `
            -RampDownMinimumHostsPct        10  `
            -OffPeakMinimumHostsPct         5   `
            -RampUpCapacityThresholdPct     60  `
            -PeakCapacityThresholdPct       80  `
            -RampDownCapacityThresholdPct   90  `
            -OffPeakCapacityThresholdPct    90  `
            -RampDownForceLogOffUser        $false `
            -RampDownWaitTimeMinute         30  `
            -RampDownNotificationMessage    'Session ending in 30 minutes.' `
            -ErrorAction Stop | Out-Null
        Write-Host '  Scaling Plan schedule added: Weekdays' -ForegroundColor Green
    }
    catch {
        Write-Host "  Failed to create Scaling Plan: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ---------------------------------------------------------------------------
# Helper: deploy session hosts
# Extension install order:
#   A. NIC
#   B. VM creation
#   C. Enable System-Assigned Managed Identity  ← NEW (required for AADLoginForWindows)
#   D. AADLoginForWindows  (Entra ID only — MUST be after identity, before DSC)
#   E. DSC                 (AVD host pool join — always)
#   F. FSLogixConfig       (Custom Script — when FSLogix UNC is set)
#   G. MicrosoftMonitoringAgent (Log Analytics — when workspace configured)
# Returns actual deployed count
# ---------------------------------------------------------------------------
function Deploy-AVDSessionHosts {
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][string]$HostPoolName,
        [Parameter(Mandatory)][string]$SubnetId,
        [Parameter(Mandatory)][string]$MonitoringRG,
        [string]$LawName  = '',
        $Law              = $null,
        $FslogixUNC       = $null
    )

    $tokenExpiry = (Get-Date).AddHours(2).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
    try {
        $regInfo  = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName -ExpirationTime $tokenExpiry -ErrorAction Stop
        $regToken = $regInfo.Token
        Write-Host '  Registration token generated (valid 2 hours).' -ForegroundColor Green
    }
    catch {
        Write-Host "  Failed to generate token: $($_.Exception.Message)" -ForegroundColor Red
        return 0
    }

    $vmSize    = $Global:AVDConfig.SessionHostSize
    $imageURN  = $Global:AVDConfig.SessionHostImage
    $diskType  = $Global:AVDConfig.SessionHostDisk
    $hCount    = [int]$Global:AVDConfig.SessionHostCount
    $pfx       = $Global:AVDConfig.Prefix
    $adminUser = $Global:AVDConfig.LocalAdmin.Username
    $adminPass = $Global:AVDConfig.LocalAdmin.Password
    $cred      = [System.Management.Automation.PSCredential]::new($adminUser, $adminPass)
    $imgParts  = $imageURN -split ':'
    if ($imgParts.Count -ne 4) {
        Write-Host "  Invalid image URN: $imageURN" -ForegroundColor Red
        return 0
    }

    $deployedCount = 0
    $dscZipUrl     = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip'
    $isEntraID     = $Global:AVDConfig.IdentityProvider -in @('Entra ID', 'Entra ID Kerberos', 'EntraID')

    for ($n = 1; $n -le $hCount; $n++) {
        $vmName  = "$pfx-avd-$('{0:D3}' -f $n)"
        $nicName = "$vmName-nic"
        Write-Host "  Deploying $n of $hCount : $vmName ..." -ForegroundColor Yellow

        $existingVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName `
            -ErrorAction SilentlyContinue
        if ($existingVM) {
            Write-Host "    Already exists, skipping: $vmName" -ForegroundColor Yellow
            $deployedCount++
            continue
        }

        $nic       = $null
        $vmCreated = $false
        try {
            # -----------------------------------------------------------------
            # Step A: NIC
            # -----------------------------------------------------------------
            $nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName `
                -Location $Location -SubnetId $SubnetId -ErrorAction Stop
            Write-Host "    NIC created: $nicName" -ForegroundColor Gray

            # -----------------------------------------------------------------
            # Step B: VM — created WITHOUT managed identity first
            # Identity is assigned in Step C via Update-AzVM after creation
            # -----------------------------------------------------------------
            $vmCfg = New-AzVMConfig -VMName $vmName -VMSize $vmSize |
                Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred `
                    -ProvisionVMAgent -EnableAutoUpdate |
                Set-AzVMSourceImage -PublisherName $imgParts[0] -Offer $imgParts[1] `
                    -Skus $imgParts[2] -Version $imgParts[3] |
                Set-AzVMOSDisk -StorageAccountType $diskType -CreateOption FromImage |
                Add-AzVMNetworkInterface -Id $nic.Id
            $vmCfg = Set-AzVMBootDiagnostic -VM $vmCfg -Disable

            $prevWP = $WarningPreference; $WarningPreference = 'SilentlyContinue'
            New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location `
                -VM $vmCfg -ErrorAction Stop | Out-Null
            $WarningPreference = $prevWP
            $vmCreated = $true
            Write-Host "    VM created: $vmName" -ForegroundColor Green

            # -----------------------------------------------------------------
            # Step C: Enable System-Assigned Managed Identity
            # REQUIRED before AADLoginForWindows — the extension reads the
            # tenant ID from the managed identity IMDS token endpoint.
            # Without this, AADLoginForWindows fails with:
            # 0x801c002d / DsrCmdAzureHelper::GetTenantId failed
            # -----------------------------------------------------------------
            if ($isEntraID) {
                Write-Host "    Enabling System-Assigned Managed Identity: $vmName ..." -ForegroundColor Gray
                $vmObj = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction Stop
                Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vmObj `
                    -IdentityType SystemAssigned -ErrorAction Stop | Out-Null
                Write-Host "    System-Assigned Managed Identity enabled: $vmName" -ForegroundColor Green
            }

            # -----------------------------------------------------------------
            # Step D: AADLoginForWindows (Entra ID ONLY — must run after
            #         managed identity is enabled, and before DSC)
            #   Publisher : Microsoft.Azure.ActiveDirectory
            #   Type      : AADLoginForWindows
            #   Version   : 2.0
            #   mdmId     : Intune MDM app ID when Intune enrollment selected,
            #               omitted otherwise
            # -----------------------------------------------------------------
            if ($isEntraID) {
                Write-Host "    Installing AADLoginForWindows (Entra ID join)..." -ForegroundColor Gray

                $intuneEnabled  = ($Global:AVDConfig.Intune -eq 'Y')
                $aadExtSettings = if ($intuneEnabled) {
                    @{ mdmId = '0000000a-0000-0000-c000-000000000000' }
                }
                else { @{} }

                Set-AzVMExtension `
                    -ResourceGroupName  $ResourceGroupName `
                    -VMName             $vmName `
                    -Name               'AADLoginForWindows' `
                    -Publisher          'Microsoft.Azure.ActiveDirectory' `
                    -ExtensionType      'AADLoginForWindows' `
                    -TypeHandlerVersion '2.0' `
                    -Settings           $aadExtSettings `
                    -Location           $Location `
                    -ErrorAction        Stop | Out-Null

                $intuneNote = if ($intuneEnabled) { ' (with Intune MDM enrollment)' } else { '' }
                Write-Host "    AADLoginForWindows installed: $vmName$intuneNote" -ForegroundColor Green
            }

            # -----------------------------------------------------------------
            # Step E: DSC — AVD host pool registration
            #   configurationFunction : single backslash, no double-escape
            #   properties            : public settings (no token)
            #   ProtectedSettings     : token here only, never in public
            #   aadJoin               : true for Entra ID providers
            # -----------------------------------------------------------------
            $dscPublicSettings = @{
                modulesUrl            = $dscZipUrl
                configurationFunction = 'Configuration.ps1\AddSessionHost'
                properties            = @{
                    hostPoolName = $HostPoolName
                    aadJoin      = $isEntraID
                }
            }
            $dscProtectedSettings = @{
                properties = @{
                    registrationInfoToken = $regToken
                }
            }

            Set-AzVMExtension `
                -ResourceGroupName  $ResourceGroupName `
                -VMName             $vmName `
                -Name               'DSC' `
                -Publisher          'Microsoft.Powershell' `
                -ExtensionType      'DSC' `
                -TypeHandlerVersion '2.83' `
                -Settings           $dscPublicSettings `
                -ProtectedSettings  $dscProtectedSettings `
                -Location           $Location `
                -ErrorAction        Stop | Out-Null
            Write-Host "    AVD DSC agent installed: $vmName" -ForegroundColor Green

            # -----------------------------------------------------------------
            # Step F: FSLogix — Custom Script Extension
            # -----------------------------------------------------------------
            if ($FslogixUNC) {
                $fsScript = @"
New-Item -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'Enabled'      -Value 1             -Type DWord
Set-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'VHDLocations' -Value '$FslogixUNC' -Type String
Set-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'DeleteLocalProfileWhenVHDShouldApply' -Value 1 -Type DWord
Set-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'PreventLoginWithFailure'              -Value 1 -Type DWord
Set-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'PreventLoginWithTempProfile'          -Value 1 -Type DWord
"@
                $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($fsScript))
                Set-AzVMExtension `
                    -ResourceGroupName  $ResourceGroupName `
                    -VMName             $vmName `
                    -Name               'FSLogixConfig' `
                    -Publisher          'Microsoft.Compute' `
                    -ExtensionType      'CustomScriptExtension' `
                    -TypeHandlerVersion '1.10' `
                    -Settings           @{ commandToExecute = "powershell.exe -EncodedCommand $enc" } `
                    -Location           $Location `
                    -ErrorAction        Stop | Out-Null
                Write-Host "    FSLogix configured: $vmName" -ForegroundColor Green
            }

            # -----------------------------------------------------------------
            # Step G: Log Analytics MMA agent
            # -----------------------------------------------------------------
            if ($Law -and -not [string]::IsNullOrWhiteSpace($LawName)) {
                $lawKey = (Get-AzOperationalInsightsWorkspaceSharedKey `
                    -ResourceGroupName $MonitoringRG -Name $LawName).PrimarySharedKey
                Set-AzVMExtension `
                    -ResourceGroupName  $ResourceGroupName `
                    -VMName             $vmName `
                    -Name               'MicrosoftMonitoringAgent' `
                    -Publisher          'Microsoft.EnterpriseCloud.Monitoring' `
                    -ExtensionType      'MicrosoftMonitoringAgent' `
                    -TypeHandlerVersion '1.0' `
                    -Settings           @{ workspaceId = $Law.CustomerId.ToString() } `
                    -ProtectedSettings  @{ workspaceKey = $lawKey } `
                    -Location           $Location `
                    -ErrorAction        Stop | Out-Null
                Write-Host "    Log Analytics agent installed: $vmName" -ForegroundColor Green
            }

            $deployedCount++
            Write-Host "    Session host complete: $vmName" -ForegroundColor Green
        }
        catch {
            Write-Host "    Failed $vmName : $($_.Exception.Message)" -ForegroundColor Red

            # Clean up both VM and NIC together on any failure
            if ($vmCreated) {
                try {
                    Write-Host "    Removing failed VM: $vmName ..." -ForegroundColor Gray
                    Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName `
                        -Force -ErrorAction SilentlyContinue | Out-Null
                    Write-Host "    Cleaned up VM: $vmName" -ForegroundColor Gray
                }
                catch { <# best-effort #> }
            }
            if ($nic) {
                try {
                    Remove-AzNetworkInterface -Name $nicName `
                        -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
                    Write-Host "    Cleaned up NIC: $nicName" -ForegroundColor Gray
                }
                catch { <# best-effort #> }
            }
        }
    }
    return $deployedCount
}

# ---------------------------------------------------------------------------
# Input prompt helpers
# ---------------------------------------------------------------------------
function Get-AVDPrefix {
    do {
        $p     = (Read-Host 'Enter a 4-character alphanumeric prefix').Trim()
        $valid = $p -match '^[A-Za-z0-9]{4}$'
        if (-not $valid) { Write-Host 'Must be exactly 4 alphanumeric characters.' -ForegroundColor Yellow }
    } while (-not $valid)
    return $p
}

function Get-AVDEnvironment {
    do {
        $e     = (Read-Host 'Enter environment (dev/test/prod)').Trim().ToLower()
        $valid = $e -in @('dev', 'test', 'prod')
        if (-not $valid) { Write-Host 'Enter dev, test, or prod.' -ForegroundColor Yellow }
    } while (-not $valid)
    return $e
}

function Get-AVDKerberosDomain {
    do {
        $d     = (Read-Host 'Enter Kerberos Domain FQDN').Trim()
        $valid = $d -match '^([a-zA-Z0-9]+\.)+[a-zA-Z]{2,}$'
        if (-not $valid) { Write-Host 'Invalid FQDN. Example: corp.contoso.com' -ForegroundColor Yellow }
    } while (-not $valid)
    return $d
}

function Get-AVDDomainJoinCredentials {
    do {
        $u     = (Read-Host 'Enter Domain Join Username').Trim()
        $valid = $u.Length -gt 0
        if (-not $valid) { Write-Host 'Username cannot be empty.' -ForegroundColor Yellow }
    } while (-not $valid)
    $p = Read-Host 'Enter Domain Join Password' -AsSecureString
    return @{ Username = $u; Password = $p }
}

function Get-AVDIntuneEnrollment {
    do {
        $v     = (Read-Host 'Enable Intune Enrollment? (Y/N)').Trim().ToUpper()
        $valid = $v -in @('Y', 'N')
        if (-not $valid) { Write-Host 'Enter Y or N.' -ForegroundColor Yellow }
    } while (-not $valid)
    return $v
}

function Get-AVDLocalAdminCredentials {
    do {
        $u     = (Read-Host 'Enter Local Admin Username').Trim()
        $valid = $u.Length -gt 0
        if (-not $valid) { Write-Host 'Username cannot be empty.' -ForegroundColor Yellow }
    } while (-not $valid)
    $p = Read-Host 'Enter Local Admin Password' -AsSecureString
    return @{ Username = $u; Password = $p }
}

function Get-AVDDefender {
    do {
        $v     = (Read-Host 'Enable Microsoft Defender for Cloud? (Y/N)').Trim().ToUpper()
        $valid = $v -in @('Y', 'N')
        if (-not $valid) { Write-Host 'Enter Y or N.' -ForegroundColor Yellow }
    } while (-not $valid)
    return $v
}

# ---------------------------------------------------------------------------
# Main Menu
# ---------------------------------------------------------------------------
function Show-AVDMainMenu {
    $menuItems = @(
        '1.  Deployment Basics',
        '2.  Identity',
        '3.  Management plane',
        '4.  Session hosts',
        '5.  Storage',
        '6.  Networking',
        '7.  Monitoring',
        '8.  Resource naming',
        '9.  Resource tagging',
        '10. Review + create',
        '0.  Exit'
    )
    $milestoneKeys = @(
        'DeploymentBasics', 'Identity', 'ManagementPlane', 'SessionHosts',
        'Storage', 'Networking', 'Monitoring', 'ResourceNaming', 'ResourceTagging', 'ReviewCreate'
    )
    Write-Host '==== AVD Accelerator Deployment Menu ====' -ForegroundColor Cyan
    for ($i = 0; $i -lt $menuItems.Count; $i++) {
        if ($i -eq 10) { Write-Host $menuItems[$i]; continue }
        $mk   = if ($i -lt $milestoneKeys.Count) { $milestoneKeys[$i] } else { '' }
        $done = $Global:AVDConfig -and $mk -and $Global:AVDConfig["${mk}Completed"]
        if ($done) { Write-Host $menuItems[$i] -ForegroundColor Green }
        else        { Write-Host $menuItems[$i] }
    }
    $choice = 0
    do {
        $raw   = Read-Host 'Select milestone (1-10) or 0 to Exit'
        $valid = $raw -match '^(10|[0-9])$' -and [int]::TryParse($raw, [ref]$choice)
        if (-not $valid) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($valid)
    return $choice
}

# ---------------------------------------------------------------------------
# Milestone 1 – Deployment Basics
# ---------------------------------------------------------------------------
function Set-AVDDeploymentBasics {
    Write-Host '[Deployment Basics]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }

    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx) {
        try   { Connect-AzAccount -ErrorAction Stop | Out-Null }
        catch { Write-Host "Connect failed: $($_.Exception.Message)" -ForegroundColor Red; return $false }
    }

    $subs = @(Get-AzSubscription)
    if ($subs.Count -eq 0) { Write-Host 'No subscriptions found.' -ForegroundColor Red; return $false }
    if ($subs.Count -eq 1) {
        $subObj = $subs[0]
    }
    else {
        $dl = $subs | ForEach-Object { "$($_.Name)  [$($_.Id)]" }
        for ($i = 0; $i -lt $dl.Count; $i++) { Write-Host "[$($i+1)] $($dl[$i])" }
        $sidx = 0
        do {
            $sx  = Read-Host "Select subscription (1-$($subs.Count))"
            $sok = $sx -match '^[0-9]+$' -and [int]::TryParse($sx, [ref]$sidx) -and
                   $sidx -ge 1 -and $sidx -le $subs.Count
            if (-not $sok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
        } until ($sok)
        $subObj = $subs[$sidx - 1]
    }
    Set-AzContext -SubscriptionId $subObj.Id | Out-Null
    $Global:AVDConfig.Subscription = $subObj

    if (-not $Global:AVDLocationCache) {
        Write-Host 'Retrieving Azure regions...' -ForegroundColor Cyan
        $Global:AVDLocationCache = @(Get-AzLocation | Sort-Object Location)
    }
    $allR  = $Global:AVDLocationCache
    $filtR = $allR
    $pageSize = 10; $page = 0; $selected = $false; $ridx = 0
    while (-not $selected) {
        $start = $page * $pageSize
        $end   = [Math]::Min($start + $pageSize, $filtR.Count)
        Write-Host "Azure regions ($($filtR.Count) total):"
        for ($i = $start; $i -lt $end; $i++) { Write-Host "[$($i+1)] $($filtR[$i].Location)" }
        if ($end -lt $filtR.Count) { Write-Host '...more. Press Enter for next page or type to filter.' }
        $rx = Read-Host 'Number, filter text, or Enter'
        if ([string]::IsNullOrWhiteSpace($rx)) {
            $page = if ($end -lt $filtR.Count) { $page + 1 } else { 0 }
            continue
        }
        $ti = 0
        if ([int]::TryParse($rx, [ref]$ti) -and $ti -ge 1 -and $ti -le $filtR.Count) {
            $ridx = $ti; $selected = $true
        }
        else {
            $filtR = @($allR | Where-Object { $_.Location -like "*$rx*" })
            if ($filtR.Count -eq 0) {
                Write-Host "No match for '$rx'. Showing all." -ForegroundColor Yellow
                $filtR = $allR
            }
            $page = 0
        }
    }
    $Global:AVDConfig.Region = $filtR[$ridx - 1].Location

    $envOpts = @('dev', 'test', 'prod')
    for ($i = 0; $i -lt $envOpts.Count; $i++) { Write-Host "[$($i+1)] $($envOpts[$i])" }
    $eidx = 0
    do {
        $ex  = Read-Host 'Select environment (1-3)'
        $eok = $ex -match '^[0-9]+$' -and [int]::TryParse($ex, [ref]$eidx) -and
               $eidx -ge 1 -and $eidx -le $envOpts.Count
        if (-not $eok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($eok)
    $Global:AVDConfig.Environment = $envOpts[$eidx - 1]
    $Global:AVDConfig.Prefix      = Get-AVDPrefix

    Write-Host 'Deployment Basics configured.' -ForegroundColor Cyan
    $Global:AVDConfig['DeploymentBasicsCompleted'] = $true
    Write-Host '[Section complete: Deployment Basics]' -ForegroundColor Green
    return $true
}

# ---------------------------------------------------------------------------
# Milestone 2 – Identity
# ---------------------------------------------------------------------------
function Set-AVDIdentity {
    Write-Host '[Identity]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }

    $idTypes = @('ADDS', 'EntraDS', 'Entra ID', 'Entra ID Kerberos')
    for ($i = 0; $i -lt $idTypes.Count; $i++) { Write-Host "[$($i+1)] $($idTypes[$i])" }
    $idx = 0
    do {
        $ix  = Read-Host 'Select identity provider (1-4)'
        $ok  = $ix -match '^[0-9]+$' -and [int]::TryParse($ix, [ref]$idx) -and
               $idx -ge 1 -and $idx -le $idTypes.Count
        if (-not $ok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($ok)
    $prov = $idTypes[$idx - 1]
    $Global:AVDConfig.IdentityProvider = $prov

    if ($prov -in @('ADDS', 'EntraDS', 'Entra ID Kerberos')) {
        $Global:AVDConfig.KerberosDomain = Get-AVDKerberosDomain
        $Global:AVDConfig.DomainJoin     = Get-AVDDomainJoinCredentials
    }
    else {
        $Global:AVDConfig.KerberosDomain = $null
        $Global:AVDConfig.DomainJoin     = $null
    }

    $Global:AVDConfig.Intune     = Get-AVDIntuneEnrollment
    $Global:AVDConfig.LocalAdmin = Get-AVDLocalAdminCredentials
    $Global:AVDConfig.Defender   = Get-AVDDefender

    Write-Host 'Identity configured.' -ForegroundColor Cyan
    $Global:AVDConfig['IdentityCompleted'] = $true
    Write-Host '[Section complete: Identity]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Milestone 3 – Management Plane
# ---------------------------------------------------------------------------
function Set-AVDManagementPlane {
    Write-Host '[Management plane]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }

    $mgmt = @('AVD ARM', 'Classic (Not recommended)')
    for ($i = 0; $i -lt $mgmt.Count; $i++) { Write-Host "[$($i+1)] $($mgmt[$i])" }
    $idx = 0
    do {
        $ix  = Read-Host 'Select management plane (1-2)'
        $ok  = $ix -match '^[0-9]+$' -and [int]::TryParse($ix, [ref]$idx) -and
               $idx -ge 1 -and $idx -le $mgmt.Count
        if (-not $ok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($ok)
    $Global:AVDConfig.ManagementPlane = $mgmt[$idx - 1]

    $agTypes = @('Desktop', 'RemoteApp')
    for ($i = 0; $i -lt $agTypes.Count; $i++) { Write-Host "[$($i+1)] $($agTypes[$i])" }
    $agIdx = 0
    do {
        $agSel = Read-Host "Select App Group Type (1-$($agTypes.Count)) [Default: 1]"
        if ([string]::IsNullOrWhiteSpace($agSel)) { $agSel = '1' }
        $agOk  = $agSel -match '^[0-9]+$' -and [int]::TryParse($agSel, [ref]$agIdx) -and
                 $agIdx -ge 1 -and $agIdx -le $agTypes.Count
        if (-not $agOk) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($agOk)
    $Global:AVDConfig.PreferredAppGroupType = $agTypes[$agIdx - 1]

    $eaDef  = '9cdead84-a844-4324-93f2-b2e6bb768d07'
    $guidRx = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
    Write-Host "`nDefault Enterprise App AppID: $eaDef" -ForegroundColor Cyan
    do {
        $eaId = Read-Host 'Enter Enterprise App AppID (Enter for default)'
        if ([string]::IsNullOrWhiteSpace($eaId)) { $eaId = $eaDef }
        $vg   = $eaId -match $guidRx
        if (-not $vg) { Write-Host 'Not a valid GUID. Try again.' -ForegroundColor Red }
    } while (-not $vg)
    $Global:AVDConfig.EnterpriseAppId = $eaId

    $sv = Read-Host "Enable 'Start VM on connect'? (Y/N) [Default: Y]"
    if ([string]::IsNullOrWhiteSpace($sv)) { $sv = 'Y' }
    $Global:AVDConfig.StartVMOnConnect  = $sv
    $Global:AVDConfig.AssignStartVMRole = $sv -match '^[Yy]'

    $sp = Read-Host 'Enable scaling plan? (Y/N) [Default: N]'
    if ([string]::IsNullOrWhiteSpace($sp)) { $sp = 'N' }
    $Global:AVDConfig.EnableScalingPlan = $sp
    if ($sp -match '^[Yy]') {
        $defSP = "vdscaling-$($Global:AVDConfig.Prefix)-$($Global:AVDConfig.Environment)"
        $spRes = Resolve-OrCreate -ResourceType 'AVD Scaling Plan' -DefaultName $defSP `
            -ExtraHint 'Automates session host power management.' -AllowSkip
        $Global:AVDConfig.ScalingPlanName  = $spRes.Name
        $Global:AVDConfig.ScalingPlanIsNew = $spRes.IsNew
        $Global:AVDConfig.ScalingPlanSkip  = $spRes.Skip
    }
    else {
        $Global:AVDConfig.ScalingPlanName  = $null
        $Global:AVDConfig.ScalingPlanIsNew = $false
        $Global:AVDConfig.ScalingPlanSkip  = $true
    }

    Write-Host 'Management plane configured.' -ForegroundColor Cyan
    $Global:AVDConfig['ManagementPlaneCompleted'] = $true
    Write-Host '[Section complete: Management plane]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Milestone 4 – Session Hosts
# ---------------------------------------------------------------------------
function Set-AVDSessionHosts {
    Write-Host '[Session hosts]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }

    $ci = Read-Host 'How many session hosts?'
    $hc = 0
    while (-not ([int]::TryParse($ci, [ref]$hc)) -or $hc -lt 1) {
        Write-Host 'Enter a valid positive integer.' -ForegroundColor Yellow
        $ci = Read-Host 'How many session hosts?'
    }
    $Global:AVDConfig.SessionHostCount = $hc

    $vmCats = @{
        'Standard Users' = @('Standard_D2s_v5','Standard_D4s_v5','Standard_B2ms','Standard_B4ms',
                              'Standard_D2as_v5','Standard_D4as_v5','Standard_F2s_v2','Standard_F4s_v2',
                              'Standard_E2s_v5','Standard_E4s_v5')
        'Power Users'    = @('Standard_D8s_v5','Standard_D16s_v5','Standard_E8s_v5','Standard_E16s_v5',
                              'Standard_F8s_v2','Standard_F16s_v2','Standard_D8as_v5','Standard_D16as_v5')
        'Graphics/GPU'   = @('Standard_NV6','Standard_NV12','Standard_NV12s_v3','Standard_NC6',
                              'Standard_NC12','Standard_NC6s_v3','Standard_NC12s_v3','Standard_ND6s','Standard_ND12s')
    }
    $catNames = @('Standard Users', 'Power Users', 'Graphics/GPU')
    Write-Host 'Select VM size category:'
    for ($i = 0; $i -lt $catNames.Count; $i++) { Write-Host "[$($i+1)] $($catNames[$i])" }
    $catIdx = 0
    do {
        $cs  = Read-Host "Select category (1-$($catNames.Count))"
        $cok = $cs -match '^[0-9]+$' -and [int]::TryParse($cs, [ref]$catIdx) -and
               $catIdx -ge 1 -and $catIdx -le $catNames.Count
        if (-not $cok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($cok)
    $chosenCat = $catNames[$catIdx - 1]
    $region    = $Global:AVDConfig.Region

    if (-not $Global:AVDSkuCache)            { $Global:AVDSkuCache   = @{} }
    if (-not $Global:AVDSkuCache[$region])   {
        Write-Host "Retrieving VM SKUs for $region..." -ForegroundColor Cyan
        $Global:AVDSkuCache[$region] = @(
            Get-AzComputeResourceSku | Where-Object {
                $_.ResourceType -eq 'virtualMachines' -and
                ($_.LocationInfo | Where-Object { $_.Location -eq $region })
            }
        )
    }
    if (-not $Global:AVDQuotaCache)          { $Global:AVDQuotaCache = @{} }
    if (-not $Global:AVDQuotaCache[$region]) {
        Write-Host "Retrieving VM quota for $region..." -ForegroundColor Cyan
        $Global:AVDQuotaCache[$region] = @(Get-AzVMUsage -Location $region)
    }
    $availNames   = $Global:AVDSkuCache[$region]  | Select-Object -ExpandProperty Name
    $quotaResults = $Global:AVDQuotaCache[$region]

    $vmList         = @()
    $skippedNoQuota = @()
    foreach ($sku in $vmCats[$chosenCat]) {
        if ($availNames -contains $sku) {
            $quotaFamily = Get-VMQuotaFamilyName -SkuName $sku
            if ($quotaFamily) {
                $q = $quotaResults | Where-Object { $_.Name.Value -eq $quotaFamily }
                if ($q -and $q.Limit -gt 0 -and $q.CurrentValue -lt $q.Limit) {
                    $vmList += $sku
                }
                elseif ($q -and $q.Limit -eq 0) {
                    $skippedNoQuota += "$sku (quota limit: 0 for $quotaFamily)"
                }
            }
        }
    }

    if ($skippedNoQuota.Count -gt 0) {
        Write-Host '  Note: The following SKUs were excluded due to zero quota:' -ForegroundColor Yellow
        $skippedNoQuota | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    }
    if ($vmList.Count -eq 0) {
        Write-Host "  No VM sizes available in '$chosenCat' with sufficient quota in $region." -ForegroundColor Red
        Write-Host '  Request a quota increase at: https://aka.ms/ProdportalCRP' -ForegroundColor Yellow
        return
    }

    $ps = 10; $pg = 0; $vmIdx = 0; $sel = $false; $fVMs = $vmList
    while (-not $sel) {
        $s = $pg * $ps
        $e = [Math]::Min($s + $ps, $fVMs.Count)
        Write-Host "VM sizes in '$chosenCat' ($($fVMs.Count) total, $region):"
        for ($i = $s; $i -lt $e; $i++) { Write-Host "[$($i+1)] $($fVMs[$i])" }
        if ($e -lt $fVMs.Count) { Write-Host '...more. Enter to page, or type to filter.' }
        $vs = Read-Host 'Number, filter, or Enter'
        if ([string]::IsNullOrWhiteSpace($vs)) {
            $pg = if ($e -lt $fVMs.Count) { $pg + 1 } else { 0 }
            continue
        }
        $ti = 0
        if ([int]::TryParse($vs, [ref]$ti) -and $ti -ge 1 -and $ti -le $fVMs.Count) {
            $vmIdx = $ti; $sel = $true
        }
        else {
            $fVMs = @($vmList | Where-Object { $_ -like "*$vs*" })
            if ($fVMs.Count -eq 0) {
                Write-Host 'No match. Showing all.' -ForegroundColor Yellow
                $fVMs = $vmList
            }
            $pg = 0
        }
    }
    $Global:AVDConfig.SessionHostSize = $fVMs[$vmIdx - 1]

    $images = @(
        @{ Name = 'Windows 11 Enterprise multi-session'; URN = 'MicrosoftWindowsDesktop:windows-11:win11-22h2-avd:latest' },
        @{ Name = 'Windows 10 Enterprise multi-session'; URN = 'MicrosoftWindowsDesktop:windows-10:win10-22h2-avd:latest' },
        @{ Name = 'Windows 11 Enterprise';               URN = 'MicrosoftWindowsDesktop:windows-11:win11-22h2-pro:latest' },
        @{ Name = 'Windows 10 Enterprise';               URN = 'MicrosoftWindowsDesktop:windows-10:win10-22h2-pro:latest' },
        @{ Name = 'Custom (enter URN or resource ID)';   URN = '' }
    )
    Write-Host 'Select session host image:'
    for ($i = 0; $i -lt $images.Count; $i++) { Write-Host "[$($i+1)] $($images[$i].Name)" }
    $imgIdx = 0
    do {
        $is  = Read-Host "Select image (1-$($images.Count))"
        $iok = $is -match '^[0-9]+$' -and [int]::TryParse($is, [ref]$imgIdx) -and
               $imgIdx -ge 1 -and $imgIdx -le $images.Count
        if (-not $iok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($iok)
    $Global:AVDConfig.SessionHostImage = if ($images[$imgIdx - 1].Name -like 'Custom*') {
        Read-Host 'Enter URN or resource ID'
    }
    else { $images[$imgIdx - 1].URN }

    $diskFriendly = @('StandardSSD_LRS', 'PremiumSSD_LRS', 'StandardHDD_LRS', 'UltraSSD_LRS')
    Write-Host 'Select OS disk type:'
    for ($i = 0; $i -lt $diskFriendly.Count; $i++) { Write-Host "[$($i+1)] $($diskFriendly[$i])" }
    $didx = 0
    do {
        $dx  = Read-Host "Select disk type (1-$($diskFriendly.Count))"
        $dok = $dx -match '^[0-9]+$' -and [int]::TryParse($dx, [ref]$didx) -and
               $didx -ge 1 -and $didx -le $diskFriendly.Count
        if (-not $dok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($dok)
    $friendlyDisk                             = $diskFriendly[$didx - 1]
    $Global:AVDConfig.SessionHostDisk         = $Script:DiskSkuMap[$friendlyDisk]
    $Global:AVDConfig.SessionHostDiskFriendly = $friendlyDisk

    Write-Host 'Session hosts configured.' -ForegroundColor Cyan
    $Global:AVDConfig['SessionHostsCompleted'] = $true
    Write-Host '[Section complete: Session hosts]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Milestone 5 – Storage
# ---------------------------------------------------------------------------
function Set-AVDStorage {
    Write-Host '[Storage]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }

    $idp = $Global:AVDConfig.IdentityProvider
    if ($idp -in @('Entra ID', 'Entra ID Kerberos')) {
        Write-Host 'FSLogix: only Azure Files supported for Entra ID.' -ForegroundColor Yellow
        $Global:AVDConfig.FSLogixType = 'AzureFiles'
    }
    else {
        $fst = @('AzureFiles', 'NetAppFiles', 'None')
        for ($i = 0; $i -lt $fst.Count; $i++) { Write-Host "[$($i+1)] $($fst[$i])" }
        $fsidx = 0
        do {
            $fsx  = Read-Host "Select FSLogix type (1-$($fst.Count))"
            $fsok = $fsx -match '^[0-9]+$' -and [int]::TryParse($fsx, [ref]$fsidx) -and
                    $fsidx -ge 1 -and $fsidx -le $fst.Count
            if (-not $fsok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
        } until ($fsok)
        $Global:AVDConfig.FSLogixType = $fst[$fsidx - 1]
    }

    if ($Global:AVDConfig.FSLogixType -ne 'None') {
        $defSA = New-SafeStorageAccountName -RawName "savd$($Global:AVDConfig.Prefix)$($Global:AVDConfig.Environment)"
        $saRes = Resolve-OrCreate -ResourceType 'Storage Account' -DefaultName $defSA `
            -ExtraHint 'Hosts the Azure Files share for FSLogix user profiles.'
        $Global:AVDConfig.StorageAccountName  = $saRes.Name
        $Global:AVDConfig.StorageAccountIsNew = $saRes.IsNew

        $shrRes = Resolve-OrCreate -ResourceType 'Azure Files Share' -DefaultName 'fslogix-profiles' `
            -ExtraHint 'File share that stores FSLogix .VHD profile containers.'
        $Global:AVDConfig.FSLogixShare      = $shrRes.Name
        $Global:AVDConfig.FSLogixShareIsNew = $shrRes.IsNew

        $qGB = 0
        do {
            $qr  = Read-Host 'File share quota in GB [Default: 100]'
            if ([string]::IsNullOrWhiteSpace($qr)) { $qGB = 100; break }
            $qok = [int]::TryParse($qr, [ref]$qGB) -and $qGB -ge 1
            if (-not $qok) { Write-Host 'Enter a valid positive integer.' -ForegroundColor Yellow }
        } until ($qok)
        $Global:AVDConfig.FSLogixShareQuotaGB = $qGB
    }
    else {
        $Global:AVDConfig.StorageAccountName  = $null
        $Global:AVDConfig.StorageAccountIsNew = $false
        $Global:AVDConfig.FSLogixShare        = $null
        $Global:AVDConfig.FSLogixShareIsNew   = $false
        $Global:AVDConfig.FSLogixShareQuotaGB = 0
    }

    $redFriendly = @('LRS', 'ZRS', 'GZRS')
    Write-Host 'Select storage redundancy:'
    for ($i = 0; $i -lt $redFriendly.Count; $i++) { Write-Host "[$($i+1)] $($redFriendly[$i])" }
    $ridx = 0
    do {
        $rx  = Read-Host "Select redundancy (1-$($redFriendly.Count))"
        $rok = $rx -match '^[0-9]+$' -and [int]::TryParse($rx, [ref]$ridx) -and
               $ridx -ge 1 -and $ridx -le $redFriendly.Count
        if (-not $rok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($rok)
    $friendly                                   = $redFriendly[$ridx - 1]
    $Global:AVDConfig.StorageRedundancy         = $Script:StorageSkuMap[$friendly]
    $Global:AVDConfig.StorageRedundancyFriendly = $friendly

    Write-Host 'Storage configured.' -ForegroundColor Cyan
    $Global:AVDConfig['StorageCompleted'] = $true
    Write-Host '[Section complete: Storage]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Milestone 6 – Networking
# ---------------------------------------------------------------------------
function Set-AVDNetworking {
    Write-Host '[Networking]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }

    $cidrRx = '^\d{1,3}(\.\d{1,3}){3}\/\d{1,2}$'
    $ipRx   = '^\d{1,3}(\.\d{1,3}){3}$'
    $pfx    = $Global:AVDConfig.Prefix
    $env    = $Global:AVDConfig.Environment

    $vRes = Resolve-OrCreate -ResourceType 'Virtual Network' -DefaultName "$pfx-vnet" `
        -ExtraHint 'VNet where AVD session hosts will be connected.'
    $Global:AVDConfig.VNetName  = $vRes.Name
    $Global:AVDConfig.VNetIsNew = $vRes.IsNew
    do {
        $Global:AVDConfig.VNetAddress = (Read-Host 'VNet address space (e.g. 10.10.0.0/16)').Trim()
        if ($Global:AVDConfig.VNetAddress -notmatch $cidrRx) {
            Write-Host 'Invalid CIDR. Example: 10.10.0.0/16' -ForegroundColor Yellow
        }
    } while ($Global:AVDConfig.VNetAddress -notmatch $cidrRx)

    $sRes = Resolve-OrCreate -ResourceType 'Subnet' -DefaultName "$pfx-subnet" `
        -ExtraHint 'Subnet for AVD session host NICs.'
    $Global:AVDConfig.SubnetName  = $sRes.Name
    $Global:AVDConfig.SubnetIsNew = $sRes.IsNew
    do {
        $Global:AVDConfig.SubnetAddress = (Read-Host 'Subnet address range (e.g. 10.10.1.0/24)').Trim()
        if ($Global:AVDConfig.SubnetAddress -notmatch $cidrRx) {
            Write-Host 'Invalid CIDR. Example: 10.10.1.0/24' -ForegroundColor Yellow
        }
    } while ($Global:AVDConfig.SubnetAddress -notmatch $cidrRx)

    $nsgRes = Resolve-OrCreate -ResourceType 'Network Security Group (NSG)' `
        -DefaultName "$pfx-nsg-$env" `
        -ExtraHint 'Controls inbound/outbound traffic for session hosts.' -AllowSkip
    $Global:AVDConfig.NSG      = $nsgRes.Name
    $Global:AVDConfig.NSGIsNew = $nsgRes.IsNew
    $Global:AVDConfig.NSGSkip  = $nsgRes.Skip

    $peRes = Resolve-OrCreate -ResourceType 'Private Endpoint Subnet' `
        -DefaultName "$pfx-pe-subnet" `
        -ExtraHint 'Dedicated subnet for private endpoints (Key Vault, Storage).' -AllowSkip
    $Global:AVDConfig.PrivateEndpointSubnet      = $peRes.Name
    $Global:AVDConfig.PrivateEndpointSubnetIsNew = $peRes.IsNew
    $Global:AVDConfig.PrivateEndpointSubnetSkip  = $peRes.Skip
    if ($peRes.IsNew -and -not $peRes.Skip) {
        do {
            $Global:AVDConfig.PrivateEndpointSubnetAddress = (Read-Host 'PE Subnet address range (e.g. 10.10.2.0/26)').Trim()
            if ($Global:AVDConfig.PrivateEndpointSubnetAddress -notmatch $cidrRx) {
                Write-Host 'Invalid CIDR. Example: 10.10.2.0/26' -ForegroundColor Yellow
            }
        } while ($Global:AVDConfig.PrivateEndpointSubnetAddress -notmatch $cidrRx)
    }

    if (-not $peRes.Skip) {
        $Global:AVDConfig.AVDPrivateEndpoints = Read-Host 'Enable private endpoints for AVD? (Y/N)'
        if ($Global:AVDConfig.AVDPrivateEndpoints -match '^[Yy]') {
            Write-Host 'Note: Requires Microsoft.Network and Microsoft.DesktopVirtualization providers.' -ForegroundColor Yellow
        }
    }
    else { $Global:AVDConfig.AVDPrivateEndpoints = 'N' }

    $dnsRes = Resolve-OrCreate -ResourceType 'Azure Private DNS Zone' `
        -DefaultName 'privatelink.wvd.microsoft.com' `
        -ExtraHint 'Resolves AVD and storage private endpoints.' -AllowSkip
    $Global:AVDConfig.PrivateDNSZone      = $dnsRes.Name
    $Global:AVDConfig.PrivateDNSZoneIsNew = $dnsRes.IsNew
    $Global:AVDConfig.PrivateDNSZoneSkip  = $dnsRes.Skip

    $kvRes = Resolve-OrCreate -ResourceType 'Azure Key Vault' `
        -DefaultName "kv-avd-$pfx-$env" `
        -ExtraHint 'Stores domain join and local admin credentials as secrets.' -AllowSkip
    $Global:AVDConfig.KeyVault      = $kvRes.Name
    $Global:AVDConfig.KeyVaultIsNew = $kvRes.IsNew
    $Global:AVDConfig.KeyVaultSkip  = $kvRes.Skip

    $defAFS = New-SafeStorageAccountName -RawName "savd${pfx}afs"
    $afsRes = Resolve-OrCreate -ResourceType 'Azure Files Storage Account (networking)' `
        -DefaultName $defAFS `
        -ExtraHint 'Storage account for private endpoint / DNS zone group setup.' -AllowSkip
    $Global:AVDConfig.AzureFiles      = $afsRes.Name
    $Global:AVDConfig.AzureFilesIsNew = $afsRes.IsNew
    $Global:AVDConfig.AzureFilesSkip  = $afsRes.Skip

    Write-Host "`n--- Hub VNet Peering ---" -ForegroundColor Cyan
    Write-Host '  Connects AVD VNet to your hub/transit network.' -ForegroundColor Gray
    $doPeer = Read-Host 'Configure Hub VNet Peering? (Y/N)'
    if ($doPeer -match '^[Yy]') {
        $peerRes = Resolve-OrCreate -ResourceType 'Hub VNet Peering' `
            -DefaultName "$pfx-peering-to-hub" `
            -ExtraHint 'Peering from AVD VNet to Hub VNet.' -AllowSkip
        $Global:AVDConfig.HubVNetPeering      = $peerRes.Name
        $Global:AVDConfig.HubVNetPeeringIsNew = $peerRes.IsNew
        $Global:AVDConfig.HubVNetPeeringSkip  = $peerRes.Skip
        if (-not $peerRes.Skip) {
            $Global:AVDConfig.HubVNetId           = (Read-Host 'Hub VNet Resource ID').Trim()
            $Global:AVDConfig.PeeringGatewayOnHub = Read-Host 'Use gateway on hub VNet? (Y/N)'
        }
    }
    else {
        $Global:AVDConfig.HubVNetPeering      = $null
        $Global:AVDConfig.HubVNetPeeringIsNew = $false
        $Global:AVDConfig.HubVNetPeeringSkip  = $true
        $Global:AVDConfig.HubVNetId           = $null
        $Global:AVDConfig.PeeringGatewayOnHub = 'N'
    }

    $Global:AVDConfig.AssignPublicIP = Read-Host 'Assign public IP to session hosts? (Y/N)'

    $dnsRaw = (Read-Host 'Custom DNS IPs (comma-separated, blank for Azure default)').Trim()
    if (-not [string]::IsNullOrWhiteSpace($dnsRaw)) {
        $inv = ($dnsRaw -split '\s*,\s*') | Where-Object { $_ -notmatch $ipRx }
        if ($inv -and $inv.Count -gt 0) {
            Write-Host "Warning: invalid IPs: $($inv -join ', ')" -ForegroundColor Yellow
        }
    }
    $Global:AVDConfig.DNS = $dnsRaw

    Write-Host 'Networking configured.' -ForegroundColor Cyan
    $Global:AVDConfig['NetworkingCompleted'] = $true
    Write-Host '[Section complete: Networking]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Milestone 7 – Monitoring
# ---------------------------------------------------------------------------
function Set-AVDMonitoring {
    Write-Host '[Monitoring]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }

    $Global:AVDConfig.EnableLogAnalytics = Read-Host 'Enable Log Analytics? (Y/N)'
    if ($Global:AVDConfig.EnableLogAnalytics -match '^[Yy]') {
        $defLAW = "law-avd-$($Global:AVDConfig.Prefix)-$($Global:AVDConfig.Environment)"
        $lawRes = Resolve-OrCreate -ResourceType 'Log Analytics Workspace' -DefaultName $defLAW `
            -ExtraHint 'Collects AVD diagnostics, performance counters and events.' -AllowSkip
        $Global:AVDConfig.LogAnalyticsWorkspace      = $lawRes.Name
        $Global:AVDConfig.LogAnalyticsWorkspaceIsNew = $lawRes.IsNew
        $Global:AVDConfig.LogAnalyticsWorkspaceSkip  = $lawRes.Skip
    }
    else {
        $Global:AVDConfig.LogAnalyticsWorkspace      = $null
        $Global:AVDConfig.LogAnalyticsWorkspaceIsNew = $false
        $Global:AVDConfig.LogAnalyticsWorkspaceSkip  = $true
    }
    $Global:AVDConfig.EnableDiagnostics = Read-Host 'Enable diagnostics settings? (Y/N)'

    Write-Host 'Monitoring configured.' -ForegroundColor Cyan
    $Global:AVDConfig['MonitoringCompleted'] = $true
    Write-Host '[Section complete: Monitoring]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Milestone 8 – Resource Naming
# ---------------------------------------------------------------------------
function Set-AVDResourceNaming {
    Write-Host '[Resource naming]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }

    $pfx = $Global:AVDConfig.Prefix
    $env = $Global:AVDConfig.Environment
    $reg = $Global:AVDConfig.Region
    $pat = @{
        Management = "rg-avd-$pfx-$env-$reg-management"
        Compute    = "rg-avd-$pfx-$env-$reg-pool-compute"
        Storage    = "rg-avd-$pfx-$env-$reg-storage"
        Monitoring = "rg-avd-$pfx-$env-$reg-monitoring"
    }
    $Global:AVDConfig.NamingPatterns = $pat
    Write-Host "1. Management : $($pat['Management'])"
    Write-Host "2. Compute    : $($pat['Compute'])"
    Write-Host "3. Storage    : $($pat['Storage'])"
    Write-Host "4. Monitoring : $($pat['Monitoring'])"

    $rgc = Read-Host 'Deploy in one resource group? (Y/N)'
    if ($rgc -match '^[Yy]') {
        $defRG = "rg-avd-$pfx-$env-$reg"
        $uRG   = (Read-Host "Unified RG name [Default: $defRG]").Trim()
        if ([string]::IsNullOrWhiteSpace($uRG)) { $uRG = $defRG }
        $Global:AVDConfig.ResourceGroups = @{ Unified = $uRG }
        Write-Host "All resources in: $uRG" -ForegroundColor Cyan
    }
    else {
        $Global:AVDConfig.ResourceGroups = $pat
        Write-Host 'Resources in separate RGs.' -ForegroundColor Cyan
    }

    Write-Host 'Resource naming configured.' -ForegroundColor Cyan
    $Global:AVDConfig['ResourceNamingCompleted'] = $true
    Write-Host '[Section complete: Resource naming]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Milestone 9 – Resource Tagging
# ---------------------------------------------------------------------------
function Set-AVDResourceTagging {
    Write-Host '[Resource tagging]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { $Global:AVDConfig = @{} }
    $Global:AVDConfig.Tags = @{}
    do {
        $tk = (Read-Host 'Tag key (blank to finish)').Trim()
        if ($tk) { $Global:AVDConfig.Tags[$tk] = Read-Host "Value for '$tk'" }
    } while ($tk)
    Write-Host 'Resource tagging configured.' -ForegroundColor Cyan
    $Global:AVDConfig['ResourceTaggingCompleted'] = $true
    Write-Host '[Section complete: Resource tagging]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Milestone 10 – Review + Create
# ---------------------------------------------------------------------------
function Invoke-AVDReviewAndCreate {
    Write-Host '[Review + Create]' -ForegroundColor Green
    if (-not $Global:AVDConfig) { Write-Host 'No configuration found.' -ForegroundColor Red; return }

    Write-Host 'Deployment Summary:' -ForegroundColor Cyan
    Write-Host ('-' * 60) -ForegroundColor DarkGray
    $skipKeys = @('NamingPatterns', 'ResourceGroups', 'Tags', 'Subscription')
    $Global:AVDConfig.GetEnumerator() | Sort-Object Key | ForEach-Object {
        $k = $_.Key; $v = $_.Value
        if ($k -in $skipKeys) { return }
        $display = if     ($v -is [System.Security.SecureString]) { '[secure]' }
                   elseif ($v -is [System.Collections.Hashtable] -and
                           ($v.ContainsKey('Password') -or $v.ContainsKey('Username'))) {
                               "[credentials: Username=$($v.Username), Password=[secure]]"
                   }
                   elseif ($v -is [bool])   { if ($v) { 'Yes' } else { 'No' } }
                   elseif ($null -eq $v -or ($v -is [string] -and
                           [string]::IsNullOrWhiteSpace($v)))     { '(not set)' }
                   else   { $v }
        Write-Host ("{0,-40}: {1}" -f $k, $display)
    }
    $subDisplay = if ($Global:AVDConfig.Subscription -is [string]) {
        $Global:AVDConfig.Subscription
    }
    else { "$($Global:AVDConfig.Subscription.Name) [$($Global:AVDConfig.Subscription.Id)]" }
    Write-Host ("{0,-40}: {1}" -f 'Subscription', $subDisplay)
    Write-Host ("{0,-40}: {1}" -f 'ResourceGroups', ($Global:AVDConfig.ResourceGroups.Values -join ', '))
    if ($Global:AVDConfig.Tags -and $Global:AVDConfig.Tags.Count -gt 0) {
        $tagStr = ($Global:AVDConfig.Tags.GetEnumerator() |
            ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '
        Write-Host ("{0,-40}: {1}" -f 'Tags', $tagStr)
    }
    Write-Host ('-' * 60) -ForegroundColor DarkGray

    $confirm = Read-Host "`nProceed with deployment? (Y/N)"
    if ($confirm -notmatch '^[Yy]') { Write-Host 'Deployment cancelled.' -ForegroundColor Yellow; return }

    $location = $Global:AVDConfig.Region
    $tags     = if ($Global:AVDConfig.Tags) { $Global:AVDConfig.Tags } else { @{} }
    $targetRG = if ($Global:AVDConfig.ResourceGroups.ContainsKey('Unified')) {
        $Global:AVDConfig.ResourceGroups['Unified']
    }
    else { $Global:AVDConfig.ResourceGroups['Management'] }

    # -------------------------------------------------------------------------
    # Step 1 — Resource Groups
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 1/12] Resource Groups" -ForegroundColor Cyan
    $rgList = if ($Global:AVDConfig.ResourceGroups.ContainsKey('Unified')) {
        @($Global:AVDConfig.ResourceGroups['Unified'])
    }
    else { @($Global:AVDConfig.ResourceGroups.Values) }
    foreach ($rgName in $rgList) {
        $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
        if (-not $rg) {
            New-AzResourceGroup -Name $rgName -Location $location -Tag $tags -Force | Out-Null
            Write-Host "  Created: $rgName" -ForegroundColor Green
        }
        else { Write-Host "  Already exists: $rgName" -ForegroundColor Yellow }
    }

    # -------------------------------------------------------------------------
    # Step 2 — Key Vault
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 2/12] Key Vault" -ForegroundColor Cyan
    $kv = $null
    if (-not $Global:AVDConfig.KeyVaultSkip -and $Global:AVDConfig.KeyVault) {
        $kvName = $Global:AVDConfig.KeyVault
        $kv     = Get-AzKeyVault -VaultName $kvName -ResourceGroupName $targetRG -ErrorAction SilentlyContinue
        if (-not $kv -and $Global:AVDConfig.KeyVaultIsNew) {
            try {
                $kv = New-AzKeyVault -VaultName $kvName -ResourceGroupName $targetRG `
                    -Location $location -EnabledForDeployment `
                    -EnabledForTemplateDeployment -Tag $tags -ErrorAction Stop
                Write-Host "  Key Vault created: $kvName" -ForegroundColor Green
                if ($Global:AVDConfig.DomainJoin) {
                    Set-AzKeyVaultSecret -VaultName $kvName -Name 'DomainJoinUsername' `
                        -SecretValue (ConvertTo-SecureString $Global:AVDConfig.DomainJoin.Username `
                            -AsPlainText -Force) | Out-Null
                    Set-AzKeyVaultSecret -VaultName $kvName -Name 'DomainJoinPassword' `
                        -SecretValue $Global:AVDConfig.DomainJoin.Password | Out-Null
                    Write-Host '  Domain join credentials stored.' -ForegroundColor Green
                }
                if ($Global:AVDConfig.LocalAdmin) {
                    Set-AzKeyVaultSecret -VaultName $kvName -Name 'LocalAdminUsername' `
                        -SecretValue (ConvertTo-SecureString $Global:AVDConfig.LocalAdmin.Username `
                            -AsPlainText -Force) | Out-Null
                    Set-AzKeyVaultSecret -VaultName $kvName -Name 'LocalAdminPassword' `
                        -SecretValue $Global:AVDConfig.LocalAdmin.Password | Out-Null
                    Write-Host '  Local admin credentials stored.' -ForegroundColor Green
                }
            }
            catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red }
        }
        elseif ($kv) { Write-Host "  Already exists: $kvName" -ForegroundColor Yellow }
    }
    else { Write-Host '  Key Vault skipped.' -ForegroundColor Gray }

    # -------------------------------------------------------------------------
    # Step 3 — NSG
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 3/12] Network Security Group" -ForegroundColor Cyan
    $nsg = $null
    if (-not $Global:AVDConfig.NSGSkip -and $Global:AVDConfig.NSG) {
        $nsgName = $Global:AVDConfig.NSG
        $nsg     = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $targetRG `
            -ErrorAction SilentlyContinue
        if (-not $nsg -and $Global:AVDConfig.NSGIsNew) {
            try {
                $rdpR   = New-AzNetworkSecurityRuleConfig -Name 'Allow-RDP-Inbound' `
                    -Protocol Tcp -Direction Inbound -Priority 300 `
                    -SourceAddressPrefix 'VirtualNetwork' -SourcePortRange '*' `
                    -DestinationAddressPrefix '*' -DestinationPortRange '3389' -Access Allow
                $httpsR = New-AzNetworkSecurityRuleConfig -Name 'Allow-HTTPS-Outbound' `
                    -Protocol Tcp -Direction Outbound -Priority 300 `
                    -SourceAddressPrefix '*' -SourcePortRange '*' `
                    -DestinationAddressPrefix 'AzureCloud' -DestinationPortRange '443' -Access Allow
                $nsg    = New-AzNetworkSecurityGroup -Name $nsgName `
                    -ResourceGroupName $targetRG -Location $location `
                    -SecurityRules @($rdpR, $httpsR) -Tag $tags -ErrorAction Stop
                Write-Host "  NSG created: $nsgName" -ForegroundColor Green
            }
            catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red }
        }
        elseif ($nsg) { Write-Host "  Already exists: $nsgName" -ForegroundColor Yellow }
    }
    else { Write-Host '  NSG skipped.' -ForegroundColor Gray }

    # -------------------------------------------------------------------------
    # Step 4 — VNet + Subnets
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 4/12] Virtual Network and Subnets" -ForegroundColor Cyan
    $vnetName      = $Global:AVDConfig.VNetName
    $vnetAddress   = $Global:AVDConfig.VNetAddress
    $subnetName    = $Global:AVDConfig.SubnetName
    $subnetAddress = $Global:AVDConfig.SubnetAddress

    [string[]]$dnsServers = if (-not [string]::IsNullOrWhiteSpace($Global:AVDConfig.DNS)) {
        @($Global:AVDConfig.DNS -split '\s*,\s*' | Where-Object { $_ -ne '' })
    }
    else { @() }

    $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $targetRG -ErrorAction SilentlyContinue
    if (-not $vnet) {
        $vp = @{
            Name              = $vnetName
            ResourceGroupName = $targetRG
            Location          = $location
            AddressPrefix     = $vnetAddress
            Tag               = $tags
        }
        if ($dnsServers -and $dnsServers.Count -gt 0) { $vp.DnsServer = $dnsServers }
        $vnet = New-AzVirtualNetwork @vp
        Write-Host "  VNet created: $vnetName" -ForegroundColor Green
    }
    else { Write-Host "  VNet already exists: $vnetName" -ForegroundColor Yellow }

    $subnet = $vnet | Get-AzVirtualNetworkSubnetConfig -Name $subnetName -ErrorAction SilentlyContinue
    if (-not $subnet) {
        $scfg = @{ Name = $subnetName; AddressPrefix = $subnetAddress; VirtualNetwork = $vnet }
        if ($nsg) { $scfg.NetworkSecurityGroup = $nsg }
        Add-AzVirtualNetworkSubnetConfig @scfg | Out-Null
        $vnet | Set-AzVirtualNetwork | Out-Null
        Write-Host "  Subnet created: $subnetName" -ForegroundColor Green
    }
    else { Write-Host "  Subnet already exists: $subnetName" -ForegroundColor Yellow }

    if (-not $Global:AVDConfig.PrivateEndpointSubnetSkip -and
        $Global:AVDConfig.PrivateEndpointSubnetIsNew -and
        $Global:AVDConfig.PrivateEndpointSubnet) {
        $vnet  = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $targetRG
        $peSub = $vnet | Get-AzVirtualNetworkSubnetConfig `
            -Name $Global:AVDConfig.PrivateEndpointSubnet -ErrorAction SilentlyContinue
        if (-not $peSub) {
            Add-AzVirtualNetworkSubnetConfig -Name $Global:AVDConfig.PrivateEndpointSubnet `
                -AddressPrefix $Global:AVDConfig.PrivateEndpointSubnetAddress `
                -VirtualNetwork $vnet | Out-Null
            $vnet | Set-AzVirtualNetwork | Out-Null
            Write-Host "  PE Subnet created: $($Global:AVDConfig.PrivateEndpointSubnet)" -ForegroundColor Green
        }
        else { Write-Host '  PE Subnet already exists.' -ForegroundColor Yellow }
    }
    elseif ($Global:AVDConfig.PrivateEndpointSubnetSkip) {
        Write-Host '  PE Subnet skipped.' -ForegroundColor Gray
    }

    $vnet   = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $targetRG
    $subnet = $vnet | Get-AzVirtualNetworkSubnetConfig -Name $subnetName

    # -------------------------------------------------------------------------
    # Step 5 — Hub VNet Peering
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 5/12] Hub VNet Peering" -ForegroundColor Cyan
    if (-not $Global:AVDConfig.HubVNetPeeringSkip -and
        $Global:AVDConfig.HubVNetPeering -and
        $Global:AVDConfig.HubVNetId) {
        $existPeer = Get-AzVirtualNetworkPeering -VirtualNetworkName $vnetName `
            -ResourceGroupName $targetRG -Name $Global:AVDConfig.HubVNetPeering `
            -ErrorAction SilentlyContinue
        if (-not $existPeer) {
            try {
                $useGW = $Global:AVDConfig.PeeringGatewayOnHub -match '^[Yy]'
                Add-AzVirtualNetworkPeering -Name $Global:AVDConfig.HubVNetPeering `
                    -VirtualNetwork $vnet -RemoteVirtualNetworkId $Global:AVDConfig.HubVNetId `
                    -AllowForwardedTraffic -UseRemoteGateways:$useGW -ErrorAction Stop | Out-Null
                Write-Host "  Peering created: $($Global:AVDConfig.HubVNetPeering)" -ForegroundColor Green
            }
            catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red }
        }
        else { Write-Host '  Peering already exists.' -ForegroundColor Yellow }
    }
    else { Write-Host '  Hub VNet Peering skipped.' -ForegroundColor Gray }

    # -------------------------------------------------------------------------
    # Step 6 — Private DNS Zone
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 6/12] Private DNS Zone" -ForegroundColor Cyan
    if (-not $Global:AVDConfig.PrivateDNSZoneSkip -and $Global:AVDConfig.PrivateDNSZone) {
        $dnsZ = Get-AzPrivateDnsZone -ResourceGroupName $targetRG `
            -Name $Global:AVDConfig.PrivateDNSZone -ErrorAction SilentlyContinue
        if (-not $dnsZ -and $Global:AVDConfig.PrivateDNSZoneIsNew) {
            try {
                $dnsZ = New-AzPrivateDnsZone -ResourceGroupName $targetRG `
                    -Name $Global:AVDConfig.PrivateDNSZone -Tag $tags -ErrorAction Stop
                New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $targetRG `
                    -ZoneName $Global:AVDConfig.PrivateDNSZone `
                    -Name "$vnetName-link" -VirtualNetworkId $vnet.Id `
                    -EnableRegistration:$false -Tag $tags | Out-Null
                Write-Host "  DNS Zone created and linked: $($Global:AVDConfig.PrivateDNSZone)" -ForegroundColor Green
            }
            catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red }
        }
        elseif ($dnsZ) { Write-Host '  DNS Zone already exists.' -ForegroundColor Yellow }
    }
    else { Write-Host '  Private DNS Zone skipped.' -ForegroundColor Gray }

    # -------------------------------------------------------------------------
    # Step 7 — Storage Account + FSLogix File Share
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 7/12] Storage Account and FSLogix File Share" -ForegroundColor Cyan
    $storageRG = if ($Global:AVDConfig.ResourceGroups.ContainsKey('Unified')) {
        $Global:AVDConfig.ResourceGroups['Unified']
    }
    else { $Global:AVDConfig.ResourceGroups['Storage'] }

    $sa     = $null
    $saName = $Global:AVDConfig.StorageAccountName
    if ($saName -and $Global:AVDConfig.FSLogixType -ne 'None') {
        $sa = Get-AzStorageAccount -ResourceGroupName $storageRG -Name $saName -ErrorAction SilentlyContinue
        if (-not $sa -and $Global:AVDConfig.StorageAccountIsNew) {
            try {
                $prevWP = $WarningPreference; $WarningPreference = 'SilentlyContinue'
                $sa = New-AzStorageAccount -ResourceGroupName $storageRG -Name $saName `
                    -Location $location -SkuName $Global:AVDConfig.StorageRedundancy `
                    -Kind 'StorageV2' -EnableLargeFileShare `
                    -MinimumTlsVersion 'TLS1_2' -AllowBlobPublicAccess $false `
                    -Tag $tags -ErrorAction Stop
                $WarningPreference = $prevWP
                Write-Host "  Storage Account created: $saName ($($Global:AVDConfig.StorageRedundancyFriendly))" -ForegroundColor Green
            }
            catch {
                $WarningPreference = $prevWP
                Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        elseif ($sa) { Write-Host "  Storage Account already exists: $saName" -ForegroundColor Yellow }

        if ($sa) {
            $shareName = $Global:AVDConfig.FSLogixShare
            if ($shareName) {
                $saCtx      = $sa.Context
                $existShare = Get-AzStorageShare -Name $shareName -Context $saCtx -ErrorAction SilentlyContinue
                if (-not $existShare -and $Global:AVDConfig.FSLogixShareIsNew) {
                    try {
                        New-AzStorageShare -Name $shareName -Context $saCtx -ErrorAction Stop | Out-Null
                        Set-AzStorageShareQuota -ShareName $shareName `
                            -Quota $Global:AVDConfig.FSLogixShareQuotaGB -Context $saCtx | Out-Null
                        Write-Host "  File Share created: $shareName ($($Global:AVDConfig.FSLogixShareQuotaGB) GB)" -ForegroundColor Green
                    }
                    catch { Write-Host "  Failed to create share: $($_.Exception.Message)" -ForegroundColor Red }
                }
                elseif ($existShare) { Write-Host "  File Share already exists: $shareName" -ForegroundColor Yellow }

                try {
                    $subId   = (Get-AzContext).Subscription.Id
                    $saScope = "/subscriptions/$subId/resourceGroups/$storageRG/providers/Microsoft.Storage/storageAccounts/$saName/fileServices/default/fileshares/$shareName"
                    $spnObj  = Get-AzADServicePrincipal -ApplicationId $Global:AVDConfig.EnterpriseAppId `
                        -ErrorAction SilentlyContinue
                    if ($spnObj) {
                        $existingSARole = Get-AzRoleAssignment -ObjectId $spnObj.Id `
                            -RoleDefinitionName 'Storage File Data SMB Share Contributor' `
                            -Scope $saScope -ErrorAction SilentlyContinue
                        if (-not $existingSARole) {
                            New-AzRoleAssignment -ObjectId $spnObj.Id `
                                -RoleDefinitionName 'Storage File Data SMB Share Contributor' `
                                -Scope $saScope -ErrorAction Stop | Out-Null
                            Write-Host '  RBAC: Storage File Data SMB Share Contributor assigned.' -ForegroundColor Green
                        }
                        else {
                            Write-Host '  RBAC: Storage File Data SMB Share Contributor already assigned.' -ForegroundColor Yellow
                        }
                    }
                }
                catch { Write-Host "  Note: RBAC: $($_.Exception.Message)" -ForegroundColor Yellow }

                if ($Global:AVDConfig.IdentityProvider -in @('ADDS', 'EntraDS')) {
                    try {
                        Update-AzStorageFileServiceProperty -ResourceGroupName $storageRG `
                            -StorageAccountName $saName -EnableSmbMultichannel $true | Out-Null
                        Write-Host '  SMB Multichannel enabled.' -ForegroundColor Green
                        Write-Host '  NOTE: Complete AD Kerberos setup via AzFilesHybrid module.' -ForegroundColor Yellow
                    }
                    catch { Write-Host "  Note: SMB config: $($_.Exception.Message)" -ForegroundColor Yellow }
                }
            }
        }
    }
    else { Write-Host '  Storage/FSLogix skipped (type is None).' -ForegroundColor Gray }

    # -------------------------------------------------------------------------
    # Step 8 — Log Analytics Workspace
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 8/12] Log Analytics Workspace" -ForegroundColor Cyan
    $monRG   = if ($Global:AVDConfig.ResourceGroups.ContainsKey('Unified')) {
        $Global:AVDConfig.ResourceGroups['Unified']
    }
    else { $Global:AVDConfig.ResourceGroups['Monitoring'] }
    $lawName = $Global:AVDConfig.LogAnalyticsWorkspace
    $law     = $null
    if (-not $Global:AVDConfig.LogAnalyticsWorkspaceSkip -and
        $lawName -and
        $Global:AVDConfig.EnableLogAnalytics -match '^[Yy]') {
        $law = Get-AzOperationalInsightsWorkspace -ResourceGroupName $monRG `
            -Name $lawName -ErrorAction SilentlyContinue
        if (-not $law -and $Global:AVDConfig.LogAnalyticsWorkspaceIsNew) {
            try {
                $law = New-AzOperationalInsightsWorkspace -ResourceGroupName $monRG `
                    -Name $lawName -Location $location -Sku 'PerGB2018' `
                    -Tag $tags -ErrorAction Stop
                Write-Host "  Log Analytics Workspace created: $lawName" -ForegroundColor Green
            }
            catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red }
        }
        elseif ($law) { Write-Host "  Already exists: $lawName" -ForegroundColor Yellow }
    }
    else { Write-Host '  Log Analytics Workspace skipped.' -ForegroundColor Gray }

    # -------------------------------------------------------------------------
    # Step 9 — Host Pool
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 9/12] AVD Host Pool" -ForegroundColor Cyan
    $hpName  = "$($Global:AVDConfig.Prefix)-hp"
    $hpTypes = @('Pooled', 'Personal')
    for ($i = 0; $i -lt $hpTypes.Count; $i++) { Write-Host "[$($i+1)] $($hpTypes[$i])" }
    $tIdx = 0
    do {
        $ts  = Read-Host "Select Host Pool Type (1-$($hpTypes.Count)) [Default: 1]"
        if ([string]::IsNullOrWhiteSpace($ts)) { $ts = '1' }
        $tok = $ts -match '^[0-9]+$' -and [int]::TryParse($ts, [ref]$tIdx) -and
               $tIdx -ge 1 -and $tIdx -le $hpTypes.Count
        if (-not $tok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($tok)
    $hpType = $hpTypes[$tIdx - 1]

    $lbTypes = @('BreadthFirst', 'DepthFirst', 'Persistent')
    for ($i = 0; $i -lt $lbTypes.Count; $i++) { Write-Host "[$($i+1)] $($lbTypes[$i])" }
    $lIdx = 0
    do {
        $ls  = Read-Host "Select Load Balancer Type (1-$($lbTypes.Count)) [Default: 1]"
        if ([string]::IsNullOrWhiteSpace($ls)) { $ls = '1' }
        $lok = $ls -match '^[0-9]+$' -and [int]::TryParse($ls, [ref]$lIdx) -and
               $lIdx -ge 1 -and $lIdx -le $lbTypes.Count
        if (-not $lok) { Write-Host 'Invalid, try again.' -ForegroundColor Yellow }
    } until ($lok)
    $lbType = $lbTypes[$lIdx - 1]

    $maxS = 16
    $mi   = Read-Host 'Max Session Limit [Default: 16]'
    if (-not [string]::IsNullOrWhiteSpace($mi)) {
        $mp = 0
        if ([int]::TryParse($mi, [ref]$mp) -and $mp -gt 0) { $maxS = $mp }
        else { Write-Host 'Invalid, using 16.' -ForegroundColor Yellow }
    }

    $hp = Get-AzWvdHostPool -ResourceGroupName $targetRG -Name $hpName -ErrorAction SilentlyContinue
    if (-not $hp) {
        try {
            $hp = New-AzWvdHostPool -ResourceGroupName $targetRG -Name $hpName `
                -Location $location -HostPoolType $hpType -LoadBalancerType $lbType `
                -MaxSessionLimit $maxS -PreferredAppGroupType 'Desktop' `
                -FriendlyName $hpName -Description 'Created by AVD Accelerator' `
                -CustomRdpProperty 'audiocapturemode:i:1;videoplaybackmode:i:1;' -ErrorAction Stop
            Write-Host "  Host Pool created: $hpName" -ForegroundColor Green
        }
        catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red; return }
    }
    else { Write-Host "  Already exists: $hpName" -ForegroundColor Yellow }
    if (-not $hp) { Write-Host 'Host Pool is null. Cannot continue.' -ForegroundColor Red; return }
    $hpId = $hp.Id

    if ($Global:AVDConfig.AssignStartVMRole) {
        $subId = (Get-AzContext).Subscription.Id
        Set-StartVMOnConnectRBAC -EnterpriseAppId $Global:AVDConfig.EnterpriseAppId `
            -SubscriptionId $subId
    }

    # -------------------------------------------------------------------------
    # Step 10 — Workspace + App Group
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 10/12] Workspace and Application Group" -ForegroundColor Cyan
    $wsName = "$($Global:AVDConfig.Prefix)-workspace"
    $ws     = Get-AzWvdWorkspace -ResourceGroupName $targetRG -Name $wsName -ErrorAction SilentlyContinue
    if (-not $ws) {
        try {
            $ws = New-AzWvdWorkspace -ResourceGroupName $targetRG -Name $wsName `
                -Location $location -FriendlyName $wsName `
                -Description "Workspace for $hpName" -ErrorAction Stop
            Write-Host "  Workspace created: $wsName" -ForegroundColor Green
        }
        catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red }
    }
    else { Write-Host "  Already exists: $wsName" -ForegroundColor Yellow }

    $agName = "$($Global:AVDConfig.Prefix)-appgroup"
    $agType = $Global:AVDConfig.PreferredAppGroupType
    $ag     = Get-AzWvdApplicationGroup -ResourceGroupName $targetRG -Name $agName -ErrorAction SilentlyContinue
    if (-not $ag) {
        try {
            $ag = New-AzWvdApplicationGroup -ResourceGroupName $targetRG -Name $agName `
                -Location $location -HostPoolArmPath $hpId `
                -ApplicationGroupType $agType -FriendlyName $agName `
                -Description "App Group for $hpName" -ErrorAction Stop
            Write-Host "  App Group created: $agName ($agType)" -ForegroundColor Green
        }
        catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red }
    }
    else { Write-Host "  Already exists: $agName" -ForegroundColor Yellow }

    if ($ws -and $ag) {
        try {
            Update-AzWvdWorkspace -ResourceGroupName $targetRG -Name $wsName `
                -ApplicationGroupReference @($ag.Id) -ErrorAction Stop | Out-Null
            Write-Host '  App Group registered with Workspace.' -ForegroundColor Green
        }
        catch { Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red }
    }

    # -------------------------------------------------------------------------
    # Step 11 — Scaling Plan
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 11/12] Scaling Plan" -ForegroundColor Cyan
    if ($Global:AVDConfig.EnableScalingPlan -match '^[Yy]' -and
        -not $Global:AVDConfig.ScalingPlanSkip -and
        $Global:AVDConfig.ScalingPlanName) {
        $spName   = $Global:AVDConfig.ScalingPlanName
        $existsSP = Get-AzWvdScalingPlan -ResourceGroupName $targetRG `
            -Name $spName -ErrorAction SilentlyContinue
        if (-not $existsSP -and $Global:AVDConfig.ScalingPlanIsNew) {
            New-AVDScalingPlan -ResourceGroupName $targetRG -Name $spName `
                -Location $location -HostPoolType $hpType -HostPoolArmPath $hpId
        }
        elseif ($existsSP) { Write-Host "  Already exists: $spName" -ForegroundColor Yellow }
    }
    else { Write-Host '  Scaling Plan skipped.' -ForegroundColor Gray }

    # -------------------------------------------------------------------------
    # Step 12 — Session Hosts
    # -------------------------------------------------------------------------
    Write-Host "`n[Step 12/12] Session Hosts" -ForegroundColor Cyan

    $fslogixUNC = $null
    if ($saName -and $Global:AVDConfig.FSLogixShare -and $Global:AVDConfig.FSLogixType -ne 'None') {
        $fslogixUNC = "\\$saName.file.core.windows.net\$($Global:AVDConfig.FSLogixShare)"
        Write-Host "  FSLogix UNC: $fslogixUNC" -ForegroundColor Cyan
    }

    $deployedCount = Deploy-AVDSessionHosts `
        -ResourceGroupName $targetRG `
        -Location          $location `
        -HostPoolName      $hpName `
        -SubnetId          $subnet.Id `
        -MonitoringRG      $monRG `
        -LawName           $(if ($lawName) { $lawName } else { '' }) `
        -Law               $law `
        -FslogixUNC        $fslogixUNC

    $hCount = [int]$Global:AVDConfig.SessionHostCount
    $Global:AVDConfig['ReviewCreateCompleted'] = $true

    Write-Host "`n========================================"  -ForegroundColor Green
    Write-Host ' Deployment Complete!'                       -ForegroundColor Green
    Write-Host '========================================'    -ForegroundColor Green
    Write-Host " Host Pool    : $hpName"                    -ForegroundColor Cyan
    Write-Host " Workspace    : $wsName"                    -ForegroundColor Cyan
    Write-Host " App Group    : $agName ($agType)"          -ForegroundColor Cyan
    $countColor = if ($deployedCount -eq $hCount) { 'Green' } else { 'Yellow' }
    Write-Host " Session Hosts: $deployedCount of $hCount deployed" -ForegroundColor $countColor
    if ($deployedCount -lt $hCount) {
        Write-Host "  WARNING: $($hCount - $deployedCount) session host(s) failed to deploy." -ForegroundColor Red
        Write-Host "  Check quota at: https://aka.ms/ProdportalCRP" -ForegroundColor Yellow
    }
    if ($fslogixUNC) { Write-Host " FSLogix UNC  : $fslogixUNC"                  -ForegroundColor Cyan }
    if ($law)        { Write-Host " Log Analytics: $lawName"                      -ForegroundColor Cyan }
    if ($kv)         { Write-Host " Key Vault    : $($Global:AVDConfig.KeyVault)" -ForegroundColor Cyan }
    Write-Host '[Section complete: Review + create]' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Main Wizard
# ---------------------------------------------------------------------------
function Start-AVDAcceleratorWizard {
    $Global:AVDConfig        = @{}
    $Global:AVDSkuCache      = @{}
    $Global:AVDQuotaCache    = @{}
    $Global:AVDLocationCache = $null

    Initialize-RequiredModules

    $authMethod  = Select-AuthenticationMethod
    $authSuccess = Invoke-AzureAuthentication -AuthMethod $authMethod
    if (-not $authSuccess) {
        Write-Host 'Authentication failed. Exiting.' -ForegroundColor Red
        return
    }

    $continue = $true
    while ($continue) {
        $choice = Show-AVDMainMenu
        switch ($choice) {
            1  { Set-AVDDeploymentBasics }
            2  { Set-AVDIdentity }
            3  { Set-AVDManagementPlane }
            4  { Set-AVDSessionHosts }
            5  { Set-AVDStorage }
            6  { Set-AVDNetworking }
            7  { Set-AVDMonitoring }
            8  { Set-AVDResourceNaming }
            9  { Set-AVDResourceTagging }
            10 { Invoke-AVDReviewAndCreate }
            0  { $continue = $false }
        }
    }
    Write-Host 'Exiting AVD Accelerator Wizard.' -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -and ($MyInvocation.MyCommand.Path -eq $PSCommandPath)) {
    Start-AVDAcceleratorWizard
}