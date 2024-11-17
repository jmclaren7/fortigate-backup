# Script to backup foritgate configurations using the FortiCloud API 

# Ensure TLS 1.2 is used for secure connections
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# Function to authenticate and retrieve access token
function Get-AccessToken {
    param (
        [string]$Username,
        [string]$Password
    )

    $Headers = @{
        'Content-Type' = 'application/json'
        'Accept'       = 'application/json'
    }
    $RequestUri = 'https://customerapiauth.fortinet.com/api/v1/oauth/token/'
    $Body = @{
        username   = $Username
        password   = $Password
        client_id  = 'fortigatecloud'
        grant_type = 'password'
    } | ConvertTo-Json

    try {
        $AuthResponse = Invoke-RestMethod -Headers $Headers -Uri $RequestUri -Method 'POST' -Body $Body
        return $AuthResponse.access_token
    }
    catch {
        Write-Error "Failed to authenticate: $_"
        throw $_
    }
}

# Function to retrieve devices
function Get-Devices {
    param (
        [string]$AccessToken,
        [string]$ApiUri
    )

    $Headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
    }

    try {
        $DevicesResponse = Invoke-RestMethod -Headers $Headers -Uri "$ApiUri/devices" -Method 'GET'
        return $DevicesResponse

    }
    catch {
        throw $_
    }
}

# Function to backup device configuration
function Backup-Device {
    param (
        [string]$AccessToken,
        [string]$ApiUri,
        [string]$DeviceSN,
        [string]$OutFile
    )

    $Headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
    }
    
    # If the output directory does not exist, create it
    $OutDir = Split-Path -Path $OutFile
    If (-not (Test-Path -Path $OutDir)) {
        New-Item -Path $OutDir -ItemType Directory -Force > $null
        Write-Host "Created directory: $OutDir"
    }

    try {
        $RequestUri = "$ApiUri/fgt/$DeviceSN/api/v2/monitor/system/config/backup?scope=global"
        Invoke-RestMethod -Headers $Headers -Uri $RequestUri -Method 'GET' -OutFile $OutFile 
    }
    catch {
        throw $_
    }
}

# ==========================================================================
#region Load Settings
Write-Host "Loading settings..."

# Configuration defaults
$Config = @{
    API       = "https://www.forticloud.com/forticloudapi/v1"
    APIRegion = ""
    BackupsPath      = Join-Path -Path $PSScriptRoot -ChildPath "fg-backups"
    KeepDays  = 30
    KeepLast  = 7
    Username  = ""
    Password  = ""
} | ForEach-Object { [PSCustomObject]$_ }

# Load configuration from file, adding or overriding prior values
try {
    $ConfigFullPath = Join-Path -Path $PSScriptRoot -ChildPath "$((Get-ChildItem $MyInvocation.MyCommand.Path | Select-Object *).BaseName).json"
    $LoadedConfig = Get-Content -Path $ConfigFullPath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $LoadedConfig.PSObject.Properties | ForEach-Object {
        If ($_.Value -ne "") { 
            $Config | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force 
            Write-Host "$($_.Name) imported from config file"
        }
    }
}
catch {
    Write-Warning "Configuration file not loaded: $_"
}

# Load configuration from ENV, overriding prior values
$Config.PSObject.Properties | ForEach-Object {
    $EnvName = "FG_$($_.Name.ToUpper())"
    $EnvValue = [System.Environment]::GetEnvironmentVariable($EnvName)
    If ($EnvValue) { 
        $Config.PSObject.Properties[$_.Name].Value = $EnvValue
        Write-Host "$($_.Name) imported from env"
    }
}

$Config | Add-Member -MemberType NoteProperty -Name "Temp" -Value $(Join-Path -Path $Config.BackupsPath -ChildPath "temp") -Force

# If API region isn't either us or europe, set it to www
If ($Config.APIRegion -notin @("us", "europe")) {
    $Config.APIRegion = "www"
}

# Replace the www with the region
$Config.API = $Config.API -replace '/www.', "/$($Config.APIRegion)."

# Error if the backup path does not exist
If (-not (Test-Path -Path $Config.BackupsPath)) {
    Write-Error "Backup path does not exist: $($Config.BackupsPath)"
    Exit
}

#endregion

# ==========================================================================
# Authenticate and get device list
try {
    $AccessToken = Get-AccessToken -Username $Config.Username -Password $Config.Password
    Write-Host "Access token retrieved successfully."

    $Devices = Get-Devices -AccessToken $AccessToken -ApiUri $Config.API
    Write-Host "Devices found: $($Devices.count)"
}
catch {
    Write-Error "An error occurred: $_"
    Exit
}


# Backup each device
try {
    foreach ($Device in $Devices) {
        $FileName = "$(Get-Date -Format yyyyMMdd_HHmmss)_$($Device.name)_$($Device.sn).conf"
        $FilePath = Join-Path -Path $Config.Temp -ChildPath $FileName

        try {
            Backup-Device -AccessToken $AccessToken -ApiUri $Config.API -DeviceSN $Device.sn -OutFile $FilePath -ErrorAction Stop 
            Write-Host "Backed up device: $($Device.name) - $($Device.sn)"
        }
        catch {
            Write-Error "Failed to backup device: $($Device.name) - $($Device.sn)"
            Write-Error $($_.Exception.Message)
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
}


# Zip the backups and move to backup path
$ZipSourcePath = Join-Path -Path $Config.Temp -ChildPath "*"
$ZipFileName = "$(Get-Date -Format yyyyMMdd_HHmmss)_$($Devices.count).zip"
$ZipPath = Join-Path -Path $Config.Path -ChildPath $ZipFileName

try {
    Compress-Archive -Path $ZipSourcePath -DestinationPath $ZipPath -Force
    Write-Host "Backups compressed to: $ZipPath"
    Remove-Item -Path $Config.Temp -Recurse -Force
    Write-Host "Temporary backup files removed."
}
catch {
    Write-Error "Failed to compress or clean up backups: $_"
}

# Prune backups
$Backups = Get-ChildItem -Path $Config.BackupsPath -Filter "*.zip" | Sort-Object -Property Name
Write-Host "$($Backups.Count) backups found."

# If the number of backups is less than the minimum, skip pruning
if ($Backups.Count -lt $Config.KeepLast) {
    Write-Host "Skipped pruning backups, count is below the minimum of $($Config.KeepLast)"
} else {
    $CurrentDate = Get-Date
    foreach ($Backup in $Backups) {
        $BackupDate = [datetime]::ParseExact($Backup.Name.Substring(0, 8), "yyyyMMdd", $null)
        if ($CurrentDate.AddDays(-$Config.KeepDays) -gt $BackupDate) {
            Remove-Item -Path $Backup.FullName -Force
            Write-Host "Removed old backup: $($Backup.Name)"
        }
    }
}

# Done
Write-Host "Backup process completed."