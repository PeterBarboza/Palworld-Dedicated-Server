FROM cm2network/steamcmd:root

LABEL maintainer="pedrobarboza"
LABEL description="Palworld Dedicated Server"

ENV PALSERVER_DIR="/home/steam/palserver"
ENV STEAMCMD="/home/steam/steamcmd/steamcmd.sh"

# Install dependencies for Palworld server
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    xdg-user-dirs \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create server directory
RUN mkdir -p "${PALSERVER_DIR}" && \
    chown steam:steam "${PALSERVER_DIR}"

# Copy scripts
COPY --chown=steam:steam scripts/entrypoint.sh /home/steam/entrypoint.sh
RUN chmod +x /home/steam/entrypoint.sh

# Switch to steam user
USER steam
WORKDIR /home/steam

# Expose ports
EXPOSE 8211/udp
EXPOSE 27015/udp

ENTRYPOINT ["/home/steam/entrypoint.sh"]
