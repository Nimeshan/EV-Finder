// Stub implementation for iOS/Android - dart:js is web-only.
// Wallet connect and signing require web (MetaMask) or WalletConnect integration.
import 'dart:async';

class Web3JsBridge {
  static const bool isAvailable = false;

  static const String _mobileMessage =
      'Wallet connection is available on web. For mobile, open the app in a browser with MetaMask, '
      'or use WalletConnect (coming soon).';

  static Future<dynamic> promiseToFuture(dynamic promise) async {
    throw UnsupportedError(_mobileMessage);
  }

  static bool hasConnectMetaMask() => false;
  static bool hasSwitchToSepolia() => false;
  static Future<dynamic> switchToSepolia() async =>
      throw UnsupportedError(_mobileMessage);
  static Future<dynamic> connectMetaMask() async =>
      throw UnsupportedError(_mobileMessage);

  static bool hasGetMetaMaskAccount() => false;
  static Future<String?> getMetaMaskAccount() async => null;

  static bool hasSendTransaction() => false;
  static void defineSendTransaction() {}
  static dynamic sendTransaction(
          String from, String to, String amountHex) =>
      throw UnsupportedError(_mobileMessage);

  static bool hasSendContractTransaction() => false;
  static void defineSendContractTransaction() {}
  static Future<dynamic> sendContractTransaction(
          String contractAddr, String dataHex, String from) =>
      throw UnsupportedError(_mobileMessage);

  static bool hasSendContractTransactionWithValue() => false;
  static void defineSendContractTransactionWithValue() {}
  static Future<dynamic> sendContractTransactionWithValue(
          String contractAddr, String dataHex, String from, String valueHex) =>
      throw UnsupportedError(_mobileMessage);

  /// Helper to safely cast JS result; on stub returns null.
  static bool getJsResultSuccess(dynamic result) => false;
  static String? getJsResultTxHash(dynamic result) => null;
  static String? getJsResultError(dynamic result) => null;
  static String? getJsResultAddress(dynamic result) => null;
}
