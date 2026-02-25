import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/web3_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Web3Service _web3Service = Web3Service();
  bool _isConnecting = false;
  bool _connectingInApp = false; // true when using in-app wallet flow
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingWallet();
  }

  Future<void> _checkExistingWallet() async {
    final savedAddress = await _web3Service.getSavedWalletAddress();
    if (savedAddress != null && savedAddress.isNotEmpty && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _connectInAppWallet() async {
    setState(() {
      _isConnecting = true;
      _connectingInApp = true;
      _errorMessage = null;
    });
    try {
      final walletAddress = await _web3Service.connectInAppWallet();
      if (!mounted) {
        return;
      }
      final isRegistered = await _web3Service.isUserRegistered(walletAddress);
      if (!isRegistered) {
        _showRegistrationDialog(walletAddress);
      } else {
        final userInfo = await _web3Service.getUserInfo(walletAddress);
        if (userInfo != null && userInfo['name'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', userInfo['name']);
        }
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not create app wallet: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) setState(() {
        _isConnecting = false;
        _connectingInApp = false;
      });
    }
  }

  Future<void> _connectMetaMask() async {
    setState(() {
      _isConnecting = true;
      _connectingInApp = false;
      _errorMessage = null;
    });

    try {
      await _web3Service.initialize(network: 'sepolia');
      final walletAddress = await _web3Service.connectWallet();

      if (walletAddress != null && walletAddress.isNotEmpty) {
        await _web3Service.saveWalletAddress(walletAddress);
        final isRegistered = await _web3Service.isUserRegistered(walletAddress);

        if (!isRegistered) {
          if (mounted) {
            _showRegistrationDialog(walletAddress);
          }
        } else {
          // Restore saved name to active session for returning users
          final userInfo = await _web3Service.getUserInfo(walletAddress);
          if (userInfo != null && userInfo['name'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_name', userInfo['name']);
          }
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to connect to MetaMask. Please try again.';
        });
      }
    } catch (e) {
      String errorMsg = 'Error connecting to wallet';

      if (e is TimeoutException) {
        errorMsg = 'Connection timed out. Open the MetaMask app, approve the connection, then tap Sign In again.';
      } else if (e.toString().contains('MetaMask is not installed')) {
        errorMsg = 'MetaMask is not installed. Please install MetaMask extension or app.';
      } else if (e.toString().contains('User rejected')) {
        errorMsg = 'Connection rejected. Please approve the connection in MetaMask.';
      } else if (e.toString().contains('not loaded')) {
        errorMsg = 'MetaMask connector not loaded. Please refresh the page.';
      } else if (e.toString().contains('timed out')) {
        errorMsg = 'Connection timed out. Open MetaMask, approve the connection, then try again.';
      } else {
        errorMsg = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      }

      setState(() {
        _errorMessage = errorMsg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _showRegistrationDialog(String walletAddress) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Register Your Account',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your name to complete registration',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Your Name',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wallet: ${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _registerUser(walletAddress, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
            child: const Text(
              'Register',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerUser(String address, String name) async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final success = await _web3Service.registerUser(address, name);
      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorMessage = 'Registration failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error during registration: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.loginBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6BC5E8),
                        Color(0xFF7ED8A3),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/Logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'EV Finder',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Power your journey, sustainably.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.subtleGray,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 64),
                // Error Message
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // In-app wallet: no MetaMask needed
                ElevatedButton(
                  onPressed: _isConnecting ? null : _connectInAppWallet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isConnecting && _connectingInApp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue with in-app wallet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No MetaMask needed — wallet stays in the app',
                  style: TextStyle(
                    color: AppColors.subtleGray.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                // MetaMask Sign In Button
                OutlinedButton(
                  onPressed: _isConnecting ? null : _connectMetaMask,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isConnecting && !_connectingInApp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/metamask.png',
                              width: 24,
                              height: 24,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign in with MetaMask',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connect to Sepolia Testnet',
                  style: TextStyle(color: AppColors.subtleGray, fontSize: 12),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 8),
                  Text(
                    'If the connection screen in MetaMask is blank or stuck, update MetaMask to the latest version and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.subtleGray.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _web3Service.dispose();
    super.dispose();
  }
}
