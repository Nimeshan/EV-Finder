# EV Finder Smart Contracts

This directory contains the Solidity smart contracts for the EV Finder application.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file in the contracts directory:
```
PRIVATE_KEY=your_private_key_here
SEPOLIA_URL=https://rpc.sepolia.org
GOERLI_URL=https://rpc.ankr.com/eth_goerli
MUMBAI_URL=https://rpc-mumbai.maticvigil.com
```

## Compile

```bash
npm run compile
```

## Deploy

### Deploy to Sepolia Testnet:
```bash
npm run deploy:sepolia
```

### Deploy to Goerli Testnet:
```bash
npm run deploy:goerli
```

### Deploy to Mumbai Testnet (Polygon):
```bash
npm run deploy:mumbai
```

## Contract Address

After deployment, update the `contractAddress` in `lib/services/web3_service.dart` with the deployed contract address.

## Contract Functions

- `registerUser(string _name)` - Register a new user
- `isUserRegistered(address _address)` - Check if user is registered
- `getUser(address _address)` - Get user information
- `updateUserName(string _name)` - Update user name

## Testing

```bash
npm test
```


