FROM plexinc/pms-docker:1.42.1.10054-f333bdaa8 AS downloader
# We are going to reuse the original image to download the installer again,
# since it already contains all the tools and information we need. Doing it
# this way also helps us keep the final image size down.
ARG TARGETARCH
ARG TARGETPLATFORM
RUN set -eu; \
    plex_version="$(grep 'version=' '/version.txt' | cut -d= -f2)"; \
    plex_arch="${TARGETARCH}"; \
    if [ "${TARGETPLATFORM}" = 'linux/arm/v7' ]; then \
        plex_arch='armhf'; \
    fi; \
    mkdir /downloads && \
    curl -SLf -o "/downloads/plex_installer.deb" \
        "https://downloads.plex.tv/plex-media-server-new/${plex_version}/debian/plexmediaserver_${plex_version}_${plex_arch}.deb"


# In this target we build an image that only contains Plex, and we try to keep
# it as similar to the original setup as possible.
# However, we remove all the superfluous S6 process supervisor and "updater"
# stuff, which makes it much simpler.
FROM debian:13.1-slim AS plex-basic

# Keep the same terminal environment as the original image.
ARG DEBIAN_FRONTEND=noninteractive
ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"

# In this first RUN we prepare the container so we can install Plex in the
# next step.
RUN set -eu; \
# First we create the plex user, which is expected to have UID=1000.
    useradd plex -u 1000 -U -d /config -s /bin/false && \
    usermod -G users plex && \
# Then we setup some directories used in the original image.
    install -o plex -g plex \
      -d /config \
      -d /transcode \
      -d /data \
    && \
# Update and get dependencies needed by Plex.
    apt-get update && \
    apt-get install -y \
      tzdata \
      curl \
      xmlstarlet \
      uuid-runtime \
    && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# In this RUN we mount the entire filesystem of the original Plex image, which
# now also has the install binary, into a known location in our current build
# step so we can just extract what is necessary and nothing else.
RUN --mount=type=bind,from=downloader,source=/,target=/original \
# First we make sure we manage to install Plex.
    dpkg -i --force-confold --force-architecture /original/downloads/plex_installer.deb \
    && \
# Then we bring over the "/etc/cont-init.d/" files into a new "/entrypoint.d/"
# folder. However, our entrypoint.sh require the files to end with ".sh".
    cp -a /original/etc/cont-init.d /entrypoint.d && \
    find /entrypoint.d -type f -exec mv '{}' '{}.sh' ';' && \
# We know the updater script is irrelevant here, so delete it.
    rm -v /entrypoint.d/50-plex-update.sh && \
# Also, we don't have the "with-contenv" binary in this image, so replace the
# shebang in the beginning of the original files.
    sed -i 's&^#!/usr/bin/with-contenv &#!/usr/bin/&g' /entrypoint.d/*.sh

# To end this build target we set the final environment variables just like the
# original image as well.
ENV CHANGE_CONFIG_DIR_OWNERSHIP="true" \
    HOME="/config"

# Make a note about which ports Plex use.
EXPOSE 32400/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp

# Finally we add our new entrypoint and healthcheck, and set the Plex binary as
# the CMD. This final part will make it easier to start this container with Bash
# or similar when debugging.
COPY ./entrypoint.sh ./healthcheck.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/lib/plexmediaserver/Plex Media Server"]
HEALTHCHECK --interval=5s --timeout=2s --retries=20 CMD /healthcheck.sh || exit 1



# This build target then extends the "basic" Plex image with some additional
# features and plug-ins.
FROM plex-basic AS plex-extras
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
# Final cleanup.
    apt-get remove -y \
        unzip \
    && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# Then we add the additional entrypoint scripts needed to handle the "extras".
COPY /entrypoint.d/* /entrypoint.d/
