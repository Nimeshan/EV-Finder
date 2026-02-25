import 'dart:math';

import 'package:convert/convert.dart' show hex;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

/// Creates and stores an in-app Ethereum wallet so users can use the app
/// without connecting MetaMask or Trust Wallet.
class InAppWalletService {
  InAppWalletService._();
  static final InAppWalletService _instance = InAppWalletService._();
  static InAppWalletService get instance => _instance;

  static const String _keyPrivateKey = 'evfinder_in_app_pk';
  static const String keyWalletType = 'wallet_type';
  static const String _typeInApp = 'in_app';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// Returns true if user has an in-app wallet (no MetaMask needed).
  Future<bool> hasInAppWallet() async {
    try {
      final pk = await _secure.read(key: _keyPrivateKey);
      return pk != null && pk.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Creates a new in-app wallet, saves it securely, and returns the address.
  /// Idempotent: if one already exists, returns its address.
  Future<String> createOrGetInAppWallet() async {
    String? pkHex = await _secure.read(key: _keyPrivateKey);
    if (pkHex != null && pkHex.isNotEmpty) {
      final cred = EthPrivateKey.fromHex(pkHex);
      return cred.address.hex;
    }
    final rng = Random.secure();
    final cred = EthPrivateKey.createRandom(rng);
    pkHex = hex.encode(cred.privateKey);
    await _secure.write(key: _keyPrivateKey, value: pkHex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyWalletType, _typeInApp);
    await prefs.setString('wallet_address', cred.address.hex);
    return cred.address.hex;
  }

  /// Returns the in-app wallet address, or null if none.
  Future<String?> getInAppWalletAddress() async {
    if (!await hasInAppWallet()) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(keyWalletType) != _typeInApp) return null;
    return prefs.getString('wallet_address');
  }

  /// Loads credentials for the in-app wallet. Returns null if none or error.
  Future<EthPrivateKey?> getCredentials() async {
    try {
      final pkHex = await _secure.read(key: _keyPrivateKey);
      if (pkHex == null || pkHex.isEmpty) return null;
      return EthPrivateKey.fromHex(pkHex);
    } catch (_) {
      return null;
    }
  }

  /// Deletes the in-app wallet (e.g. on sign out). Caller must clear prefs wallet_address/wallet_type.
  Future<void> deleteInAppWallet() async {
    await _secure.delete(key: _keyPrivateKey);
  }

  /// Whether the given address is the current in-app wallet.
  Future<bool> isInAppWallet(String address) async {
    final addr = await getInAppWalletAddress();
    return addr != null && address.toLowerCase() == addr.toLowerCase();
  }
}
