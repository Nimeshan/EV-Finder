import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import '../services/web3_service.dart';
import '../services/transaction_service.dart';
import '../config/payment_config.dart';
import '../theme/app_theme.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String stationName;
  final String address;
  final double totalAmount;
  final double energy;
  final double duration;
  final String energyType;
  final String? bookingId;
  /// On-chain booking id; when set, payment goes through contract escrow (secure, refundable).
  final int? contractBookingId;
  final bool isP2P;
  final String? ownerAddress;

  const PaymentConfirmationScreen({
    super.key,
    required this.stationName,
    required this.address,
    required this.totalAmount,
    required this.energy,
    required this.duration,
    this.energyType = 'Standard',
    this.bookingId,
    this.contractBookingId,
    this.isP2P = false,
    this.ownerAddress,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final Web3Service _web3Service = Web3Service();
  final TransactionService _transactionService = TransactionService();
  final BookingService _bookingService = BookingService();
  String? _walletAddress;
  double _walletBalance = 0.0;
  bool _isProcessing = false;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoadingBalance = true;
    });

    try {
      await _web3Service.initialize();
      _walletAddress = await _web3Service.getSavedWalletAddress();

      if (_walletAddress != null) {
        _walletBalance = await _web3Service.getBalance(_walletAddress!);
      }
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
        });
      }
    }
  }

  bool get _hasSufficientBalance {
    final amountInEth = widget.totalAmount / PaymentConfig.ethToUsdRate;
    return _walletBalance >= (amountInEth + PaymentConfig.gasFeeBuffer);
  }

  String get _formattedDateTime {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour;
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '${months[now.month - 1]} ${now.day}, ${now.year} at $hour:${now.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _processPayment() async {
    if (_walletAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No wallet connected. Please connect MetaMask first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_hasSufficientBalance) {
      final amountInEth = widget.totalAmount / PaymentConfig.ethToUsdRate;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Insufficient Balance',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your wallet balance is insufficient to complete this payment.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  'Required: ${amountInEth.toStringAsFixed(4)} ETH (\$${widget.totalAmount.toStringAsFixed(2)})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: ${_walletBalance.toStringAsFixed(4)} ETH (\$${(_walletBalance * PaymentConfig.ethToUsdRate).toStringAsFixed(2)})',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please add funds to your wallet and try again.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _web3Service.initialize();

      final amountInEth = widget.totalAmount / PaymentConfig.ethToUsdRate;
      String? txHash;

      if (widget.contractBookingId != null) {
        // Pay through contract escrow (secure, refund on cancel)
        final beneficiary = (widget.isP2P && widget.ownerAddress != null)
            ? widget.ownerAddress!
            : PaymentConfig.receiverWalletAddress;
        txHash = await _web3Service.payBooking(
          fromAddress: _walletAddress!,
          bookingId: widget.contractBookingId!,
          beneficiaryAddress: beneficiary,
          amountInEth: amountInEth,
        );
        if (txHash != null) {
          await _web3Service.completeBookingOnChain(
            fromAddress: _walletAddress!,
            bookingId: widget.contractBookingId!,
            txHash: txHash,
          );
        }
      } else {
        // Fallback: direct transfer to receiver (no escrow)
        final paymentAddress = (widget.isP2P && widget.ownerAddress != null)
            ? widget.ownerAddress!
            : PaymentConfig.receiverWalletAddress;
        txHash = await _web3Service.sendPayment(
          fromAddress: _walletAddress!,
          toAddress: paymentAddress,
          amountInEth: amountInEth,
        );
      }

      if (txHash != null) {
        await Future.delayed(const Duration(seconds: 2));
        await _loadWalletData();

        final transaction = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          stationName: widget.stationName,
          dateTime: DateTime.now(),
          energy: widget.energy,
          amount: -widget.totalAmount,
          isCredit: false,
          txHash: txHash,
          walletAddress: _walletAddress,
        );

        await _transactionService.saveTransaction(transaction);

        // Complete the associated booking locally if present
        if (widget.bookingId != null) {
          await _bookingService.completeBooking(widget.bookingId!, txHash: txHash);
        }

        if (mounted) {
          final hash = txHash;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.green, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment Successful!',
                      style: TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your payment has been processed successfully.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Transaction: ${hash.substring(0, 10)}...${hash.substring(hash.length - 8)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Amount: \$${widget.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Updated Balance: ${_walletBalance.toStringAsFixed(4)} ETH (\$${(_walletBalance * PaymentConfig.ethToUsdRate).toStringAsFixed(2)})',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('Continue', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.popUntil((route) => route.isFirst);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) nav.pushNamed('/wallet');
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                  ),
                  child: const Text('View Wallet', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Transaction hash not received');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Payment failed';
        if (e.toString().contains('insufficient') || e.toString().contains('balance')) {
          errorMessage = 'Insufficient balance. Please add funds to your wallet.';
        } else if (e.toString().contains('rejected') || e.toString().contains('User denied')) {
          errorMessage = 'Payment was cancelled.';
        } else {
          errorMessage = 'Payment failed: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final serviceFee = PaymentConfig.serviceFee;
    final subtotal = widget.totalAmount - serviceFee;
    final ethEquivalent = widget.totalAmount / PaymentConfig.ethToUsdRate;

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
          'Payment Confirmation',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station Information Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stationName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.address,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Available Now',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.ev_station,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Booking Details Section
            const Text(
              'BOOKING DETAILS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Date & Time', _formattedDateTime),
                  const SizedBox(height: 12),
                  _buildDetailRow('Est. Duration', '${widget.duration.toInt()} mins'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Energy Type',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Row(
                        children: [
                          if (widget.energyType == 'Green Energy')
                            const Icon(Icons.eco, color: AppColors.green, size: 16),
                          if (widget.energyType == 'Green Energy')
                            const SizedBox(width: 4),
                          Text(
                            widget.energyType,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Rate', '\$${(subtotal / widget.energy).toStringAsFixed(2)}/kWh'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Payment Method Section
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/metamask.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 32,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _walletAddress != null
                              ? 'MetaMask (${_formatAddress(_walletAddress!)})'
                              : 'No wallet connected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_walletAddress != null && !_isLoadingBalance)
                          Text(
                            'Balance: ${_walletBalance.toStringAsFixed(4)} ETH (\$${(_walletBalance * PaymentConfig.ethToUsdRate).toStringAsFixed(2)})',
                            style: TextStyle(
                              color: _hasSufficientBalance ? Colors.green : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Payment Summary Section
            const Text(
              'PAYMENT SUMMARY',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal (approx. ${widget.energy.toStringAsFixed(0)} kWh)',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        '\$${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Service Fee',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        '\$${serviceFee.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${widget.totalAmount.toStringAsFixed(2)} USD',
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '~${ethEquivalent.toStringAsFixed(4)} ETH',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Security Message
            const Row(
              children: [
                Icon(Icons.lock, color: AppColors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payments are secure and encrypted',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Balance Warning
            if (_walletAddress != null && !_isLoadingBalance && !_hasSufficientBalance)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient balance. Please add funds to your wallet.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Confirm and Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isProcessing || _isLoadingBalance || !_hasSufficientBalance)
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Processing Payment...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Confirm and Pay \$${widget.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: Colors.white),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
