#!/bin/bash
# Exercise 01: Pay to Public Key
#
# Fund and spend a P2PK SimplicityHL contract on Liquid Testnet.
# Alice's signature (private key 1*G) is required to spend the coins.
#
# Usage:  ./demo.sh [destination-address]
# Deps:   simc  hal-simplicity  jq  curl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAM_SOURCE="$SCRIPT_DIR/p2pk.simf"
WITNESS_FILE="$SCRIPT_DIR/p2pk.wit"

# BIP-0341 unspendable internal key (NUMS point — do not change)
INTERNAL_KEY="50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0"
TMPDIR=$(mktemp -d)

# Private key corresponding to Alice's public key (1 * G). Test-only.
PRIVKEY_ALICE="0000000000000000000000000000000000000000000000000000000000000001"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pause() { read -rp "Press Enter to continue..."; echo; echo; }

# Convert a confidential Liquid address to its unconfidential equivalent.
get_unconfidential() {
    if ! hal-simplicity address inspect "$1" | jq -e 'has("witness_pubkey_hash")' >/dev/null 2>&1; then
        echo "Not a valid Liquid address: $1" >&2
        exit 1
    fi
    if hal-simplicity address inspect "$1" | jq -e 'has("unconfidential")' >/dev/null 2>&1; then
        hal-simplicity address inspect "$1" | jq -r .unconfidential
    else
        echo "$1"
    fi
}

# Poll until $FAUCET_TRANSACTION appears on the given Liquid API endpoint.
check_propagation() {
    echo -n "Waiting for transaction $FAUCET_TRANSACTION..."
    for _ in {1..60}; do
        if curl -sSL "$1$FAUCET_TRANSACTION" | jq ".vout[0]" 2>/dev/null \
                | tee "$TMPDIR/faucet-tx-data.json" | jq -e >/dev/null 2>&1; then
            echo " found."
            break
        fi
        echo -n "."
        sleep 1
    done
}

show_vars() {
    for var in "$@"; do
        echo -n "$var="
        eval echo "\$$var"
    done
}


# ---------------------------------------------------------------------------
# Destination address
# ---------------------------------------------------------------------------

if [ -z "${1-}" ]; then
    DESTINATION_ADDRESS=tlq1qq2g07nju42l0nlx0erqa3wsel2l8prnq96rlnhml262mcj7pe8w6ndvvyg237japt83z24m8gu4v3yfhaqvrqxydadc9scsmw
    echo "No destination address given — returning coins to faucet."
else
    DESTINATION_ADDRESS="$1"
    echo "Destination: $1"
fi

DESTINATION_ADDRESS=$(get_unconfidential "$DESTINATION_ADDRESS")
echo "Unconfidential address: $DESTINATION_ADDRESS"
echo

show_vars PROGRAM_SOURCE WITNESS_FILE INTERNAL_KEY PRIVKEY_ALICE DESTINATION_ADDRESS
pause


# ---------------------------------------------------------------------------
# Step 1: Compile
# ---------------------------------------------------------------------------

echo "==> Compiling $PROGRAM_SOURCE"
simc "$PROGRAM_SOURCE"
pause

COMPILED_PROGRAM=$(simc "$PROGRAM_SOURCE" | sed '1d; 3,$d')

echo "==> Getting contract info"
hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq
CMR=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq -r .cmr)
CONTRACT_ADDRESS=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq -r .liquid_testnet_address_unconf)

show_vars CMR CONTRACT_ADDRESS
pause


# ---------------------------------------------------------------------------
# Step 2: Fund via faucet
# ---------------------------------------------------------------------------

echo "==> Requesting testnet coins from faucet..."
FAUCET_TRANSACTION=$(curl -s "https://liquidtestnet.com/faucet?address=$CONTRACT_ADDRESS&action=lbtc" \
    | sed -n "s/.*with transaction \([0-9a-f]*\)\..*$/\1/p")
show_vars FAUCET_TRANSACTION
pause


# ---------------------------------------------------------------------------
# Step 3: Build unsigned PSET
# ---------------------------------------------------------------------------

echo "==> Creating PSET"
PSET1=$(hal-simplicity simplicity pset create \
    "[ { \"txid\": \"$FAUCET_TRANSACTION\", \"vout\": 0 } ]" \
    "[ { \"$DESTINATION_ADDRESS\": 0.00099900 }, { \"fee\": 0.00000100 } ]" \
    | jq -r .pset)
echo "Minimal PSET: $PSET1"
pause


# ---------------------------------------------------------------------------
# Step 4: Look up faucet tx details
# ---------------------------------------------------------------------------

echo "==> Fetching faucet transaction details"
check_propagation https://liquid.network/liquidtestnet/api/tx/
cat "$TMPDIR/faucet-tx-data.json" | jq

HEX=$(jq -r .scriptpubkey < "$TMPDIR/faucet-tx-data.json")
ASSET=$(jq -r .asset < "$TMPDIR/faucet-tx-data.json")
VALUE=0.00$(jq -r .value < "$TMPDIR/faucet-tx-data.json")

echo "hex:asset:value = $HEX:$ASSET:$VALUE"
pause


# ---------------------------------------------------------------------------
# Step 5: Attach contract metadata to PSET
# ---------------------------------------------------------------------------

echo "==> Updating PSET input with contract metadata"
hal-simplicity simplicity pset update-input "$PSET1" 0 \
    -i "$HEX:$ASSET:$VALUE" -c "$CMR" -p "$INTERNAL_KEY" \
    | tee "$TMPDIR/updated.json" | jq

PSET2=$(jq -r .pset < "$TMPDIR/updated.json")
pause


# ---------------------------------------------------------------------------
# Step 6: Sign
# ---------------------------------------------------------------------------

echo "==> Generating Alice's signature"
hal-simplicity simplicity sighash "$PSET2" 0 "$CMR" -x "$PRIVKEY_ALICE" | jq
SIGNATURE_ALICE=$(hal-simplicity simplicity sighash "$PSET2" 0 "$CMR" -x "$PRIVKEY_ALICE" | jq -r .signature)
echo "Alice's signature: $SIGNATURE_ALICE"
pause


# ---------------------------------------------------------------------------
# Step 7: Inject signature into witness file
# ---------------------------------------------------------------------------

cp "$WITNESS_FILE" "$TMPDIR/witness.wit"
sed -i "s/0x[0-9a-f]*/0x$SIGNATURE_ALICE/" "$TMPDIR/witness.wit"
echo "Populated witness:"; cat "$TMPDIR/witness.wit"
pause


# ---------------------------------------------------------------------------
# Step 8: Recompile with witness
# ---------------------------------------------------------------------------

echo "==> Recompiling with witness"
simc "$PROGRAM_SOURCE" -w "$TMPDIR/witness.wit" | tee "$TMPDIR/compiled-with-witness"

PROGRAM=$(sed '1d; 3,$d' "$TMPDIR/compiled-with-witness")
WITNESS=$(sed '1,3d; 5,$d' "$TMPDIR/compiled-with-witness")
pause


# ---------------------------------------------------------------------------
# Step 9: Finalize and extract raw transaction
# ---------------------------------------------------------------------------

echo "==> Finalizing PSET"
hal-simplicity simplicity pset finalize "$PSET2" 0 "$PROGRAM" "$WITNESS" | jq
PSET3=$(hal-simplicity simplicity pset finalize "$PSET2" 0 "$PROGRAM" "$WITNESS" | jq -r .pset)
pause

echo "==> Extracting raw transaction"
hal-simplicity simplicity pset extract "$PSET3" | jq
RAW_TX=$(hal-simplicity simplicity pset extract "$PSET3" | jq -r)
pause


# ---------------------------------------------------------------------------
# Step 10: Broadcast
# ---------------------------------------------------------------------------

check_propagation https://blockstream.info/liquidtestnet/api/tx/

echo "==> Broadcasting transaction"
TXID=$(curl -sX POST "https://blockstream.info/liquidtestnet/api/tx" -d "$RAW_TX")
echo "Transaction ID: $TXID"
echo "View at: https://blockstream.info/liquidtestnet/tx/$TXID?expand"
