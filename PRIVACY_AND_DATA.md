# Privacy and data management

## What we store

- **On-chain (public)**: Wallet address, user name (registration), bookings, transactions, P2P stations, energy listings, reviews, reward points. This data is immutable and visible to anyone reading the blockchain.
- **On-device (local cache)**: Copy of bookings and transactions for offline/fast access; wallet address and user name for session. You can export or clear this via **Profile → Privacy & data**.

## No intermediaries

Payments go through the smart contract (escrow) or directly to the station/platform wallet. We do not run a central server that stores your payment details.

## Decentralized data

- **Sensitive data**: We do not store passwords; identity is your wallet. We do not collect email or phone unless you add them later.
- **Scalability**: Station list is loaded from public APIs (e.g. Open Charge Map) and from the blockchain. Large blobs (e.g. profile images) are not stored on-chain in the current version; future versions may use off-chain storage (e.g. IPFS) with an on-chain hash for verification.
- **Anonymity**: Wallet addresses are public on-chain by design. If you need stronger privacy, use a fresh wallet for the app.

## Your rights (GDPR-style)

- **Access**: You can export your data (Profile → Privacy & data → Export my data).
- **Erasure**: Clearing local cache removes cached bookings/transactions from the device. On-chain data cannot be erased; the blockchain is immutable.
- **Consent**: By using the app and connecting your wallet, you accept that your wallet address and on-chain activity are public. Local cache is used to improve experience and can be cleared at any time.
