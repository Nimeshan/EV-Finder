import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/web3_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final Web3Service _web3Service = Web3Service();
  final TransactionService _transactionService = TransactionService();

  int _totalPoints = 0;
  bool _isLoading = true;
  List<_RewardEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() => _isLoading = true);

    try {
      await _web3Service.initialize();
      final address = await _web3Service.getSavedWalletAddress();
      if (address == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final transactions = await _transactionService.getTransactionsForWallet(address);

      // Build reward history from transactions
      final history = <_RewardEntry>[];
      for (final tx in transactions) {
        if (!tx.isCredit) {
          // Charging session = reward points
          final pts = (tx.energy * 10).round(); // 10 pts per kWh
          history.add(_RewardEntry(
            title: 'Charging Session',
            subtitle: tx.stationName,
            points: pts,
            icon: Icons.ev_station,
            color: AppColors.primaryBlue,
            date: tx.dateTime,
          ));
        } else {
          // Earned as P2P host
          final pts = (tx.energy * 15).round(); // 15 pts per kWh hosted
          history.add(_RewardEntry(
            title: 'P2P Hosting Reward',
            subtitle: tx.stationName,
            points: pts,
            icon: Icons.home_work,
            color: const Color(0xFF9C27B0),
            date: tx.dateTime,
          ));
        }
      }

      // Sort newest first
      history.sort((a, b) => b.date.compareTo(a.date));

      // Total = sum of all history points minus already-redeemed points
      final earned = history.fold<int>(0, (sum, e) => sum + e.points);
      final prefs = await SharedPreferences.getInstance();
      final redeemed = prefs.getInt('redeemed_points_${address.toLowerCase()}') ?? 0;
      final available = (earned - redeemed).clamp(0, earned);

      if (mounted) {
        setState(() {
          _totalPoints = available;
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rewards: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRedeemSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text('Redeem Points', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildRedeemOption(
                icon: Icons.bolt,
                title: 'Energy Credits',
                subtitle: '500 pts = 1 kWh credit',
                pointsCost: 500,
                color: AppColors.green,
              ),
              const SizedBox(height: 12),
              _buildRedeemOption(
                icon: Icons.discount,
                title: 'Charging Discount',
                subtitle: '1000 pts = 10% off next session',
                pointsCost: 1000,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(height: 12),
              _buildRedeemOption(
                icon: Icons.star,
                title: 'Priority Booking',
                subtitle: '750 pts = priority access for 7 days',
                pointsCost: 750,
                color: const Color(0xFFFFB300),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRedeemOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required int pointsCost,
    required Color color,
  }) {
    final canRedeem = _totalPoints >= pointsCost;
    return GestureDetector(
      onTap: canRedeem
          ? () async {
              Navigator.pop(context);
              try {
                final address = await _web3Service.getSavedWalletAddress();
                if (address != null) {
                  await _web3Service.redeemRewardPoints(address, pointsCost);
                  await _loadRewards();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Redeemed $title for $pointsCost pts!'),
                      backgroundColor: AppColors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Redemption failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: canRedeem ? color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: canRedeem ? color.withValues(alpha: 0.3) : Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: canRedeem ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: canRedeem ? color : Colors.white38, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: canRedeem ? Colors.white : Colors.white38, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: canRedeem ? Colors.white54 : Colors.white24, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: canRedeem ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$pointsCost pts',
                style: TextStyle(color: canRedeem ? color : Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rewards', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue)))
          : RefreshIndicator(
              onRefresh: _loadRewards,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Points summary card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars, color: Colors.white, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            '$_totalPoints',
                            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                          ),
                          const Text('Reward Points', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _totalPoints > 0 ? _showRedeemSheet : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFFF8F00),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Redeem Points', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // How to earn section
                    const Text('HOW TO EARN', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _buildEarnTile(Icons.ev_station, 'Charge your EV', '10 pts per kWh', AppColors.primaryBlue),
                    const SizedBox(height: 8),
                    _buildEarnTile(Icons.home_work, 'Host P2P charging', '15 pts per kWh hosted', const Color(0xFF9C27B0)),
                    const SizedBox(height: 8),
                    _buildEarnTile(Icons.eco, 'Use green energy', '2x bonus multiplier', AppColors.green),
                    const SizedBox(height: 8),
                    _buildEarnTile(Icons.rate_review, 'Write a review', '25 pts per review', const Color(0xFFFFB300)),
                    const SizedBox(height: 24),

                    // Earning history
                    const Text('EARNING HISTORY', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    if (_history.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.history, color: Colors.white38, size: 40),
                            SizedBox(height: 12),
                            Text('No reward history yet', style: TextStyle(color: Colors.white54, fontSize: 14)),
                            SizedBox(height: 4),
                            Text('Start charging to earn points!', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ..._history.map((entry) => _buildHistoryTile(entry)),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEarnTile(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(_RewardEntry entry) {
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
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, color: entry.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(entry.subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${entry.points} pts',
                style: TextStyle(color: entry.color, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                _formatDate(entry.date),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _RewardEntry {
  final String title;
  final String subtitle;
  final int points;
  final IconData icon;
  final Color color;
  final DateTime date;

  _RewardEntry({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.icon,
    required this.color,
    required this.date,
  });
}
