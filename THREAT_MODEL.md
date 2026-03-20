# Threat Model: EV Finder

## Overview

This document identifies potential security threats to the EV Finder platform and describes the mitigations implemented in the smart contract and application layers.

## Assets

| Asset | Description | Storage |
|-------|-------------|---------|
| User wallet private keys | Controls identity and funds | Device secure storage (Keychain/Keystore) or external wallet (MetaMask) |
| ETH funds (escrow) | Payments held during booking | EVFinder smart contract |
| Energy credits | Virtual credits for P2P trading | On-chain (EVFinder contract) |
| Booking records | Charging session details | On-chain + local cache |
| User PII (name) | Display name | On-chain (public) |
| Location data | GPS coordinates for stations | On-chain for P2P stations; API for public stations |

## Threat Categories (STRIDE)

### 1. Spoofing (Identity)

| Threat | Risk | Mitigation |
|--------|------|------------|
| Impersonation of another user | Medium | All contract functions use `msg.sender` for authentication; cannot be spoofed on-chain |
| Fake wallet connection | Low | Wallet signing verifies ownership; in-app wallet uses cryptographic key generation |
| Session hijacking | Low | No server sessions; each transaction requires wallet signature |

### 2. Tampering

| Threat | Risk | Mitigation |
|--------|------|------------|
| Modifying booking data | Low | Bookings stored on-chain (immutable); local cache is read-only copy |
| Altering transaction amounts | Low | Contract validates payment amounts via `msg.value`; amounts recorded immutably |
| Changing station ownership | Low | `require(owner == msg.sender)` enforced in `updateStation` and `deactivateStation` |

### 3. Repudiation

| Threat | Risk | Mitigation |
|--------|------|------------|
| User denies making a payment | Low | All payments recorded on-chain with transaction hashes; blockchain provides non-repudiation |
| Station owner denies receiving payment | Low | `PaymentReleased` event emitted with amount and beneficiary address |

### 4. Information Disclosure

| Threat | Risk | Mitigation |
|--------|------|------------|
| Private key exposure | High | Keys stored in platform secure storage (flutter_secure_storage); MetaMask/WalletConnect keep keys in user's wallet |
| Wallet address linkability | Medium | Inherent to public blockchain; acknowledged in privacy policy; future work: ZKP-based identity |
| API key exposure | Medium | OpenChargeMap API key in source code; mitigated by using free-tier key with rate limits |

### 5. Denial of Service

| Threat | Risk | Mitigation |
|--------|------|------------|
| Contract state bloat | Medium | No pagination in contract queries; accepted for testnet scale; production would use The Graph indexer |
| RPC endpoint unavailability | Medium | App falls back to local cached data when blockchain is unreachable |
| Booking spam | Low | Each booking requires gas fee (economic deterrent); `registeredUsers` check prevents anonymous spam |

### 6. Elevation of Privilege

| Threat | Risk | Mitigation |
|--------|------|------------|
| Reentrancy attack on escrow | Critical | `nonReentrant` modifier on `payBooking`, `completeBooking`, `cancelBooking` |
| Unauthorized booking cancellation | High | `require(booking.userAddress == msg.sender)` enforced |
| Unauthorized station modification | High | `require(p2pStations[_stationId].owner == msg.sender)` enforced |
| Draining escrow funds | Critical | Funds only released to `booking.beneficiary` on `completeBooking`; refunded only to `booking.userAddress` on `cancelBooking` |
| Double-spending energy credits | Medium | Credits deducted atomically in `listEnergy`; `require(energyCredits >= amount)` checked |

## Smart Contract Security Measures

| Measure | Implementation | Contract Lines |
|---------|---------------|---------------|
| Reentrancy guard | Custom `nonReentrant` modifier (lock variable) | 10-17 |
| Access control | `msg.sender` checks on all state-changing functions | Throughout |
| Input validation | `require` statements for all parameters | Throughout |
| Double-booking prevention | Time-overlap check in `createBooking` | 298-308 |
| Escrow pattern | Funds held in contract, released/refunded atomically | 337-405 |
| Checks-Effects-Interactions | State updated before ETH transfers | 366-372, 394-401 |
| Integer overflow protection | Solidity ^0.8.20 built-in overflow checks | Compiler |
| Event logging | Events emitted for all state changes (audit trail) | Throughout |

## Application Security Measures

| Measure | Implementation |
|---------|---------------|
| Secure key storage | `flutter_secure_storage` (iOS Keychain / Android Keystore) |
| No server-side key storage | Private keys never leave the device |
| External wallet delegation | MetaMask/WalletConnect handle signing externally |
| Input validation | Hex format validation for addresses, length/range checks on all inputs |
| Error handling | Try-catch with fallback to local storage; no silent failures |
| Data export/deletion | GDPR-aligned: export as JSON, clear local cache, delete account |

## Known Limitations

1. **No formal audit**: Contract has not been audited by a third-party security firm
2. **No automated testing**: No Slither/Mythril analysis performed (recommended for mainnet)
3. **Testnet only**: Deployed on Sepolia testnet; mainnet deployment requires additional security review
4. **Public blockchain**: All transaction data is publicly visible (wallet addresses, amounts, station locations)
5. **No upgrade path**: Contract uses no proxy pattern; bugs require redeployment

## Recommendations for Production

1. Run Slither and Mythril static analysis on EVFinder.sol
2. Commission a third-party smart contract audit
3. Implement a proxy pattern (e.g., UUPS) for upgradeability
4. Add an emergency pause mechanism (`Pausable` from OpenZeppelin)
5. Move API keys and config to environment variables
6. Implement rate limiting on the application layer
7. Add monitoring and alerting for unusual contract activity
