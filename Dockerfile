# Use the official PowerShell image as the base image
FROM mcr.microsoft.com/powershell:latest

RUN apt-get update && apt-get -y install cron

# Set the working directory to the root of the image
WORKDIR /

# Copy the project files
COPY entrypoint.sh /entrypoint.sh
COPY fg-backup.ps1 /fg-backup.ps1

# Give execution rights on the entrypoint script
RUN chmod +x /entrypoint.sh

# Set the entrypoint to entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]