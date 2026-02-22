# Complete Setup Guide for EV Finder with Blockchain Integration

## Overview

This guide will help you set up the EV Finder app with Solidity smart contract backend and MetaMask integration.

## Part 1: Smart Contract Deployment

### Prerequisites
- Node.js (v16 or higher)
- npm or yarn
- MetaMask wallet with testnet ETH

### Step 1: Install Contract Dependencies

```bash
cd contracts
npm install
```

### Step 2: Configure Environment

1. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

2. Edit `.env` and add your wallet private key:
```env
PRIVATE_KEY=your_private_key_here
```

⚠️ **WARNING**: Never commit your `.env` file or share your private key!

### Step 3: Get Testnet ETH

Get testnet ETH from faucets:
- **Sepolia**: https://sepoliafaucet.com/
- **Goerli**: https://goerli-faucet.pk910.de/
- **Mumbai**: https://faucet.polygon.technology/

### Step 4: Deploy Contract

```bash
npm run deploy:sepolia
```

This will:
- Compile the Solidity contract
- Deploy to Sepolia testnet
- Save contract address to `deployments/sepolia.json`

### Step 5: Update Flutter App

1. Open `lib/services/web3_service.dart`
2. Find the line: `static const String contractAddress = 'YOUR_CONTRACT_ADDRESS_HERE';`
3. Replace with your deployed contract address from `deployments/sepolia.json`

## Part 2: Flutter App Setup

### Step 1: Install Dependencies

```bash
flutter pub get
```

### Step 2: Configure Network

The app defaults to Sepolia testnet. To change:

1. Open `lib/screens/login_screen.dart`
2. Find: `await _web3Service.initialize(network: 'sepolia');`
3. Change to: `'goerli'` or `'mumbai'` if needed

## Part 3: MetaMask Setup

### For Web (Chrome/Browser):

1. Install [MetaMask Extension](https://metamask.io/download/)
2. Create or import a wallet
3. Switch to Sepolia testnet:
   - Click network dropdown
   - Select "Sepolia" or add custom network:
     - Network Name: Sepolia
     - RPC URL: https://rpc.sepolia.org
     - Chain ID: 11155111
     - Currency Symbol: ETH
4. Get testnet ETH from faucet
5. Open the app and click "Sign In With Metamask"
6. Approve the connection in MetaMask popup

### For Mobile:

1. Install [MetaMask Mobile App](https://metamask.io/download/)
2. Create or import a wallet
3. Switch to Sepolia testnet
4. Get testnet ETH
5. Click "Sign In With Metamask" - it will open MetaMask app
6. Approve the connection
7. Return to the app

## Part 4: Testing the Integration

1. **Start the app**: `flutter run`
2. **Click "Sign In With Metamask"**
3. **Approve connection** in MetaMask
4. **If not registered**: Enter your name in the registration dialog
5. **Complete registration**: User info is saved locally and on blockchain
6. **Navigate to home**: You should see the map screen

## Troubleshooting

### "MetaMask is not installed"
- Install MetaMask extension/app
- Refresh the page/app

### "Failed to connect to MetaMask"
- Ensure MetaMask is unlocked
- Check you're on the correct testnet
- Try disconnecting and reconnecting

### "Insufficient funds"
- Get testnet ETH from a faucet
- Ensure you have enough for gas fees

### "Contract not found"
- Verify contract address in `web3_service.dart`
- Ensure contract is deployed to the same network
- Check network in MetaMask matches app configuration

### Contract Deployment Fails
- Check you have testnet ETH
- Verify private key in `.env` is correct
- Check RPC URL is accessible

## Security Best Practices

1. ✅ Use separate wallets for testing
2. ✅ Never commit private keys
3. ✅ Only use testnets for development
4. ✅ Use environment variables for sensitive data
5. ✅ Verify contract addresses before using

## Next Steps

- Implement transaction signing for user registration
- Add payment functionality using smart contracts
- Implement charging session recording on blockchain
- Add transaction history from blockchain


