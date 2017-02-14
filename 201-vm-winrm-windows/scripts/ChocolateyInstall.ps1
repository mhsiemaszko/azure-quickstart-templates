#######################
# Install Chocolatey
Write-Host "Installing Chocolatey..."
powershell.exe -NoProfile -Execution unrestricted -Command "Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression"

Write-Host "Updating PATH..."
$env:Path += ";$env:SystemDrive\ProgramData\chocolatey\bin"
