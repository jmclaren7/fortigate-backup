# Use the official PowerShell image as the base image
FROM --platform=$TARGETPLATFORM alpine:latest

#RUN apt-get update && apt-get -y install cron
RUN apk -U upgrade; apk add --no-cache powershell

# Set the working directory to the root of the image
WORKDIR /

# Copy the project files
COPY entrypoint.sh fg-backup.ps1 /

# Give execution rights on the entrypoint script
RUN chmod +x /entrypoint.sh

# Set the entrypoint to entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
 