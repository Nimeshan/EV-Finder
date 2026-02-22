import 'package:flutter/material.dart';
import '../models/energy_listing.dart';
import '../services/energy_trading_service.dart';
import '../services/web3_service.dart';
import '../config/payment_config.dart';
import '../theme/app_theme.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> with SingleTickerProviderStateMixin {
  final EnergyTradingService _tradingService = EnergyTradingService();
  final Web3Service _web3Service = Web3Service();
  late TabController _tabController;

  List<EnergyListing> _activeListings = [];
  List<EnergyListing> _myListings = [];
  double _myCredits = 0;
  String? _walletAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _walletAddress = await _web3Service.getSavedWalletAddress();
      if (_walletAddress != null) {
        _myCredits = await _tradingService.getMyEnergyCredits(_walletAddress!);
        _myListings = await _tradingService.getMyListings(_walletAddress!);
      }
      _activeListings = await _tradingService.getActiveListings();
    } catch (e) {
      debugPrint('Error loading marketplace data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addCredits() async {
    final controller = TextEditingController(text: '50');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Add Energy Credits', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Simulate solar energy production by adding energy credits to your account.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Energy (kWh)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(context, value);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Add Credits', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result > 0 && _walletAddress != null) {
      await _tradingService.addCredits(walletAddress: _walletAddress!, energyKwh: result);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${result.toStringAsFixed(1)} kWh credits!'), backgroundColor: AppColors.green),
        );
      }
    }
  }

  Future<void> _buyListing(EnergyListing listing) async {
    if (_walletAddress == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Confirm Purchase', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Energy: ${listing.energyKwh.toStringAsFixed(1)} kWh', style: const TextStyle(color: Colors.white)),
            Text('Price: \$${listing.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
            Text('Seller: ${listing.sellerShort}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            const Text('This will trigger a MetaMask payment to the seller.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Buy Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _web3Service.initialize();
      final amountInEth = listing.totalPrice / PaymentConfig.ethToUsdRate;

      final txHash = await _web3Service.sendPayment(
        fromAddress: _walletAddress!,
        toAddress: listing.sellerAddress,
        amountInEth: amountInEth,
      );

      if (txHash != null) {
        await _tradingService.purchaseListing(
          buyerAddress: _walletAddress!,
          listingId: listing.id,
          sellerAddress: listing.sellerAddress,
          totalPriceUsd: listing.totalPrice,
          energyKwh: listing.energyKwh,
          paymentTxHash: txHash,
        );

        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchased ${listing.energyKwh.toStringAsFixed(1)} kWh! Credits added to your balance.'),
              backgroundColor: AppColors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Energy Marketplace', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.green,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Buy Energy'),
            Tab(text: 'Sell Energy'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.green)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBuyTab(),
                _buildSellTab(),
              ],
            ),
    );
  }

  Widget _buildBuyTab() {
    if (_activeListings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, color: Colors.white38, size: 64),
            SizedBox(height: 16),
            Text('No energy listings available', style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 8),
            Text('Check back later for P2P energy offers', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeListings.length,
        itemBuilder: (context, index) {
          final listing = _activeListings[index];
          // Don't show own listings in buy tab
          if (_walletAddress != null && listing.sellerAddress.toLowerCase() == _walletAddress!.toLowerCase()) {
            return const SizedBox.shrink();
          }
          return _buildBuyCard(listing);
        },
      ),
    );
  }

  Widget _buildBuyCard(EnergyListing listing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt, color: AppColors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${listing.energyKwh.toStringAsFixed(1)} kWh', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Seller: ${listing.sellerShort}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${listing.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('\$${listing.pricePerKwh.toStringAsFixed(2)}/kWh', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _buyListing(listing),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Buy Energy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Credits balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Energy Credits', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('${_myCredits.toStringAsFixed(1)} kWh', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addCredits,
                          icon: const Icon(Icons.solar_power, color: Colors.white, size: 18),
                          label: const Text('Add Solar Credits', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _myCredits > 0 ? () => Navigator.pushNamed(context, '/create-listing') : null,
                          icon: const Icon(Icons.sell, color: Colors.white, size: 18),
                          label: const Text('Sell Energy', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('MY LISTINGS', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            if (_myListings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.sell, color: Colors.white38, size: 40),
                    SizedBox(height: 8),
                    Text('No listings yet', style: TextStyle(color: Colors.white54)),
                    Text('Create a listing to sell your energy credits', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              )
            else
              ..._myListings.map((listing) => _buildMyListingCard(listing)),
          ],
        ),
      ),
    );
  }

  Widget _buildMyListingCard(EnergyListing listing) {
    Color statusColor;
    if (listing.isSold) {
      statusColor = AppColors.green;
    } else if (listing.isActive) {
      statusColor = AppColors.primaryBlue;
    } else {
      statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                Text('${listing.energyKwh.toStringAsFixed(1)} kWh @ \$${listing.pricePerKwh.toStringAsFixed(2)}/kWh',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Total: \$${listing.totalPrice.toStringAsFixed(2)} • ${listing.formattedDate}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(listing.statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
