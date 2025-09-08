#!/bin/sh
set -e

# Make sure that the expected base folder exists.
home="$(echo ~plex)"
export PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="${PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR:-${home}/Library/Application Support}"
if [ ! -d "${PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR}" ]; then
  mkdir -p "${PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR}"
  chown plex:plex "${PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR}"
fi
pmsBaseDir="${PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR}/Plex Media Server"
if [ ! -d "${pmsBaseDir}" ]; then
  mkdir "${pmsBaseDir}"
  chown plex:plex "${pmsBaseDir}"
fi

# Execute any potential shell scripts in the entrypoint.d/ folder.
find "/entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
    case "${f}" in
        *.sh)
            if [ -x "${f}" ]; then
                echo "Launching ${f}";
                "${f}"
            else
                echo "Ignoring ${f}, not executable";
            fi
            ;;
        *)
            echo "Ignoring ${f}";;
    esac
done

# Prepare a lot of environmental variables that are used by Plex.
export PLEX_MEDIA_SERVER_HOME=/usr/lib/plexmediaserver
export PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS="${PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS:-6}"
export PLEX_MEDIA_SERVER_INFO_VENDOR="Docker"
export PLEX_MEDIA_SERVER_INFO_DEVICE="Docker Container (jonasal)"
export PLEX_MEDIA_SERVER_INFO_MODEL=$(uname -m)
export PLEX_MEDIA_SERVER_INFO_PLATFORM_VERSION=$(uname -r)

# Check for ghost PID file after crash for example.
if [ -f "${pmsBaseDir}/plexmediaserver.pid" ]; then
    echo "WARNING: Found PID file even though Plex shouldn't be running"
    if ps -p "$(cat "${pmsBaseDir}/plexmediaserver.pid")" > /dev/null; then
        echo "ERROR: Process with PID $(cat "${pmsBaseDir}/plexmediaserver.pid") running"
        exit 1
    fi
    echo -n "Process with PID $(cat "${pmsBaseDir}/plexmediaserver.pid") not found: "
    rm -v "${pmsBaseDir}/plexmediaserver.pid"
fi

echo "Starting Plex Media Server."
# Use exec to make sure the next command inherit PID 1.
# The setpriv command then allows us to change to the plex user before the
# final command is executed (still as PID 1).
exec setpriv --reuid=plex --regid=plex --init-groups -- "$@"
