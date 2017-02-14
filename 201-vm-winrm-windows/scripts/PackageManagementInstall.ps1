################################################# 
# Install "PackageManagement PowerShell Modules"
Write-Host "Installing 'PackageManagement PowerShell Modules' ..."
$tempDirectory = "$env:SystemDrive\temp"
New-Item "$tempDirectory" -type directory
Invoke-WebRequest https://download.microsoft.com/download/C/4/1/C41378D4-7F41-4BBE-9D0D-0E4F98585C61/PackageManagement_x64.msi -outfile "$tempDirectory\PackageManagement_x64.msi"
Start-Process "$tempDirectory\PackageManagement_x64.msi" -ArgumentList '/qn' -Wait
Remove-Item "$tempDirectory" -recurse

# Install NuGet
Write-Host "Installing 'NuGet' ..."
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 –Force –Verbose

# Modify installation policy for 'PowerShellGallery' repository
Write-Host "Modifying installation policy for 'PowerShellGallery' repository ..."
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
