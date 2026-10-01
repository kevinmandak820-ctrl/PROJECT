import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crop_model.dart';
import 'api_service.dart';

class CropService {
  /// When true, methods return offline mock data immediately without performing real network I/O
  static bool isTestMode = false;

  static const String _cachedCropsKey = 'cached_marketplace_crops';
  static const String _cachedMyCropsKey = 'cached_farmer_my_crops';

  /// Initial default crops for instant offline availability & fallback
  static List<CropModel> get defaultInitialCrops => [
        const CropModel(
          id: 'initial-1',
          name: 'Aloe Vera Barbadensis',
          price: 8.50,
          basePrice: 8.50,
          category: 'Medicinal',
          quantity: 120,
          unit: 'unit',
          description: 'Succulent species with thick fleshy leaves for medicinal and cosmetic extract.',
          imageUrl: 'assets/images/aloe_vera.png',
          status: 'available',
        ),
        const CropModel(
          id: 'initial-2',
          name: 'Panax Ginseng Root',
          price: 42.00,
          basePrice: 42.00,
          category: 'Adaptogenic',
          quantity: 45,
          unit: 'kg',
          description: 'Fleshy adaptogenic roots recognized for revitalizing wellness remedies.',
          imageUrl: 'assets/images/aloe_vera.png',
          status: 'available',
        ),
        const CropModel(
          id: 'initial-3',
          name: 'German Chamomile',
          price: 15.00,
          basePrice: 15.00,
          category: 'Medicinal',
          quantity: 80,
          unit: 'bundle',
          description: 'Sun-dried daisy-like flower heads for soothing herbal infusions.',
          imageUrl: 'assets/images/aloe_vera.png',
          status: 'available',
        ),
        const CropModel(
          id: 'initial-4',
          name: 'Dwarf Cavendish Banana',
          price: 12.50,
          basePrice: 12.50,
          category: 'Commercial Crop',
          quantity: 350,
          unit: 'kg',
          description: 'High potassium sweet fruit variety, organic greenhouse produced.',
          imageUrl: 'assets/images/aloe_vera.png',
          status: 'available',
        ),
      ];

  /// Fetch all marketplace crops
  static Future<List<CropModel>> getCrops({
    String? category,
    String? query,
  }) async {
    if (isTestMode) return defaultInitialCrops;
    try {
      final queryParams = <String>[];
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams.add('category=${Uri.encodeComponent(category)}');
      }
      if (query != null && query.trim().isNotEmpty) {
        queryParams.add('q=${Uri.encodeComponent(query.trim())}');
      }

      final path = queryParams.isEmpty ? '/crops' : '/crops?${queryParams.join('&')}';
      final res = await ApiService.authGet(path).timeout(const Duration(seconds: 2));

      if (res['status'] == 'success' && res['data']?['crops'] != null) {
        final List raw = res['data']['crops'] as List;
        final crops = raw.map((c) => CropModel.fromJson(c as Map<String, dynamic>)).toList();
        if (crops.isNotEmpty) {
          await _cacheCrops(_cachedCropsKey, crops);
        }
        return crops;
      }
    } catch (_) {
      // Fallback to local cache or defaults on network failure
    }

    final cached = await _getCachedCrops(_cachedCropsKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return defaultInitialCrops;
  }

  /// Fetch logged-in farmer's crops
  static Future<List<CropModel>> getMyCrops() async {
    if (isTestMode) return defaultInitialCrops;
    try {
      final res = await ApiService.authGet('/crops/my-crops').timeout(const Duration(seconds: 2));
      if (res['status'] == 'success' && res['data']?['crops'] != null) {
        final List raw = res['data']['crops'] as List;
        final crops = raw.map((c) => CropModel.fromJson(c as Map<String, dynamic>)).toList();
        await _cacheCrops(_cachedMyCropsKey, crops);
        return crops;
      }
    } catch (_) {
      // Return cached farmer crops if available
    }

    final cached = await _getCachedCrops(_cachedMyCropsKey);
    return cached ?? [];
  }

  /// Farmer creates a new crop
  static Future<CropModel> createCrop({
    required String name,
    required double price,
    String category = 'General',
    double quantity = 0.0,
    String unit = 'kg',
    String? description,
    String? imageUrl,
    String status = 'available',
    String? harvestDate,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    Map<String, dynamic> res;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final fields = {
        'name': name.trim(),
        'price': price.toString(),
        'category': category,
        'quantity': quantity.toString(),
        'unit': unit,
        if (description != null) 'description': description.trim(),
        'status': status,
        if (harvestDate != null) 'harvestDate': harvestDate,
      };
      res = await ApiService.authMultipart(
        '/crops',
        method: 'POST',
        fields: fields,
        fileBytes: imageBytes,
        filename: imageFilename ?? 'crop.png',
      );
    } else {
      res = await ApiService.authPost('/crops', {
        'name': name.trim(),
        'price': price,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'description': description?.trim(),
        'imageUrl': imageUrl?.trim(),
        'status': status,
        'harvestDate': harvestDate,
      });
    }

    if (res['status'] != 'success') {
      throw res['message'] as String? ?? 'Failed to create crop';
    }

    final cropJson = res['data']['crop'] as Map<String, dynamic>;
    return CropModel.fromJson(cropJson);
  }

  /// Farmer modifies/updates an existing crop
  static Future<CropModel> updateCrop({
    required String id,
    String? name,
    double? price,
    String? category,
    double? quantity,
    String? unit,
    String? description,
    String? imageUrl,
    String? status,
    String? harvestDate,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    Map<String, dynamic> res;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final fields = <String, String>{};
      if (name != null) fields['name'] = name.trim();
      if (price != null) fields['price'] = price.toString();
      if (category != null) fields['category'] = category;
      if (quantity != null) fields['quantity'] = quantity.toString();
      if (unit != null) fields['unit'] = unit;
      if (description != null) fields['description'] = description.trim();
      if (status != null) fields['status'] = status;
      if (harvestDate != null) fields['harvestDate'] = harvestDate;

      res = await ApiService.authMultipart(
        '/crops/$id',
        method: 'PUT',
        fields: fields,
        fileBytes: imageBytes,
        filename: imageFilename ?? 'crop_update.png',
      );
    } else {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name.trim();
      if (price != null) body['price'] = price;
      if (category != null) body['category'] = category;
      if (quantity != null) body['quantity'] = quantity;
      if (unit != null) body['unit'] = unit;
      if (description != null) body['description'] = description.trim();
      if (imageUrl != null) body['imageUrl'] = imageUrl.trim();
      if (status != null) body['status'] = status;
      if (harvestDate != null) body['harvestDate'] = harvestDate;

      res = await ApiService.authPut('/crops/$id', body);
    }

    if (res['status'] != 'success') {
      throw res['message'] as String? ?? 'Failed to update crop';
    }

    final cropJson = res['data']['crop'] as Map<String, dynamic>;
    return CropModel.fromJson(cropJson);
  }

  /// Farmer deletes a crop
  static Future<void> deleteCrop(String id) async {
    final res = await ApiService.authDelete('/crops/$id');
    if (res['status'] != 'success') {
      throw res['message'] as String? ?? 'Failed to delete crop';
    }
  }

  /// Dedicated image upload
  static Future<String> uploadCropImage(List<int> imageBytes, String filename) async {
    final res = await ApiService.authMultipart(
      '/crops/upload-image',
      method: 'POST',
      fileBytes: imageBytes,
      filename: filename,
    );

    if (res['status'] != 'success') {
      throw res['message'] as String? ?? 'Failed to upload image';
    }

    return res['data']['imageUrl'] as String;
  }

  /// Bulk import crops
  static Future<List<CropModel>> bulkUploadCrops(List<Map<String, dynamic>> items) async {
    final res = await ApiService.authPost('/crops/bulk', {
      'crops': items,
    });

    if (res['status'] != 'success') {
      throw res['message'] as String? ?? 'Failed to bulk upload crops';
    }

    final raw = res['data']['crops'] as List;
    return raw.map((c) => CropModel.fromJson(c as Map<String, dynamic>)).toList();
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────

  static Future<void> _cacheCrops(String key, List<CropModel> crops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(crops.map((c) => c.toJson()).toList());
      await prefs.setString(key, jsonString);
    } catch (_) {}
  }

  static Future<List<CropModel>?> _getCachedCrops(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);
      if (jsonString == null) return null;
      final List raw = jsonDecode(jsonString) as List;
      return raw.map((c) => CropModel.fromJson(c as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }
}
