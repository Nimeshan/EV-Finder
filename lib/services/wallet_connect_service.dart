import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import '../config/wallet_connect_config.dart';

/// Service for WalletConnect-based MetaMask connection on mobile.
/// Not used on web (dart:js/MetaMask extension used instead).
class WalletConnectService {
  WalletConnectService._();
  static final WalletConnectService _instance = WalletConnectService._();
  static WalletConnectService get instance => _instance;

  Web3App? _web3App;
  SessionData? _session;
  bool _initialized = false;

  static const String _sepoliaChainId = 'eip155:11155111';

  /// Whether WalletConnect is available (mobile only, not web)
  static bool get isAvailable => !kIsWeb;

  /// Initialize the Web3App. Call once before connect.
  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    try {
      _web3App = await Web3App.createInstance(
        projectId: WalletConnectConfig.projectId,
        metadata: PairingMetadata(
          name: 'EV Finder',
          description: 'EV charging station finder with Web3 payments',
          url: WalletConnectConfig.universalLink,
          icons: ['https://evfinder.app/icon.png'],
          redirect: Redirect(
            native: '${WalletConnectConfig.nativeScheme}://',
            universal: WalletConnectConfig.universalLink,
          ),
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('WalletConnectService init error: $e');
      rethrow;
    }
  }

  /// Open the connect flow and return the wallet address when connected.
  /// Launches MetaMask app with WalletConnect URI on mobile.
  Future<String?> connect() async {
    if (kIsWeb) return null;
    if (!_initialized || _web3App == null) {
      await init();
    }

    try {
      // Use requiredNamespaces so MetaMask shows a proper approval sheet (optionalNamespaces can lead to blank/broken UI on some versions).
      final connectResponse = await _web3App!.connect(
        requiredNamespaces: {
          'eip155': RequiredNamespace(
            chains: [_sepoliaChainId, 'eip155:1'],
            methods: ['personal_sign', 'eth_sendTransaction', 'eth_signTransaction'],
            events: ['accountsChanged', 'chainChanged'],
          ),
        },
      );

      final uri = connectResponse.uri;
      final uriStr = uri?.toString() ?? '';
      if (uriStr.isEmpty) {
        debugPrint('WalletConnect: No URI received');
        return null;
      }

      // On mobile: launch MetaMask (or other wallet) with the WC URI
      final launchUri = 'metamask://wc?uri=${Uri.encodeComponent(uriStr)}';
      if (await canLaunchUrl(Uri.parse(launchUri))) {
        await launchUrl(Uri.parse(launchUri), mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try generic wc: format
        await launchUrl(Uri.parse(uriStr), mode: LaunchMode.externalApplication);
      }

      // Wait for session with timeout so we don't hang forever if user doesn't approve
      const sessionTimeout = Duration(seconds: 120);
      _session = await connectResponse.session.future.timeout(
        sessionTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Connection timed out. Open MetaMask, approve the connection, then try again.',
            sessionTimeout,
          );
        },
      );
      final accounts = _session?.namespaces['eip155']?.accounts;
      final address = accounts?.isNotEmpty == true
          ? accounts!.first.split(':').last
          : null;
      return address;
    } catch (e) {
      debugPrint('WalletConnect connect error: $e');
      rethrow;
    }
  }

  /// Get the currently connected address if any
  String? get connectedAddress {
    if (_session == null) return null;
    final accounts = _session!.namespaces['eip155']?.accounts;
    return accounts?.isNotEmpty == true
        ? accounts!.first.split(':').last
        : null;
  }

  /// Check if wallet is connected
  bool get isConnected => _session != null;

  /// Disconnect the current session
  Future<void> disconnect() async {
    if (_session != null) {
      try {
        await _web3App?.disconnectSession(
          topic: _session!.topic,
          reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
        );
      } catch (e) {
        debugPrint('WalletConnect disconnect error: $e');
      }
      _session = null;
    }
  }

  /// Request switch to Sepolia
  Future<void> switchToSepolia() async {
    if (_web3App == null || _session == null) return;
    try {
      await _web3App!.request(
        topic: _session!.topic,
        chainId: _sepoliaChainId,
        request: SessionRequestParams(
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': '0xaa36a7'} // Sepolia
          ],
        ),
      );
    } catch (e) {
      debugPrint('Switch to Sepolia warning: $e');
    }
  }

  /// Send a transaction via the connected wallet.
  Future<String?> sendTransaction({
    required String from,
    required String to,
    required String valueHex,
    String? data,
    String? gas,
  }) async {
    if (_web3App == null || _session == null) return null;

    try {
      final txParams = <String, dynamic>{
        'from': from,
        'to': to,
        'value': valueHex,
      };
      if (data != null && data.isNotEmpty) txParams['data'] = data;
      if (gas != null) txParams['gas'] = gas;

      final result = await _web3App!.request(
        topic: _session!.topic,
        chainId: _sepoliaChainId,
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [txParams],
        ),
      );

      return result as String?;
    } catch (e) {
      debugPrint('WalletConnect sendTransaction error: $e');
      return null;
    }
  }

  /// Send a contract transaction (no value)
  Future<String?> sendContractTransaction({
    required String contractAddress,
    required String dataHex,
    required String from,
  }) async {
    return sendTransaction(
      from: from,
      to: contractAddress,
      valueHex: '0x0',
      data: dataHex,
    );
  }

  /// Send a contract transaction with value
  Future<String?> sendContractTransactionWithValue({
    required String contractAddress,
    required String dataHex,
    required String from,
    required String valueHex,
  }) async {
    return sendTransaction(
      from: from,
      to: contractAddress,
      valueHex: valueHex,
      data: dataHex,
    );
  }
}
