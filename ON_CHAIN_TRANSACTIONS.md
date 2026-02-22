# On-Chain Transaction Storage

The EV Finder app now stores all transactions on the blockchain using the EVFinder smart contract. This ensures transparency, immutability, and permanent record-keeping.

## Contract Updates

The `EVFinder.sol` contract has been updated to include:

### Transaction Structure
```solidity
struct Transaction {
    uint256 id;
    address userAddress;
    string stationName;
    uint256 timestamp;
    uint256 energy;      // in kWh (scaled by 1000, e.g., 15.1 kWh = 15100)
    uint256 amount;      // in USD cents (scaled by 100, e.g., $12.11 = 1211)
    bool isCredit;
    string txHash;       // Blockchain transaction hash
}
```

### New Functions

1. **`recordTransaction`**: Records a new transaction on-chain
   - Requires user to be registered
   - Stores transaction with all details
   - Emits `TransactionRecorded` event

2. **`getTransaction`**: Retrieves a single transaction by ID

3. **`getUserTransactionIds`**: Gets all transaction IDs for a user

4. **`getUserTransactionCount`**: Gets the count of transactions for a user

5. **`getTransactions`**: Gets multiple transactions by IDs

## Deployment

### 1. Update Contract Address

After deploying the updated contract, update the contract address in `lib/services/web3_service.dart`:

```dart
static const String contractAddress = 'YOUR_DEPLOYED_CONTRACT_ADDRESS';
```

### 2. Deploy the Contract

```bash
cd contracts
npm install
npx hardhat compile
npx hardhat run scripts/deploy.js --network sepolia
```

### 3. Update ABI

The contract ABI has been updated in `lib/services/web3_service.dart` to include all transaction-related functions.

## How It Works

### Saving Transactions

1. When a payment is made, the app:
   - Sends ETH payment via MetaMask
   - Records the transaction on-chain using `recordTransaction`
   - Also saves locally as cache/backup

2. The transaction includes:
   - Station name
   - Energy consumed (in kWh)
   - Amount paid (in USD)
   - Payment transaction hash
   - Timestamp

### Reading Transactions

1. The app first tries to fetch from blockchain
2. If blockchain is unavailable, falls back to local cache
3. Transactions are sorted by timestamp (newest first)

### Data Format

- **Energy**: Stored as integer (multiplied by 1000)
  - Example: 15.1 kWh → 15100
  - Converted back when reading: 15100 / 1000 = 15.1 kWh

- **Amount**: Stored as integer in cents (multiplied by 100)
  - Example: $12.11 → 1211 cents
  - Converted back when reading: 1211 / 100 = $12.11

## Benefits

1. **Permanence**: Transactions are permanently stored on blockchain
2. **Transparency**: All transactions are publicly verifiable
3. **Immutability**: Once recorded, transactions cannot be altered
4. **Decentralization**: No single point of failure
5. **Auditability**: Easy to verify and audit transaction history

## Fallback Mechanism

The app includes a fallback mechanism:
- If blockchain is unavailable, transactions are saved locally
- Local cache is used when blockchain read fails
- Once blockchain is available, transactions sync automatically

## Gas Costs

Recording a transaction on-chain requires gas fees. On Sepolia testnet:
- Estimated gas: ~50,000 - 100,000 gas
- Cost: Minimal on testnet (free testnet ETH)

## Testing

1. Make a payment through the app
2. Check transaction on Sepolia Etherscan
3. Verify transaction appears in History screen
4. Check that transaction is stored on-chain using contract view functions

## Future Enhancements

- Batch transaction recording to reduce gas costs
- Event-based transaction syncing
- Transaction filtering and search
- Export transaction history
- Integration with accounting systems


