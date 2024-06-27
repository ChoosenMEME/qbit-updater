#  Set Base Image
FROM alpine:3.20.1

# Install curl
RUN apk add --no-cache curl

# Set environment variables
ENV CRON_TIMING="* * * * *"

# Create updater directory
RUN mkdir /updater

# Copy file to image
COPY qbitportupdater.sh /updater
RUN chmod +x /updater/qbitportupdater.sh

# Add script to crontab
RUN echo "${CRON_TIMING} sh /updater/qbitportupdater.sh" >> /etc/crontabs/root

# Run Crond
ENTRYPOINT ["crond", "-f"]

#Testing
#CMD ["sh", "/updater/qbitportupdater.sh"]