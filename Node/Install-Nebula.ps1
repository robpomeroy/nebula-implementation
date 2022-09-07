#Requires -RunAsAdministrator
#^^^ admin rights required, to install the Nebula service
<#

.SYNOPSIS
    Installs and configures the Nebula network overlay system on a Windows node.

.DESCRIPTION
    This script has some hard-coded parameters, relevant to the specific version
    of Nebula in use. It will prompt for groups, which are a security feature.
    Firewall rules attach to groups.

.COMPONENT
    Nebula

.NOTES
    This release:

        Version: 1.2
        Date:    7 September 2022
        Author:  Rob Pomeroy

    Version history:

        1.2 -  7 September 2022 - upgrade Nebula from 1.4 to 1.6
		1.1 - 11 October   2021 - add service recovery options
        1.0 - 29 September 2021 - first release

#>

##############
## SETTINGS ##
##############

$NebulaFolder = ($Env:APPDATA + "\Nebula") 
$NebulaZipUrl = "https://github.com/slackhq/nebula/releases/download/v1.6.0/nebula-windows-amd64.zip"
$NebulaZipHash = "c700b658f600ee3cffdccb28223e60417969ded5f6804df643f0b0d1b173af78" # SHA256 hash for v1.6 Nebula zip file
$NebulaBinHash = "c700b658f600ee3cffdccb28223e60417969ded5f6804df643f0b0d1b173af78" # SHA256 hash for v1.6 Nebula binary
$CACertName = "2021_office_ca" # the public cert's file name, minus ".crt"
$LighthouseDNS = "enter.external.DNS" # you can alternatively use a public IP
$LighthouseInternalIP = "192.168.92.1" # amend as required; this is the IP on the Nebula network


############
## BASICS ##
############

# Ensure Nebula folder exists
New-Item -Path $NebulaFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# Set working directory
Push-Location -Path $NebulaFolder


####################
## NEBULA INSTALL ##
####################

# Test if we already have the nebula binary/zip file and if hash is correct
if (
    # Nebula binary missing:
    (! (Test-Path -Path ($NebulaFolder + "\nebula.exe") -PathType Leaf)) -or
    # Nebula binary hash mismatch:
    ((Get-FileHash -Path ($NebulaFolder + "\nebula.exe") -Algorithm SHA256).Hash.ToLower() -ne $NebulaBinHash)
) {
    # Check if we have a valid copy of the zip file
    if (
        # Nebula zip file missing:
        (! (Test-Path -Path ($NebulaFolder + "\nebula.zip") -PathType Leaf)) -or
        # Nebula hash mismatch:
        ((Get-FileHash -Path ($NebulaFolder + "\nebula.zip") -Algorithm SHA256).Hash.ToLower() -ne $NebulaZipHash)    
    ) {
        Write-Host "Downloading Nebula..."

        # Download the Nebula zip file
        Invoke-WebRequest -Uri $NebulaZipUrl -OutFile "nebula.zip" | Unblock-File
        If ((Get-FileHash -Path ($NebulaFolder + "\nebula.zip") -Algorithm SHA256).Hash.ToLower() -ne $NebulaZipHash) {
            Throw "Error: Downloaded Nebula zip file hash was incorrect. Try again?"
        }
    }
    # Unpack the zip file
    Expand-Archive -Path "nebula.zip" -DestinationPath $NebulaFolder -Force
    Remove-Item -Path ($NebulaFolder + "\nebula.zip")
}


#####################
## SECURITY GROUPS ##
#####################

# Prompt the user to enter the groups for this node
$BadAnswer = $true
while ($BadAnswer) {
    $Groups = Read-Host -Prompt "Please enter the group(s) this node will join (e.g. 'me' or 'servers,me')"
    if ($Groups -match "[^A-Za-z0-9-_,]") {
        Write-Host "Groups must only contain letters, numbers and/or the following: -_,"
    } else {
        $BadAnswer = $false
    }
}


######################
## WINDOWS FIREWALL ##
######################

# Enable ping/RDP:
# Core Networking Diagnostics firewall group is "@FirewallAPI.dll,-27000"
# Remote Desktop firewall group is "@FirewallAPI.dll,-28752"
Write-Host "Enabling inbound ping and remote desktop through Windows firewall..."
Enable-NetFirewallRule -Group "@FirewallAPI.dll,-27000"
Set-NetFirewallRule -Group "@FirewallAPI.dll,-27000" -Profile Domain,Private
Enable-NetFirewallRule -Group "@FirewallAPI.dll,-28752"
Set-NetFirewallRule -Group "@FirewallAPI.dll,-28752" -Profile Domain,Private


############################
## GENERATE CONFIGURATION ##
############################

# Paths in the config file need forward slashes
$CAPath = ($NebulaFolder + "\" + $CACertName + ".crt") -replace "\\","/"
$BasePath = $NebulaFolder  -replace "\\","/"

# Generate the configuration file
$ConfigFile = @"
pki:
  ca: $CAPath
  cert: $BasePath/node.crt
  key: $BasePath/node.key

static_host_map:
  "$LighthouseInternalIP": ["$LighthouseDNS:4242"]

lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
    - "$LighthouseInternalIP"

listen:
  host: 0.0.0.0
  port: 0

punchy:
  punch: true
  respond: true

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300
  routes:

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    - port: any
      proto: icmp
      host: any

    - port: 3389
      proto: tcp
      group: $Groups
"@

Write-Host Writing Nebula configuration file...
New-Item -Path ($NebulaFolder + "\node.yaml") -ErrorAction SilentlyContinue | Out-Null
Set-Content -Path ($NebulaFolder + "\node.yaml")  -Value $ConfigFile | Out-Null


####################
## NEBULA SERVICE ##
####################

# [Re]install the service
Write-Host "Intalling the Nebula service"
& ($NebulaFolder + "\nebula") -service uninstall | Out-Null
& ($NebulaFolder + "\nebula") -config ($NebulaFolder + "\node.yaml") -service install

# Set service recovery options (restart after 1 minute)
& C:\Windows\System32\sc.exe failure Nebula reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null


#########
## END ##
#########

# Finished
Write-Host "All done. You should now place $CACertName.crt, node.crt and node.key at $NebulaFolder and start the Nebula Network Service."
Pop-Location