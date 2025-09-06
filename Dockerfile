FROM plexinc/pms-docker:1.32.8.7639-fb6452ebf

# We are going to need to configure the s6 supervisor to behave in a sane manner
# and actually exit if startup script and/or services fail. Change some timeouts
# since they are not used after we change the CMD.
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=10 \
    S6_KILL_GRACETIME=10 \
    S6_KILL_FINISH_MAXTIME=10

ARG DEBIAN_FRONTEND=noninteractive
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
#
# Below we are going to try to straighten out the (in my opinion) suboptimal
# use of Docker by including s6 as a supervisor for a single process inside this
# container.
# However, instead of rewriting the entire image we read in the s6 docs that the
# better solution here is to just make this single service into a CMD. So the
# first step in doing that is moving the "run" script outside the reach of s6.
    mv -v "/etc/services.d/plex/run" "/run-plex" && \
    rm -rf "/etc/services.d/plex" && \
# Also remove this updater file, unsure exactly what this is trying to achieve
# and I don't like it.
    rm -v /etc/cont-init.d/50-plex-update && \
#
#
# Final cleanup.
    apt-get remove -y \
        unzip \
    && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# Since we are only running a single process inside this container, and we want
# to fail this container if this service dies, the s6 docs hints at that it is
# much better to provide it as a CMD instead.
CMD [ "/run-plex" ]

# Include the new files executed during startup.
COPY cont-init.d/ /etc/cont-init.d
