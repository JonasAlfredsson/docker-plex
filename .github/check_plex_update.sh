#!/bin/bash
set -eo pipefail

################################################################################
#
# This script checks Docker Hub for newer plexinc/pms-docker tags and can
# update the pinned base tag in the Dockerfile.
#
# This workaround is necessary because Dependabot does not support the
# X.Y.Z.W-hexsuffix version format used by plexinc/pms-docker tags:
# https://github.com/dependabot/dependabot-core/issues/15624
#
# Usage: ./check_plex_update.sh <path-to-Dockerfile>
#
################################################################################

DOCKERFILE="${1}"
PAGE_SIZE="100"

if [ -z "${DOCKERFILE}" ]; then
    echo "Usage: $0 <path-to-Dockerfile>" >&2
    exit 1
fi

if [ ! -f "${DOCKERFILE}" ]; then
    echo "Dockerfile not found: ${DOCKERFILE}" >&2
    exit 1
fi

current_tag=$(sed -n -E -e 's&^FROM plexinc/pms-docker:([0-9]+(\.[0-9]+){3}-[0-9a-f]+)([[:space:]].*)?$&\1&p' "${DOCKERFILE}" | head -n1)

if [ -z "${current_tag}" ]; then
    echo "Could not extract current Plex tag from ${DOCKERFILE}" >&2
    exit 1
fi

echo "Current Plex tag: ${current_tag}"

tmp_tags_file=$(mktemp)
trap 'rm -f "${tmp_tags_file}"' EXIT

page=1
while true; do
    api_url="https://hub.docker.com/v2/namespaces/plexinc/repositories/pms-docker/tags?page_size=${PAGE_SIZE}&page=${page}"
    response=$(curl --fail --silent --show-error --location "${api_url}")

    printf '%s' "${response}" |
        grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' |
        sed -E 's/^"name"[[:space:]]*:[[:space:]]*"([^"]+)"$/\1/' |
        grep -E '^[0-9]+(\.[0-9]+){3}-[0-9a-f]+$' >> "${tmp_tags_file}" || true

    if printf '%s' "${response}" | grep -Eq '"next"[[:space:]]*:[[:space:]]*null'; then
        break
    fi

    page=$((page + 1))
done

latest_tag=$(sort -u "${tmp_tags_file}" | awk -F'[.-]' '
{
    printf "%012d.%012d.%012d.%012d-%s\t%s\n", $1, $2, $3, $4, $5, $0
}
' | sort | tail -n1 | cut -f2)

if [ -z "${latest_tag}" ]; then
    echo "No valid Plex tags found from Docker Hub." >&2
    exit 1
fi

echo "Latest Plex tag:  ${latest_tag}"

if [ "${latest_tag}" != "${current_tag}" ]; then
    echo "A newer Plex tag is available."
    sed -i -E "0,/^FROM plexinc\/pms-docker:[^[:space:]]+([[:space:]].*)?$/s//FROM plexinc\/pms-docker:${latest_tag}\1/" "${DOCKERFILE}"
    echo "Updated ${DOCKERFILE} to ${latest_tag}."
else
    echo "Already up to date."
fi
