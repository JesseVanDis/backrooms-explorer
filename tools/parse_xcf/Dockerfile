FROM ubuntu:24.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install GIMP and other necessary tools
RUN apt-get update && apt-get install -y \
    gimp \
    xvfb

# Set the working directory
WORKDIR /app

# Copy the script
COPY parse.sh /app/parse.sh
COPY convertXCF.py /app/convertXCF.py

# Ensure the script is executable
RUN chmod +x /app/parse.sh

# The container will run the script by default
ENTRYPOINT ["/app/parse.sh"]
