import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // Sample transaction data
  final List<Map<String, dynamic>> transactions = const [
    {
      'name': 'Rajagiriya Station 1',
      'date': 'Today, 11PM',
      'energy': '15.1 kWh',
      'amount': -12.11,
      'isCredit': false,
    },
    {
      'name': 'Solar Panel Power Ex',
      'date': 'Today, 11PM',
      'energy': '15.1 kWh',
      'amount': 12.11,
      'isCredit': true,
    },
    {
      'name': 'Rajagiriya Station 1',
      'date': 'Today, 11PM',
      'energy': '15.1 kWh',
      'amount': -12.11,
      'isCredit': false,
    },
    {
      'name': 'Solar Panel Power Ex',
      'date': 'Today, 11PM',
      'energy': '15.1 kWh',
      'amount': 12.11,
      'isCredit': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2B3A),
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
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildTransactionCard(
              name: transaction['name'] as String,
              date: transaction['date'] as String,
              energy: transaction['energy'] as String,
              amount: transaction['amount'] as double,
              isCredit: transaction['isCredit'] as bool,
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 2),
    );
  }

  Widget _buildTransactionCard({
    required String name,
    required String date,
    required String energy,
    required double amount,
    required bool isCredit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF3A5A4A), // Dark olive green
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Left: Circular icon with red border and EV charging plug
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.ev_station,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Middle: Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$date, $energy',
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0), // Light gray
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Right: Transaction amount
          Text(
            '${amount >= 0 ? '+' : ''}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: isCredit ? const Color(0xFF4CAF50) : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2B3A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/wallet');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(context, '/history');
          } else if (index == 3) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A2B3A),
        selectedItemColor: const Color(0xFF4A9EFF),
        unselectedItemColor: Colors.white,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
