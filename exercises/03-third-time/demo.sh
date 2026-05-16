#!/bin/bash

# Fund and spend an example "third time's the charm" SimplicityHL contract
# on Liquid Testnet.

# Dependencies: simc hal-simplicity jq curl

pause() { echo -n "Press Enter to continue. " ; read -r; echo; echo; }
# pause() { echo; echo; }

# This demo has been updated to not require the use of elements-cli.
# Some tasks could be simpler or more scalable in some sense if we used
# a local elements-cli, but here we use the Liquid Testnet web API
# instead to remove local dependencies. The main reason for this is that
# elementsd will require multiple gigabytes of blockchain data. Having
# a working local copy of elementsd can be useful for other development
# tasks, but represents a larger time and disk space commitment.

PROGRAM_SOURCE=third-time.simf

# This is an unspendable public key address derived from BIP 0341. It is
# semi-hardcoded in some Simplicity tools. You can change it in order
# to make existing contract source code have a different address on the
# blockchain but you must use a NUMS method to make sure that the key
# is unspendable. BIP 0341 gives a method to modify the number below to
# retain that property.
#
# If you are sending assets to a contract created by someone else, you
# must make sure that the internal key used for that instance of the
# contract is an unspendable value (if it is changed from this default).
# Otherwise, the contract creator may be able to unilaterally steal
# value from the contract.
INTERNAL_KEY="50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0"
TMPDIR=$(mktemp -d)
WITNESS_FILE=$TMPDIR/witness.wit

# Private keys of parties whose signatures can approve this transaction.
PRIVKEY_1="0000000000000000000000000000000000000000000000000000000000000001"

# Hardcoded address of the Liquid testnet for returning tLBTC (so that
# they aren't wasted!) If a different wallet is provided as a command
# line argument, send to that instead.

if [ $# -gt 0 ]
then
	DESTINATION_ADDRESS="$1"
	echo "Using specified recipient address $1 for withdrawal destination."
else
	DESTINATION_ADDRESS=tlq1qq2g07nju42l0nlx0erqa3wsel2l8prnq96rlnhml262mcj7pe8w6ndvvyg237japt83z24m8gu4v3yfhaqvrqxydadc9scsmw
	echo "Using faucet-return address $DESTINATION_ADDRESS for default withdrawal destination."
fi

if echo "$DESTINATION_ADDRESS" | grep -E "^t?lq1" >/dev/null
then
# Get unconfidential address from confidential address
# DESTINATION_ADDRESS=$("$ELEMENTS_CLI" validateaddress "$DESTINATION_ADDRESS" | jq -r .unconfidential)
DESTINATION_ADDRESS=$(hal-simplicity address inspect "$DESTINATION_ADDRESS" | jq -r .unconfidential)
echo "Using unconfidential version: $DESTINATION_ADDRESS"
fi

for variable in PROGRAM_SOURCE WITNESS_FILE INTERNAL_KEY PRIVKEY_1 DESTINATION_ADDRESS
do
echo -n "$variable="
eval echo \$$variable
done

# This check is used for two different purposes. First, we need to be
# able to actually download the transaction data in order to extract
# some details. Second, we need the node that we will ultimately submit
# our transaction to to have a copy of the input transaction (at least
# in its mempool; not necessarily confirmed!). There are propagation
# delays in the Liquid Network, so we cannot assume all nodes have heard
# about all newly-submitted transactions within a matter of only 1-2
# seconds.
#
# An alternative using elements-cli would use the subcommand gettxout,
# again polling to ensure that the local node has received a copy of the
# relevant transaction!

propagation_check(){
  # TODO: Give a useful error if this times out.
  echo -n "Checking for transaction $TXID via Liquid API..."
  for _ in {1..60}; do
    if curl -sSL "$1""$TXID" | jq ".vout[0]" 2>/dev/null | tee "$TMPDIR"/faucet-tx-data.json | jq -e >/dev/null 2>&1
  then
    echo " found."
    break
  else
    echo -n "."
  fi
  sleep 1
  done
}

pause

# Compile program
echo simc "$PROGRAM_SOURCE"
simc "$PROGRAM_SOURCE"

pause

# Extract the compiled program from the output of that command
COMPILED_PROGRAM=$(simc --json "$PROGRAM_SOURCE" | jq -r .program)

echo hal-simplicity simplicity info "$COMPILED_PROGRAM"
hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq
# You can get the human-readable display of the low-level combinators with
#   hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq -r .commit_decode
# but this isn't used anywhere in the transaction.
CMR=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq -r .cmr)
CONTRACT_ADDRESS=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" | jq -r .liquid_testnet_address_unconf)
echo

for variable in CMR CONTRACT_ADDRESS
do
echo -n "$variable="
eval echo \$$variable
done

CMR=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" -s 0000000000000000000000000000000000000000000000000000000000000000 | jq -r .cmr)
CONTRACT_ADDRESS=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" -s 0000000000000000000000000000000000000000000000000000000000000000 | jq -r .liquid_testnet_address_unconf)
CONTRACT_ADDRESS1=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" -s 0000000000000000000000000000000000000000000000000000000000000001 | jq -r .liquid_testnet_address_unconf)
CONTRACT_ADDRESS2=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" -s 0000000000000000000000000000000000000000000000000000000000000002 | jq -r .liquid_testnet_address_unconf)

for variable in CONTRACT_ADDRESS CONTRACT_ADDRESS1 CONTRACT_ADDRESS2
do
echo -n "$variable="
eval echo \$$variable
done

pause

# Here we use a curl command to contact the Liquid Testnet faucet to
# ask it to fund our contract. We extract the resulting txid.
echo Running curl to connect to Liquid Testnet faucet...
TXID=$(curl "https://liquidtestnet.com/api/faucet?address=$CONTRACT_ADDRESS&action=lbtc" 2>/dev/null | jq -r .txid)

echo "TXID=$TXID"
pause

echo "==================="
echo "First time (update)"
echo "==================="
echo

# Ask hal-simplicity to create a minimal PSET which asks to spend the
# value that the faucet sent to our contract, by sending it back to
# DESTINATION_ADDRESS (the address the contract is asked to send this value
# to) -- less a fee.
#
# Note that this hard-coded fee is higher than required. The concept of
# weight can be used to calculate the minimum appropriate fee, but we'll
# need other tools to determine it.
echo hal-simplicity simplicity pset create '[ { "txid": "'"$TXID"'", "vout": 0 } ]' '[ { "'"$CONTRACT_ADDRESS1"'": 0.00099900 }, { "fee": 0.00000100 } ]'
PSET=$(hal-simplicity simplicity pset create '[ { "txid": "'"$TXID"'", "vout": 0 } ]' '[ { "'"$CONTRACT_ADDRESS1"'": 0.00099900 }, { "fee": 0.00000100 } ]' | jq -r .pset)

echo "Minimal PSET is $PSET"

pause

# Now we will attach a lot of stuff to this PSET.

# First, we want to know more details related to the incoming transaction
# that funded the contract and that we are now attempting to spend.
echo "Looking up faucet transaction details (tx with state = 0)."

# Note that the elements-cli version would also require polling in a loop
# until the local elementsd has a copy of the transaction in its mempool
# (this isn't guaranteed to be true instantly). The JSON details are also
# slightly different from the API in this case, including measuring the
# value in a different base unit.
# echo $ELEMENTS_CLI gettxout $FAUCET_TRANSACTION 0
# $ELEMENTS_CLI gettxout $FAUCET_TRANSACTION 0 | tee $TMPDIR/faucet-tx-data.orig.json | jq 
# HEX=$(jq -r .scriptPubKey.hex < $TMPDIR/faucet-tx-data.json)
# ASSET=$(jq -r .asset < $TMPDIR/faucet-tx-data.json)
# VALUE=$(jq -r .value < $TMPDIR/faucet-tx-data.json)

propagation_check https://liquid.network/liquidtestnet/api/tx/
cat "$TMPDIR"/faucet-tx-data.json | jq

HEX=$(jq -r .scriptpubkey < "$TMPDIR"/faucet-tx-data.json)
ASSET=$(jq -r .asset < "$TMPDIR"/faucet-tx-data.json)
VALUE=$(jq -r '.value' < "$TMPDIR"/faucet-tx-data.json | awk '{printf "%.8f", $1/100000000}')

echo "Extracted hex:asset:value parameters $HEX:$ASSET:$VALUE"

pause

echo hal-simplicity simplicity pset update-input "$PSET" 0 -i "$HEX:$ASSET:$VALUE" -c "$CMR" -p "$INTERNAL_KEY" -s 0000000000000000000000000000000000000000000000000000000000000000
hal-simplicity simplicity pset update-input "$PSET" 0 -i "$HEX:$ASSET:$VALUE" -c "$CMR" -p "$INTERNAL_KEY" -s 0000000000000000000000000000000000000000000000000000000000000000 | tee "$TMPDIR"/updated.json | jq

PSET=$(cat "$TMPDIR"/updated.json | jq -r .pset)

pause

# Now we have to generate the sighash and then, for this case, make a
# signature on it corresponding to Alice's key. This allows us to build
# the witness that will be input to the Simplicity program, convincing
# it to approve this transaction.

# Signature 1
echo "Signing on behalf of Alice using private key $PRIVKEY_1"
echo hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1"
hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1" | jq
SIGNATURE_1=$(hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1" | jq -r .signature)
echo "Alice's signature is $SIGNATURE_1 (different from JSON due to signing nonce)"

pause

cat > "$WITNESS_FILE" << FOO
{
    "STATE": {
        "value": "0000000000000000000000000000000000000000000000000000000000000000",
        "type": "u256"
    },
    "UPDATE_OR_WITHDRAW": {
        "value": "Left(0x$SIGNATURE_1)",
        "type": "Either<Signature, Signature>"
    }
}
FOO

echo "Contents of witness:"
cat "$WITNESS_FILE"

pause

# The compiled program is not itself different when compiled with the
# witness, but it's usual that it would be compiled once without a
# witness when sending assets to the contract, as we do above, and once
# with a witness when claiming assets from the contract, as we do here.
# Those would usually be done by different people on different occasions.
echo "Recompiling Simplicity program with attached populated witness file..."
echo simc --json "$PROGRAM_SOURCE" -w "$WITNESS_FILE"
simc --json "$PROGRAM_SOURCE" -w "$WITNESS_FILE" | tee "$TMPDIR"/compiled-with-witness.json | jq

PROGRAM=$(cat "$TMPDIR"/compiled-with-witness.json | jq -r .program)
WITNESS=$(cat "$TMPDIR"/compiled-with-witness.json | jq -r .witness)

pause

echo hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS"
hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS" | jq
PSET=$(hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS" | jq -r .pset)

pause

echo hal-simplicity simplicity pset extract "$PSET"
hal-simplicity simplicity pset extract "$PSET" | jq
RAW_TX=$(hal-simplicity simplicity pset extract "$PSET" | jq -r)

echo "Raw transaction is $RAW_TX"

pause

propagation_check https://blockstream.info/liquidtestnet/api/tx/

# With a sufficiently up-to-date local copy of elementsd, we could also use
# TXID=$("$ELEMENTS_CLI" sendrawtransaction "$RAW_TX")
# instead of using the web API.
echo "Submitting raw transaction via Liquid Testnet web API..."
echo -n "Resulting transaction ID is "
TXID=$(curl -X POST "https://blockstream.info/liquidtestnet/api/tx" -d "$RAW_TX" 2>/dev/null)
echo "$TXID"
echo
echo "You can view it online at https://blockstream.info/liquidtestnet/tx/$TXID?expand"

echo

# Second time
echo "===================="
echo "Second time (update)"
echo "===================="
echo

# Ask hal-simplicity to create a minimal PSET which asks to spend the
# value that the faucet sent to our contract, by sending it back to
# the covenant with updated state -- less a fee.
#
# Note that this hard-coded fee is higher than required. The concept of
# weight can be used to calculate the minimum appropriate fee, but we'll
# need other tools to determine it.
echo hal-simplicity simplicity pset create '[ { "txid": "'"$TXID"'", "vout": 0 } ]' '[ { "'"$CONTRACT_ADDRESS2"'": 0.00099800 }, { "fee": 0.00000100 } ]'
PSET=$(hal-simplicity simplicity pset create '[ { "txid": "'"$TXID"'", "vout": 0 } ]' '[ { "'"$CONTRACT_ADDRESS2"'": 0.00099800 }, { "fee": 0.00000100 } ]' | jq -r .pset)

echo "Minimal PSET is $PSET"

CMR=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" -s 0000000000000000000000000000000000000000000000000000000000000001 | jq -r .cmr)
echo "CMR is $CMR"

pause

# Now we will attach a lot of stuff to this PSET.

# First, we want to know more details related to the prior
# transaction that we are now attempting to spend.
echo "Looking up prior transaction details (tx with state = 1)."

# Note that the elements-cli version would also require polling in a loop
# until the local elementsd has a copy of the transaction in its mempool
# (this isn't guaranteed to be true instantly). The JSON details are also
# slightly different from the API in this case, including measuring the
# value in a different base unit.
# echo $ELEMENTS_CLI gettxout $FAUCET_TRANSACTION 0
# $ELEMENTS_CLI gettxout $FAUCET_TRANSACTION 0 | tee $TMPDIR/faucet-tx-data.orig.json | jq 
# HEX=$(jq -r .scriptPubKey.hex < $TMPDIR/faucet-tx-data.json)
# ASSET=$(jq -r .asset < $TMPDIR/faucet-tx-data.json)
# VALUE=$(jq -r .value < $TMPDIR/faucet-tx-data.json)

propagation_check https://liquid.network/liquidtestnet/api/tx/
cat "$TMPDIR"/faucet-tx-data.json | jq

# foo
HEX=$(jq -r .scriptpubkey < "$TMPDIR"/faucet-tx-data.json)
ASSET=$(jq -r .asset < "$TMPDIR"/faucet-tx-data.json)
VALUE=$(jq -r '.value' < "$TMPDIR"/faucet-tx-data.json | awk '{printf "%.8f", $1/100000000}')

echo "Extracted hex:asset:value parameters $HEX:$ASSET:$VALUE"

pause

echo hal-simplicity simplicity pset update-input "$PSET" 0 -i "$HEX:$ASSET:$VALUE" -c "$CMR" -p "$INTERNAL_KEY" -s 0000000000000000000000000000000000000000000000000000000000000001
hal-simplicity simplicity pset update-input "$PSET" 0 -i "$HEX:$ASSET:$VALUE" -c "$CMR" -p "$INTERNAL_KEY" -s 0000000000000000000000000000000000000000000000000000000000000001 | tee "$TMPDIR"/updated.json | jq

PSET=$(cat "$TMPDIR"/updated.json | jq -r .pset)

pause

# Now we have to generate the sighash and then, for this case, make a
# signature on it corresponding to Alice's key. This allows us to build
# the witness that will be input to the Simplicity program, convincing
# it to approve this transaction.

# Signature 1
echo "Signing on behalf of Alice using private key $PRIVKEY_1"
echo hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1"
hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1" | jq
SIGNATURE_1=$(hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1" | jq -r .signature)
echo "Alice's signature is $SIGNATURE_1 (different from JSON due to signing nonce)"

pause

cat > "$WITNESS_FILE" << FOO
{
    "STATE": {
        "value": "0000000000000000000000000000000000000000000000000000000000000001",
        "type": "u256"
    },
    "UPDATE_OR_WITHDRAW": {
        "value": "Left(0x$SIGNATURE_1)",
        "type": "Either<Signature, Signature>"
    }
}
FOO

echo "Contents of witness:"
cat "$WITNESS_FILE"

pause

# The compiled program is not itself different when compiled with the
# witness, but it's usual that it would be compiled once without a
# witness when sending assets to the contract, as we do above, and once
# with a witness when claiming assets from the contract, as we do here.
# Those would usually be done by different people on different occasions.
echo "Recompiling Simplicity program with attached populated witness file..."
echo simc --json "$PROGRAM_SOURCE" -w "$WITNESS_FILE"
simc --json "$PROGRAM_SOURCE" -w "$WITNESS_FILE" | tee "$TMPDIR"/compiled-with-witness.json | jq

PROGRAM=$(cat "$TMPDIR"/compiled-with-witness.json | jq -r .program)
WITNESS=$(cat "$TMPDIR"/compiled-with-witness.json | jq -r .witness)

pause

# echo hal-simplicity simplicity pset run "$PSET" 0 "$PROGRAM" "$WITNESS"
# hal-simplicity simplicity pset run "$PSET" 0 "$PROGRAM" "$WITNESS" | jq

echo hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS"
hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS" | jq
PSET=$(hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS" | jq -r .pset)

pause

echo hal-simplicity simplicity pset extract "$PSET"
hal-simplicity simplicity pset extract "$PSET" | jq
RAW_TX=$(hal-simplicity simplicity pset extract "$PSET" | jq -r)

echo "Raw transaction is $RAW_TX"

pause

# propagation_check https://blockstream.info/liquidtestnet/api/tx/

# With a sufficiently up-to-date local copy of elementsd, we could also use
# TXID=$("$ELEMENTS_CLI" sendrawtransaction "$RAW_TX")
# instead of using the web API.
echo "Submitting raw transaction via Liquid Testnet web API..."
echo -n "Resulting transaction ID is "
TXID=$(curl -X POST "https://blockstream.info/liquidtestnet/api/tx" -d "$RAW_TX" 2>/dev/null)
echo "$TXID"
echo
echo "You can view it online at https://blockstream.info/liquidtestnet/tx/$TXID?expand"

echo

# Third time (the charm)

echo "====================="
echo "Third time (withdraw)"
echo "====================="
echo

# Ask hal-simplicity to create a minimal PSET which asks to spend the
# value that the faucet sent to our contract, by sending it back to
# the covenant with updated state -- less a fee.
#
# Note that this hard-coded fee is higher than required. The concept of
# weight can be used to calculate the minimum appropriate fee, but we'll
# need other tools to determine it.
echo hal-simplicity simplicity pset create '[ { "txid": "'"$TXID"'", "vout": 0 } ]' '[ { "'"$DESTINATION_ADDRESS"'": 0.00099700 }, { "fee": 0.00000100 } ]'
PSET=$(hal-simplicity simplicity pset create '[ { "txid": "'"$TXID"'", "vout": 0 } ]' '[ { "'"$DESTINATION_ADDRESS"'": 0.00099700 }, { "fee": 0.00000100 } ]' | jq -r .pset)

echo "Minimal PSET is $PSET"

CMR=$(hal-simplicity simplicity info "$COMPILED_PROGRAM" -s 0000000000000000000000000000000000000000000000000000000000000002 | jq -r .cmr)
echo "CMR is $CMR"

pause

# Now we will attach a lot of stuff to this PSET.

# First, we want to know more details related to the prior
# transaction that we are now attempting to spend.
echo "Looking up prior transaction details (tx with state = 2)."

# Note that the elements-cli version would also require polling in a loop
# until the local elementsd has a copy of the transaction in its mempool
# (this isn't guaranteed to be true instantly). The JSON details are also
# slightly different from the API in this case, including measuring the
# value in a different base unit.
# echo $ELEMENTS_CLI gettxout $FAUCET_TRANSACTION 0
# $ELEMENTS_CLI gettxout $FAUCET_TRANSACTION 0 | tee $TMPDIR/faucet-tx-data.orig.json | jq 
# HEX=$(jq -r .scriptPubKey.hex < $TMPDIR/faucet-tx-data.json)
# ASSET=$(jq -r .asset < $TMPDIR/faucet-tx-data.json)
# VALUE=$(jq -r .value < $TMPDIR/faucet-tx-data.json)

propagation_check https://liquid.network/liquidtestnet/api/tx/
cat "$TMPDIR"/faucet-tx-data.json | jq

HEX=$(jq -r .scriptpubkey < "$TMPDIR"/faucet-tx-data.json)
ASSET=$(jq -r .asset < "$TMPDIR"/faucet-tx-data.json)
VALUE=$(jq -r '.value' < "$TMPDIR"/faucet-tx-data.json | awk '{printf "%.8f", $1/100000000}')

echo "Extracted hex:asset:value parameters $HEX:$ASSET:$VALUE"

pause

echo hal-simplicity simplicity pset update-input "$PSET" 0 -i "$HEX:$ASSET:$VALUE" -c "$CMR" -p "$INTERNAL_KEY" -s 0000000000000000000000000000000000000000000000000000000000000002
hal-simplicity simplicity pset update-input "$PSET" 0 -i "$HEX:$ASSET:$VALUE" -c "$CMR" -p "$INTERNAL_KEY" -s 0000000000000000000000000000000000000000000000000000000000000002 | tee "$TMPDIR"/updated.json | jq

PSET=$(cat "$TMPDIR"/updated.json | jq -r .pset)

pause

# Now we have to generate the sighash and then, for this case, make a
# signature on it corresponding to Alice's key. This allows us to build
# the witness that will be input to the Simplicity program, convincing
# it to approve this transaction.

# Signature 1
echo "Signing on behalf of Alice using private key $PRIVKEY_1"
echo hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1"
hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1" | jq
SIGNATURE_1=$(hal-simplicity simplicity sighash "$PSET" 0 "$CMR" -x "$PRIVKEY_1" | jq -r .signature)
echo "Alice's signature is $SIGNATURE_1 (different from JSON due to signing nonce)"

pause

cat > "$WITNESS_FILE" << FOO
{
    "STATE": {
        "value": "0000000000000000000000000000000000000000000000000000000000000002",
        "type": "u256"
    },
    "UPDATE_OR_WITHDRAW": {
        "value": "Right(0x$SIGNATURE_1)",
        "type": "Either<Signature, Signature>"
    }
}
FOO

echo "Contents of witness:"
cat "$WITNESS_FILE"

pause

# The compiled program is not itself different when compiled with the
# witness, but it's usual that it would be compiled once without a
# witness when sending assets to the contract, as we do above, and once
# with a witness when claiming assets from the contract, as we do here.
# Those would usually be done by different people on different occasions.
echo "Recompiling Simplicity program with attached populated witness file..."
echo simc --json "$PROGRAM_SOURCE" -w "$WITNESS_FILE"
simc --json "$PROGRAM_SOURCE" -w "$WITNESS_FILE" | tee "$TMPDIR"/compiled-with-witness.json | jq

PROGRAM=$(cat "$TMPDIR"/compiled-with-witness.json | jq -r .program)
WITNESS=$(cat "$TMPDIR"/compiled-with-witness.json | jq -r .witness)

pause

# echo hal-simplicity simplicity pset run "$PSET" 0 "$PROGRAM" "$WITNESS"
# hal-simplicity simplicity pset run "$PSET" 0 "$PROGRAM" "$WITNESS" | jq

echo hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS"
hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS" | jq
PSET=$(hal-simplicity simplicity pset finalize "$PSET" 0 "$PROGRAM" "$WITNESS" | jq -r .pset)

pause

echo hal-simplicity simplicity pset extract "$PSET"
hal-simplicity simplicity pset extract "$PSET" | jq
RAW_TX=$(hal-simplicity simplicity pset extract "$PSET" | jq -r)

echo "Raw transaction is $RAW_TX"

pause

# propagation_check https://blockstream.info/liquidtestnet/api/tx/

# With a sufficiently up-to-date local copy of elementsd, we could also use
# TXID=$("$ELEMENTS_CLI" sendrawtransaction "$RAW_TX")
# instead of using the web API.
echo "Submitting raw transaction via Liquid Testnet web API..."
echo -n "Resulting transaction ID is "
TXID=$(curl -X POST "https://blockstream.info/liquidtestnet/api/tx" -d "$RAW_TX" 2>/dev/null)
echo "$TXID"
echo
echo "You can view it online at https://blockstream.info/liquidtestnet/tx/$TXID?expand"

echo
