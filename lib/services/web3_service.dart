import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:js' as js;

class Web3Service {
  static const String sepoliaRpcUrl = 'https://rpc.sepolia.org';
  static const String goerliRpcUrl = 'https://rpc.ankr.com/eth_goerli';
  static const String mumbaiRpcUrl = 'https://rpc-mumbai.maticvigil.com';
  
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

  // Connect to MetaMask
  Future<String?> connectWallet() async {
    try {
      if (kIsWeb) {
        // For web, use JavaScript interop to connect to MetaMask
        return await _connectMetaMaskWeb();
      } else {
        // For mobile, we need a different approach
        // For now, provide instructions or use a test mode
        throw Exception(
          'Mobile MetaMask connection requires additional setup. '
          'For testing, please use the web version in a browser with MetaMask extension installed.'
        );
      }
    } catch (e) {
      debugPrint('Error connecting wallet: $e');
      rethrow; // Re-throw to show error to user
    }
  }

  // Helper function to convert JavaScript Promise to Dart Future
  // Since the js package doesn't have promiseToFuture, we use a workaround
  Future<dynamic> _promiseToFuture(dynamic promise) async {
    // The JavaScript functions return Promises, but we can't easily await them
    // So we'll use a callback-based approach via JavaScript
    final completer = Completer<dynamic>();
    
    try {
      // Use JavaScript to handle the promise
      js.context.callMethod('eval', [
        '''
        (function() {
          var promise = arguments[0];
          var resolve = arguments[1];
          promise.then(function(value) {
            resolve(value);
          }).catch(function(error) {
            resolve({success: false, error: error.message || error.toString()});
          });
        })
        '''
      ]).apply([promise, (value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      }]);
      
      return completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('MetaMask connection timed out. Please try again.');
        },
      );
    } catch (e) {
      // Fallback: return promise as-is and hope it works
      debugPrint('Warning: Could not properly convert promise: $e');
      await Future.delayed(const Duration(milliseconds: 500));
      return promise;
    }
  }

  Future<String?> _connectMetaMaskWeb() async {
    try {
      // Check if MetaMask functions are available
      if (!js.context.hasProperty('connectMetaMask')) {
        throw Exception(
          'MetaMask connector script not loaded.\n\n'
          'Troubleshooting:\n'
          '1. Check that web/metamask_connector.js exists\n'
          '2. Verify web/index.html includes the script tag\n'
          '3. Rebuild: flutter clean && flutter build web\n'
          '4. Hard refresh browser (Ctrl+Shift+R)'
        );
      }

      // Switch to Sepolia testnet first (try, but don't block on failure)
      try {
        if (js.context.hasProperty('switchToSepolia')) {
          // switchToSepolia returns a Promise, so we need to await it properly
          final switchPromise = js.context.callMethod('switchToSepolia', []);
          // Convert Promise to Future manually
          final switchResult = await _promiseToFuture(switchPromise);
          
          if (switchResult != null) {
            final switchResultObj = switchResult as js.JsObject;
            final switchSuccess = switchResultObj['success'] as bool? ?? false;
            if (!switchSuccess) {
              final switchError = switchResultObj['error'] as String?;
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

      // Connect to MetaMask (this is async, so we need to await the Promise)
      dynamic result;
      try {
        // connectMetaMask returns a Promise, so we need to convert it to a Future
        final connectPromise = js.context.callMethod('connectMetaMask', []);
        result = await _promiseToFuture(connectPromise);
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
      
      final jsResult = result as js.JsObject;
      final success = jsResult['success'] as bool? ?? false;
      
      if (!success) {
        final error = jsResult['error'] as String? ?? 'Unknown error';
        
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
      
      final address = jsResult['address'] as String?;
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

  // Get saved wallet address. On web, if storage is empty, try to recover from MetaMask (no popup).
  Future<String?> getSavedWalletAddress() async {
    final prefs = await SharedPreferences.getInstance();
    String? address = prefs.getString('wallet_address');
    if ((address == null || address.isEmpty) && kIsWeb) {
      try {
        if (js.context.hasProperty('getMetaMaskAccount')) {
          final promise = js.context.callMethod('getMetaMaskAccount', []);
          final result = await _promiseToFuture(promise);
          if (result != null && result is String && result.isNotEmpty) {
            address = result;
            await prefs.setString('wallet_address', address);
          }
        }
      } catch (e) {
        debugPrint('Could not recover wallet from MetaMask: $e');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_address');
    await prefs.remove('user_name');
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

  // Send payment via MetaMask (web only)
  Future<String?> sendPayment({
    required String fromAddress,
    required String toAddress,
    required double amountInEth,
    String? data,
  }) async {
    try {
      if (!kIsWeb) {
        throw Exception('Payment processing is only available on web platform');
      }

      // Use MetaMask to send transaction
      final amountInWei = (amountInEth * BigInt.from(1000000000000000000).toDouble()).toInt();
      final amountHex = '0x${BigInt.from(amountInWei).toRadixString(16)}';

      // Call JavaScript function to send transaction via MetaMask
      if (!js.context.hasProperty('sendTransaction')) {
        // Define the function if it doesn't exist
        js.context.callMethod('eval', [
          '''
          window.sendTransaction = async function(from, to, amount) {
            if (typeof window.ethereum === 'undefined') {
              return {success: false, error: 'MetaMask not found'};
            }
            try {
              const txHash = await window.ethereum.request({
                method: 'eth_sendTransaction',
                params: [{
                  from: from,
                  to: to,
                  value: amount,
                  gas: '0x5208', // 21000 gas
                }]
              });
              return {success: true, txHash: txHash};
            } catch (error) {
              return {success: false, error: error.message || error.toString()};
            }
          };
          '''
        ]);
      }

      final result = js.context.callMethod('sendTransaction', [fromAddress, toAddress, amountHex]);
      
      if (result != null) {
        final jsResult = result as js.JsObject;
        final success = jsResult['success'] as bool? ?? false;
        
        if (success) {
          final txHash = jsResult['txHash'] as String?;
          return txHash;
        } else {
          final error = jsResult['error'] as String? ?? 'Unknown error';
          throw Exception('Payment failed: $error');
        }
      }
      
      throw Exception('Payment failed: No response from MetaMask');
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

      // Use MetaMask to sign and send transaction
      if (!kIsWeb) {
        throw Exception('Transaction recording is only available on web platform');
      }

      // Encode the function call
      final recordFunction = _contract!.function('recordTransaction');
      final functionCall = recordFunction.encodeCall([
        stationName,
        energyScaled,
        amountScaled,
        isCredit,
        txHash,
      ]);

      // Get the contract address
      final contractAddressHex = _contractAddr!.hex;

      // Call JavaScript function to send transaction via MetaMask
      if (!js.context.hasProperty('sendContractTransaction')) {
        // Define the function
        js.context.callMethod('eval', [
          '''
          window.sendContractTransaction = async function(contractAddress, encodedData, fromAddress) {
            if (typeof window.ethereum === 'undefined') {
              return {success: false, error: 'MetaMask not found'};
            }
            try {
              // Estimate gas
              const gasEstimate = await window.ethereum.request({
                method: 'eth_estimateGas',
                params: [{
                  from: fromAddress,
                  to: contractAddress,
                  data: encodedData
                }]
              });
              
              // Send transaction
              const txHash = await window.ethereum.request({
                method: 'eth_sendTransaction',
                params: [{
                  from: fromAddress,
                  to: contractAddress,
                  data: encodedData,
                  gas: gasEstimate
                }]
              });
              return {success: true, txHash: txHash};
            } catch (error) {
              return {success: false, error: error.message || error.toString()};
            }
          };
          '''
        ]);
      }

      // Send the transaction
      final result = js.context.callMethod('sendContractTransaction', [
        contractAddressHex,
        functionCall,
        userAddress,
      ]);
      
      if (result != null) {
        final jsResult = result as js.JsObject;
        final success = jsResult['success'] as bool? ?? false;
        
        if (success) {
          final recordTxHash = jsResult['txHash'] as String?;
          debugPrint('Transaction recorded on blockchain: $recordTxHash');
          return recordTxHash;
        } else {
          final error = jsResult['error'] as String? ?? 'Unknown error';
          debugPrint('Error recording transaction on blockchain: $error');
          // Don't throw - allow fallback to local storage
          return null;
        }
      }
      
      return null;
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
      if (!kIsWeb || _contract == null || _contractAddr == null) return null;

      final fn = _contract!.function('payBooking');
      final call = fn.encodeCall([
        BigInt.from(bookingId),
        EthereumAddress.fromHex(beneficiaryAddress),
      ]);
      final dataHex = '0x${call.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      final amountWei = BigInt.from((amountInEth * 1e18).round());
      final valueHex = '0x${amountWei.toRadixString(16)}';

      if (!js.context.hasProperty('sendContractTransactionWithValue')) {
        js.context.callMethod('eval', [
          '''
          window.sendContractTransactionWithValue = async function(contractAddress, encodedData, fromAddress, valueHex) {
            if (typeof window.ethereum === 'undefined') return {success: false, error: 'MetaMask not found'};
            try {
              const gasEstimate = await window.ethereum.request({
                method: 'eth_estimateGas',
                params: [{ from: fromAddress, to: contractAddress, data: encodedData, value: valueHex }]
              });
              const txHash = await window.ethereum.request({
                method: 'eth_sendTransaction',
                params: [{ from: fromAddress, to: contractAddress, data: encodedData, value: valueHex, gas: gasEstimate }]
              });
              return {success: true, txHash: txHash};
            } catch (error) {
              return {success: false, error: error.message || error.toString()};
            }
          };
          '''
        ]);
      }
      final promise = js.context.callMethod('sendContractTransactionWithValue', [
        _contractAddr!.hex,
        dataHex,
        fromAddress,
        valueHex,
      ]);
      final result = await _promiseToFuture(promise);
      if (result == null) return null;
      final jsResult = result as js.JsObject;
      final success = jsResult['success'] as bool? ?? false;
      if (success) return jsResult['txHash'] as String?;
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
    if (!kIsWeb) {
      throw Exception('Contract transactions only available on web');
    }

    final contractAddressHex = _contractAddr!.hex;
    final dataHex = '0x${functionCall.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    if (!js.context.hasProperty('sendContractTransaction')) {
      js.context.callMethod('eval', [
        '''
        window.sendContractTransaction = async function(contractAddress, encodedData, fromAddress) {
          if (typeof window.ethereum === 'undefined') {
            return {success: false, error: 'MetaMask not found'};
          }
          try {
            const gasEstimate = await window.ethereum.request({
              method: 'eth_estimateGas',
              params: [{
                from: fromAddress,
                to: contractAddress,
                data: encodedData
              }]
            });
            const txHash = await window.ethereum.request({
              method: 'eth_sendTransaction',
              params: [{
                from: fromAddress,
                to: contractAddress,
                data: encodedData,
                gas: gasEstimate
              }]
            });
            return {success: true, txHash: txHash};
          } catch (error) {
            return {success: false, error: error.message || error.toString()};
          }
        };
        window.sendContractTransactionWithValue = async function(contractAddress, encodedData, fromAddress, valueHex) {
          if (typeof window.ethereum === 'undefined') {
            return {success: false, error: 'MetaMask not found'};
          }
          try {
            const gasEstimate = await window.ethereum.request({
              method: 'eth_estimateGas',
              params: [{
                from: fromAddress,
                to: contractAddress,
                data: encodedData,
                value: valueHex
              }]
            });
            const txHash = await window.ethereum.request({
              method: 'eth_sendTransaction',
              params: [{
                from: fromAddress,
                to: contractAddress,
                data: encodedData,
                value: valueHex,
                gas: gasEstimate
              }]
            });
            return {success: true, txHash: txHash};
          } catch (error) {
            return {success: false, error: error.message || error.toString()};
          }
        };
        '''
      ]);
    }

    final promise = js.context.callMethod('sendContractTransaction', [
      contractAddressHex,
      dataHex,
      fromAddress,
    ]);

    final result = await _promiseToFuture(promise);

    if (result != null) {
      final jsResult = result as js.JsObject;
      final success = jsResult['success'] as bool? ?? false;

      if (success) {
        return jsResult['txHash'] as String?;
      } else {
        final error = jsResult['error'] as String? ?? 'Unknown error';
        debugPrint('Contract transaction error: $error');
        return null;
      }
    }

    return null;
  }

  void dispose() {
    _client?.dispose();
  }
}
