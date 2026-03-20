import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/web3_service.dart';
import '../services/in_app_wallet_service.dart';
import '../services/transaction_service.dart';
import '../config/payment_config.dart';
import '../theme/app_theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final Web3Service _web3Service = Web3Service();
  final TransactionService _transactionService = TransactionService();
  final InAppWalletService _inAppWalletService = InAppWalletService.instance;
  String? _walletAddress;
  double _balance = 0.0;
  bool _isLoading = true;
  String _walletType = 'In-App Wallet';
  List<Transaction> _recentTransactions = [];
  late Timer _autoRefreshTimer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    // Auto-refresh balance every 10 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadWalletData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't reload here to avoid excessive calls
  }

  @override
  void dispose() {
    _autoRefreshTimer.cancel();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await _web3Service.initialize();
      _walletAddress = await _web3Service.getSavedWalletAddress();

      if (_walletAddress != null) {
        _balance = await _web3Service.getBalance(_walletAddress!);
        final txs = await _transactionService.getTransactions();
        _recentTransactions = txs.take(5).toList();

        final isInApp = await _inAppWalletService.isInAppWallet(_walletAddress!);
        _walletType = isInApp ? 'In-App Wallet' : 'MetaMask';
        _lastUpdated = DateTime.now();
      }
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _copyAddress() {
    if (_walletAddress != null) {
      Clipboard.setData(ClipboardData(text: _walletAddress!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet address copied to clipboard'),
          backgroundColor: AppColors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== TOP UP ====================
  void _showTopUp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final mq = MediaQuery.of(context);
        final maxH = mq.size.height * 0.82;
        final pad = EdgeInsets.only(left: 20, right: 20, top: 16, bottom: mq.viewInsets.bottom + 16);
        return SizedBox(
          height: maxH,
          child: SingleChildScrollView(
            padding: pad,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Up Wallet',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Get Sepolia Test ETH',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'This app uses the Sepolia testnet. Get free test ETH from a faucet.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (_walletAddress != null) ...[
                        const SizedBox(height: 12),
                        const Text('Your wallet address:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _walletAddress!,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: AppColors.green, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _walletAddress!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Address copied!'), backgroundColor: AppColors.green, duration: Duration(seconds: 2)),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Text('Steps:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      _buildStep('1', 'Copy your wallet address above'),
                      _buildStep('2', 'Visit a Sepolia faucet (e.g. sepoliafaucet.com)'),
                      _buildStep('3', 'Paste your address and request test ETH'),
                      _buildStep('4', 'Refresh your balance here'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildOtherPaymentMethods(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadWalletData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Refresh Balance', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOtherPaymentMethods() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        collapsedBackgroundColor: AppColors.background,
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Other payment methods',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        children: [
          _buildPaymentMethodRow(Icons.credit_card, 'Credit / Debit card', 'Fiat top-up'),
          const SizedBox(height: 4),
          _buildPaymentMethodRow(Icons.account_balance_wallet, 'PayPal', 'Instant top-up'),
          const SizedBox(height: 4),
          _buildPaymentMethodRow(Icons.savings, 'Bank transfer', 'SEPA'),
          const SizedBox(height: 4),
          const Text(
            'Coming soon. Use Sepolia faucet above for test ETH.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(IconData icon, String title, String subtitle) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title – fiat on-ramp integration planned for future release'),
            backgroundColor: AppColors.primaryBlue,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ==================== WITHDRAW / SEND ====================
  void _showWithdraw() {
    final amountController = TextEditingController();
    final addressController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send ETH',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Available: ${_balance.toStringAsFixed(4)} ETH',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Recipient Address',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: '0x...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Amount (ETH)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: '0.01',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.white54),
                  suffixIcon: TextButton(
                    onPressed: () {
                      final max = (_balance - PaymentConfig.gasFeeBuffer).clamp(0.0, double.infinity);
                      amountController.text = max.toStringAsFixed(6);
                    },
                    child: const Text('MAX', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final toAddress = addressController.text.trim();
                          final amount = double.tryParse(amountController.text.trim());

                          final hexRegExp = RegExp(r'^0x[0-9a-fA-F]{40}$');
                          if (toAddress.isEmpty || !hexRegExp.hasMatch(toAddress)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid Ethereum address'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          if (amount + PaymentConfig.gasFeeBuffer > _balance) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Insufficient balance (including gas fee)'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setSheetState(() => isSending = true);
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final txHash = await _web3Service.sendPayment(
                              fromAddress: _walletAddress!,
                              toAddress: toAddress,
                              amountInEth: amount,
                            );

                            if (txHash != null) {
                              await _transactionService.saveTransaction(Transaction(
                                id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                                stationName: 'Send to ${toAddress.substring(0, 6)}...${toAddress.substring(toAddress.length - 4)}',
                                dateTime: DateTime.now(),
                                energy: 0,
                                amount: amount * PaymentConfig.ethToUsdRate,
                                isCredit: false,
                                txHash: txHash,
                                walletAddress: _walletAddress,
                              ));
                            }

                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(txHash != null ? 'Sent! Tx: ${txHash.substring(0, 10)}... (checking balance...)' : 'Transaction submitted'),
                                backgroundColor: AppColors.green,
                              ),
                            );
                            _refreshBalanceAfterSend();
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Send failed: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
                            );
                          } finally {
                            if (context.mounted) setSheetState(() => isSending = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Send ETH', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshBalanceAfterSend() {
    // Wait 3 seconds for Sepolia to process, then refresh
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _loadWalletData();
      }
    });
  }

  // ==================== SWAP (ETH info) ====================
  void _showSwap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Swap',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.swap_horiz, color: AppColors.green, size: 24),
                      SizedBox(width: 8),
                      Text('Token Swap', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Token swapping is not available on the Sepolia testnet. This feature will be enabled when the app moves to mainnet.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text('Current Balance', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${_balance.toStringAsFixed(4)} ETH',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '≈ \$${(_balance * PaymentConfig.ethToUsdRate).toStringAsFixed(2)} USD',
                    style: const TextStyle(color: AppColors.green, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SCAN (QR-like send) ====================
  void _showScan() {
    final addressController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Pay',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter or paste a wallet address to send a quick payment for EV charging.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: addressController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Wallet Address',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: '0x...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.qr_code, color: Colors.white54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, color: AppColors.green),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.startsWith('0x')) {
                      addressController.text = data.text!;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final addr = addressController.text.trim();
                  final addrHexRegExp = RegExp(r'^0x[0-9a-fA-F]{40}$');
                  if (addr.isEmpty || !addrHexRegExp.hasMatch(addr)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid Ethereum address'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  // Open the withdraw/send sheet pre-filled with this address
                  _showSendToAddress(addr);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue to Send', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendToAddress(String prefillAddress) {
    final amountController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send Payment', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'To: ${prefillAddress.substring(0, 6)}...${prefillAddress.substring(prefillAddress.length - 4)}',
                style: const TextStyle(color: AppColors.green, fontSize: 14, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'Available: ${_balance.toStringAsFixed(4)} ETH',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Amount (ETH)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: '0.01',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final amount = double.tryParse(amountController.text.trim());
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          if (amount + PaymentConfig.gasFeeBuffer > _balance) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Insufficient balance'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setSheetState(() => isSending = true);
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final txHash = await _web3Service.sendPayment(
                              fromAddress: _walletAddress!,
                              toAddress: prefillAddress,
                              amountInEth: amount,
                            );

                            if (txHash != null) {
                              await _transactionService.saveTransaction(Transaction(
                                id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                                stationName: 'Payment to ${prefillAddress.substring(0, 6)}...${prefillAddress.substring(prefillAddress.length - 4)}',
                                dateTime: DateTime.now(),
                                energy: 0,
                                amount: amount * PaymentConfig.ethToUsdRate,
                                isCredit: false,
                                txHash: txHash,
                                walletAddress: _walletAddress,
                              ));
                            }

                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(txHash != null ? 'Sent! Tx: ${txHash.substring(0, 10)}... (checking balance...)' : 'Transaction submitted'),
                                backgroundColor: AppColors.green,
                              ),
                            );
                            _refreshBalanceAfterSend();
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
                            );
                          } finally {
                            if (context.mounted) setSheetState(() => isSending = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Confirm & Send', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddWalletSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Connect Wallet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Add or switch your payment wallet', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),
              _buildWalletOption(
              icon: Icons.account_balance_wallet,
              title: 'In-App Wallet',
              subtitle: 'Quick setup, no extension needed',
              color: AppColors.primaryBlue,
              isActive: _walletType == 'In-App Wallet',
              onTap: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                nav.pop();
                try {
                  final address = await _inAppWalletService.createOrGetInAppWallet();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('wallet_address', address);
                  await _loadWalletData();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('In-App Wallet connected'), backgroundColor: AppColors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _buildWalletOption(
              icon: Icons.open_in_new,
              title: 'MetaMask',
              subtitle: 'Connect external MetaMask wallet',
              color: Colors.orange,
              isActive: _walletType == 'MetaMask',
              onTap: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                nav.pop();
                try {
                  await _web3Service.initialize(network: 'sepolia');
                  final address = await _web3Service.connectWallet();
                  if (address != null && address.isNotEmpty) {
                    await _web3Service.saveWalletAddress(address);
                    await _loadWalletData();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('MetaMask wallet connected'), backgroundColor: AppColors.green),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('MetaMask: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _buildWalletOption(
              icon: Icons.key,
              title: 'Import Private Key',
              subtitle: 'Import an existing wallet by private key',
              color: const Color(0xFF9C27B0),
              isActive: false,
              onTap: () {
                Navigator.pop(context);
                _showImportKeySheet();
              },
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildWalletOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? color.withValues(alpha: 0.4) : Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Active', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  void _showImportKeySheet() {
    final keyController = TextEditingController();
    bool isImporting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Import Private Key', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Paste your Ethereum private key to import an existing wallet. Your key is stored securely on-device only.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: keyController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Private Key',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: '0x... or hex string',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.key, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: AppColors.green),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        keyController.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isImporting
                      ? null
                      : () async {
                          var key = keyController.text.trim();
                          if (key.startsWith('0x')) key = key.substring(2);
                          final hexKeyRegExp = RegExp(r'^[0-9a-fA-F]{64}$');
                          if (!hexKeyRegExp.hasMatch(key)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid private key (must be 64 hex characters: 0-9, a-f)'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          setSheetState(() => isImporting = true);
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _web3Service.importPrivateKey(key);
                            nav.pop();
                            await _loadWalletData();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Wallet imported successfully!'), backgroundColor: AppColors.green),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Import failed: ${e.toString()}'), backgroundColor: Colors.red),
                            );
                          } finally {
                            if (context.mounted) setSheetState(() => isImporting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isImporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Import Wallet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usdBalance = _balance * PaymentConfig.ethToUsdRate;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWalletData,
          color: AppColors.green,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Current Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.darkGreen,
                        AppColors.green,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Current Balance',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '\$${usdBalance.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_balance.toStringAsFixed(4)} ETH',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _lastUpdated != null
                                          ? 'Updated: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}:${_lastUpdated!.second.toString().padLeft(2, '0')}'
                                          : 'Loading balance...',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brightGreen,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Sepolia',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              const SizedBox(height: 32),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: Icons.add_circle_outline,
                    label: 'Top Up',
                    onTap: _showTopUp,
                  ),
                  _buildActionButton(
                    icon: Icons.account_balance_wallet,
                    label: 'Send',
                    onTap: _showWithdraw,
                    customIcon: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet,
                          color: AppColors.green,
                          size: 28,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward,
                              color: AppColors.green,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionButton(
                    icon: Icons.swap_horiz,
                    label: 'Swap',
                    onTap: _showSwap,
                  ),
                  _buildActionButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Quick Pay',
                    onTap: _showScan,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Recent Transactions
              if (_recentTransactions.isNotEmpty) ...[
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...(_recentTransactions.map((tx) => _buildTransactionTile(tx))),
                const SizedBox(height: 24),
              ],
              // Payment Methods Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Methods',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showAddWalletSheet,
                    child: const Text(
                      '+ Add New',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_walletAddress != null)
                _buildWalletCard(
                  walletNumber: '1',
                  address: _walletAddress!,
                  walletType: _walletType,
                )
              else
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No wallet connected',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Connect MetaMask or create an in-app wallet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _showAddWalletSheet,
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.green, size: 20),
                        label: const Text(
                          'Connect a wallet',
                          style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Transaction tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tx.isCredit ? AppColors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: tx.isCredit ? AppColors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.stationName,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tx.formattedDate,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${tx.isCredit ? '+' : '-'}\$${tx.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: tx.isCredit ? AppColors.green : Colors.red,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? customIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.green,
                width: 2,
              ),
            ),
            child: customIcon ??
                Icon(
                  icon,
                  color: AppColors.green,
                  size: 28,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard({
    required String walletNumber,
    required String address,
    required String walletType,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/metamask.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 16,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Wallet $walletNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Wallet Address',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                onPressed: _copyAddress,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Wallet Type',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            walletType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
