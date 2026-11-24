#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CIQ_SDK:?Set CIQ_SDK to your Connect IQ SDK directory}"
key="${CIQ_KEY:-.keys/developer.der}"
if [[ ! -f "$key" ]]; then
    mkdir -p "$(dirname "$key")"
    temporary_key=$(mktemp)
    trap 'rm -f "$temporary_key"' EXIT
    openssl genrsa -out "$temporary_key" 4096 2>/dev/null
    openssl pkcs8 -topk8 -inform PEM -outform DER -in "$temporary_key" -out "$key" -nocrypt
    chmod 600 "$key"
fi
mkdir -p bin
# SDK 9.3.0's gradual checker throws ConcurrentModificationException on this
# valid model. Its bytecode compiler works with type checking disabled.
"$CIQ_SDK/bin/monkeyc" -f monkey.jungle -d edge540 \
    -o bin/Ride540NB.prg -y "$key" -l 0 -w -r
if [[ "${1:-}" == "--tests" ]]; then
    "$CIQ_SDK/bin/monkeyc" -f test.jungle -d edge540 \
        -o bin/Ride540NB-tests.prg -y "$key" -l 0 -w -t
fi
