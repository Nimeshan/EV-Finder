/// WalletConnect configuration for mobile MetaMask connection.
///
/// Get a free project ID at https://cloud.walletconnect.com
class WalletConnectConfig {
  /// Your WalletConnect Cloud project ID (required for mobile wallet connection).
  /// Create one at https://cloud.walletconnect.com
  static const String projectId =
      String.fromEnvironment('WC_PROJECT_ID', defaultValue: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e');

  /// Deep link scheme for returning to the app after wallet approval
  static const String nativeScheme = 'evfinder';
  static const String universalLink = 'https://evfinder.app';
}
