<# 
.SYNOPSIS
    Automates rolling replacement of Azure Virtual Desktop session hosts with drain-wait-remove-replace workflow from Azure Compute Gallery images.

.DESCRIPTION
    Performs controlled rolling replacement of AVD session hosts by implementing a comprehensive drain-wait-remove-replace workflow. 
    The script manages session host lifecycle by draining existing hosts (disabling new sessions), waiting for active sessions 
    to complete naturally, removing drained hosts and their Azure resources, then creating new session hosts from Azure Compute 
    Gallery images with automated domain join and AVD agent configuration.

    CORE FUNCTIONALITY:
    - Drains existing session hosts by disabling new session allocation
    - Monitors and waits for active user sessions to complete gracefully  
    - Removes drained session hosts from AVD and deletes associated Azure resources (VM, NIC, disks, public IPs)
    - Creates new session hosts from specified Azure Compute Gallery image version
    - Configures domain join (Active Directory Domain Services or Entra ID)
    - Installs and registers AVD agent with host pool registration token
    - Supports batch processing for controlled capacity management

    REPLACEMENT STRATEGIES:
    - Standard Mode: Drain -> Wait -> Remove -> Replace (maintains reduced capacity during replacement)
    - Pre-Add Capacity Mode: Add -> Drain -> Wait -> Remove (maintains full capacity throughout process)
    - Configurable batch sizes for processing multiple hosts per wave
    - Dry run mode for validation and testing without destructive operations

    RESOURCE MANAGEMENT:
    - Comprehensive cleanup of all VM-associated resources (NICs, managed disks, public IPs)
    - Automatic registration token generation with configurable expiry
    - Support for custom VM sizing and disk configurations
    - Network integration with existing VNet/subnet infrastructure

    DOMAIN JOIN OPTIONS:
    - Active Directory Domain Services (ADDS): Traditional domain join with OU placement
    - Entra ID (Azure AD): Cloud-native identity with optional AAD Login extension
    - Automated credential handling and secure password management

.PARAMETER SubscriptionId
    Azure subscription ID containing the AVD environment and target resources.

.PARAMETER HostPoolName
    Name of the existing AVD host pool containing session hosts to replace.

.PARAMETER HostPoolRG
    Resource group name containing the AVD host pool.

.PARAMETER Location
    Azure region where new session host VMs will be created (e.g., "eastus", "westus2").

.PARAMETER SessionHostPrefix
    Naming prefix for new session host VMs (e.g., "avd-sh-prod-", "avd-host-").

.PARAMETER TargetVmRG
    Resource group where new session host VMs and associated resources will be created.

.PARAMETER VnetName
    Virtual network name for new session host network interfaces.

.PARAMETER SubnetName
    Subnet name within the VNet where new session hosts will be placed.

.PARAMETER GalleryImageId
    Full Azure resource ID of the Azure Compute Gallery image version (not image definition).
    Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{gallery}/images/{image}/versions/{version}

.PARAMETER NewHostCount
    Number of new session hosts to create during each replacement batch.

.PARAMETER BatchSize
    Number of existing session hosts to drain and remove per replacement wave.

.PARAMETER PreAddCapacity
    Switch to create new hosts before draining old ones, maintaining full capacity during replacement.

.PARAMETER DryRun
    Switch to perform validation and planning without executing destructive operations.

.PARAMETER VmSize
    Azure VM SKU for new session hosts (e.g., "Standard_D4s_v5", "Standard_D8s_v5").

.PARAMETER OsDiskSizeGB
    Operating system disk size in gigabytes for new VMs (default: 128).

.PARAMETER OsDiskSku
    Managed disk storage type for OS disks (default: "Premium_LRS"). Options: Standard_LRS, Premium_LRS, StandardSSD_LRS.

.PARAMETER JoinMethod
    Domain join method for new session hosts. Options: "ADDS" (Active Directory Domain Services) or "EntraID" (Azure AD).

.PARAMETER DomainName
    Active Directory domain name (required when JoinMethod is "ADDS").

.PARAMETER DomainJoinUser
    Domain administrator user principal name for AD join (required when JoinMethod is "ADDS").

.PARAMETER DomainJoinPassword
    Secure string containing domain join credentials (required when JoinMethod is "ADDS").

.PARAMETER OuPath
    Optional organizational unit path for AD domain join (e.g., "OU=AVDHosts,OU=Computers,DC=contoso,DC=com").

.PARAMETER EnableAadLoginExtension
    Switch to install Azure AD Login extension for Entra ID joined VMs.

.PARAMETER AvdAgentBootstrapUrl
    URL to PowerShell script that installs AVD agent, registers with host pool, and configures FSLogix.

.PARAMETER RegistrationTokenExpiryHours
    Host pool registration token validity period in hours (default: "12").

.EXAMPLE
    .\23_AVD_SessionHosts_Replacer.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -HostPoolName "hp-avd-prod" -HostPoolRG "rg-avd-hostpool" -Location "eastus" -SessionHostPrefix "avd-sh-prod-" -TargetVmRG "rg-avd-sessionhosts" -VnetName "vnet-avd-prod" -SubnetName "subnet-sessionhosts" -GalleryImageId "/subscriptions/12345/resourceGroups/rg-images/providers/Microsoft.Compute/galleries/gal_avd/images/win11-avd/versions/1.0.0" -NewHostCount 2 -BatchSize 1 -VmSize "Standard_D4s_v5" -JoinMethod "ADDS" -DomainName "contoso.com" -DomainJoinUser "admin@contoso.com" -DomainJoinPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) -AvdAgentBootstrapUrl "https://mystorageaccount.blob.core.windows.net/scripts/avd-bootstrap.ps1"

    Performs standard rolling replacement with AD DS domain join, replacing 1 host at a time with 2 new hosts.

.EXAMPLE  
    .\23_AVD_SessionHosts_Replacer.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -HostPoolName "hp-avd-dev" -HostPoolRG "rg-avd-dev" -Location "westus2" -SessionHostPrefix "avd-dev-" -TargetVmRG "rg-avd-dev-vms" -VnetName "vnet-avd-dev" -SubnetName "subnet-hosts" -GalleryImageId "/subscriptions/12345/resourceGroups/rg-images/providers/Microsoft.Compute/galleries/gal_avd/images/win11-avd/versions/2.0.0" -NewHostCount 1 -BatchSize 2 -VmSize "Standard_D2s_v5" -JoinMethod "EntraID" -EnableAadLoginExtension -AvdAgentBootstrapUrl "https://github.com/company/avd-scripts/raw/main/bootstrap.ps1" -PreAddCapacity -DryRun

    Dry run of Entra ID joined replacement with pre-add capacity mode, processing 2 old hosts per batch.

.NOTES
    File Name: 23_AVD_SessionHosts_Replacer.ps1
    Author: edthefixer + GitHub Copilot... well, I fell asleep, copilot finished it...  
    Version: 1.0.0
    Prerequisite: Az.Accounts, Az.DesktopVirtualization, Az.Compute, Az.Network, Az.Resources modules
    RBAC: Contributor role on resource groups containing host pool and session host VMs
    Creation Date: 2025-12-30
    Last Updated: 2025-12-30

.LINK
    https://docs.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-powershell
    https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries

.REQUIREMENTS
    Az.Accounts, Az.DesktopVirtualization, Az.Compute, Az.Network, Az.Resources
    RBAC: Contributor on RGs holding Host Pool and VM resources  
    Image: Azure Compute Gallery image version, sysprep'd, AVD-safe
#>

param(
    [Parameter(Mandatory)]
    [string] $SubscriptionId,

    [Parameter(Mandatory)]
    [string] $HostPoolName,

    [Parameter(Mandatory)]
    [string] $HostPoolRG,

    [Parameter(Mandatory)]
    [string] $Location,                       # e.g., "eastus"

    [Parameter(Mandatory)]
    [string] $SessionHostPrefix,              # e.g., "avd-sh-"

    [Parameter(Mandatory)]
    [string] $TargetVmRG,                     # RG where new VMs will be created

    [Parameter(Mandatory)]
    [string] $VnetName,

    [Parameter(Mandatory)]
    [string] $SubnetName,

    [Parameter(Mandatory)]
    [string] $GalleryImageId,                 # Full resourceId of the ACG image version (NOT the definition)

    [Parameter(Mandatory)]
    [int] $NewHostCount,                      # Count to add in each replace batch

    [Parameter(Mandatory)]
    [int] $BatchSize,                         # How many existing hosts to drain/remove per wave

    [Parameter()]
    [switch] $PreAddCapacity,                 # If set, add new hosts BEFORE draining/removing old ones

    [Parameter()]
    [switch] $DryRun,                         # If set, no destructive actions occur

    # VM sizing
    [Parameter(Mandatory)]
    [string] $VmSize,                         # e.g., "Standard_D4s_v5"

    # OS disk
    [int] $OsDiskSizeGB = 128,
    [string] $OsDiskSku = "Premium_LRS",

    # Join method: choose AD DS OR Entra ID
    [Parameter()]
    [ValidateSet("ADDS", "EntraID")]
    [string] $JoinMethod = "ADDS",

    # AD DS join (if JoinMethod = ADDS)
    [string] $DomainName,
    [string] $DomainJoinUser,                 # UPN: user@domain
    [securestring] $DomainJoinPassword,
    [string] $OuPath,                         # Optional OU path (e.g., "OU=AVD,DC=contoso,DC=com")

    # Entra ID join (if JoinMethod = EntraID) - assumes extension and Intune auto-enrollment or later manual
    [switch] $EnableAadLoginExtension,

    # AVD Agent bootstrap
    [Parameter(Mandatory)]
    [string] $AvdAgentBootstrapUrl,           # Script URL or storage blob SAS that installs AVD agent, FSLogix, etc.

    [Parameter()]
    [string] $RegistrationTokenExpiryHours = "12" # token validity
)

# region Helpers
function Write-Info { param([string]$m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err { param([string]$m) Write-Host "[ERR ] $m" -ForegroundColor Red }
# endregion

# region Connect and context
Write-Info "Connecting to Azure and setting subscription..."
Connect-AzAccount -ErrorAction Stop | Out-Null
Select-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
# endregion

# region AVD: get host pool and session hosts
Write-Info "Fetching Host Pool [$HostPoolName] in RG [$HostPoolRG]..."
$hostPool = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $HostPoolRG -ErrorAction Stop

Write-Info "Fetching current Session Hosts..."
$sessionHosts = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $HostPoolRG -ErrorAction Stop
if (-not $sessionHosts) { Write-Warn "No session hosts found."; }
# endregion

# region Networking
Write-Info "Resolving VNet/Subnet..."
$vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $TargetVmRG -ErrorAction Stop
$subnet = $vnet.Subnets | Where-Object { $_.Name -eq $SubnetName }
if (-not $subnet) { throw "Subnet [$SubnetName] not found in VNet [$VnetName]."; }
# endregion

# region Registration Token
function New-HostPoolRegistrationToken {
    param(
        [Microsoft.Azure.Commands.DesktopVirtualization.Models.PSHostPool] $hp,
        [int] $ExpiryHours
    )
    Write-Info "Creating a new registration token valid for $ExpiryHours hour(s)..."
    if ($DryRun) { 
        Write-Warn "DryRun: Skipping token creation."
        return @{
            Token  = "<DRYRUN-TOKEN>"
            Expiry = (Get-Date).AddHours($ExpiryHours)
        }
    }
    $reg = New-AzWvdRegistrationInfo -HostPoolName $hp.Name -ResourceGroupName $hp.ResourceGroupName -ExpirationTime (Get-Date).AddHours($ExpiryHours).ToUniversalTime() -ErrorAction Stop
    return @{
        Token  = $reg.Token
        Expiry = $reg.ExpirationTime
    }
}
# endregion

# region Drain function
function Set-DrainMode {
    param(
        [Microsoft.Azure.Commands.DesktopVirtualization.Models.PSSessionHost[]] $Hosts,
        [int] $MaxToDrain
    )
    $targets = $Hosts | Sort-Object -Property Name | Select-Object -First $MaxToDrain
    foreach ($h in $targets) {
        Write-Info "Enabling Drain on [$($h.Name)] (AllowNewSession = false)..."
        if ($DryRun) { Write-Warn "DryRun: Skipping drain call."; continue }
        Update-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $HostPoolRG -Name $h.Name -AllowNewSession:$false -ErrorAction Stop | Out-Null
    }
    return $targets
}

function Wait-ForEmptyHosts {
    param([Microsoft.Azure.Commands.DesktopVirtualization.Models.PSSessionHost[]] $Hosts)
    foreach ($h in $Hosts) {
        Write-Info "Waiting for sessions to end on [$($h.Name)]..."
        do {
            Start-Sleep -Seconds 10
            $ref = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $HostPoolRG -Name $h.Name
            $active = $ref.SessionCount
            Write-Info "Host [$($h.Name)] active sessions: $active"
        } while ($active -gt 0)
        Write-Info "Host [$($h.Name)] is empty."
    }
}
# endregion

# region Remove function
function Remove-SessionHostsAndResources {
    param([Microsoft.Azure.Commands.DesktopVirtualization.Models.PSSessionHost[]] $HostsToRemove)

    foreach ($h in $HostsToRemove) {
        Write-Info "Processing removal for session host [$($h.Name)]..."
        # Session host name format: <hpResourceId>/sessionHosts/<vmName>.assumed FQDN part:
        $vmName = ($h.Name -split "/")[-1] -replace "\.default$", "" -replace "\.internal$", ""
        if (-not $vmName) { Write-Warn "Could not infer VM name from [$($h.Name)]. Skipping."; continue }

        # Remove AVD session host record
        Write-Info "Deleting AVD session host record for [$vmName]..."
        if (-not $DryRun) {
            Remove-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $HostPoolRG -Name $h.Name -Force -ErrorAction Continue
        }
        else { Write-Warn "DryRun: Skipping Remove-AzWvdSessionHost." }

        # Delete VM + NICs + disks
        Write-Info "Locating VM [$vmName] in RG [$TargetVmRG]..."
        $vm = Get-AzVM -Name $vmName -ResourceGroupName $TargetVmRG -ErrorAction SilentlyContinue
        if ($vm) {
            Write-Info "Deallocating VM [$vmName]..."
            if (-not $DryRun) { Stop-AzVM -Name $vmName -ResourceGroupName $TargetVmRG -Force -ErrorAction SilentlyContinue | Out-Null }

            Write-Info "Deleting VM [$vmName]..."
            if (-not $DryRun) { Remove-AzVM -Name $vmName -ResourceGroupName $TargetVmRG -Force -ErrorAction SilentlyContinue }

            # NICs
            foreach ($nicId in $vm.NetworkProfile.NetworkInterfaces.Id) {
                $nicName = ($nicId -split "/")[-1]
                Write-Info "Deleting NIC [$nicName]..."
                if (-not $DryRun) { Remove-AzNetworkInterface -Name $nicName -ResourceGroupName $TargetVmRG -Force -ErrorAction SilentlyContinue }
            }
            # OS Disk
            $osDiskId = $vm.StorageProfile.OSDisk.ManagedDisk.Id
            $osDiskName = ($osDiskId -split "/")[-1]
            Write-Info "Deleting OS disk [$osDiskName]..."
            if (-not $DryRun) { Remove-AzDisk -ResourceGroupName $TargetVmRG -DiskName $osDiskName -Force -ErrorAction SilentlyContinue }
            # Data disks
            foreach ($d in $vm.StorageProfile.DataDisks) {
                $dName = ($d.ManagedDisk.Id -split "/")[-1]
                Write-Info "Deleting data disk [$dName]..."
                if (-not $DryRun) { Remove-AzDisk -ResourceGroupName $TargetVmRG -DiskName $dName -Force -ErrorAction SilentlyContinue }
            }
            # Public IPs (if any)
            $nics = Get-AzNetworkInterface -ResourceGroupName $TargetVmRG | Where-Object { $_.VirtualMachine -and $_.VirtualMachine.Id -eq $vm.Id }
            foreach ($n in $nics) {
                foreach ($ipconfig in $n.IpConfigurations) {
                    if ($ipconfig.PublicIpAddress -and $ipconfig.PublicIpAddress.Id) {
                        $pipName = ($ipconfig.PublicIpAddress.Id -split "/")[-1]
                        Write-Info "Deleting Public IP [$pipName]..."
                        if (-not $DryRun) { Remove-AzPublicIpAddress -Name $pipName -ResourceGroupName $TargetVmRG -Force -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
        else {
            Write-Warn "VM [$vmName] not found in RG [$TargetVmRG]. Skipping Azure resource deletion."
        }
    }
}
# endregion

# region Replace/Add function
function New-AvdSessionHosts {
    param(
        [int] $Count,
        [string] $Prefix,
        [string] $Token,
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork] $Vnet,
        [object] $Subnet
    )

    $created = @()
    for ($i = 1; $i -le $Count; $i++) {
        $newName = "{0}{1:000}" -f $Prefix, (Get-Random -Minimum 100 -Maximum 999) # random suffix to avoid collisions
        Write-Info "Creating VM [$newName] from ACG image version..."

        if ($DryRun) { Write-Warn "DryRun: Skipping VM create for [$newName]."; continue }

        # Create NIC
        $nicName = "$newName-nic01"
        $nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $TargetVmRG -Location $Location -SubnetId $Subnet.Id -ErrorAction Stop

        # Build VM config
        $vmConfig = New-AzVMConfig -VMName $newName -VMSize $VmSize
        $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $newName -ProvisionVMAgent -EnableAutoUpdate
        $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
        $vmConfig = Set-AzVMSourceImage -VM $vmConfig -Id $GalleryImageId
        $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name "$newName-osdisk" -CreateOption FromImage -DiskSizeGB $OsDiskSizeGB -StorageAccountType $OsDiskSku

        # Domain Join or AAD Login extension
        if ($JoinMethod -eq "ADDS") {
            if (-not $DomainName -or -not $DomainJoinUser -or -not $DomainJoinPassword) {
                throw "AD DS join selected but DomainName/DomainJoinUser/DomainJoinPassword not provided."
            }
            $plainPw = (New-Object System.Net.NetworkCredential("", $DomainJoinPassword)).Password
            $joinCmd = @"
Add-Computer -DomainName '$DomainName' -Credential (New-Object System.Management.Automation.PSCredential('$DomainJoinUser',(ConvertTo-SecureString '$plainPw' -AsPlainText -Force))) -Force $(if('$OuPath'){ "-OUPath '$OuPath'"} )
Restart-Computer -Force
"@
            Write-Info "Configuring AD domain join extension for [$newName]..."
            $domainJoinExt = New-AzVMCustomScriptExtension -ResourceGroupName $TargetVmRG -VMName $newName -Location $Location `
                -Name "ad-join" -FileUri @() -Run "$joinCmd" -Force -ErrorAction Stop
            Write-Info "Domain join extension configured successfully for [$newName]. Status: $($domainJoinExt.ProvisioningState)"
            # NOTE: if you prefer official AD domain join extension, replace with Json extension for 'ADDomainExtension'
        }
        else {
            if ($EnableAadLoginExtension) {
                Set-AzVMExtension -ResourceGroupName $TargetVmRG -VMName $newName -Name "AADLoginForWindows" -Publisher "Microsoft.Azure.ActiveDirectory" `
                    -ExtensionType "AADLoginForWindows" -TypeHandlerVersion "1.0" -Location $Location -ErrorAction Stop | Out-Null
            }
        }

        # AVD Agent + Registration via Custom Script Extension
        # Your AvdAgentBootstrapUrl should point to a script that:
        #   - Downloads and installs AVD agent + side-by-side stack (latest)
        #   - Writes registration token to the expected path or runs msiexec with /regtoken=<token>
        #   - Installs FSLogix and configures base settings (optional)
        $bootstrapCmd = "powershell -ExecutionPolicy Bypass -File C:\Windows\Temp\avd-bootstrap.ps1 -RegistrationToken `"$Token`""
        Set-AzVMExtension -ResourceGroupName $TargetVmRG -VMName $newName -Name "avd-bootstrap" -Publisher "Microsoft.Compute" -ExtensionType "CustomScriptExtension" `
            -TypeHandlerVersion "1.10" -Location $Location -Settings @{ "fileUris" = @($AvdAgentBootstrapUrl) } -ProtectedSettings @{ "commandToExecute" = $bootstrapCmd } -ErrorAction Stop | Out-Null

        # Create VM
        New-AzVM -ResourceGroupName $TargetVmRG -Location $Location -VM $vmConfig -ErrorAction Stop | Out-Null

        $created += $newName
        Write-Info "VM [$newName] creation submitted."
    }
    return $created
}
# endregion

# region Orchestrator
Write-Info "Generating Host Pool registration token..."
$tokenInfo = New-HostPoolRegistrationToken -hp $hostPool -ExpiryHours ([int]$RegistrationTokenExpiryHours)
$regToken = $tokenInfo.Token
Write-Info "Token expires: $($tokenInfo.Expiry)"

if ($PreAddCapacity) {
    Write-Info "PreAddCapacity mode: creating $NewHostCount new hosts before draining/removing old ones..."
    $created = New-AvdSessionHosts -Count $NewHostCount -Prefix $SessionHostPrefix -Token $regToken -Vnet $vnet -Subnet $subnet
    Write-Info "Created hosts: $($created -join ", ")"
}

Write-Info "Starting drain of $BatchSize host(s)..."
$toDrain = Set-DrainMode -Hosts $sessionHosts -MaxToDrain $BatchSize

Write-Info "Waiting for drained hosts to become empty..."
Wait-ForEmptyHosts -Hosts $toDrain

Write-Info "Removing drained hosts and Azure resources..."
Remove-SessionHostsAndResources -HostsToRemove $toDrain

if (-not $PreAddCapacity) {
    Write-Info "Creating $NewHostCount replacement host(s)..."
    $created = New-AvdSessionHosts -Count $NewHostCount -Prefix $SessionHostPrefix -Token $regToken -Vnet $vnet -Subnet $subnet
    Write-Info "Created hosts: $($created -join ", ")"
}

Write-Info "Rolling replacement wave complete."
# endregion
