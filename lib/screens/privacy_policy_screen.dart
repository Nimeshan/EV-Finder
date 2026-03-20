import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Data We Collect',
              'EV Finder collects the following data to provide our services:\n\n'
              '\u2022 Wallet address (Ethereum) \u2013 used as your account identifier\n'
              '\u2022 Display name \u2013 shown on your profile\n'
              '\u2022 Location data \u2013 used to find nearby charging stations\n'
              '\u2022 Booking history \u2013 your charging session records\n'
              '\u2022 Transaction records \u2013 payment and energy trade history\n'
              '\u2022 Reviews and ratings \u2013 feedback you leave on stations',
            ),
            _buildSection(
              'Blockchain Data',
              'Transactions, bookings, reviews, and energy trades are recorded on the Ethereum blockchain '
              '(Sepolia testnet). Blockchain data is public and immutable \u2013 it cannot be modified or '
              'deleted once written. Your wallet address is publicly visible on-chain.\n\n'
              'We do not store private keys on our servers. In-app wallet keys are stored '
              'securely on your device using platform-specific secure storage (Keychain on iOS, '
              'Keystore on Android).',
            ),
            _buildSection(
              'Local Data Storage',
              'We cache bookings, transactions, and preferences locally on your device using '
              'SharedPreferences for offline access and performance. This data can be exported '
              'or cleared at any time from Settings > Privacy & Data.',
            ),
            _buildSection(
              'Third-Party Services',
              '\u2022 Open Charge Map API \u2013 provides public charging station data\n'
              '\u2022 Ethereum RPC (Sepolia) \u2013 blockchain communication\n'
              '\u2022 MetaMask / WalletConnect \u2013 wallet connection (your keys never leave your wallet)',
            ),
            _buildSection(
              'Your Rights',
              '\u2022 Access: View all your data in the app (Profile > Transaction History)\n'
              '\u2022 Export: Download your data as JSON (Profile > Privacy & Data > Export)\n'
              '\u2022 Delete: Clear local data or delete your account entirely\n'
              '\u2022 Portability: Your blockchain data is accessible via any Ethereum explorer\n\n'
              'Note: Blockchain records cannot be deleted due to the immutable nature of the ledger. '
              'Account deletion removes all local data and disconnects your wallet from the app.',
            ),
            _buildSection(
              'Data Security',
              '\u2022 Private keys stored in platform secure enclave (not in app memory)\n'
              '\u2022 Smart contract uses reentrancy guards and access controls\n'
              '\u2022 Payments use escrow for buyer/seller protection\n'
              '\u2022 No personal data sent to external servers (blockchain only)',
            ),
            _buildSection(
              'Contact',
              'For privacy-related queries, contact the EV Finder development team.\n\n'
              'Last updated: March 2026',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
