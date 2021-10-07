<#

.SYNOPSIS
    Create a key pair for a Nebula node

.COMPONENT
    Nebula

.NOTES
    This release:

        Version: 1.0
        Date:    29 September 2021
        Author:  Rob Pomeroy

    Version history:

        1.0 - 29 September 2021 - first release

#>

param
(
    [Parameter(Mandatory = $true, Position = 0)][String]$NodeName,
    [Parameter(Mandatory = $true, Position = 0)][String]$NodeIP,
    [Parameter(Mandatory = $true, Position = 0)][String]$NodeGroups,
    [Parameter(Mandatory = $true, Position = 0)][String]$ZipPwd
)

##############
## SETTINGS ##
##############

$CACertName = "2021_office_ca" # the certs' file name, minus ".crt" and ".key"
$NetworkCIDR = "22" # You might want to use 24?

##################
## END SETTINGS ##
##################


# We use 7-Zip to password-protect the certificates once generated
Install-Module -Name 7Zip4Powershell

$NebulaFolder = ($Env:APPDATA + "\Nebula") 
$NodeFolder = ($NebulaFolder + "\nodes\" + $NodeName) # we'll store the generated certs here

# Ensure node folder exists
New-Item -Path $NodeFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# Set working directory and empty it
Push-Location -Path $NodeFolder
Remove-Item -Path ($NodeFolder + "\*") | Out-Null

# Remove old zip file
Remove-Item -Path ($NebulaFolder + "\nodes\" + $NodeName + ".zip") -ErrorAction SilentlyContinue | Out-Null

# Check CA certs are available
If(! (Test-Path -Path ($NebulaFolder + "\" + $CACertName + ".crt") -PathType Leaf) ) {
    Throw "ERROR: The CA public certificate $CACertName.crt is not available"
}
If(! (Test-Path -Path ($NebulaFolder + "\" + $CACertName + ".key") -PathType Leaf) ) {
    Throw "ERROR: The CA private key $CACertName.key is not available"
}

# Create the certificates
Write-Host Generating the certificates...
& ($NebulaFolder + "\nebula-cert") sign `
    -name "$NodeName" `
    -ip "$NodeIP/$NetworkCIDR" `
    -groups "$NodeGroups" `
    -ca-crt ($NebulaFolder + "\" + $CACertName + ".crt") `
    -ca-key ($NebulaFolder + "\" + $CACertName + ".key") `
    -out-crt node.crt `
    -out-key node.key

# Copy the CA certificate into the certificate directory
Copy-Item -Path ($NebulaFolder + "\" + $CACertName + ".crt") -Destination $NodeFolder | Out-Null

Write-Host Creating the zip file...
Compress-7Zip `
    -ArchiveFileName ($NodeName + ".zip") `
    -Path $NodeFolder `
    -OutputPath ($NebulaFolder + "\nodes") `
    -Format Zip `
    -CompressionLevel Ultra `
    -Password $ZipPwd

Write-Host "Done."
Pop-Location