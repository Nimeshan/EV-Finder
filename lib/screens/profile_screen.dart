import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/web3_service.dart';
import '../services/energy_trading_service.dart';
import '../services/booking_service.dart';
import '../services/charging_station_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Web3Service _web3Service = Web3Service();
  final EnergyTradingService _energyService = EnergyTradingService();
  final BookingService _bookingService = BookingService();
  final TransactionService _transactionService = TransactionService();
  String? _userName;
  String? _walletAddress;
  double _energyCredits = 0;
  int _rewardPoints = 0;
  bool _demoMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    await _web3Service.initialize();
    final address = await _web3Service.getSavedWalletAddress();
    final name = await _web3Service.getSavedUserName();

    double credits = 0;
    int points = 0;
    if (address != null) {
      try {
        credits = await _energyService.getMyEnergyCredits(address);
        points = await _web3Service.getRewardPoints(address);
      } catch (_) {}
    }

    final demoMode = await ChargingStationService.isDemoMode();
    setState(() {
      _walletAddress = address;
      _userName = name ?? 'User';
      _energyCredits = credits;
      _rewardPoints = points;
      _demoMode = demoMode;
    });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _web3Service.clearWallet();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _showPrivacySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Privacy & data',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your wallet address and transaction data are stored on the blockchain (public). '
                'We keep a local cache for offline access. You can export or clear it.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.download, color: AppColors.primaryBlue),
                title: const Text('Export my data', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Copy wallet, name, bookings & transactions', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportMyData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: const Text('Clear local cache', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Remove cached bookings & transactions from this device', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  await _clearLocalCache();
                },
              ),
              const Divider(color: Colors.white24),
              SwitchListTile(
                secondary: const Icon(Icons.science, color: Colors.deepPurple),
                title: const Text('Simulation mode', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Use mock stations only (for testing)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: _demoMode,
                onChanged: (value) async {
                  await ChargingStationService.setDemoMode(value);
                  setState(() => _demoMode = value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value ? 'Demo mode on: map shows mock stations' : 'Demo mode off'),
                        backgroundColor: AppColors.primaryBlue,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportMyData() async {
    final address = _walletAddress;
    if (address == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No wallet connected'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    final bookings = await _bookingService.getUserBookings(walletAddress: address);
    final transactions = await _transactionService.getTransactionsForWallet(address);
    final export = {
      'walletAddress': address,
      'userName': _userName,
      'exportedAt': DateTime.now().toIso8601String(),
      'bookings': bookings.map((b) => b.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
    final jsonString = jsonEncode(export);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Exported data', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: SelectableText(
              jsonString,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bookings');
    await prefs.remove('transactions');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local cache cleared. On-chain data is unchanged.'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
            // Profile Picture
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/User.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // User Name
            Text(
              _userName ?? 'User',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Wallet Address
            if (_walletAddress != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            // Menu Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.ev_station,
                    label: 'My Stations',
                    subtitle: 'Manage your P2P chargers',
                    color: const Color(0xFF9C27B0),
                    onTap: () => Navigator.pushNamed(context, '/my-stations'),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.bolt,
                    label: 'Energy Credits',
                    subtitle: '${_energyCredits.toStringAsFixed(1)} kWh available',
                    color: AppColors.green,
                    onTap: () => Navigator.pushNamed(context, '/marketplace'),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.star,
                    label: 'Reward Points',
                    subtitle: '$_rewardPoints pts (charging, P2P, green energy)',
                    color: const Color(0xFFFFB300),
                    onTap: () => Navigator.pushNamed(context, '/history'),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.history,
                    label: 'Transaction History',
                    subtitle: 'View all payments and trades',
                    color: AppColors.primaryBlue,
                    onTap: () => Navigator.pushNamed(context, '/history'),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.privacy_tip,
                    label: 'Privacy & data',
                    subtitle: 'Export data, clear local cache',
                    color: Colors.teal,
                    onTap: _showPrivacySheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Sign Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
              child: ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _web3Service.dispose();
    super.dispose();
  }
}
