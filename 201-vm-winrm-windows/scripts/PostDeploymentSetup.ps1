#################################################################################################################################
#  Name        : PostDeploymentSetup.ps1                                                                                       
#                                                                                                                             
#  Description : Installs 'PackageManagement PowerShell Modules', 'Azure Resource Manager Modules' and 'Chocolatey'; 
#                configures WinRM service                                                                        
#                                                                                                                              
#  Arguments   : HostName, specifies the FQDN of machine or domain                                                           
#################################################################################################################################

param
(
    [Parameter(Mandatory = $true)]
    [string] $HostName
)

#################################################################################################################################
#                                             Helper Functions                                                                  #
#################################################################################################################################

function Delete-WinRMListener
{
    try
    {
        $config = Winrm enumerate winrm/config/listener
        foreach($conf in $config)
        {
            if($conf.Contains("HTTPS"))
            {
                Write-Verbose "HTTPS is already configured. Deleting the exisiting configuration."
    
                winrm delete winrm/config/Listener?Address=*+Transport=HTTPS
                break
            }
        }
    }
    catch
    {
        Write-Verbose -Verbose "Exception while deleting the listener: " + $_.Exception.Message
    }
}

function Configure-WinRMHttpsListener
{
    param([string] $HostName,
          [string] $port)

    # Delete the WinRM Https listener if it is already configured
    Delete-WinRMListener

    # Create a test certificate
    $thumbprint = (Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=" + $hostname } | Select-Object -Last 1).Thumbprint
    if(-not $thumbprint)
    {
	# makecert ocassionally produces negative serial numbers
	# which golang tls/crypto <1.6.1 cannot handle
	# https://github.com/golang/go/issues/8265
        $serial = Get-Random
        .\makecert -r -pe -n CN=$hostname -b 01/01/2012 -e 01/01/2022 -eku 1.3.6.1.5.5.7.3.1 -ss my -sr localmachine -sky exchange -sp "Microsoft RSA SChannel Cryptographic Provider" -sy 12 -# $serial
        $thumbprint=(Get-ChildItem cert:\Localmachine\my | Where-Object { $_.Subject -eq "CN=" + $hostname } | Select-Object -Last 1).Thumbprint

        if(-not $thumbprint)
        {
            throw "Failed to create the test certificate."
        }
    }    

    $response = cmd.exe /c .\winrmconf.cmd $hostname $thumbprint
}

function Add-FirewallException
{
    param([string] $port)

    # Delete an exisitng rule
    netsh advfirewall firewall delete rule name="Windows Remote Management (HTTPS-In)" dir=in protocol=TCP localport=$port

    # Add a new firewall rule
    netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=$port
}

#################################################################################################################################
#                                              Install 'PackageManagement PowerShell Modules'                                   #
#################################################################################################################################

Write-Host "Installing 'PackageManagement PowerShell Modules' ..."
$tempDirectory = "$env:SystemDrive\temp"
New-Item "$tempDirectory" -type directory
Invoke-WebRequest https://download.microsoft.com/download/C/4/1/C41378D4-7F41-4BBE-9D0D-0E4F98585C61/PackageManagement_x64.msi -outfile "$tempDirectory\PackageManagement_x64.msi"
Start-Process "$tempDirectory\PackageManagement_x64.msi" -ArgumentList '/qn' -Wait
Remove-Item "$tempDirectory" -recurse

# Install NuGet
Write-Host "Installing 'NuGet' ..."
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Verbose

# Modify installation policy for 'PowerShellGallery' repository
Write-Host "Modifying installation policy for 'PowerShellGallery' repository ..."
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

#################################################################################################################################
#                                              Install 'Azure Resource Manager Modules'                                         #
#################################################################################################################################

Write-Host "Installing Microsoft Azure Resource Manager modules ..."
Install-Module AzureRM

#################################################################################################################################
#                                              Install 'Chocolatey'                                                             #
#################################################################################################################################

Write-Host "Installing Chocolatey..."
powershell.exe -NoProfile -Execution unrestricted -Command "Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression"

Write-Host "Updating PATH..."
$env:Path += ";$env:SystemDrive\ProgramData\chocolatey\bin"

#################################################################################################################################
#                                              Configure WinRM                                                                  #
#################################################################################################################################

$winrmHttpsPort=5986

# The default MaxEnvelopeSizekb on Windows Server is 500 Kb which is very less. It needs to be at 8192 Kb. The small envelop size if not changed
# results in WS-Management service responding with error that the request size exceeded the configured MaxEnvelopeSize quota.
winrm set winrm/config '@{MaxEnvelopeSizekb = "8192"}'

# Configure https listener
Configure-WinRMHttpsListener $HostName $port

# Add firewall exception
Add-FirewallException -port $winrmHttpsPort

#################################################################################################################################
