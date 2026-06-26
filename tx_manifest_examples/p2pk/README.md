# p2pk — pay-to-public-key

The simplest possible manifest: lock funds into an output that only the holder of a
given x-only public key can spend. The covenant ([`p2pk.simf`](p2pk.simf)) is a single
`bip_0340_verify` against `param::PUB_KEY`.

- **`Pay`** — lock `amount_sat` into a p2pk output for a recipient `pubkey`.
- **`Receive`** — spend a p2pk output back into your wallet (the `pubkey` must be one of
  your own wallet keys so it can sign).

## Running it

The CLI is `tx-manifest-wallet`, aliased to `txw`. Make sure you've done the
[one-time wallet setup](../README.md#one-time-setup) and have some testnet L-BTC.

```sh
# Inspect the manifest and sanity-check its schema
txw describe tx_manifest_examples/p2pk/txmanifest.json
txw validate tx_manifest_examples/p2pk/txmanifest.json

# Make sure the wallet holds a UTXO big enough for the Pay action
txw prepare tx_manifest_examples/p2pk/txmanifest.json Pay --wallet wallet.json

# Execute Pay — you'll be prompted for the recipient pubkey and amount,
# then shown the transaction before it's signed and broadcast
txw run tx_manifest_examples/p2pk/txmanifest.json Pay --wallet wallet.json

# Later, spend the locked output back to yourself
txw run tx_manifest_examples/p2pk/txmanifest.json Receive --wallet wallet.json
```

After a broadcast, run `txw sync --wallet wallet.json` to refresh your balance.
