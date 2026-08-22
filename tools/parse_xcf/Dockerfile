FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install GIMP and other necessary tools
RUN apt-get update && apt-get install -y \
    gimp \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy the script
COPY parse.sh /app/parse.sh

# Ensure the script is executable
RUN chmod +x /app/parse.sh

# The container will run the script by default
ENTRYPOINT ["/app/parse.sh"]
