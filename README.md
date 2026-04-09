# Simplicity Workshop

A GitHub Codespace workshop for writing and deploying [Simplicity](https://github.com/BlockstreamResearch/simplicity) smart contracts on Liquid Testnet.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/blockstream/simplicity-codespace)

---

## What is Simplicity?

Simplicity is a low-level, formally-verified smart contract language designed for Bitcoin and Liquid. Programs are represented as typed combinator trees, giving them provable resource bounds and a clean formal semantics. [SimplicityHL](https://github.com/BlockstreamResearch/SimplicityHL) is a higher-level language that compiles down to Simplicity.

---

## Toolchain

The Codespace includes:

| Tool | Purpose |
|------|---------|
| `simc` | SimplicityHL compiler — turns `.simf` source into a compiled program |
| `hal-simplicity` | HAL tools — inspect programs, build PSETs, sign, broadcast |
| `lwk_cli` | Liquid Wallet Kit CLI — wallet and transaction utilities |

All tools are pre-built from source and available on `PATH` when the Codespace starts.

---

## Exercises

Work through the exercises in order. Each one introduces new concepts.

### [Exercise 01 — Pay to Public Key](exercises/01-p2pk/)

The simplest possible Simplicity contract: coins move only when the holder of a given public key produces a valid Schnorr signature.

**Concepts:** `jet::bip_0340_verify`, `witness`, `jet::sig_all_hash`

```bash
cd exercises/01-p2pk
simc p2pk.simf                    # compile and inspect
bash demo.sh                      # end-to-end testnet demo
```

---

### [Exercise 02 — Pay to Multisig (2-of-3)](exercises/02-p2ms/)

A 2-of-3 multisig contract. Three public keys are embedded in the contract; any two valid signatures unlock the coins.

**Concepts:** `Option<T>`, arrays, helper functions, `checksig_add` pattern

```bash
cd exercises/02-p2ms
simc p2ms.simf
bash demo.sh
```


## How a Demo Works

Each `demo.sh` walks through the full lifecycle of a Simplicity contract on testnet:

```
1. Compile         simc <program>.simf
2. Get address     hal-simplicity simplicity info <compiled>
3. Fund            Liquid Testnet faucet → contract address
4. Build PSET      hal-simplicity simplicity pset create ...
5. Sign            hal-simplicity simplicity sighash ...
6. Inject witness  update .wit file with real signature(s)
7. Recompile       simc <program>.simf -w <witness>.wit
8. Finalize        hal-simplicity simplicity pset finalize ...
9. Broadcast       curl → Liquid Testnet API
```

Run any script with an optional destination address, or omit it to return funds to the faucet:

```bash
bash demo.sh [your-liquid-testnet-address]
```

---

## Writing Your Own Contract

1. Create a new `.simf` file:

```rust
fn main() {
    // your logic here
}
```

2. Compile to check for errors:

```bash
simc mycontract.simf
```

3. Inspect the compiled program:

```bash
PROGRAM=$(simc mycontract.simf | sed '1d; 3,$d')
hal-simplicity simplicity info "$PROGRAM" | jq
```

4. Create a `.wit` file for any witness values your contract needs, then compile with it:

```bash
simc mycontract.simf -w mycontract.wit
```

5. Follow the same PSET lifecycle as the demo scripts to fund and spend on testnet.

---

## Key Concepts

### Witnesses

Witness values (e.g. signatures) are provided at spend time, not at contract creation. They live in `.wit` JSON files:

```json
{
    "MY_SIGNATURE": {
        "value": "0x...",
        "type": "Signature"
    }
}
```

Reference them in Simplicity as `witness::MY_SIGNATURE`.

### Internal Key

All contracts use a BIP-341 NUMS (nothing-up-my-sleeve) internal key so that the Taproot key-path spend is provably disabled:

```
50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0
```

### Test Keys

The demo scripts use the secp256k1 generator multiples as private keys (1, 2, 3). The corresponding public keys are embedded in the contracts. **These are well-known test vectors — never use them with real funds.**

---

## Resources

- [SimplicityHL documentation](https://github.com/BlockstreamResearch/SimplicityHL)
- [Simplicity whitepaper](https://github.com/BlockstreamResearch/simplicity/blob/master/Simplicity-TR.pdf)
- [Liquid Testnet faucet](https://liquidtestnet.com/faucet)
- [Liquid Testnet explorer](https://blockstream.info/liquidtestnet/)
