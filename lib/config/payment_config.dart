/// Payment configuration constants
class PaymentConfig {
  // Main wallet: receives all non-P2P charging payments (platform)
  static const String receiverWalletAddress = '0x5CB9141132599DdA1572a528a9cF6f45EAC8F5Bb';
  
  // ETH to USD conversion rate (approximate)
  static const double ethToUsdRate = 2800.0;
  
  // Gas fee buffer (in ETH) to ensure sufficient balance
  static const double gasFeeBuffer = 0.001;

  // Service fee for each charging session (USD)
  static const double serviceFee = 1.50;
}


