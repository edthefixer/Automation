# Requires: Az.Accounts, Az.Resources
# PowerShell 7.x compatible

# Ensure Az.Accounts and Az.Resources modules are available
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Host "Az.Accounts module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name Az.Accounts -Scope CurrentUser -Force
}
Import-Module Az.Accounts
Import-Module Az.Resources

Write-Host "Logging in to Azure..." -ForegroundColor Cyan
Connect-AzAccount -UseDeviceAuthentication

# 2. Find AVD-related resource groups (by name pattern)
Write-Host "Scanning for AVD-related resource groups..." -ForegroundColor Cyan

$avdRgPattern = '^rg-avd.*' # Regex for AVD resource groups
$resourceGroups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -match $avdRgPattern }

if (-not $resourceGroups) {
    Write-Host "No AVD-related resource groups found." -ForegroundColor Green
    return
}

# 3. Generate a list of resource groups that can be deleted
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = "AVD_Orphan_ResourceGroups_$timestamp.csv"
$resourceGroups | Select-Object ResourceGroupName, Location, Id | Export-Csv -Path $reportFile -NoTypeInformation

Write-Host "AVD-related resource groups report generated: $reportFile" -ForegroundColor Yellow

# 4. Review and prompt for deletion
Write-Host "The following AVD-related resource groups were found:" -ForegroundColor Red
$resourceGroups | Format-Table ResourceGroupName, Location

$confirm = Read-Host "Do you want to delete these resource groups? (Y/N)"
if ($confirm -eq "Y") {
    foreach ($rg in $resourceGroups) {
        Write-Host "Deleting resource group $($rg.ResourceGroupName)..." -ForegroundColor Magenta
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force
    }
    Write-Host "Deletion complete." -ForegroundColor Green
}
else {
    Write-Host "No resource groups were deleted." -ForegroundColor Yellow
}