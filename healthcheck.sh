#!/bin/sh -e

# Try to contact a known endpoint on our server, and fail unless we get a 200
# response back.
curl --silent --show-error --fail \
    ${HEALTCHECK_CURL_OPTS:- --connect-timeout 15 --max-time 100} \
    "http://${HEALTCHECK_CURL_TARGET:-localhost}:32400/identity" >/dev/null
