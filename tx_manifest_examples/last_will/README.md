# last_will — a recursive covenant

A time-locked inheritance covenant ([`last_will.simf`](last_will.simf)) with three
spending paths:

- **Inherit** — the heir may claim the funds after a relative timelock (`INHERIT_BLOCKS`,
  ~180 days in production) since the coins last moved.
- **ColdBreak** — the owner's *cold* key spends freely, escaping the covenant.
- **Refresh** — the owner's *hot* key moves the coins but must **re-lock them into the
  same covenant** (the recursive part), resetting the inheritance timer.

It's modelled as a class (`last_will_contract`) — one instance per will:

| Method | Kind | Purpose |
|--------|------|---------|
| `Fund` | constructor | Lock funds and write the instance file recording the three keys. |
| `Refresh` | method | Hot-key refresh; repeats the covenant and resets the timer. |
| `ColdBreak` | method | Cold-key break-out of the covenant. |
| `Inherit` | method | Heir claims after the timelock expires. |

[`params.json`](params.json) holds sample compile-time keys (`INHERITOR_PUB_KEY`,
`HOT_PUB_KEY`, `COLD_PUB_KEY`, `INHERIT_BLOCKS`) — `INHERIT_BLOCKS` is set low so the
inherit path is testable without waiting months.

## Running it

The CLI is `tx-manifest-wallet`, aliased to `txw`. Complete the
[one-time wallet setup](../README.md#one-time-setup) first.

```sh
# Inspect the class and its methods, and validate the manifest
txw describe tx_manifest_examples/last_will/txmanifest.json
txw validate tx_manifest_examples/last_will/txmanifest.json

# 1. Fund the will (constructor). Writes last_will.instance.json next to the manifest,
#    recording the keys this instance was locked to. You'll be prompted for the keys
#    and amount (or pass --params to fill them from the sample file).
txw run tx_manifest_examples/last_will/txmanifest.json Fund \
    --params tx_manifest_examples/last_will/params.json \
    --wallet wallet.json

# 2. Spend a covenant method later. Pass the instance file written by Fund so the
#    wallet knows which keys/params the output was locked to. Swap Inherit for
#    Refresh or ColdBreak to exercise the other paths.
txw run tx_manifest_examples/last_will/txmanifest.json Inherit \
    --instance tx_manifest_examples/last_will/last_will.instance.json \
    --params tx_manifest_examples/last_will/params.json \
    --wallet wallet.json
```

Run `txw sync --wallet wallet.json` after each broadcast to refresh balances. The
`Inherit` spend only succeeds once `INHERIT_BLOCKS` have passed since the Fund/Refresh.
