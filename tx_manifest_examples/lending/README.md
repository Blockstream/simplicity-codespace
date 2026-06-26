# lending — a P2P collateralised lending protocol

A full multi-covenant protocol: a borrower locks collateral and advertises loan terms
via Liquid NFTs; a lender accepts by delivering the principal; the loan then settles by
repayment or by liquidation after expiry. Everything is enforced on-chain by Simplicity
covenants — no trusted backend.

### Covenant scripts

| File | Role |
|------|------|
| [`pre_lock.simf`](pre_lock.simf) | Holds collateral while the offer is open. `PATH::LEFT` activates the loan, `PATH::RIGHT` cancels it. |
| [`lending.simf`](lending.simf) | Holds collateral during the active loan. `PATH::LEFT` repays, `PATH::RIGHT` liquidates. |
| [`script_auth.simf`](script_auth.simf) | Wraps the NFTs, enforcing they're co-spent with the right covenant UTXO. |
| [`asset_auth.simf`](asset_auth.simf) | Guards the principal vault and asset/amount/burn checks. |
| [`p2pk.simf`](p2pk.simf) | Borrower's plain Schnorr payout address. |

### Lifecycle (`lending_contract` class)

1. **`IssueUtilityNFTs`** *(constructor)* — borrower mints the four NFTs, computes the
   covenant hashes, and writes the instance file.
2. **`LockCollateral`** — borrower locks collateral + NFTs into the covenants → open offer.
3. **`SetupLending`** — lender accepts: spends `pre_lock` (`PATH::LEFT`), moves collateral
   into the lending covenant, delivers the principal. *(or **`CancelOffer`** — borrower
   withdraws the offer, `pre_lock` `PATH::RIGHT`.)*
4. **`ClaimLoanFunds`** — borrower sweeps the delivered principal into a wallet output.
5. Settlement — either **`RepayLoan`** (borrower repays, reclaims collateral) or
   **`LiquidateAfterExpiry`** (lender claims collateral after expiry).
6. **`ClaimPrincipalWithInterest`** — lender withdraws principal + interest from the vault.

Two helper actions pre-fund wallets: **`Prepare`** (split a UTXO into 4 for the NFTs) and
**`PrepareLender`** (ensure the lender has a principal-sized UTXO).

## Running it

The CLI is `tx-manifest-wallet`, aliased to `txw`. Complete the
[one-time wallet setup](../README.md#one-time-setup) first. This protocol has two roles
(borrower and lender) — in practice use a separate `--wallet` file for each.

```sh
# Explore the manifest's classes/methods and validate it
txw describe tx_manifest_examples/lending/txmanifest.json
txw validate tx_manifest_examples/lending/txmanifest.json

# --- Borrower opens an offer ---
txw run tx_manifest_examples/lending/txmanifest.json Prepare           --wallet borrower.json
txw run tx_manifest_examples/lending/txmanifest.json IssueUtilityNFTs  --wallet borrower.json
#   ^ constructor: writes lending.instance.json next to the manifest

txw run tx_manifest_examples/lending/txmanifest.json LockCollateral \
    --instance tx_manifest_examples/lending/lending.instance.json --wallet borrower.json

# --- Lender accepts ---
txw run tx_manifest_examples/lending/txmanifest.json PrepareLender --wallet lender.json
txw run tx_manifest_examples/lending/txmanifest.json SetupLending \
    --instance tx_manifest_examples/lending/lending.instance.json --wallet lender.json

# --- Borrower draws the principal, then settles ---
txw run tx_manifest_examples/lending/txmanifest.json ClaimLoanFunds \
    --instance tx_manifest_examples/lending/lending.instance.json --wallet borrower.json
txw run tx_manifest_examples/lending/txmanifest.json RepayLoan \
    --instance tx_manifest_examples/lending/lending.instance.json --wallet borrower.json
```

Every covenant method takes `--instance lending.instance.json` (written by
`IssueUtilityNFTs`) so the wallet knows the hashes and parameters the UTXOs were locked
to. `sync` each wallet after a broadcast. To exercise the alternate branches, swap in
`CancelOffer` (instead of `SetupLending`) or `LiquidateAfterExpiry` /
`ClaimPrincipalWithInterest` on the lender side.

> This is the most involved example — start with [`../p2pk`](../p2pk) and
> [`../last_will`](../last_will) before working through the full lending flow.
