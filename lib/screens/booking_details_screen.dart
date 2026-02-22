import 'package:flutter/material.dart';
import '../config/payment_config.dart';
import '../services/booking_service.dart';
import '../services/web3_service.dart';
import '../theme/app_theme.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String stationName;
  final String address;
  final double pricePerKwh;
  final String energyType;
  final String? stationId;
  final bool isP2P;
  final String? ownerAddress;

  const BookingDetailsScreen({
    super.key,
    required this.stationName,
    required this.address,
    required this.pricePerKwh,
    this.energyType = 'Standard',
    this.stationId,
    this.isP2P = false,
    this.ownerAddress,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  double _targetCharge = 80.0;
  String _selectedConnector = 'CCS2 150kW';
  double _connectorPrice = 0.45;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final BookingService _bookingService = BookingService();
  final Web3Service _web3Service = Web3Service();
  bool _isCreatingBooking = false;

  static const List<Map<String, dynamic>> _connectorOptions = [
    {'name': 'CCS2 150kW', 'price': 0.45, 'type': 'Fast Charging'},
    {'name': 'CHAdeMO 50kW', 'price': 0.35, 'type': 'Fast Charging'},
    {'name': 'Type 2 22kW', 'price': 0.25, 'type': 'AC Charging'},
    {'name': 'Type 2 7kW', 'price': 0.20, 'type': 'Slow Charging'},
  ];

  void _showConnectorSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Connector',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._connectorOptions.map((connector) {
                final isSelected = connector['name'] == _selectedConnector;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedConnector = connector['name'];
                      _connectorPrice = connector['price'];
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.connectorBlue : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppColors.primaryBlue, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.ev_station, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                connector['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '\$${connector['price'].toStringAsFixed(2)}/kWh • ${connector['type']}',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppColors.green, size: 24),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryBlue,
              surface: AppColors.cardBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryBlue,
              surface: AppColors.cardBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String get _formattedBookingTime {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = _selectedTime.hour > 12 ? _selectedTime.hour - 12 : _selectedTime.hour == 0 ? 12 : _selectedTime.hour;
    final period = _selectedTime.hour >= 12 ? 'PM' : 'AM';
    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year} at $hour:${_selectedTime.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _confirmAndPay() async {
    final estimatedEnergy = (_targetCharge / 100) * 40;
    final energyCost = estimatedEnergy * _connectorPrice;
    final serviceFee = PaymentConfig.serviceFee;
    final totalEstimate = energyCost + serviceFee;
    final estimatedTime = (_targetCharge / 100) * 45;

    final startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final endTime = startTime.add(Duration(minutes: estimatedTime.toInt()));

    setState(() => _isCreatingBooking = true);

    try {
      await _web3Service.initialize();
      final walletAddress = await _web3Service.getSavedWalletAddress();
      final stationId = widget.stationId ?? widget.stationName.hashCode.toString();

      // Create on-chain first when contract is deployed (enables escrow payment and refunds)
      int? contractBookingId;
      try {
        contractBookingId = await _web3Service.createBookingOnChain(
          fromAddress: walletAddress ?? '',
          stationId: stationId,
          connectorType: _selectedConnector,
          startTimeUnix: startTime.millisecondsSinceEpoch ~/ 1000,
          endTimeUnix: endTime.millisecondsSinceEpoch ~/ 1000,
          energyKwhScaled: (estimatedEnergy * 1000).round(),
          amountUsdCents: (totalEstimate * 100).round(),
        );
      } catch (_) {
        // Continue with local-only booking if contract not deployed or RPC fails
      }

      final booking = await _bookingService.createBooking(
        stationId: stationId,
        stationName: widget.stationName,
        address: widget.address,
        connectorType: _selectedConnector,
        startTime: startTime,
        endTime: endTime,
        energyKwh: estimatedEnergy,
        amountUsd: totalEstimate,
        walletAddress: walletAddress,
        contractBookingId: contractBookingId,
      );

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/payment-confirmation',
          arguments: {
            'stationName': widget.stationName,
            'address': widget.address,
            'totalAmount': totalEstimate,
            'energy': estimatedEnergy,
            'duration': estimatedTime,
            'energyType': widget.energyType,
            'bookingId': booking.id,
            'contractBookingId': contractBookingId,
            'isP2P': widget.isP2P,
            'ownerAddress': widget.ownerAddress,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Time conflict')
                ? 'This time slot is already booked. Please choose a different time.'
                : 'Error creating booking: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimatedEnergy = (_targetCharge / 100) * 40;
    final energyCost = estimatedEnergy * _connectorPrice;
    final serviceFee = PaymentConfig.serviceFee;
    final totalEstimate = energyCost + serviceFee;
    final estimatedTime = (_targetCharge / 100) * 45;

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
          'Booking Details',
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.stationName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (widget.energyType == 'Green Energy')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Eco-Spot',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.address,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Schedule Section
            const Text(
              'SCHEDULE',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _selectDate,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.primaryBlue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  GestureDetector(
                    onTap: _selectTime,
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: AppColors.primaryBlue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Time',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Est. Duration',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '~${estimatedTime.toInt()} min',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Selected Connector Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SELECTED CONNECTOR',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                TextButton(
                  onPressed: _showConnectorSelection,
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Connector Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.connectorBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.ev_station,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedConnector,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_connectorPrice.toStringAsFixed(2)}/kWh • ${_connectorOptions.firstWhere((c) => c['name'] == _selectedConnector)['type']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.green,
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Charging Session Section
            const Text(
              'CHARGING SESSION',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'TARGET CHARGE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_targetCharge.toInt()} %',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text(
                      'EST. TIME',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '~${estimatedTime.toInt()} min',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Slider
            Slider(
              value: _targetCharge,
              min: 20,
              max: 100,
              divisions: 16,
              label: '${_targetCharge.toInt()}%',
              activeColor: AppColors.primaryBlue,
              inactiveColor: Colors.white.withValues(alpha: 0.2),
              onChanged: (value) {
                setState(() {
                  _targetCharge = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('20%', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('50%', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('80%', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('100%', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 32),
            // Estimate Summary
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
                      const Text(
                        'Booking Time',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _formattedBookingTime,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Energy (est. ${estimatedEnergy.toStringAsFixed(0)}kWh)',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        '\$${energyCost.toStringAsFixed(2)}',
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
                        'Total Estimate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${totalEstimate.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Confirm & Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreatingBooking ? null : _confirmAndPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isCreatingBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Confirm & Pay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white),
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
}
