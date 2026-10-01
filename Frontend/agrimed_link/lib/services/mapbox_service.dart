import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Representation of a Geocoded Place / Address
class MapPlace {
  final String id;
  final String placeName;
  final String text;
  final double latitude;
  final double longitude;

  const MapPlace({
    required this.id,
    required this.placeName,
    required this.text,
    required this.latitude,
    required this.longitude,
  });

  factory MapPlace.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lng = 0.0;

    if (json['coordinates'] != null) {
      lng = (json['coordinates']['longitude'] as num?)?.toDouble() ?? 0.0;
      lat = (json['coordinates']['latitude'] as num?)?.toDouble() ?? 0.0;
    } else if (json['center'] != null && json['center'] is List) {
      final center = json['center'] as List;
      if (center.length >= 2) {
        lng = (center[0] as num).toDouble();
        lat = (center[1] as num).toDouble();
      }
    }

    return MapPlace(
      id: json['id']?.toString() ?? '',
      placeName: json['placeName'] ?? json['place_name'] ?? '',
      text: json['name'] ?? json['text'] ?? '',
      latitude: lat,
      longitude: lng,
    );
  }
}

/// Representation of an Agricultural Hub or Farm
class FarmLocation {
  final String id;
  final String name;
  final String farmerName;
  final String region;
  final double latitude;
  final double longitude;
  final List<String> crops;
  final double rating;
  final bool verified;
  final String phone;
  final String description;
  final String? mapPreviewUrl;

  const FarmLocation({
    required this.id,
    required this.name,
    required this.farmerName,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.crops,
    required this.rating,
    this.verified = true,
    required this.phone,
    required this.description,
    this.mapPreviewUrl,
  });

  factory FarmLocation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] ?? {};
    return FarmLocation(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      farmerName: json['farmerName'] ?? '',
      region: json['region'] ?? '',
      latitude: (coords['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (coords['longitude'] as num?)?.toDouble() ?? 0.0,
      crops: (json['crops'] as List?)?.map((e) => e.toString()).toList() ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      verified: json['verified'] ?? true,
      phone: json['phone'] ?? '',
      description: json['description'] ?? '',
      mapPreviewUrl: json['mapPreviewUrl'],
    );
  }
}

/// Representation of calculated Delivery Route
class DeliveryRoute {
  final double distanceKm;
  final int durationMinutes;
  final int deliveryFeeXAF;
  final String? staticRouteMapUrl;
  final List<String> steps;

  const DeliveryRoute({
    required this.distanceKm,
    required this.durationMinutes,
    required this.deliveryFeeXAF,
    this.staticRouteMapUrl,
    this.steps = const [],
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List?;
    final parsedSteps = <String>[];
    if (rawSteps != null) {
      for (final s in rawSteps) {
        if (s is Map && s['instruction'] != null) {
          parsedSteps.add(s['instruction'].toString());
        } else if (s is String) {
          parsedSteps.add(s);
        }
      }
    }

    return DeliveryRoute(
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      deliveryFeeXAF: (json['deliveryFeeXAF'] as num?)?.toInt() ?? 500,
      staticRouteMapUrl: json['staticRouteMapUrl'],
      steps: parsedSteps,
    );
  }
}

/// Mapbox Service Client for AgriMed Link
class MapboxService {
  static const String mapboxAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');

  static final MapboxService instance = MapboxService._internal();
  MapboxService._internal();

  /// Default Hubs when offline or fallback
  static const List<FarmLocation> defaultFarms = [
    FarmLocation(
      id: 'farm-001',
      name: 'Foumbot High-Yield Tomato & Pepper Farm',
      farmerName: 'Jean-Paul Ndam',
      region: 'West Region (Foumbot)',
      latitude: 5.5083,
      longitude: 10.6311,
      crops: ['Tomatoes', 'Bell Peppers', 'Carrots'],
      rating: 4.9,
      verified: true,
      phone: '+237 670 11 22 33',
      description: 'Fertile volcanic soil producing organic tomatoes and fresh bell peppers for local and wholesale markets.',
    ),
    FarmLocation(
      id: 'farm-002',
      name: 'Njombe-Penja Plantain & Banana Plantation',
      farmerName: 'Alain Ekotto',
      region: 'Littoral (Njombe-Penja)',
      latitude: 4.5772,
      longitude: 9.6633,
      crops: ['Plantains', 'Bananas', 'Penja White Pepper'],
      rating: 4.8,
      verified: true,
      phone: '+237 690 44 55 66',
      description: 'World-renowned Penja white pepper and premium organic sweet plantains harvested daily.',
    ),
    FarmLocation(
      id: 'farm-003',
      name: 'Bamenda Highland Arabica Coffee & Cabbage',
      farmerName: 'Mary Lum Che',
      region: 'Northwest (Bamenda Santa)',
      latitude: 5.8617,
      longitude: 10.1591,
      crops: ['Arabica Coffee', 'Cabbage', 'Potatoes'],
      rating: 4.95,
      verified: true,
      phone: '+237 677 88 99 00',
      description: 'Highland altitude specialty coffee and cool-climate organic cabbages and Irish potatoes.',
    ),
    FarmLocation(
      id: 'farm-004',
      name: 'Obala Greenbelt Agro-Farm',
      farmerName: 'Ebenezer Mbarga',
      region: 'Centre (Obala - Yaounde North)',
      latitude: 4.1667,
      longitude: 11.5333,
      crops: ['Cassava', 'Maize', 'Okra', 'Pineapples'],
      rating: 4.7,
      verified: true,
      phone: '+237 655 22 33 44',
      description: 'Primary organic cassava and sweet yellow maize farm supplying Yaounde central food markets.',
    ),
    FarmLocation(
      id: 'farm-005',
      name: 'Bafoussam Poultry & Maize cooperative',
      farmerName: 'Dieudonne Kamga',
      region: 'West Region (Bafoussam)',
      latitude: 5.4777,
      longitude: 10.4179,
      crops: ['Yellow Maize', 'Soya Beans', 'Poultry Feed'],
      rating: 4.85,
      verified: true,
      phone: '+237 671 23 45 67',
      description: 'Leading cooperative grain depot and organic feed supply hub for central Cameroon farmers.',
    ),
  ];

  /// Generate Mapbox Static Snapshot URL with marker
  String getStaticMapUrl({
    required double lat,
    required double lng,
    int zoom = 12,
    int width = 600,
    int height = 400,
    String style = 'outdoors-v12',
    String markerLabel = 'farm',
    String markerColor = '2E7D32',
  }) {
    final pin = 'pin-s-$markerLabel+$markerColor($lng,$lat)';
    return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/$pin/$lng,$lat,$zoom,0/${width}x${height}@2x?access_token=$mapboxAccessToken';
  }

  /// Generate Mapbox Static Route Preview URL between two coordinates
  String getRouteStaticMapUrl({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    int width = 600,
    int height = 400,
    String style = 'streets-v12',
  }) {
    final originPin = 'pin-s-farm+2E7D32($originLng,$originLat)';
    final destPin = 'pin-s-car+E65100($destLng,$destLat)';
    return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/$originPin,$destPin/auto/${width}x${height}@2x?padding=45&access_token=$mapboxAccessToken';
  }

  /// Calculate delivery fee locally based on distance
  int calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 0) return 500;
    const base = 500;
    const perKm = 150;
    final total = base + (distanceKm * perKm);
    return ((total / 50).round()) * 50;
  }

  /// Fetch registered agricultural hubs & farms
  Future<List<FarmLocation>> fetchFarms({String? crop, String? region}) async {
    try {
      final backendUrl = '${ApiService.baseUrl}/maps/farms';
      final uri = Uri.parse(backendUrl).replace(
        queryParameters: {
          if (crop != null && crop.isNotEmpty) 'crop': crop,
          if (region != null && region.isNotEmpty) 'region': region,
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded['status'] == 'success' && decoded['data']?['farms'] != null) {
          final list = decoded['data']['farms'] as List;
          return list.map((item) => FarmLocation.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[MapboxService] Fallback to default farms: $e');
    }

    // Return enriched default farms
    return defaultFarms.map((f) {
      return FarmLocation(
        id: f.id,
        name: f.name,
        farmerName: f.farmerName,
        region: f.region,
        latitude: f.latitude,
        longitude: f.longitude,
        crops: f.crops,
        rating: f.rating,
        verified: f.verified,
        phone: f.phone,
        description: f.description,
        mapPreviewUrl: getStaticMapUrl(
          lat: f.latitude,
          lng: f.longitude,
          zoom: 12,
        ),
      );
    }).toList();
  }

  /// Search places and addresses using Mapbox Geocoding API
  Future<List<MapPlace>> searchPlaces(String query, {String country = 'cm'}) async {
    if (query.trim().isEmpty) return [];

    // 1. Try via Backend API
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/maps/geocode').replace(
        queryParameters: {
          'q': query.trim(),
          'country': country,
          'limit': '6',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['status'] == 'success' && body['data']?['features'] != null) {
          final list = body['data']['features'] as List;
          return list.map((item) => MapPlace.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[MapboxService] Backend geocode fallback to direct Mapbox API: $e');
    }

    // 2. Direct Mapbox API fallback
    try {
      final directUri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query.trim())}.json',
      ).replace(
        queryParameters: {
          'access_token': mapboxAccessToken,
          'country': country,
          'limit': '6',
        },
      );

      final res = await http.get(directUri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final list = body['features'] as List?;
        if (list != null) {
          return list.map((item) => MapPlace.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[MapboxService] Direct geocode failed: $e');
    }

    return [];
  }

  /// Calculate route and delivery details
  Future<DeliveryRoute?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // 1. Try via Backend
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/maps/directions').replace(
        queryParameters: {
          'originLng': originLng.toString(),
          'originLat': originLat.toString(),
          'destLng': destLng.toString(),
          'destLat': destLat.toString(),
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['status'] == 'success' && body['data'] != null) {
          return DeliveryRoute.fromJson(body['data']);
        }
      }
    } catch (e) {
      debugPrint('[MapboxService] Backend directions fallback to direct Mapbox API: $e');
    }

    // 2. Direct Mapbox Directions API fallback
    try {
      final coords = '$originLng,$originLat;$destLng,$destLat';
      final directUri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/$coords',
      ).replace(
        queryParameters: {
          'access_token': mapboxAccessToken,
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
        },
      );

      final res = await http.get(directUri).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final routes = body['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final r = routes[0];
          final distM = (r['distance'] as num?)?.toDouble() ?? 0.0;
          final durS = (r['duration'] as num?)?.toDouble() ?? 0.0;
          final distKm = ((distM / 1000) * 10).round() / 10;
          final durMin = (durS / 60).round();
          final fee = calculateDeliveryFee(distKm);

          final rawSteps = r['legs']?[0]?['steps'] as List?;
          final parsedSteps = <String>[];
          if (rawSteps != null) {
            for (final s in rawSteps) {
              if (s['maneuver']?['instruction'] != null) {
                parsedSteps.add(s['maneuver']['instruction'].toString());
              }
            }
          }

          return DeliveryRoute(
            distanceKm: distKm,
            durationMinutes: durMin,
            deliveryFeeXAF: fee,
            staticRouteMapUrl: getRouteStaticMapUrl(
              originLat: originLat,
              originLng: originLng,
              destLat: destLat,
              destLng: destLng,
            ),
            steps: parsedSteps,
          );
        }
      }
    } catch (e) {
      debugPrint('[MapboxService] Direct directions calculation failed: $e');
    }

    return null;
  }
}
