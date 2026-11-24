#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CIQ_SDK:?Set CIQ_SDK}"
: "${CIQ_KEY:?Set CIQ_KEY to your existing private signing key}"
mkdir -p bin
"$CIQ_SDK/bin/monkeyc" -f monkey.jungle -e -r -l 0 -w -y "$CIQ_KEY" -o bin/Ride540NB.iq
