This file `simplicity_p2pk_testnet.py` is an adapted version of the LWK bindings test scripts to demonstrate spending a P2PK Simplicity contract on Liquid Testnet from Python with `simplicity_lwk` Python bindings.

It also uses LWK's Esplora bindings to query transactions on Liquid Testnet via the Esplora API.

To run with `simplicity_lwk`:

```
git clone https://github.com/Blockstream/lwk
cd lwk
just python-build-bindings-simplicity
# copy simplicity_p2pk_testnet.py into the lwk directory or change
# the path below to indicate the location of the script
PYTHONPATH=target/release/bindings/ python3 simplicity_p2pk_testnet.py
```
