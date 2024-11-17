# FortiGate Backup
This project provides a PowerShell script and a Docker image to backup FortiGate configurations using the FortiCloud API. The backups can be scheduled using cron jobs and managed through Docker Compose.

## Features
* Backup FortiGate device configurations using the FortiCloud API.
* Compress and store backups.
* Prune old backups based on configurable retention policies.
* Deployable as a Docker container with scheduled backups using cron or as a standalone script.
* Standalone script works on any powershell 7 compatible platform (Windows, Linux, MacOS).

## Prerequisites
* PowerShell 7 or later.
* Docker and Docker Compose.

## Configuration
* Create a configuration file named fg-backup.json (matches the script name) in the same directory as fg-backup.ps1. Use the following template:

```json
{
    "BackupsPath": "c:\\fg-backups",
    "KeepDays": "365",
    "KeepLast": "100",
    "APIRegion": "us",
    "Username": "your-username",
    "Password": "your-password"
}
```

* BackupsPath: Path to store the backup files.
* KeepDays: Number of days to keep backups, leaving this blank or omitting it will skip pruning old backups.
* KeepLast: Minimum number of backups to keep.
* APIRegion: API region (us, europe, or global).
* Username: FortiGate API username.
* Password: FortiGate API password.

## Usage
First, create IAM API user credentials on FortiCloud: https://docs.fortinet.com/index.php/document/forticloud/24.3.0/identity-access-management-iam/282341/adding-an-api-user

### Running the PowerShell Script

1. Ensure you have the required configuration file fg-backup.json with the appropriate settings.
2. Run the PowerShell script: ``pwsh ./fg-backup.ps1``

### Deploying with Docker Compose

1. Create a new folder for your compose project and copy the example compose.yml file into it.
2. Configure the environmental variables in compose.yml to match your configuration.
3. Deploy the container: ``docker-compose up -d``
