class CropModel {
  final String id;
  final String? farmerId;
  final String name;
  final String category;
  final double price;
  final double basePrice;
  final double change;
  final double quantity;
  final String unit;
  final String? description;
  final String? imageUrl;
  final String status;
  final String? harvestDate;
  final String? farmerName;
  final double? farmerRating;
  final DateTime? createdAt;

  const CropModel({
    required this.id,
    this.farmerId,
    required this.name,
    this.category = 'General',
    required this.price,
    double? basePrice,
    this.change = 0.0,
    this.quantity = 0.0,
    this.unit = 'kg',
    this.description,
    this.imageUrl,
    this.status = 'available',
    this.harvestDate,
    this.farmerName,
    this.farmerRating,
    this.createdAt,
  }) : basePrice = basePrice ?? price;

  factory CropModel.fromJson(Map<String, dynamic> json) {
    // Parse nested farmer info if present
    String? fName;
    double? fRating;
    if (json['farmer'] is Map<String, dynamic>) {
      final farmerJson = json['farmer'] as Map<String, dynamic>;
      fName = farmerJson['name'] as String? ?? farmerJson['email'] as String?;
      if (farmerJson['rating'] != null) {
        fRating = double.tryParse(farmerJson['rating'].toString());
      }
    }

    final parsedPrice = double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0;
    final parsedBase = json['basePrice'] != null
        ? double.tryParse(json['basePrice'].toString()) ?? parsedPrice
        : parsedPrice;
    final parsedChange = json['change'] != null
        ? double.tryParse(json['change'].toString()) ?? 0.0
        : 0.0;
    final parsedQty = double.tryParse(json['quantity']?.toString() ?? '0.0') ?? 0.0;

    return CropModel(
      id: json['id']?.toString() ?? '',
      farmerId: json['farmerId']?.toString(),
      name: json['name']?.toString() ?? 'Unnamed Crop',
      category: json['category']?.toString() ?? 'General',
      price: parsedPrice,
      basePrice: parsedBase,
      change: parsedChange,
      quantity: parsedQty,
      unit: json['unit']?.toString() ?? 'kg',
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      status: json['status']?.toString() ?? 'available',
      harvestDate: json['harvestDate']?.toString(),
      farmerName: fName,
      farmerRating: fRating,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmerId': farmerId,
        'name': name,
        'category': category,
        'price': price,
        'basePrice': basePrice,
        'change': change,
        'quantity': quantity,
        'unit': unit,
        'description': description,
        'imageUrl': imageUrl,
        'status': status,
        'harvestDate': harvestDate,
        'farmerName': farmerName,
        'farmerRating': farmerRating,
        'createdAt': createdAt?.toIso8601String(),
      };

  CropModel copyWith({
    String? id,
    String? farmerId,
    String? name,
    String? category,
    double? price,
    double? basePrice,
    double? change,
    double? quantity,
    String? unit,
    String? description,
    String? imageUrl,
    String? status,
    String? harvestDate,
    String? farmerName,
    double? farmerRating,
    DateTime? createdAt,
  }) {
    return CropModel(
      id: id ?? this.id,
      farmerId: farmerId ?? this.farmerId,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      basePrice: basePrice ?? this.basePrice,
      change: change ?? this.change,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      harvestDate: harvestDate ?? this.harvestDate,
      farmerName: farmerName ?? this.farmerName,
      farmerRating: farmerRating ?? this.farmerRating,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Resolve full image URL or asset fallback
  String get displayImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return 'assets/images/aloe_vera.png';
    }
    if (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://')) {
      return imageUrl!;
    }
    if (imageUrl!.startsWith('/uploads/')) {
      // Backend static upload path
      return 'http://localhost:3000$imageUrl';
    }
    if (imageUrl!.startsWith('assets/')) {
      return imageUrl!;
    }
    return imageUrl!;
  }

  bool get isNetworkImage =>
      imageUrl != null &&
      (imageUrl!.startsWith('http://') ||
          imageUrl!.startsWith('https://') ||
          imageUrl!.startsWith('/uploads/'));
}
