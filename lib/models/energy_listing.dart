import 'package:intl/intl.dart';

class EnergyListing {
  final int id;
  final String sellerAddress;
  final double energyKwh;
  final double pricePerKwh;
  final double totalPrice;
  final bool isActive;
  final bool isSold;
  final String? buyerAddress;
  final String? txHash;
  final DateTime createdAt;

  EnergyListing({
    required this.id,
    required this.sellerAddress,
    required this.energyKwh,
    required this.pricePerKwh,
    required this.totalPrice,
    required this.isActive,
    required this.isSold,
    this.buyerAddress,
    this.txHash,
    required this.createdAt,
  });

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final timeStr = DateFormat('h:mm a').format(createdAt);

    if (date == today) return 'Today, $timeStr';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday, $timeStr';
    return '${DateFormat('dd/MM/yyyy').format(createdAt)}, $timeStr';
  }

  String get statusLabel {
    if (isSold) return 'Sold';
    if (isActive) return 'Active';
    return 'Cancelled';
  }

  String get sellerShort {
    if (sellerAddress.length < 10) return sellerAddress;
    return '${sellerAddress.substring(0, 6)}...${sellerAddress.substring(sellerAddress.length - 4)}';
  }

  factory EnergyListing.fromContractData(Map<String, dynamic> data) {
    return EnergyListing(
      id: data['id'] ?? 0,
      sellerAddress: data['seller'] ?? '',
      energyKwh: (data['energyKwh'] ?? 0) / 1000.0,
      pricePerKwh: (data['pricePerKwh'] ?? 0) / 100.0,
      totalPrice: (data['totalPrice'] ?? 0) / 100.0,
      isActive: data['isActive'] ?? false,
      isSold: data['isSold'] ?? false,
      buyerAddress: data['buyer'],
      txHash: data['txHash'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((data['createdAt'] ?? 0) as int) * 1000,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerAddress': sellerAddress,
      'energyKwh': energyKwh,
      'pricePerKwh': pricePerKwh,
      'totalPrice': totalPrice,
      'isActive': isActive,
      'isSold': isSold,
      'buyerAddress': buyerAddress,
      'txHash': txHash,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory EnergyListing.fromJson(Map<String, dynamic> json) {
    return EnergyListing(
      id: json['id'] ?? 0,
      sellerAddress: json['sellerAddress'] ?? '',
      energyKwh: (json['energyKwh'] ?? 0.0).toDouble(),
      pricePerKwh: (json['pricePerKwh'] ?? 0.0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0.0).toDouble(),
      isActive: json['isActive'] ?? false,
      isSold: json['isSold'] ?? false,
      buyerAddress: json['buyerAddress'],
      txHash: json['txHash'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
    );
  }
}
