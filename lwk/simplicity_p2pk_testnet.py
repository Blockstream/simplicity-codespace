import json
import os
import requests
import time

from lwk import *

_SIMF_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "..", "lwk_simplicity", "data")
P2PK_SOURCE = open(os.path.join(_SIMF_DIR, "p2pk.simf")).read()

# 1. Set up regtest environment
# node = LwkTestEnv()
network = Network.testnet()
policy_asset = network.policy_asset()
client = EsploraClient("https://blockstream.info/liquidtestnet/api", network)

# 2. Create signer and derive x-only public key
mnemonic = Mnemonic("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
signer = Signer(mnemonic, network)
derivation_path = "m/86'/1'/0'/0/0"
xonly_pubkey = simplicity_derive_xonly_pubkey(signer, derivation_path)

# 3. Compile P2PK program with the public key
args = SimplicityArguments()
args = args.add_value("PUBLIC_KEY", SimplicityTypedValue.u256(xonly_pubkey.to_bytes()))
program = SimplicityProgram.load(P2PK_SOURCE, args)

# 4. Create P2TR address from the program
simplicity_address = program.create_p2tr_address(xonly_pubkey, network)
simplicity_script = simplicity_address.script_pubkey()

# Create Wollet
desc = WolletDescriptor(f":{simplicity_script}")
wollet = Wollet(network, desc, datadir=None)
assert str(simplicity_address) == str(wollet.address(0).address())

# wait_for_tx implementation compatible with EsploraClient
 
def wait_for_tx(wollet: Wollet, client: EsploraClient, txid: Txid, max_attempts: int = 120, sleep_ms: int = 7000):
    """  
    Wait for a transaction to appear in the wallet using EsploraClient.  
      
    Args:  
        wollet: The wallet to monitor  
        client: EsploraClient instance  
        txid: Transaction ID to wait for  
        max_attempts: Maximum number of attempts (default: 120)  
        sleep_ms: Milliseconds to sleep between attempts (default: 500)  
      
    Returns:  
        None if transaction found, raises RuntimeError if timeout  
    """  
    print("DEBUG: waiting for tx", txid)
    for attempt in range(max_attempts):  
        # Sync wallet with blockchain  
        update = client.full_scan(wollet)  
        print("Single full_scan succeeded")
        if update is not None:  
            wollet.apply_update(update)  
          
        # Check if transaction is present  
        transactions = wollet.transactions()  
        print("Got {} transactions from Esplora".format(len(transactions)))
        candidates = [tx for tx in transactions if str(tx.txid()) == str(txid)]
        if candidates:
            return candidates[0]

        # Sleep before next attempt  
        time.sleep(sleep_ms / 1000.0)  
      
    raise RuntimeError(f"Transaction {txid} not found after {max_attempts} attempts")  

# 5. Fund the Simplicity address

def faucet(address):
    faucet_api = f"https://liquidtestnet.com/api/faucet?address={address}&action=lbtc"
    return json.loads(requests.get(faucet_api).text)["txid"]

funding_txid = Txid(faucet(simplicity_address))
# Faucet is hard-coded to send 100000 sats
funded_satoshi = 100000

# node.generate(1)
funding_tx = wait_for_tx(wollet, client, funding_txid).tx()

# 6. Find the funding TxOut
vout, funding_output = next(
    (idx, out) for (idx, out) in enumerate(funding_tx.outputs())
    if str(out.script_pubkey()) == str(simplicity_script)
)

# 7. Create ExternalUtxo for TxBuilder
SIMPLICITY_WITNESS_WEIGHT = 700  # FIXME(KyrylR): Conservative estimate for Simplicity witness
unblinded = TxOutSecrets.from_explicit(policy_asset, funded_satoshi)
external_utxo = ExternalUtxo.from_unchecked_data(
    OutPoint.from_parts(funding_txid, vout),
    funding_output,
    unblinded,
    SIMPLICITY_WITNESS_WEIGHT
)

# 8. Build transaction using TxBuilder
# recipient_address = node.get_new_address()
recipient_address = Address("tlq1qq2g07nju42l0nlx0erqa3wsel2l8prnq96rlnhml262mcj7pe8w6ndvvyg237japt83z24m8gu4v3yfhaqvrqxydadc9scsmw")
send_amount = 50000

builder = network.tx_builder()
builder.add_external_utxos([external_utxo])
builder.add_lbtc_recipient(recipient_address, send_amount)
builder.drain_lbtc_to(simplicity_address)  # Change back to Simplicity address
pset = builder.finish(wollet)

# 9. Extract unsigned transaction and create signature
unsigned_tx = pset.extract_tx()
all_utxos = [funding_output]

signature = program.create_p2pk_signature(
    signer, derivation_path, unsigned_tx,
    all_utxos, 0, network
)

# 10. Finalize transaction with Simplicity witness
witness = SimplicityWitnessValues()
witness = witness.add_value("SIGNATURE", SimplicityTypedValue.byte_array(signature))

finalized_tx = program.finalize_transaction(
    unsigned_tx, xonly_pubkey, all_utxos, 0,
    witness, network, SimplicityLogLevel.NONE
)

# 11. Verify TxInWitness can be built manually and matches finalize_transaction output
finalized_witness = finalized_tx.inputs()[0].witness()
assert not finalized_witness.is_empty(), "Finalized witness should not be empty"
finalized_script_witness = finalized_witness.script_witness()
assert len(finalized_script_witness) == 4, "Simplicity witness should have 4 elements"

# Run the program to get the pruned program and witness bytes
run_result = program.run(
    unsigned_tx, xonly_pubkey, all_utxos, 0,
    witness, network, SimplicityLogLevel.NONE
)

# Build the witness manually from its components:
# [simplicity_witness_bytes, simplicity_program_bytes, cmr, control_block]
simplicity_witness_bytes = run_result.witness_bytes()
simplicity_program_bytes = run_result.program_bytes()
cmr = run_result.cmr()

control_block = simplicity_control_block(cmr, xonly_pubkey)
control_block_hex = control_block.to_bytes().hex()

# Verify it matches what program.control_block() returns
program_control_block_hex = program.control_block(xonly_pubkey).to_bytes().hex()
assert control_block_hex == program_control_block_hex, \
    "simplicity_control_block should match program.control_block()"

manual_script_witness = [
    simplicity_witness_bytes,
    simplicity_program_bytes,
    cmr.to_bytes(),
    control_block.to_bytes(),
]

manual_witness = TxInWitness.from_script_witness(manual_script_witness)
assert manual_witness.script_witness() == finalized_script_witness, \
    f"Manual witness should match finalized witness:\n  manual={manual_witness.script_witness()}\n  finalized={finalized_script_witness}"

# Test TransactionEditor.set_input_witness produces same result
tx_editor = TransactionEditor.from_transaction(unsigned_tx)
tx_editor.set_input_witness(0, manual_witness)
tx_with_manual_witness = tx_editor.build()
assert tx_with_manual_witness.inputs()[0].witness().script_witness() == finalized_script_witness, \
    "TransactionEditor.set_input_witness should produce matching witness"

# 12. Broadcast and mempool acceptance
txid = client.broadcast(finalized_tx)

result = wait_for_tx(wollet, client, txid).tx()

print("Success:", result)
