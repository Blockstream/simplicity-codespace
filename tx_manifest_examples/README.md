# tx-manifest examples

Sample [transaction manifests](https://github.com/stringhandler/manifest-wallet) for
the `tx-manifest-wallet` CLI. A manifest (`txmanifest.json`) is a JSON document that
declares a protocol's UTXO types, actions, covenant scripts (SimplicityHL `.simf`
programs), and compile-time parameters — the wallet figures out how to build, sign,
and broadcast the transactions.

This devcontainer ships the CLI preinstalled as **`tx-manifest-wallet`**, aliased to
**`txw`**. Every command below can be written either way.

| Example | What it shows |
|---------|---------------|
| [`p2pk/`](p2pk/) | "Hello world" — pay-to-public-key with a single Schnorr-checksig covenant. Start here. |
| [`last_will/`](last_will/) | A single-file **recursive covenant** with three spending paths (timelocked inheritance, cold break-out, hot refresh). |
| [`lending/`](lending/) | A full multi-covenant **P2P lending protocol** (collateral lock, offers via NFTs, repayment / liquidation). |

Each example folder has its own `README.md` with copy-paste run instructions.

## One-time setup

The CLI defaults to **Liquid testnet**. Create and fund a wallet once, then reuse it
across the examples:

```sh
txw create-wallet --out wallet.json     # generate a wallet
txw info --wallet wallet.json           # print a receive address — send it testnet L-BTC
txw sync --wallet wallet.json           # pull UTXOs and show balance
```

Get testnet L-BTC from the [Liquid testnet faucet](https://liquidtestnet.com/faucet).

Run `txw <command> --help` for the full flag list.
