#!/bin/bash
# DISPOSABLE one-shot probe. Sends telemetry frame (4201) to each Seplos pack
# address 0x00..0x0F over RS485 and reports which respond. Delete after use.
#
# Usage: ./probe_slaves.sh
# Optional: MAX_ADDR=3 ./probe_slaves.sh     (probe only 0x00..0x03)

CONFIG_DIR="${CONFIG_DIR:-$(dirname "$(readlink -f "$0")")}"
CONFIG_FILE="$CONFIG_DIR/config.ini"
DEV=$(grep "^DEV=" "$CONFIG_FILE" 2>/dev/null | awk -F "=" '{print $2}')
BAUD=$(grep "^BAUD=" "$CONFIG_FILE" 2>/dev/null | awk -F "=" '{print $2}')
DEV="${DEV:-/dev/ttyUSB0}"
BAUD="${BAUD:-19200}"
MAX_ADDR="${MAX_ADDR:-15}"

if [ ! -e "$DEV" ]; then
    echo "ERROR: serial device $DEV not found" >&2
    exit 1
fi

stty -F "$DEV" sane -echo -echoe -echok "$BAUD"

build_frame() {
    local addr_hex="$1"
    local RQ="20${addr_hex}464201"
    local CMD=${RQ:0:8}
    local DATA=${RQ:8}
    local LEN=${#DATA}
    LEN=$(printf "%03X" "$LEN")
    local LENSUM=$((~(${LEN:0:1} + ${LEN:1:1} + ${LEN:2:1})))
    LENSUM=$(printf "%X" "$LENSUM")
    LENSUM=${LENSUM:0-1:1}
    LENSUM=$((0x$LENSUM + 1))
    LENSUM=$(printf "%X" "$LENSUM")
    LENSUM=${LENSUM:0-1:1}
    local SEND="${CMD}${LENSUM}${LEN}${DATA}"
    local SUM=0
    local d
    for d in $(echo -n "$SEND" | od -An -td1); do
        SUM=$((SUM + d))
    done
    SUM=$((~SUM))
    SUM="$(printf "%04X" "$SUM")"
    SUM="${SUM:0-4:4}"
    SUM=$((0x$SUM + 1))
    SUM=$(printf "%04X" "$SUM")
    SUM="${SUM:0-4:4}"
    printf "~%s%s\r" "$SEND" "$SUM"
}

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

probe_addr() {
    local addr_hex="$1"
    local frame
    frame=$(build_frame "$addr_hex")
    : > "$TMP"

    ( timeout 3 cat "$DEV" > "$TMP" ) &
    local reader_pid=$!
    sleep 0.2
    echo -ne "$frame" > "$DEV"
    wait "$reader_pid" 2>/dev/null

    local resp
    resp=$(tr -d '\r\n' < "$TMP")

    if [ -z "$resp" ]; then
        printf "  %s : no response\n" "$addr_hex"
        return
    fi

    if [ "${resp:0:1}" != "~" ]; then
        printf "  %s : garbage (%d bytes): %s\n" "$addr_hex" "${#resp}" "${resp:0:40}"
        return
    fi

    # Bytes 7-8 = RTN (return code). 00 = OK.
    local rtn="${resp:7:2}"
    if [ "$rtn" = "00" ]; then
        printf "  %s : OK   (%d bytes, RTN=00)\n" "$addr_hex" "${#resp}"
    else
        printf "  %s : error RTN=%s (%d bytes)\n" "$addr_hex" "$rtn" "${#resp}"
    fi
}

echo "Probing Seplos packs on $DEV @ ${BAUD} baud"
echo "Addresses 0x00..$(printf '0x%02X' "$MAX_ADDR")"
echo

for addr_dec in $(seq 0 "$MAX_ADDR"); do
    addr_hex=$(printf "%02X" "$addr_dec")
    probe_addr "$addr_hex"
done

echo
echo "Done. Addresses marked OK respond to telemetry (CID2=42 01)."
echo "To poll a slave from query_seplos_ha.sh, edit ADDR=<hex> in that script"
echo "or wrap the call. Delete this probe script once you have the answer."
