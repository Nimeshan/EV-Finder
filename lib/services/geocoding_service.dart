import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  // Using Nominatim (OpenStreetMap's free geocoding service)
  static const String baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<LatLng?> geocodeLocation(String query) async {
    try {
      final url = Uri.parse(
        '$baseUrl?q=${Uri.encodeComponent(query)}&format=json&limit=1'
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'EVFinder App', // Required by Nominatim
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final result = data[0];
          final lat = double.parse(result['lat'].toString());
          final lon = double.parse(result['lon'].toString());
          return LatLng(lat, lon);
        }
      }
      return null;
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }
}

