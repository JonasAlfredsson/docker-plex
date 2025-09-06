#!/bin/bash
set -eo pipefail

################################################################################
#
# This script will try to extract the Plex version from the Dockerfile targeted.
#
# $1: The file to scan
#
################################################################################


version=$(sed -n -r -e 's&^FROM plexinc/pms-docker:([1-9]+(\.[0-9]+){3}-[0-9a-f]+)$&\1&p' "${1}")

if [ -z "${version}" ]; then
    echo "Could not extract version from '${1}'"
    exit 1
fi

echo "APP_MAJOR=$(echo ${version} | cut -d. -f 1)"
echo "APP_MINOR=$(echo ${version} | cut -d. -f 2)"
echo "APP_PATCH=$(echo ${version} | cut -d. -f 3)"
echo "APP_VERSION=${version}"
