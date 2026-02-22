import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web3_service.dart';

class Transaction {
  final String id;
  final String stationName;
  final DateTime dateTime;
  final double energy; // kWh
  final double amount; // USD
  final bool isCredit; // true for credits, false for debits
  final String? txHash; // Blockchain transaction hash
  final String? walletAddress;

  Transaction({
    required this.id,
    required this.stationName,
    required this.dateTime,
    required this.energy,
    required this.amount,
    required this.isCredit,
    this.txHash,
    this.walletAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationName': stationName,
      'dateTime': dateTime.toIso8601String(),
      'energy': energy,
      'amount': amount,
      'isCredit': isCredit,
      'txHash': txHash,
      'walletAddress': walletAddress,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      stationName: json['stationName'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      energy: (json['energy'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      isCredit: json['isCredit'] as bool,
      txHash: json['txHash'] as String?,
      walletAddress: json['walletAddress'] as String?,
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (transactionDate == today) {
      return 'Today, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

class TransactionService {
  final Web3Service _web3Service = Web3Service();
  static const String _transactionsKey = 'transactions'; // Keep for local cache

  // Save transaction to blockchain
  Future<void> saveTransaction(Transaction transaction) async {
    try {
      await _web3Service.initialize();
      
      // Record transaction on blockchain
      await _web3Service.recordTransaction(
        userAddress: transaction.walletAddress ?? '',
        stationName: transaction.stationName,
        energy: transaction.energy,
        amount: transaction.amount.abs(), // Store as positive value
        isCredit: transaction.isCredit,
        txHash: transaction.txHash ?? '',
      );
      
      // Also save locally as cache/backup
      await _saveTransactionLocally(transaction);
    } catch (e) {
      debugPrint('Error saving transaction to blockchain: $e');
      // Fallback to local storage if blockchain fails
      await _saveTransactionLocally(transaction);
      rethrow;
    }
  }

  // Save transaction to local storage (as cache/backup)
  Future<void> _saveTransactionLocally(Transaction transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await _getLocalTransactions();
    transactions.add(transaction);
    
    // Sort by date (newest first)
    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    
    // Save only last 100 transactions
    final transactionsToSave = transactions.take(100).toList();
    
    final jsonList = transactionsToSave.map((t) => t.toJson()).toList();
    await prefs.setString(_transactionsKey, json.encode(jsonList));
  }

  // Get all transactions from blockchain (with local cache fallback)
  Future<List<Transaction>> getTransactions() async {
    try {
      await _web3Service.initialize();
      final walletAddress = await _web3Service.getSavedWalletAddress();
      
      if (walletAddress != null) {
        // Try to get from blockchain first
        final blockchainTxs = await _web3Service.getUserTransactions(walletAddress);
        
        if (blockchainTxs.isNotEmpty) {
          // Convert blockchain format to Transaction objects
          return blockchainTxs.map((tx) {
            return Transaction(
              id: tx['id'] as String,
              stationName: tx['stationName'] as String,
              dateTime: DateTime.fromMillisecondsSinceEpoch((tx['timestamp'] as int) * 1000),
              energy: tx['energy'] as double,
              amount: (tx['isCredit'] as bool) ? tx['amount'] as double : -(tx['amount'] as double),
              isCredit: tx['isCredit'] as bool,
              txHash: tx['txHash'] as String,
              walletAddress: tx['userAddress'] as String,
            );
          }).toList();
        }
      }
      
      // Fallback to local storage if blockchain is empty or unavailable
      return await _getLocalTransactions();
    } catch (e) {
      debugPrint('Error getting transactions from blockchain: $e');
      // Fallback to local storage
      return await _getLocalTransactions();
    }
  }

  // Get transactions from local storage
  Future<List<Transaction>> _getLocalTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_transactionsKey);
    
    if (jsonString == null) {
      return [];
    }

    try {
      final jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((json) => Transaction.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading local transactions: $e');
      return [];
    }
  }

  // Get transactions for a specific wallet address
  Future<List<Transaction>> getTransactionsForWallet(String walletAddress) async {
    try {
      await _web3Service.initialize();
      
      // Try to get from blockchain first
      final blockchainTxs = await _web3Service.getUserTransactions(walletAddress);
      
      if (blockchainTxs.isNotEmpty) {
        // Convert blockchain format to Transaction objects
        return blockchainTxs.map((tx) {
          return Transaction(
            id: tx['id'] as String,
            stationName: tx['stationName'] as String,
            dateTime: DateTime.fromMillisecondsSinceEpoch((tx['timestamp'] as int) * 1000),
            energy: tx['energy'] as double,
            amount: (tx['isCredit'] as bool) ? tx['amount'] as double : -(tx['amount'] as double),
            isCredit: tx['isCredit'] as bool,
            txHash: tx['txHash'] as String,
            walletAddress: tx['userAddress'] as String,
          );
        }).toList();
      }
      
      // Fallback to local storage
      final allTransactions = await _getLocalTransactions();
      return allTransactions.where((t) => t.walletAddress == walletAddress).toList();
    } catch (e) {
      debugPrint('Error getting transactions for wallet: $e');
      // Fallback to local storage
      final allTransactions = await _getLocalTransactions();
      return allTransactions.where((t) => t.walletAddress == walletAddress).toList();
    }
  }

  // Clear all transactions (local cache only - blockchain data is permanent)
  Future<void> clearTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transactionsKey);
  }
}

