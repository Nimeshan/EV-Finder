/// Payment configuration constants.
/// In production, these should be fetched from a backend config service.
class PaymentConfig {
  // Main wallet: receives all non-P2P charging payments (platform).
  // TODO: Move to environment variable or remote config for production.
  static const String receiverWalletAddress = '0x5CB9141132599DdA1572a528a9cF6f45EAC8F5Bb';

  // ETH to USD conversion rate (approximate).
  // TODO: Fetch live rate from a price oracle (e.g. Chainlink, CoinGecko API).
  static const double ethToUsdRate = 2800.0;

  // Gas fee buffer (in ETH) to ensure sufficient balance
  static const double gasFeeBuffer = 0.001;

  // Service fee for each charging session (USD)
  static const double serviceFee = 1.50;
}


