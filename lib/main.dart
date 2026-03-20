import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/booking_details_screen.dart';
import 'screens/payment_confirmation_screen.dart';
import 'screens/list_station_screen.dart';
import 'screens/create_energy_listing_screen.dart';
import 'screens/my_stations_screen.dart';
import 'screens/station_reviews_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'widgets/app_scaffold.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const AppScaffold(initialIndex: 0),
        '/marketplace': (context) => const AppScaffold(initialIndex: 1),
        '/wallet': (context) => const AppScaffold(initialIndex: 2),
        '/history': (context) => const AppScaffold(initialIndex: 3),
        '/profile': (context) => const AppScaffold(initialIndex: 4),
        '/list-station': (context) => const ListStationScreen(),
        '/my-stations': (context) => const MyStationsScreen(),
        '/create-listing': (context) => const CreateEnergyListingScreen(),
        '/rewards': (context) => const RewardsScreen(),
        '/privacy-policy': (context) => const PrivacyPolicyScreen(),
        '/station-reviews': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          return StationReviewsScreen(
            stationId: args['stationId'] ?? '',
            stationName: args['stationName'] ?? 'Station',
          );
        },
        '/booking-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          return BookingDetailsScreen(
            stationName: args['stationName'] ?? 'Unknown Station',
            address: args['address'] ?? '',
            pricePerKwh: (args['pricePerKwh'] as num?)?.toDouble() ?? 0.25,
            energyType: args['energyType'] ?? 'Standard',
            stationId: args['stationId'],
            isP2P: args['isP2P'] ?? false,
            ownerAddress: args['ownerAddress'],
          );
        },
        '/payment-confirmation': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          return PaymentConfirmationScreen(
            stationName: args['stationName'] ?? 'Unknown Station',
            address: args['address'] ?? '',
            totalAmount: (args['totalAmount'] as num?)?.toDouble() ?? 0.0,
            energy: (args['energy'] as num?)?.toDouble() ?? 0.0,
            duration: (args['duration'] as num?)?.toDouble() ?? 0.0,
            energyType: args['energyType'] ?? 'Standard',
            bookingId: args['bookingId'] ?? '',
            contractBookingId: args['contractBookingId'],
            isP2P: args['isP2P'] ?? false,
            ownerAddress: args['ownerAddress'],
          );
        },
      },
    );
  }
}
