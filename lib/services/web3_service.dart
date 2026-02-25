import 'dart:async';
import 'dart:typed_data';
import 'package:convert/convert.dart' show hex;

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

// Platform-specific: web uses dart:js/MetaMask; mobile uses WalletConnect.
import 'web3_js_bridge_web.dart'
    if (dart.library.io) 'web3_js_bridge_stub.dart' as js_bridge;

import 'wallet_connect_service.dart';
import 'in_app_wallet_service.dart';

class Web3Service {
  static const String sepoliaRpcUrl = 'https://rpc.sepolia.org';
  static const String goerliRpcUrl = 'https://rpc.ankr.com/eth_goerli';
  static const String mumbaiRpcUrl = 'https://rpc-mumbai.maticvigil.com';
  static const int sepoliaChainId = 11155111;
  
  // Update this with your deployed contract address
  static const String contractAddress = 'YOUR_CONTRACT_ADDRESS_HERE';
  
  // Contract ABI (Application Binary Interface)
  static const String contractABI = '''
  [
    {
      "inputs": [{"internalType": "string", "name": "_name", "type": "string"}],
      "name": "registerUser",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "_address", "type": "address"}],
      "name": "isUserRegistered",
      "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "_address", "type": "address"}],
      "name": "getUser",
      "outputs": [
        {"internalType": "address", "name": "walletAddress", "type": "address"},
        {"internalType": "string", "name": "name", "type": "string"},
        {"internalType": "uint256", "name": "registrationTimestamp", "type": "uint256"},
        {"internalType": "bool", "name": "isRegistered", "type": "bool"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "string", "name": "_name", "type": "string"}],
      "name": "updateUserName",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "string", "name": "_stationName", "type": "string"},
        {"internalType": "uint256", "name": "_energy", "type": "uint256"},
        {"internalType": "uint256", "name": "_amount", "type": "uint256"},
        {"internalType": "bool", "name": "_isCredit", "type": "bool"},
        {"internalType": "string", "name": "_txHash", "type": "string"}
      ],
      "name": "recordTransaction",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "_transactionId", "type": "uint256"}],
      "name": "getTransaction",
      "outputs": [
        {"internalType": "uint256", "name": "id", "type": "uint256"},
        {"internalType": "address", "name": "userAddress", "type": "address"},
        {"internalType": "string", "name": "stationName", "type": "string"},
        {"internalType": "uint256", "name": "timestamp", "type": "uint256"},
        {"internalType": "uint256", "name": "energy", "type": "uint256"},
        {"internalType": "uint256", "name": "amount", "type": "uint256"},
        {"internalType": "bool", "name": "isCredit", "type": "bool"},
        {"internalType": "string", "name": "txHash", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "_userAddress", "type": "address"}],
      "name": "getUserTransactionIds",
      "outputs": [{"internalType": "uint256[]", "name": "", "type": "uint256[]"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "_userAddress", "type": "address"}],
      "name": "getUserTransactionCount",
      "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256[]", "name": "_transactionIds", "type": "uint256[]"}],
      "name": "getTransactions",
      "outputs": [
        {
          "components": [
            {"internalType": "uint256", "name": "id", "type": "uint256"},
            {"internalType": "address", "name": "userAddress", "type": "address"},
            {"internalType": "string", "name": "stationName", "type": "string"},
            {"internalType": "uint256", "name": "timestamp", "type": "uint256"},
            {"internalType": "uint256", "name": "energy", "type": "uint256"},
            {"internalType": "uint256", "name": "amount", "type": "uint256"},
            {"internalType": "bool", "name": "isCredit", "type": "bool"},
            {"internalType": "string", "name": "txHash", "type": "string"}
          ],
          "internalType": "struct EVFinder.Transaction[]",
          "name": "",
          "type": "tuple[]"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "string", "name": "_name", "type": "string"},
        {"internalType": "string", "name": "_locationAddress", "type": "string"},
        {"internalType": "int256", "name": "_latitude", "type": "int256"},
        {"internalType": "int256", "name": "_longitude", "type": "int256"},
        {"internalType": "string", "name": "_connectorType", "type": "string"},
        {"internalType": "uint256", "name": "_powerKw", "type": "uint256"},
        {"internalType": "uint256", "name": "_pricePerKwh", "type": "uint256"},
        {"internalType": "bool", "name": "_isGreenEnergy", "type": "bool"}
      ],
      "name": "registerStation",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "_stationId", "type": "uint256"},
        {"internalType": "uint256", "name": "_pricePerKwh", "type": "uint256"},
        {"internalType": "bool", "name": "_isActive", "type": "bool"}
      ],
      "name": "updateStation",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "_stationId", "type": "uint256"}],
      "name": "deactivateStation",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "_stationId", "type": "uint256"}],
      "name": "getStation",
      "outputs": [
        {
          "components": [
            {"internalType": "uint256", "name": "id", "type": "uint256"},
            {"internalType": "address", "name": "owner", "type": "address"},
            {"internalType": "string", "name": "name", "type": "string"},
            {"internalType": "string", "name": "locationAddress", "type": "string"},
            {"internalType": "int256", "name": "latitude", "type": "int256"},
            {"internalType": "int256", "name": "longitude", "type": "int256"},
            {"internalType": "string", "name": "connectorType", "type": "string"},
            {"internalType": "uint256", "name": "powerKw", "type": "uint256"},
            {"internalType": "uint256", "name": "pricePerKwh", "type": "uint256"},
            {"internalType": "bool", "name": "isGreenEnergy", "type": "bool"},
            {"internalType": "bool", "name": "isActive", "type": "bool"},
            {"internalType": "uint256", "name": "createdAt", "type": "uint256"}
          ],
          "internalType": "struct EVFinder.P2PStation",
          "name": "",
          "type": "tuple"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getAllActiveStations",
      "outputs": [
        {
          "components": [
            {"internalType": "uint256", "name": "id", "type": "uint256"},
            {"internalType": "address", "name": "owner", "type": "address"},
            {"internalType": "string", "name": "name", "type": "string"},
            {"internalType": "string", "name": "locationAddress", "type": "string"},
            {"internalType": "int256", "name": "latitude", "type": "int256"},
            {"internalType": "int256", "name": "longitude", "type": "int256"},
            {"internalType": "string", "name": "connectorType", "type": "string"},
            {"internalType": "uint256", "name": "powerKw", "type": "uint256"},
            {"internalType": "uint256", "name": "pricePerKwh", "type": "uint256"},
            {"internalType": "bool", "name": "isGreenEnergy", "type": "bool"},
            {"internalType": "bool", "name": "isActive", "type": "bool"},
            {"internalType": "uint256", "name": "createdAt", "type": "uint256"}
          ],
          "internalType": "struct EVFinder.P2PStation[]",
          "name": "",
          "type": "tuple[]"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "_owner", "type": "address"}],
      "name": "getOwnerStations",
      "outputs": [{"internalType": "uint256[]", "name": "", "type": "uint256[]"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "_amount", "type": "uint256"}],
      "name": "addEnergyCredits",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "_user", "type": "address"}],
      "name": "getEnergyCredits",
      "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "_energyKwh", "type": "uint256"},
        {"internalType": "uint256", "name": "_pricePerKwh", "type": "uint256"}
      ],
      "name": "listEnergy",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "_listingId", "type": "uint256"},
        {"internalType": "string", "name": "_txHash", "type": "string"}
      ],
      "name": "purchaseEnergy",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "_listingId", "type": "uint256"}],
      "name": "cancelEnergyListing",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getActiveListings",
      "outputs": [
        {
          "components": [
            {"internalType": "uint256", "name": "id", "type": "uint256"},
            {"internalType": "address", "name": "seller", "type": "address"},
            {"internalType": "uint256", "name": "energyKwh", "type": "uint256"},
            {"internalType": "uint256", "name": "pricePerKwh", "type": "uint256"},
            {"internalType": "uint256", "name": "totalPrice", "type": "uint256"},
            {"internalType": "bool", "name": "isActive", "type": "bool"},
            {"internalType": "bool", "name": "isSold", "type": "bool"},
            {"internalType": "address", "name": "buyer", "type": "address"},
            {"internalType": "string", "name": "txHash", "type": "string"},
            {"internalType": "uint256", "name": "createdAt", "type": "uint256"}
          ],
          "internalType": "struct EVFinder.EnergyListing[]",
          "name": "",
          "type": "tuple[]"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "_seller", "type": "address"}],
      "name": "getSellerListings",
      "outputs": [{"internalType": "uint256[]", "name": "", "type": "uint256[]"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "_stationId", "type": "uint256"},
        {"internalType": "uint256", "name": "_bookingId", "type": "uint256"},
        {"internalType": "uint8", "name": "_rating", "type": "uint8"},
        {"internalType": "string", "name": "_comment", "type": "string"}
      ],
      "name": "submitReview",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "_stationId", "type": "uint256"}],
      "name": "getStationReviews",
      "outputs": [
        {
          "components": [
            {"internalType": "uint256", "name": "id", "type": "uint256"},
            {"internalType": "address", "name": "reviewer", "type": "address"},
            {"internalType": "uint256", "name": "stationId", "type": "uint256"},
            {"internalType": "uint256", "name": "bookingId", "type": "uint256"},
            {"internalType": "uint8", "name": "rating", "type": "uint8"},
            {"internalType": "string", "name": "comment", "type": "string"},
            {"internalType": "uint256", "name": "timestamp", "type": "uint256"}
          ],
          "internalType": "struct EVFinder.Review[]",
          "name": "",
          "type": "tuple[]"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "_stationId", "type": "uint256"}],
      "name": "getStationAverageRating",
      "outputs": [
        {"internalType": "uint256", "name": "totalRating", "type": "uint256"},
        {"internalType": "uint256", "name": "count", "type": "uint256"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "string", "name": "_stationId", "type": "string"},
        {"internalType": "string", "name": "_connectorType", "type": "string"},
        {"internalType": "uint256", "name": "_startTime", "type": "uint256"},
        {"internalType": "uint256", "name": "_endTime", "type": "uint256"},
        {"internalType": "uint256", "name": "_energyKwh", "type": "uint256"},
        {"internalType": "uint256", "name": "_amountUsd", "type": "uint256"}
      ],
      "name": "createBooking",
      "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "_bookingId", "type": "uint256"},
        {"internalType": "address", "name": "_beneficiary", "type": "address"}
      ],
      "name": "payBooking",
      "outputs": [],
      "stateMutability": "payable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "_bookingId", "type": "uint256"},
        {"internalType": "string", "name": "_txHash", "type": "string"}
      ],
      "name": "completeBooking",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "_bookingId", "type": "uint256"}],
      "name": "cancelBooking",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getBookingCounter",
      "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "_user", "type": "address"}],
      "name": "getRewardPoints",
      "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "defaultPaymentReceiver",
      "outputs": [{"internalType": "address", "name": "", "type": "address"}],
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  Web3Client? _client;
  DeployedContract? _contract;
  EthereumAddress? _contractAddr;

  // Initialize Web3 connection
  Future<void> initialize({String network = 'sepolia'}) async {
    String rpcUrl;
    switch (network.toLowerCase()) {
      case 'sepolia':
        rpcUrl = sepoliaRpcUrl;
        break;
      case 'goerli':
        rpcUrl = goerliRpcUrl;
        break;
      case 'mumbai':
        rpcUrl = mumbaiRpcUrl;
        break;
      default:
        rpcUrl = sepoliaRpcUrl;
    }

    _client = Web3Client(rpcUrl, http.Client());
    
    // Only initialize contract if address is set
    if (contractAddress != 'YOUR_CONTRACT_ADDRESS_HERE') {
      _contractAddr = EthereumAddress.fromHex(contractAddress);
      final contractAbi = ContractAbi.fromJson(contractABI, 'EVFinder');
      _contract = DeployedContract(contractAbi, _contractAddr!);
    }
  }

  /// Create or get in-app wallet (no MetaMask needed). Returns address.
  Future<String> connectInAppWallet() async {
    await initialize(network: 'sepolia');
    return InAppWalletService.instance.createOrGetInAppWallet();
  }

  /// True if the current saved wallet is the in-app one (no external wallet).
  Future<bool> hasInAppWallet() async =>
      InAppWalletService.instance.hasInAppWallet();

  // Connect to MetaMask (web) or WalletConnect (mobile)
  Future<String?> connectWallet() async {
    try {
      if (js_bridge.Web3JsBridge.isAvailable) {
        return await _connectMetaMaskWeb();
      }
      if (WalletConnectService.isAvailable) {
        return await _connectWalletConnect();
      }
      throw UnsupportedError(
        'Wallet connection is not available on this platform.',
      );
    } catch (e) {
      debugPrint('Error connecting wallet: $e');
      rethrow; // Re-throw to show error to user
    }
  }

  Future<String?> _connectWalletConnect() async {
    try {
      final address =
          await WalletConnectService.instance.connect();
      if (address != null) {
        try {
          await WalletConnectService.instance.switchToSepolia();
        } catch (_) {
          debugPrint('Switch to Sepolia warning (continuing anyway)');
        }
      }
      return address;
    } catch (e) {
      debugPrint('WalletConnect error: $e');
      rethrow;
    }
  }

  Future<dynamic> _promiseToFuture(dynamic promise) async {
    return js_bridge.Web3JsBridge.promiseToFuture(promise);
  }

  Future<String?> _connectMetaMaskWeb() async {
    try {
      // Check if MetaMask functions are available
      if (!js_bridge.Web3JsBridge.hasConnectMetaMask()) {
        throw Exception(
          'MetaMask connector script not loaded.\n\n'
          'Troubleshooting:\n'
          '1. Check that web/metamask_connector.js exists\n'
          '2. Verify web/index.html includes the script tag\n'
          '3. Rebuild: flutter clean && flutter build web\n'
          '4. Hard refresh browser (Ctrl+Shift+R)'
        );
      }

      try {
        if (js_bridge.Web3JsBridge.hasSwitchToSepolia()) {
          final switchResult = await js_bridge.Web3JsBridge.switchToSepolia();
          if (switchResult != null) {
            final switchSuccess =
                js_bridge.Web3JsBridge.getJsResultSuccess(switchResult);
            if (!switchSuccess) {
              final switchError =
                  js_bridge.Web3JsBridge.getJsResultError(switchResult);
              debugPrint('Warning: Could not switch to Sepolia: $switchError');
              debugPrint('Note: You can continue on your current network, but Sepolia is recommended.');
            } else {
              debugPrint('Successfully switched to Sepolia testnet');
              // Wait a moment for network switch to complete
              await Future.delayed(const Duration(milliseconds: 1000));
            }
          }
        }
      } catch (e) {
        debugPrint('Warning: Network switch error (continuing anyway): $e');
        // Continue anyway - user might already be on the right network
      }

      dynamic result;
      try {
        result = await js_bridge.Web3JsBridge.connectMetaMask();
      } catch (e) {
        debugPrint('Error calling MetaMask connector: $e');
        throw Exception(
          'Failed to call MetaMask connector.\n\n'
          'Error: ${e.toString()}\n\n'
          'Please ensure:\n'
          '1. MetaMask extension is installed\n'
          '2. MetaMask is unlocked\n'
          '3. Check browser console (F12) for more details'
        );
      }
      
      if (result == null) {
        throw Exception(
          'MetaMask connection returned null.\n\n'
          'Possible causes:\n'
          '1. MetaMask is not installed\n'
          '2. MetaMask is locked\n'
          '3. JavaScript error occurred\n\n'
          'Check browser console (F12) for details.'
        );
      }
      
      final success = js_bridge.Web3JsBridge.getJsResultSuccess(result);
      if (!success) {
        final error =
            js_bridge.Web3JsBridge.getJsResultError(result) ?? 'Unknown error';
        
        debugPrint('MetaMask connection error: $error');
        
        // Provide user-friendly error messages
        String userMessage = error;
        final errorLower = error.toLowerCase();
        
        if (errorLower.contains('user rejected') || error.contains('4001')) {
          userMessage = 'Connection rejected.\n\n'
              'Please approve the connection request in MetaMask and try again.';
        } else if (errorLower.contains('not installed') || 
                   errorLower.contains('undefined') ||
                   errorLower.contains('metamask is not')) {
          userMessage = 'MetaMask is not installed.\n\n'
              'Please install MetaMask browser extension:\n'
              'https://metamask.io/download/\n\n'
              'After installation, refresh this page.';
        } else if (errorLower.contains('pending') || 
                   error.contains('32002') || 
                   error.contains('-32002')) {
          userMessage = 'Connection request already pending.\n\n'
              'Please check MetaMask for a pending connection request and approve it.';
        } else if (errorLower.contains('no accounts')) {
          userMessage = 'No accounts found.\n\n'
              'Please unlock MetaMask and ensure you have at least one account.';
        } else if (errorLower.contains('insufficient') || 
                   errorLower.contains('balance')) {
          userMessage = 'Insufficient balance.\n\n'
              'You need Sepolia testnet ETH (not mainnet ETH).\n'
              'Get free testnet ETH from: https://sepoliafaucet.com/\n\n'
              'Note: Mainnet balance does not work on testnet.';
        } else {
          // Show the actual error for debugging
          userMessage = 'Connection failed.\n\n'
              'Error: $error\n\n'
              'Please ensure:\n'
              '1. MetaMask is installed and unlocked\n'
              '2. You are on Sepolia testnet (not mainnet)\n'
              '3. You have testnet ETH (get from faucet if needed)\n'
              '4. Check browser console (F12) for details';
        }
        
        throw Exception(userMessage);
      }
      final address = js_bridge.Web3JsBridge.getJsResultAddress(result);
      if (address == null || address.isEmpty) {
        throw Exception(
          'MetaMask returned empty address.\n\n'
          'Please ensure:\n'
          '1. MetaMask is unlocked\n'
          '2. You have at least one account\n'
          '3. Try refreshing the page'
        );
      }
      
      // Validate address format
      if (!address.startsWith('0x') || address.length != 42) {
        throw Exception('Invalid wallet address format received from MetaMask.');
      }
      
      debugPrint('Successfully connected to MetaMask: $address');
      return address;
    } catch (e) {
      debugPrint('Error connecting MetaMask on web: $e');
      rethrow; // Re-throw to show error to user
    }
  }


  // Check if user is registered on blockchain
  Future<bool> isUserRegistered(String address) async {
    final addrKey = address.toLowerCase();
    try {
      if (_client == null || _contract == null) {
        // If contract not deployed, check per-wallet local storage
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool('registered_$addrKey') ?? false;
      }

      final isRegisteredFunction = _contract!.function('isUserRegistered');
      final result = await _client!.call(
        contract: _contract!,
        function: isRegisteredFunction,
        params: [EthereumAddress.fromHex(address)],
      );

      final isRegistered = result[0] as bool;

      // Cache on-chain result locally for offline/fallback use
      if (isRegistered) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('registered_$addrKey', true);
      }

      return isRegistered;
    } catch (e) {
      debugPrint('Error checking registration: $e');
      // Fallback to per-wallet local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('registered_$addrKey') ?? false;
    }
  }

  // Register user on blockchain
  Future<bool> registerUser(String address, String name) async {
    final addrKey = address.toLowerCase();
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save per-wallet (persists across sign-outs)
      await prefs.setBool('registered_$addrKey', true);
      await prefs.setString('user_name_$addrKey', name);

      // Save as active session
      await prefs.setString('wallet_address', address);
      await prefs.setString('user_name', name);

      // If contract is deployed, register on blockchain
      // Note: This requires the user to sign the transaction with MetaMask
      // For now, we save locally. In production, implement transaction signing flow.

      return true;
    } catch (e) {
      debugPrint('Error registering user: $e');
      return false;
    }
  }

  // Get user info from blockchain
  Future<Map<String, dynamic>?> getUserInfo(String address) async {
    final addrKey = address.toLowerCase();
    try {
      if (_client == null || _contract == null) {
        // Fallback to per-wallet local storage
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('user_name_$addrKey') ?? prefs.getString('user_name');
        if (name != null) {
          return {
            'walletAddress': address,
            'name': name,
            'registrationTimestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'isRegistered': true,
          };
        }
        return null;
      }

      final getUserFunction = _contract!.function('getUser');
      final result = await _client!.call(
        contract: _contract!,
        function: getUserFunction,
        params: [EthereumAddress.fromHex(address)],
      );

      final name = result[1] as String;

      // Cache name locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name_$addrKey', name);

      return {
        'walletAddress': (result[0] as EthereumAddress).hex,
        'name': name,
        'registrationTimestamp': (result[2] as BigInt).toInt(),
        'isRegistered': result[3] as bool,
      };
    } catch (e) {
      debugPrint('Error getting user info: $e');
      // Fallback to per-wallet local storage
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name_$addrKey') ?? prefs.getString('user_name');
      if (name != null) {
        return {
          'walletAddress': address,
          'name': name,
          'registrationTimestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'isRegistered': true,
        };
      }
      return null;
    }
  }

  // Save wallet address locally
  Future<void> saveWalletAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet_address', address);
  }

  // Get saved wallet address. In-app wallet first, then prefs, then MetaMask/WalletConnect.
  Future<String?> getSavedWalletAddress() async {
    if (await InAppWalletService.instance.hasInAppWallet()) {
      return InAppWalletService.instance.getInAppWalletAddress();
    }
    final prefs = await SharedPreferences.getInstance();
    String? address = prefs.getString('wallet_address');
    if (address == null || address.isEmpty) {
      if (js_bridge.Web3JsBridge.isAvailable) {
        try {
          if (js_bridge.Web3JsBridge.hasGetMetaMaskAccount()) {
            final recovered = await js_bridge.Web3JsBridge.getMetaMaskAccount();
            if (recovered != null && recovered.isNotEmpty) {
              address = recovered;
              await prefs.setString('wallet_address', address);
            }
          }
        } catch (e) {
          debugPrint('Could not recover wallet from MetaMask: $e');
        }
      } else if (WalletConnectService.isAvailable &&
          WalletConnectService.instance.isConnected) {
        address = WalletConnectService.instance.connectedAddress;
        if (address != null && address.isNotEmpty) {
          await prefs.setString('wallet_address', address);
        }
      }
    }
    return address;
  }

  // Get saved user name (checks per-wallet first, then session)
  Future<String?> getSavedUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('wallet_address');
    if (address != null) {
      final addrKey = address.toLowerCase();
      return prefs.getString('user_name_$addrKey') ?? prefs.getString('user_name');
    }
    return prefs.getString('user_name');
  }

  // Clear active session (per-wallet registration data is preserved)
  Future<void> clearWallet() async {
    if (await InAppWalletService.instance.hasInAppWallet()) {
      await InAppWalletService.instance.deleteInAppWallet();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_address');
    await prefs.remove('user_name');
    await prefs.remove(InAppWalletService.keyWalletType);
  }

  /// Send a transaction using the in-app wallet (signed locally). Returns tx hash or null.
  Future<String?> _sendWithInAppWallet({
    required String toAddress,
    required BigInt valueWei,
    Uint8List? data,
  }) async {
    if (_client == null) return null;
    final cred = await InAppWalletService.instance.getCredentials();
    if (cred == null) return null;
    try {
      final tx = Transaction(
        to: EthereumAddress.fromHex(toAddress),
        value: EtherAmount.inWei(valueWei),
        data: data,
      );
      return await _client!.sendTransaction(
        cred,
        tx,
        chainId: sepoliaChainId,
      );
    } catch (e) {
      debugPrint('In-app wallet send error: $e');
      return null;
    }
  }

  static Uint8List _hexToBytes(String hexStr) {
    final s = hexStr.startsWith('0x') ? hexStr.substring(2) : hexStr;
    return Uint8List.fromList(hex.decode(s));
  }

  // Get ETH balance for an address
  Future<double> getBalance(String address) async {
    try {
      await initialize();
      if (_client == null) {
        return 0.0;
      }

      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await _client!.getBalance(ethAddress);
      
      // Convert from Wei to ETH (1 ETH = 10^18 Wei)
      // balance is already in EtherAmount, use getValueInUnit
      final ethBalance = balance.getValueInUnit(EtherUnit.ether);
      return ethBalance;
    } catch (e) {
      debugPrint('Error getting balance: $e');
      return 0.0;
    }
  }

  // Send payment via in-app wallet, MetaMask (web), or WalletConnect (mobile)
  Future<String?> sendPayment({
    required String fromAddress,
    required String toAddress,
    required double amountInEth,
    String? data,
  }) async {
    try {
      final amountInWei =
          (amountInEth * BigInt.from(1000000000000000000).toDouble()).toInt();
      final amountHex = '0x${BigInt.from(amountInWei).toRadixString(16)}';

      if (await InAppWalletService.instance.isInAppWallet(fromAddress)) {
        final valueWei = BigInt.from(amountInWei);
        final dataBytes = data != null && data.isNotEmpty
            ? _hexToBytes(data)
            : null;
        return await _sendWithInAppWallet(
          toAddress: toAddress,
          valueWei: valueWei,
          data: dataBytes,
        );
      }

      if (WalletConnectService.isAvailable &&
          WalletConnectService.instance.isConnected) {
        final txHash = await WalletConnectService.instance.sendTransaction(
          from: fromAddress,
          to: toAddress,
          valueHex: amountHex,
          data: data,
        );
        return txHash;
      }

      if (js_bridge.Web3JsBridge.isAvailable) {
        if (!js_bridge.Web3JsBridge.hasSendTransaction()) {
          js_bridge.Web3JsBridge.defineSendTransaction();
        }
        final result = js_bridge.Web3JsBridge.sendTransaction(
            fromAddress, toAddress, amountHex);
        if (result != null) {
          final promiseResult = await _promiseToFuture(result);
          if (js_bridge.Web3JsBridge.getJsResultSuccess(promiseResult)) {
            return js_bridge.Web3JsBridge.getJsResultTxHash(promiseResult);
          } else {
            final error =
                js_bridge.Web3JsBridge.getJsResultError(promiseResult) ??
                    'Unknown error';
            throw Exception('Payment failed: $error');
          }
        }
      }

      throw Exception(
          'Connect your wallet first. On mobile, use MetaMask via WalletConnect.');
    } catch (e) {
      debugPrint('Error sending payment: $e');
      rethrow;
    }
  }

  // Get transaction receipt (to verify payment)
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    try {
      await initialize();
      if (_client == null) {
        return null;
      }

      final receipt = await _client!.getTransactionReceipt(txHash);
      if (receipt == null) {
        return null;
      }

      return {
        'txHash': receipt.transactionHash,
        'blockNumber': receipt.blockNumber,
        'status': receipt.status,
        'from': receipt.from?.hex,
        'to': receipt.to?.hex,
        'gasUsed': receipt.gasUsed?.toInt(),
      };
    } catch (e) {
      debugPrint('Error getting transaction receipt: $e');
      return null;
    }
  }

  // Record transaction on blockchain
  Future<String?> recordTransaction({
    required String userAddress,
    required String stationName,
    required double energy, // kWh
    required double amount, // USD
    required bool isCredit,
    required String txHash,
  }) async {
    try {
      if (_client == null || _contract == null) {
        debugPrint('Warning: Contract not deployed. Transaction will be saved locally only.');
        return null; // Return null to indicate it wasn't saved on-chain
      }

      // Convert energy to uint256 (multiply by 1000 to preserve 1 decimal place)
      // e.g., 15.1 kWh = 15100
      final energyScaled = BigInt.from((energy * 1000).round());
      
      // Convert amount to uint256 (multiply by 100 to convert USD to cents)
      // e.g., $12.11 = 1211
      final amountScaled = BigInt.from((amount.abs() * 100).round());

      final recordFunction = _contract!.function('recordTransaction');
      final functionCall = recordFunction.encodeCall([
        stationName,
        energyScaled,
        amountScaled,
        isCredit,
        txHash,
      ]);
      final contractAddressHex = _contractAddr!.hex;
      final dataHex =
          '0x${functionCall.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

      if (await InAppWalletService.instance.isInAppWallet(userAddress)) {
        final txHash = await _sendWithInAppWallet(
          toAddress: contractAddressHex,
          valueWei: BigInt.zero,
          data: _hexToBytes(dataHex),
        );
        if (txHash != null) debugPrint('Transaction recorded on blockchain: $txHash');
        return txHash;
      }

      if (WalletConnectService.isAvailable &&
          WalletConnectService.instance.isConnected) {
        final recordTxHash =
            await WalletConnectService.instance.sendContractTransaction(
          contractAddress: contractAddressHex,
          dataHex: dataHex,
          from: userAddress,
        );
        if (recordTxHash != null) {
          debugPrint('Transaction recorded on blockchain: $recordTxHash');
          return recordTxHash;
        }
        return null;
      }

      if (js_bridge.Web3JsBridge.isAvailable) {
        if (!js_bridge.Web3JsBridge.hasSendContractTransaction()) {
          js_bridge.Web3JsBridge.defineSendContractTransaction();
        }
        final result = await js_bridge.Web3JsBridge.sendContractTransaction(
            contractAddressHex, dataHex, userAddress);
        if (result != null &&
            js_bridge.Web3JsBridge.getJsResultSuccess(result)) {
          final recordTxHash =
              js_bridge.Web3JsBridge.getJsResultTxHash(result);
          debugPrint('Transaction recorded on blockchain: $recordTxHash');
          return recordTxHash;
        } else {
          final error =
              js_bridge.Web3JsBridge.getJsResultError(result) ?? 'Unknown error';
          debugPrint('Error recording transaction on blockchain: $error');
          return null;
        }
      }

      return null; // No wallet connected, save locally only
    } catch (e) {
      debugPrint('Error recording transaction: $e');
      // Don't throw - allow fallback to local storage
      return null;
    }
  }

  // Get transactions for a user from blockchain
  Future<List<Map<String, dynamic>>> getUserTransactions(String userAddress) async {
    try {
      if (_client == null || _contract == null) {
        // If contract not deployed, return empty list
        return [];
      }

      // Get transaction IDs for user
      final getIdsFunction = _contract!.function('getUserTransactionIds');
      final idsResult = await _client!.call(
        contract: _contract!,
        function: getIdsFunction,
        params: [EthereumAddress.fromHex(userAddress)],
      );

      final transactionIds = idsResult[0] as List<dynamic>;
      
      if (transactionIds.isEmpty) {
        return [];
      }

      // Convert to List<BigInt>
      final ids = transactionIds.map((id) => id as BigInt).toList();

      // Get all transactions
      final getTransactionsFunction = _contract!.function('getTransactions');
      final transactionsResult = await _client!.call(
        contract: _contract!,
        function: getTransactionsFunction,
        params: [ids],
      );

      final transactionsList = transactionsResult[0] as List<dynamic>;
      
      // Convert to Map format
      final List<Map<String, dynamic>> transactions = [];
      for (final tx in transactionsList) {
        final txList = tx as List<dynamic>;
        transactions.add({
          'id': (txList[0] as BigInt).toString(),
          'userAddress': (txList[1] as EthereumAddress).hex,
          'stationName': txList[2] as String,
          'timestamp': (txList[3] as BigInt).toInt(),
          'energy': (txList[4] as BigInt).toInt() / 1000.0, // Convert back from scaled value
          'amount': (txList[5] as BigInt).toInt() / 100.0, // Convert back from cents
          'isCredit': txList[6] as bool,
          'txHash': txList[7] as String,
        });
      }

      // Sort by timestamp (newest first)
      transactions.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      return transactions;
    } catch (e) {
      debugPrint('Error getting user transactions: $e');
      return [];
    }
  }

  // ==================== P2P STATION METHODS ====================

  Future<String?> registerStation({
    required String fromAddress,
    required String name,
    required String locationAddress,
    required double latitude,
    required double longitude,
    required String connectorType,
    required double powerKw,
    required double pricePerKwh,
    required bool isGreenEnergy,
  }) async {
    try {
      if (_client == null || _contract == null) {
        debugPrint('Warning: Contract not deployed.');
        return null;
      }

      final function_ = _contract!.function('registerStation');
      final functionCall = function_.encodeCall([
        name,
        locationAddress,
        BigInt.from((latitude * 1e6).round()),
        BigInt.from((longitude * 1e6).round()),
        connectorType,
        BigInt.from((powerKw * 1000).round()),
        BigInt.from((pricePerKwh * 100).round()),
        isGreenEnergy,
      ]);

      return await _sendContractTx(functionCall, fromAddress);
    } catch (e) {
      debugPrint('Error registering station: $e');
      return null;
    }
  }

  Future<String?> updateStationOnChain({
    required String fromAddress,
    required int stationId,
    required double pricePerKwh,
    required bool isActive,
  }) async {
    try {
      if (_client == null || _contract == null) return null;

      final function_ = _contract!.function('updateStation');
      final functionCall = function_.encodeCall([
        BigInt.from(stationId),
        BigInt.from((pricePerKwh * 100).round()),
        isActive,
      ]);

      return await _sendContractTx(functionCall, fromAddress);
    } catch (e) {
      debugPrint('Error updating station: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllActiveP2PStations() async {
    try {
      if (_client == null || _contract == null) return [];

      final function_ = _contract!.function('getAllActiveStations');
      final result = await _client!.call(
        contract: _contract!,
        function: function_,
        params: [],
      );

      final stations = result[0] as List<dynamic>;
      return stations.map((s) {
        final data = s as List<dynamic>;
        return {
          'id': (data[0] as BigInt).toInt(),
          'owner': (data[1] as EthereumAddress).hex,
          'name': data[2] as String,
          'locationAddress': data[3] as String,
          'latitude': (data[4] as BigInt).toInt(),
          'longitude': (data[5] as BigInt).toInt(),
          'connectorType': data[6] as String,
          'powerKw': (data[7] as BigInt).toInt(),
          'pricePerKwh': (data[8] as BigInt).toInt(),
          'isGreenEnergy': data[9] as bool,
          'isActive': data[10] as bool,
          'createdAt': (data[11] as BigInt).toInt(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting active stations: $e');
      return [];
    }
  }

  // ==================== ENERGY TRADING METHODS ====================

  Future<String?> addEnergyCredits({
    required String fromAddress,
    required double energyKwh,
  }) async {
    try {
      if (_client == null || _contract == null) return null;

      final function_ = _contract!.function('addEnergyCredits');
      final functionCall = function_.encodeCall([
        BigInt.from((energyKwh * 1000).round()),
      ]);

      return await _sendContractTx(functionCall, fromAddress);
    } catch (e) {
      debugPrint('Error adding energy credits: $e');
      return null;
    }
  }

  Future<double> getEnergyCredits(String address) async {
    try {
      if (_client == null || _contract == null) return 0;

      final function_ = _contract!.function('getEnergyCredits');
      final result = await _client!.call(
        contract: _contract!,
        function: function_,
        params: [EthereumAddress.fromHex(address)],
      );

      return (result[0] as BigInt).toInt() / 1000.0;
    } catch (e) {
      debugPrint('Error getting energy credits: $e');
      return 0;
    }
  }

  Future<String?> listEnergy({
    required String fromAddress,
    required double energyKwh,
    required double pricePerKwh,
  }) async {
    try {
      if (_client == null || _contract == null) return null;

      final function_ = _contract!.function('listEnergy');
      final functionCall = function_.encodeCall([
        BigInt.from((energyKwh * 1000).round()),
        BigInt.from((pricePerKwh * 100).round()),
      ]);

      return await _sendContractTx(functionCall, fromAddress);
    } catch (e) {
      debugPrint('Error listing energy: $e');
      return null;
    }
  }

  Future<String?> purchaseEnergy({
    required String fromAddress,
    required int listingId,
    required String txHash,
  }) async {
    try {
      if (_client == null || _contract == null) return null;

      final function_ = _contract!.function('purchaseEnergy');
      final functionCall = function_.encodeCall([
        BigInt.from(listingId),
        txHash,
      ]);

      return await _sendContractTx(functionCall, fromAddress);
    } catch (e) {
      debugPrint('Error purchasing energy: $e');
      return null;
    }
  }

  Future<String?> cancelEnergyListing({
    required String fromAddress,
    required int listingId,
  }) async {
    try {
      if (_client == null || _contract == null) return null;

      final function_ = _contract!.function('cancelEnergyListing');
      final functionCall = function_.encodeCall([
        BigInt.from(listingId),
      ]);

      return await _sendContractTx(functionCall, fromAddress);
    } catch (e) {
      debugPrint('Error cancelling listing: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveEnergyListings() async {
    try {
      if (_client == null || _contract == null) return [];

      final function_ = _contract!.function('getActiveListings');
      final result = await _client!.call(
        contract: _contract!,
        function: function_,
        params: [],
      );

      final listings = result[0] as List<dynamic>;
      return listings.map((l) {
        final data = l as List<dynamic>;
        return {
          'id': (data[0] as BigInt).toInt(),
          'seller': (data[1] as EthereumAddress).hex,
          'energyKwh': (data[2] as BigInt).toInt(),
          'pricePerKwh': (data[3] as BigInt).toInt(),
          'totalPrice': (data[4] as BigInt).toInt(),
          'isActive': data[5] as bool,
          'isSold': data[6] as bool,
          'buyer': (data[7] as EthereumAddress).hex,
          'txHash': data[8] as String,
          'createdAt': (data[9] as BigInt).toInt(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting active listings: $e');
      return [];
    }
  }

  // ==================== BOOKING & REWARDS (ESCROW / REFUND) ====================

  /// Returns current booking counter (latest id). Returns null if contract not deployed.
  Future<int?> getBookingCounter() async {
    try {
      if (_client == null || _contract == null) return null;
      final fn = _contract!.function('getBookingCounter');
      final result = await _client!.call(contract: _contract!, function: fn, params: []);
      return (result[0] as BigInt).toInt();
    } catch (e) {
      debugPrint('Error getBookingCounter: $e');
      return null;
    }
  }

  /// Create booking on-chain. Returns new booking id, or null on failure.
  Future<int?> createBookingOnChain({
    required String fromAddress,
    required String stationId,
    required String connectorType,
    required int startTimeUnix,
    required int endTimeUnix,
    required int energyKwhScaled,
    required int amountUsdCents,
  }) async {
    try {
      if (_client == null || _contract == null) return null;
      final counterBefore = await getBookingCounter();
      if (counterBefore == null) return null;

      final fn = _contract!.function('createBooking');
      final call = fn.encodeCall([
        stationId,
        connectorType,
        BigInt.from(startTimeUnix),
        BigInt.from(endTimeUnix),
        BigInt.from(energyKwhScaled),
        BigInt.from(amountUsdCents),
      ]);
      final txHash = await _sendContractTx(call, fromAddress);
      if (txHash == null) return null;

      // Wait for tx to be mined then read new counter
      await Future.delayed(const Duration(seconds: 2));
      final counterAfter = await getBookingCounter();
      if (counterAfter == null || counterAfter <= counterBefore) return null;
      return counterAfter;
    } catch (e) {
      debugPrint('Error createBookingOnChain: $e');
      return null;
    }
  }

  /// Pay for a booking (send ETH to contract escrow). Returns tx hash or null.
  Future<String?> payBooking({
    required String fromAddress,
    required int bookingId,
    required String beneficiaryAddress,
    required double amountInEth,
  }) async {
    try {
      if (_contract == null || _contractAddr == null) return null;

      final fn = _contract!.function('payBooking');
      final call = fn.encodeCall([
        BigInt.from(bookingId),
        EthereumAddress.fromHex(beneficiaryAddress),
      ]);
      final dataHex =
          '0x${call.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      final amountWei = BigInt.from((amountInEth * 1e18).round());
      final valueHex = '0x${amountWei.toRadixString(16)}';

      if (await InAppWalletService.instance.isInAppWallet(fromAddress)) {
        return await _sendWithInAppWallet(
          toAddress: _contractAddr!.hex,
          valueWei: amountWei,
          data: _hexToBytes(dataHex),
        );
      }

      if (WalletConnectService.isAvailable &&
          WalletConnectService.instance.isConnected) {
        return await WalletConnectService.instance
            .sendContractTransactionWithValue(
          contractAddress: _contractAddr!.hex,
          dataHex: dataHex,
          from: fromAddress,
          valueHex: valueHex,
        );
      }

      if (js_bridge.Web3JsBridge.isAvailable) {
        if (!js_bridge.Web3JsBridge.hasSendContractTransactionWithValue()) {
          js_bridge.Web3JsBridge.defineSendContractTransactionWithValue();
        }
        final result = await js_bridge.Web3JsBridge
            .sendContractTransactionWithValue(
                _contractAddr!.hex, dataHex, fromAddress, valueHex);
        if (result == null) return null;
        if (js_bridge.Web3JsBridge.getJsResultSuccess(result)) {
          return js_bridge.Web3JsBridge.getJsResultTxHash(result);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error payBooking: $e');
      return null;
    }
  }

  /// Complete booking on-chain (releases escrow to beneficiary and awards reward points).
  Future<String?> completeBookingOnChain({
    required String fromAddress,
    required int bookingId,
    required String txHash,
  }) async {
    try {
      if (_contract == null) return null;
      final fn = _contract!.function('completeBooking');
      final call = fn.encodeCall([BigInt.from(bookingId), txHash]);
      return await _sendContractTx(call, fromAddress);
    } catch (e) {
      debugPrint('Error completeBookingOnChain: $e');
      return null;
    }
  }

  /// Cancel booking on-chain (refunds escrowed ETH if any).
  Future<String?> cancelBookingOnChain({
    required String fromAddress,
    required int bookingId,
  }) async {
    try {
      if (_contract == null) return null;
      final fn = _contract!.function('cancelBooking');
      final call = fn.encodeCall([BigInt.from(bookingId)]);
      return await _sendContractTx(call, fromAddress);
    } catch (e) {
      debugPrint('Error cancelBookingOnChain: $e');
      return null;
    }
  }

  /// Get reward points for an address (incentive for sessions, P2P, green energy).
  Future<int> getRewardPoints(String address) async {
    try {
      if (_client == null || _contract == null) return 0;
      final fn = _contract!.function('getRewardPoints');
      final result = await _client!.call(
        contract: _contract!,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      return (result[0] as BigInt).toInt();
    } catch (e) {
      debugPrint('Error getRewardPoints: $e');
      return 0;
    }
  }

  // ==================== REVIEW METHODS ====================

  Future<String?> submitReview({
    required String fromAddress,
    required int stationId,
    required int bookingId,
    required int rating,
    required String comment,
  }) async {
    try {
      if (_client == null || _contract == null) return null;

      final function_ = _contract!.function('submitReview');
      final functionCall = function_.encodeCall([
        BigInt.from(stationId),
        BigInt.from(bookingId),
        BigInt.from(rating),
        comment,
      ]);

      return await _sendContractTx(functionCall, fromAddress);
    } catch (e) {
      debugPrint('Error submitting review: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getStationReviews(int stationId) async {
    try {
      if (_client == null || _contract == null) return [];

      final function_ = _contract!.function('getStationReviews');
      final result = await _client!.call(
        contract: _contract!,
        function: function_,
        params: [BigInt.from(stationId)],
      );

      final reviews = result[0] as List<dynamic>;
      return reviews.map((r) {
        final data = r as List<dynamic>;
        return {
          'id': (data[0] as BigInt).toInt(),
          'reviewer': (data[1] as EthereumAddress).hex,
          'stationId': (data[2] as BigInt).toInt(),
          'bookingId': (data[3] as BigInt).toInt(),
          'rating': (data[4] as BigInt).toInt(),
          'comment': data[5] as String,
          'timestamp': (data[6] as BigInt).toInt(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting station reviews: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getStationAverageRating(int stationId) async {
    try {
      if (_client == null || _contract == null) return {'average': 0.0, 'count': 0};

      final function_ = _contract!.function('getStationAverageRating');
      final result = await _client!.call(
        contract: _contract!,
        function: function_,
        params: [BigInt.from(stationId)],
      );

      final totalRating = (result[0] as BigInt).toInt();
      final count = (result[1] as BigInt).toInt();

      return {
        'average': count > 0 ? totalRating / count : 0.0,
        'count': count,
      };
    } catch (e) {
      debugPrint('Error getting station rating: $e');
      return {'average': 0.0, 'count': 0};
    }
  }

  // ==================== HELPER: SEND CONTRACT TRANSACTION ====================

  Future<String?> _sendContractTx(List<int> functionCall, String fromAddress) async {
    if (_contractAddr == null) return null;

    final contractAddressHex = _contractAddr!.hex;
    final dataHex =
        '0x${functionCall.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    if (await InAppWalletService.instance.isInAppWallet(fromAddress)) {
      return await _sendWithInAppWallet(
        toAddress: contractAddressHex,
        valueWei: BigInt.zero,
        data: _hexToBytes(dataHex),
      );
    }

    if (WalletConnectService.isAvailable &&
        WalletConnectService.instance.isConnected) {
      return await WalletConnectService.instance.sendContractTransaction(
        contractAddress: contractAddressHex,
        dataHex: dataHex,
        from: fromAddress,
      );
    }

    if (js_bridge.Web3JsBridge.isAvailable) {
      if (!js_bridge.Web3JsBridge.hasSendContractTransaction()) {
        js_bridge.Web3JsBridge.defineSendContractTransaction();
      }
      final result = await js_bridge.Web3JsBridge.sendContractTransaction(
          contractAddressHex, dataHex, fromAddress);

      if (result != null && js_bridge.Web3JsBridge.getJsResultSuccess(result)) {
        return js_bridge.Web3JsBridge.getJsResultTxHash(result);
      }
      if (result != null) {
        final error =
            js_bridge.Web3JsBridge.getJsResultError(result) ?? 'Unknown error';
        debugPrint('Contract transaction error: $error');
      }
    }
    return null;
  }

  void dispose() {
    _client?.dispose();
  }
}
