FROM plexinc/pms-docker:1.20.1.3252-a78fef9a9

RUN apt-get update && apt-get install -y \
# Install USB libraries if any such thing is to be mounted.
        libusb-dev \
# Dependencies needed by ASS.
        libxslt1.1 \
# Needed during installation of HAMA.
        unzip \
    && \
# Create a folder hierarchy under "/extras" in which we can configure all
# additional stuff we want to inject in the real "/config" folder later.
    extras_base_path="/extras" && \
    install -o plex -g plex \
        -d "${extras_base_path}/Plug-ins" \
        -d "${extras_base_path}/Scanners/Series" \
    && \
# Begin by installing the Absolute Series Scanner (ASS).
    curl -sSLf -o "${extras_base_path}/Scanners/Series/Absolute Series Scanner.py" \
        "https://raw.githubusercontent.com/ZeroQI/Absolute-Series-Scanner/master/Scanners/Series/Absolute%20Series%20Scanner.py" && \
# Install the HAMA Bundle plug-in.
    cd /tmp && \
    curl -sSLf -O https://github.com/ZeroQI/Hama.bundle/archive/master.zip && \
    unzip master.zip && \
    mv -v Hama.bundle-master "${extras_base_path}/Plug-ins/Hama.bundle" && \
# Make sure all permissions in this folder tree are correct.
    chown -R plex:plex "${extras_base_path}" && \
    chmod -R 775 "${extras_base_path}" && \
# Remove this updater file, unsure exactly what this is trying to achieve and
# I don't like it so just discard it.
    rm -v /etc/cont-init.d/50-plex-update && \
# Final cleanup.
    apt-get remove -y \
        unzip \
    && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# Include the new files executed during startup.
COPY cont-init.d/ /etc/cont-init.d
