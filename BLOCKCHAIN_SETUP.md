# Blockchain Setup Guide for EV Finder

## Overview

The EV Finder app uses Solidity smart contracts deployed on Ethereum testnets for user authentication via MetaMask.

## Prerequisites

1. **MetaMask Wallet**: Install MetaMask browser extension or mobile app
2. **Testnet ETH**: Get testnet ETH from faucets:
   - Sepolia: https://sepoliafaucet.com/
   - Goerli: https://goerli-faucet.pk910.de/
   - Mumbai: https://faucet.polygon.technology/

## Smart Contract Deployment

### Step 1: Install Dependencies

```bash
cd contracts
npm install
```

### Step 2: Configure Environment

Create a `.env` file in the `contracts` directory:

```env
PRIVATE_KEY=your_wallet_private_key_here
SEPOLIA_URL=https://rpc.sepolia.org
```

**⚠️ WARNING**: Never commit your private key to version control!

### Step 3: Deploy Contract

```bash
npm run deploy:sepolia
```

This will:
- Compile the Solidity contract
- Deploy to Sepolia testnet
- Save the contract address to `deployments/sepolia.json`

### Step 4: Update Flutter App

After deployment, update the contract address in `lib/services/web3_service.dart`:

```dart
static const String contractAddress = 'YOUR_DEPLOYED_CONTRACT_ADDRESS';
```

## Flutter App Setup

### Step 1: Install Dependencies

```bash
flutter pub get
```

### Step 2: Configure Network

The app is configured to use Sepolia testnet by default. To change:

1. Open `lib/services/web3_service.dart`
2. Update the `initialize()` call in `login_screen.dart`:
   ```dart
   await _web3Service.initialize(network: 'sepolia'); // or 'goerli', 'mumbai'
   ```

## MetaMask Connection

### For Web (Chrome/Browser):

1. Install MetaMask browser extension
2. Create or import a wallet
3. Switch to Sepolia testnet
4. Click "Sign In With Metamask" in the app
5. Approve the connection in MetaMask

### For Mobile:

1. Install MetaMask mobile app
2. The app will open MetaMask via deep link
3. Approve the connection
4. Return to the app

## Testing

1. Make sure MetaMask is connected to Sepolia testnet
2. Ensure you have testnet ETH for gas fees
3. Click "Sign In With Metamask"
4. Approve the connection
5. If not registered, enter your name
6. Complete registration

## Troubleshooting

### "Failed to connect to MetaMask"
- Ensure MetaMask is installed and unlocked
- Check that you're on the correct testnet
- Try refreshing the page/app

### "Insufficient funds"
- Get testnet ETH from a faucet
- Ensure you have enough for gas fees

### "Contract not found"
- Verify the contract address is correct
- Ensure the contract is deployed to the same network

## Security Notes

- Never share your private key
- Only use testnets for development
- Use a separate wallet for testing
- Don't use mainnet private keys


