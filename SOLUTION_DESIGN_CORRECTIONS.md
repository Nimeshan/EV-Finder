# Solution Design (Section 4.2) Corrections for Report/Artefact Alignment

This document lists corrections to apply to your **Design and Implementation** report (Deliverable 3) so that the written **Solution Design** matches the actual EV Finder codebase. Use it when updating your Artefact or report document.

---

## Solution Design (4.2) Verification Against Codebase

Comparison of your written solution design with the actual EV Finder implementation.

### What is correct

- **Overall architecture:** Three-layer idea (UI, application, blockchain) matches. The app has a Flutter UI, a service layer that talks to the chain, and a blockchain layer.
- **P2P charging, wallet connection, booking, payments, transparency:** All present. Users connect a wallet (MetaMask on web, WalletConnect on mobile), search stations, book, pay via contract, and data is recorded on-chain.
- **Testnets:** Sepolia (and Goerli, Mumbai in code) are used for development; no real money.
- **Workflow:** Connect wallet → search stations → select & book → payment → recorded on-chain is accurate. Booking uses time-conflict checks; payment uses escrow; completion releases funds to the station owner.
- **Core capabilities:** Station registration, booking with conflict checks, escrow payments, refunds on cancel, and transaction recording are all implemented in the contract and used by the app.

### Inaccuracies to fix

#### 1. Smart contract design: one contract, not three

**Document says:** "Three primary smart contracts: Station Registry Contract, Booking Contract, Payment Contract."

**Actual project:** A single Solidity contract, [contracts/EVFinder.sol](contracts/EVFinder.sol), implements all of this:

- User auth: `registerUser`, `getUser`, `isUserRegistered`, `updateUserName`
- Station registry: `registerStation`, `updateStation`, `deactivateStation`, P2PStation struct, `getAllActiveP2PStations`, etc.
- Booking: `createBooking`, `getBooking`, `getStationActiveBookings`, time-conflict checks
- Payment/escrow: `payBooking` (escrow), `completeBooking` (release to beneficiary), `cancelBooking` (refund)
- Transactions: `recordTransaction`, `getTransaction`, `getUserTransactionIds`
- Extras: reviews, energy trading, reward points

**Recommendation:** Reword 4.2 to say the system uses one smart contract (e.g. "EVFinder contract") that provides station registry, booking, and payment/escrow functionality, rather than three separate contracts.

##### 2. User interface: Flutter multi-platform, not only "Flutter Web"

**Document says:** "Web-based interface", "Flutter Web", "responsive user interface and cross-platform compatibility."

**Actual project:** The app is a full multi-platform Flutter app:

- **Web:** MetaMask via [web/metamask_connector.js](web/metamask_connector.js) and [lib/services/web3_js_bridge_web.dart](lib/services/web3_js_bridge_web.dart).
- **Mobile:** WalletConnect ([lib/services/wallet_connect_service.dart](lib/services/wallet_connect_service.dart)) and in-app wallet; `kIsWeb` is used to branch (e.g. [lib/screens/login_screen.dart](lib/screens/login_screen.dart)).

**Recommendation:** Describe the UI as a Flutter application for web and mobile, with a web-based flow (e.g. MetaMask) on web and WalletConnect/in-app wallet on mobile, rather than only "Flutter Web."

#### 3. Application layer: web3dart, not Web3.js or Ethers.js

**Document says:** "Application layer interacts with smart contracts through blockchain libraries such as Web3.js or Ethers.js."

**Actual project:** The Flutter app uses **web3dart** ([pubspec.yaml](pubspec.yaml): `web3dart: ^2.7.3`) in [lib/services/web3_service.dart](lib/services/web3_service.dart) for RPC, contract calls, and ABI encoding. On the web build, a small JavaScript bridge is used to invoke MetaMask for signing; the main blockchain interaction in the app is via web3dart, not Web3.js or Ethers.js in the Dart layer.

**Recommendation:** State that the application layer interacts with the blockchain using web3dart (and, on web, a JS bridge to MetaMask for signing), rather than "Web3.js or Ethers.js."

#### 4. Charging station data: hybrid (API + blockchain), not only blockchain

**Document says:** "Retrieving charging station data" and "The system retrieves station data from the blockchain registry."

**Actual project:** Stations come from two sources ([lib/services/charging_station_service.dart](lib/services/charging_station_service.dart)):

- Open Charge Map API (`https://api.openchargemap.io/v3/poi`) for public stations.
- Blockchain: P2P stations from the EVFinder contract via [lib/services/p2p_station_service.dart](lib/services/p2p_station_service.dart) and `Web3Service.getAllActiveP2PStations()`.

Results are merged and sorted by distance. Demo mode uses mock data.

**Recommendation:** Clarify that station discovery is hybrid: public stations from Open Charge Map (or mock in demo) and P2P stations from the blockchain registry.

#### 5. Payment: escrow inside the same contract

**Document says:** A separate "Payment Contract" "securely transfers funds to the station owner."

**Actual project:** There is no separate payment contract. The EVFinder contract holds ETH in escrow (`payBooking`), then releases to the beneficiary on `completeBooking` or refunds on `cancelBooking` ([SECURITY.md](SECURITY.md), contract around lines 335–406).

**Recommendation:** Describe payment as escrow and release/refund handled by the same EVFinder contract, not a standalone "Payment Contract."

### Summary table

| Topic | Document (4.2) | Actual project |
|-------|-----------------|----------------|
| Smart contracts | Three (Registry, Booking, Payment) | One contract: EVFinder.sol |
| UI platform | Flutter Web, web-based | Flutter web + mobile (MetaMask / WalletConnect) |
| Blockchain library | Web3.js or Ethers.js | web3dart (+ JS bridge for MetaMask on web) |
| Station data source | Blockchain registry | Open Charge Map API + blockchain P2P registry |
| Payment | Separate Payment Contract | Escrow in EVFinder (payBooking → completeBooking / cancelBooking) |

### Optional: extra features not in the document

If you want 4.2 to reflect the full system, you could briefly mention:

- Reviews and ratings (on-chain in EVFinder).
- Energy trading (list/purchase energy credits).
- Reward points (incentives for sessions and P2P hosting).
- Wallet options: MetaMask (web), WalletConnect (mobile), and in-app wallet.

Applying the corrections above will align section 4.2 with the current codebase while keeping the same high-level architecture and workflow.

---

## Suggested wording for the report (by topic)

### 1. Smart contract design

**Current wording (incorrect):**  
"The system consists of three primary smart contracts: Station Registry Contract, Booking Contract, Payment Contract."

**Correction:**  
The system uses a **single** Solidity contract, **EVFinder** (`contracts/EVFinder.sol`), which implements all of the following in one deployment:

- **User authentication**: `registerUser`, `getUser`, `isUserRegistered`, `updateUserName`
- **Station registry**: `registerStation`, `updateStation`, `deactivateStation`, P2PStation storage, `getAllActiveStations`, `getStation`, `getOwnerStations`
- **Booking**: `createBooking`, `getBooking`, `getStationActiveBookings`, time-conflict checks
- **Payment / escrow**: `payBooking` (escrow), `completeBooking` (release to beneficiary), `cancelBooking` (refund)
- **Transaction records**: `recordTransaction`, `getTransaction`, `getUserTransactionIds`, `getTransactions`
- **Additional features**: reviews, energy trading, reward points

**Suggested wording for report:**  
"The system is built around a single smart contract (EVFinder) that provides station registry, booking with conflict checks, and payment via escrow, along with user authentication, transaction recording, reviews, energy trading, and reward points."

---

## 2. User interface: Flutter multi-platform, not only “Flutter Web”

**Current wording (incomplete):**  
"Web-based interface", "Flutter Web", "responsive user interface and cross-platform compatibility."

**Correction:**  
The application is a **multi-platform** Flutter app:

- **Web**: MetaMask via a JavaScript bridge (`web/metamask_connector.js`, `lib/services/web3_js_bridge_web.dart`) for wallet connection and signing.
- **Mobile**: WalletConnect and in-app wallet options; the code uses `kIsWeb` to choose between web and mobile flows (e.g. in `lib/screens/login_screen.dart`).

**Suggested wording for report:**  
"The user interface is implemented as a Flutter application for **web and mobile**. On web, users connect via MetaMask; on mobile, via WalletConnect or the in-app wallet. The UI supports wallet connection, station search, booking, and secure payments on both platforms."

---

### 3. Application layer: web3dart, not Web3.js or Ethers.js

**Current wording (incorrect):**  
"Application layer interacts with smart contracts through blockchain libraries such as Web3.js or Ethers.js."

**Correction:**  
The Flutter app uses the **web3dart** package (`pubspec.yaml`: `web3dart: ^2.7.3`) in `lib/services/web3_service.dart` for RPC, contract calls, and ABI encoding. On web, a small JavaScript bridge is used only to invoke MetaMask for signing; the main blockchain interaction in the app is via **web3dart**, not Web3.js or Ethers.js in the application layer.

**Suggested wording for report:**  
"The application layer communicates with the blockchain using the **web3dart** library. On web builds, a JavaScript bridge is used to request transaction signing via MetaMask."

---

### 4. Charging station data: hybrid (API + blockchain), not only blockchain

**Current wording (incomplete):**  
"Retrieving charging station data", "The system retrieves station data from the blockchain registry."

**Correction:**  
Stations are loaded from **two** sources (`lib/services/charging_station_service.dart`):

- **Open Charge Map API** (`https://api.openchargemap.io/v3/poi`) for public stations.
- **Blockchain**: P2P stations from the EVFinder contract via `P2PStationService` and `Web3Service.getAllActiveP2PStations()`.

Results are merged and sorted by distance. Demo mode can use mock data instead of the API.

**Suggested wording for report:**  
"Station discovery is **hybrid**: public stations are fetched from the Open Charge Map API (or mock data in demo mode), and P2P stations are read from the blockchain registry. The app merges both sources and presents them by distance."

---

### 5. Payment: escrow in the same contract, not a separate “Payment Contract”

**Current wording (incorrect):**  
A separate "Payment Contract" that "securely transfers funds to the station owner."

**Correction:**  
There is no separate payment contract. The **EVFinder** contract holds ETH in escrow in `payBooking`, then releases to the beneficiary in `completeBooking` or refunds the user in `cancelBooking` (see `SECURITY.md` and the contract).

**Suggested wording for report:**  
"Payments are handled by the same EVFinder contract: users pay into escrow with `payBooking`; funds are released to the station owner on `completeBooking` or refunded to the user on `cancelBooking`."

---

## Alignment with assignment brief (CO3008)

- **Deliverable 3** asks for a design that is "appropriate for your project" (e.g. system architecture) and a critical review of implementation and testing. Applying the corrections above keeps the written design aligned with the implemented artefact and supports an accurate implementation section and evaluation (Deliverable 4).

---

## Code fixes applied (incomplete functionality)

The following incomplete behaviour in the codebase was fixed so that the artefact matches the design (P2P station registration, update, and deactivate on-chain):

1. **Station id after registration**  
   After a successful on-chain `registerStation`, the app now reads `stationCounter` from the contract and uses that as the P2P station id. Previously the app used a local timestamp id, so updates/deactivates could not target the correct on-chain station.

2. **`getStationCounter()` in Web3Service**  
   A new method was added to read the contract’s `stationCounter` (and the ABI was extended with the public getter). This is used after registration to set the correct station id.

3. **P2P station update and deactivate on-chain**  
   `P2PStationService.updateStation` now calls `Web3Service.updateStationOnChain` when the current wallet is the station owner, so price and active status stay in sync with the contract. `deactivateStation` already delegated to `updateStation(isActive: false)`, so it now updates the chain as well. If the contract is not deployed or the call fails, the local cache is still updated so the app continues to work offline or without a deployed contract.
