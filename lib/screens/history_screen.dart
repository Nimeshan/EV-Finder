import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/booking_service.dart';
import '../services/energy_trading_service.dart';
import '../services/receipt_service.dart';
import '../services/transaction_service.dart';
import '../services/web3_service.dart';
import '../models/energy_listing.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final BookingService _bookingService = BookingService();
  final Web3Service _web3Service = Web3Service();
  final ReceiptService _receiptService = ReceiptService();
  final EnergyTradingService _energyService = EnergyTradingService();
  late TabController _tabController;

  List<Transaction> _transactions = [];
  List<Booking> _bookings = [];
  List<EnergyListing> _energyTrades = [];
  bool _isLoading = true;
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _walletAddress = await _web3Service.getSavedWalletAddress();
      if (_walletAddress != null) {
        _transactions = await _transactionService.getTransactionsForWallet(
          _walletAddress!,
        );
        _bookings = await _bookingService.getUserBookings(
          walletAddress: _walletAddress,
        );
        // Get ALL energy trades (both bought and sold)
        _energyTrades = await _energyService.getMyEnergyTrades(_walletAddress!);
      } else {
        _transactions = await _transactionService.getTransactions();
        _bookings = await _bookingService.getUserBookings();
        _energyTrades = [];
      }
    } catch (e) {
      debugPrint('Error loading history data: $e');
      _transactions = [];
      _bookings = [];
      _energyTrades = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadReceipt(Transaction transaction) async {
    final pdf = _receiptService.generateReceipt(transaction);
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'EVFinder_Receipt_${transaction.id}',
    );
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Cancel Booking',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to cancel your booking at ${booking.stationName}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Cancel Booking',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (booking.contractBookingId != null && _walletAddress != null) {
        await _web3Service.initialize();
        await _web3Service.cancelBookingOnChain(
          fromAddress: _walletAddress!,
          bookingId: booking.contractBookingId!,
        );
      }
      await _bookingService.cancelBooking(booking.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              booking.contractBookingId != null
                  ? 'Booking cancelled. Refund will appear in your wallet.'
                  : 'Booking cancelled successfully',
            ),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  void _showTransactionDetail(Transaction transaction) {
    final walletDisplay = transaction.walletAddress != null
        ? '${transaction.walletAddress!.substring(0, 6)}...${transaction.walletAddress!.substring(transaction.walletAddress!.length - 4)}'
        : 'N/A';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Transaction Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Station', transaction.stationName),
            _buildDetailRow('Date', transaction.formattedDate),
            _buildDetailRow(
              'Energy',
              '${transaction.energy.toStringAsFixed(1)} kWh',
            ),
            _buildDetailRow(
              'Amount',
              '\$${transaction.amount.abs().toStringAsFixed(2)}',
            ),
            _buildDetailRow('Wallet', walletDisplay),
            if (transaction.txHash != null && transaction.txHash!.isNotEmpty)
              _buildDetailRow(
                'Tx Hash',
                '${transaction.txHash!.substring(0, 10)}...${transaction.txHash!.substring(transaction.txHash!.length - 6)}',
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _downloadReceipt(transaction);
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  'Download Receipt',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Bookings'),
            Tab(text: 'Energy Trades'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(),
                _buildBookingsTab(),
                _buildEnergyTradesTab(),
              ],
            ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history, color: Colors.white70, size: 64),
            SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Your payment history will appear here',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildTransactionCard(transaction),
          );
        },
      ),
    );
  }

  Widget _buildBookingsTab() {
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.calendar_today, color: Colors.white70, size: 64),
            SizedBox(height: 16),
            Text(
              'No bookings yet',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Your charging bookings will appear here',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildBookingCard(booking),
          );
        },
      ),
    );
  }

  Widget _buildEnergyTradesTab() {
    if (_energyTrades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bolt, color: Colors.white70, size: 64),
            SizedBox(height: 16),
            Text(
              'No energy trades yet',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Your energy trading history will appear here',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _energyTrades.length,
        itemBuilder: (context, index) {
          final trade = _energyTrades[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildEnergyTradeCard(trade),
          );
        },
      ),
    );
  }

  Widget _buildEnergyTradeCard(EnergyListing trade) {
    // Determine if user is buyer or seller
    final isSeller =
        _walletAddress != null &&
        trade.sellerAddress.toLowerCase() == _walletAddress!.toLowerCase();

    Color statusColor;
    String actionText;

    if (trade.isSold) {
      statusColor = AppColors.green;
      actionText = isSeller ? 'SOLD ↗' : 'PURCHASED ↙';
    } else if (trade.isActive) {
      statusColor = Colors.orange;
      actionText = 'LISTED';
    } else {
      statusColor = Colors.red;
      actionText = 'CANCELLED';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.historyCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSeller ? Colors.orange : AppColors.green,
                width: 2,
              ),
            ),
            child: Icon(
              isSeller ? Icons.arrow_upward : Icons.arrow_downward,
              color: isSeller ? Colors.orange : AppColors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${trade.energyKwh.toStringAsFixed(1)} kWh @ \$${trade.pricePerKwh.toStringAsFixed(2)}/kWh',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trade.formattedDate,
                    style: const TextStyle(
                      color: AppColors.subtleGray,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${trade.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isSeller ? Colors.orange : AppColors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    actionText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    return GestureDetector(
      onTap: () => _showTransactionDetail(transaction),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.historyCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: const Icon(Icons.ev_station, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      transaction.stationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transaction.formattedDate}, ${transaction.energy.toStringAsFixed(1)} kWh',
                      style: const TextStyle(
                        color: AppColors.subtleGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}\$${transaction.amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: transaction.isCredit
                          ? AppColors.green
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.receipt_long,
                    color: Colors.white38,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final isCancellable =
        booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.confirmed;

    Color statusColor;
    switch (booking.status) {
      case BookingStatus.pending:
        statusColor = Colors.orange;
        break;
      case BookingStatus.confirmed:
        statusColor = AppColors.primaryBlue;
        break;
      case BookingStatus.completed:
        statusColor = AppColors.green;
        break;
      case BookingStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.historyCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryBlue, width: 2),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        booking.stationName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booking.formattedDate} • ${booking.durationMinutes} min',
                        style: const TextStyle(
                          color: AppColors.subtleGray,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 64),
              Expanded(
                child: Text(
                  '${booking.connectorType} • ${booking.energyKwh.toStringAsFixed(1)} kWh • \$${booking.amountUsd.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          if (isCancellable) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancelBooking(booking),
                child: const Text(
                  'Cancel Booking',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
