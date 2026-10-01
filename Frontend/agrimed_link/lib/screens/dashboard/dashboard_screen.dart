import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/crop_service.dart';
import '../../services/app_localizations.dart';
import '../../services/localization_service.dart';
import '../../widgets/language_selector_dialog.dart';
import '../../widgets/currency_converter_dialog.dart';
import '../../services/currency_service.dart';
import '../../services/gemini_scanner_service.dart';
import '../../models/crop_model.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/digipay_checkout_sheet.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  /// In widget tests, can be set to false to prevent periodic price flushes from blocking pumpAndSettle
  static bool enablePriceTimer = true;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _userEmail = 'user@example.com';
  String _userRole = 'farmer';
  String _userName = '';
  String _userId = '';

  // Scanner & Upload States
  bool _isScanning = false;
  String? _scanResult;
  late AnimationController _scannerAnimationController;
  int _scanInputMode = 0; // 0: Camera Viewfinder, 1: Upload Image
  String _activeScanImage = 'assets/images/aloe_vera.png';
  String _activeScanLabel = 'Organic Aloe Vera';
  bool _isFlashOn = false;
  bool _showGrid = true;
  bool _isFrontCamera = false;
  final TextEditingController _uploadImageUrlController = TextEditingController();
  Map<String, dynamic>? _lastDiagnosis;

  // User Device Uploaded Image State
  Uint8List? _deviceImageBytes;
  String? _deviceImageName;
  String? _deviceImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImageFromDevice(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _deviceImageBytes = bytes;
          _deviceImageName = picked.name;
          _deviceImagePath = picked.path;
          _activeScanLabel = picked.name;
          _scanResult = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Selected "${picked.name}" (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB) - Ready to scan!',
              ),
              backgroundColor: AppTheme.primaryGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[DashboardScreen] Error picking device image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open device picker: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _clearDeviceImage() {
    setState(() {
      _deviceImageBytes = null;
      _deviceImageName = null;
      _deviceImagePath = null;
      _activeScanLabel = 'Organic Aloe Vera';
      _activeScanImage = 'assets/images/aloe_vera.png';
    });
  }

  // Real-time market prices state
  Timer? _priceTimer;
  final Random _random = Random();

  late List<Map<String, dynamic>> _products;
  late List<CropModel> _crops;
  List<CropModel> _myCrops = [];
  bool _isLoadingCrops = false;
  int _cropTabFilter = 0; // 0: All Marketplace, 1: My Farm
  String _selectedCropCategory = 'All';
  String _cropSearchQuery = '';
  final TextEditingController _cropSearchController = TextEditingController();

  bool get _isFarmer =>
      _userRole.toLowerCase() == 'farmer' || _userRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _scannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Initial supplies data
    _products = [
      {
        'title': 'Organic Bio-Fertilizer',
        'price': 24.99,
        'basePrice': 24.99,
        'change': 0.0,
        'rating': '★ 4.8',
        'desc': 'Slow-release natural fertilizer.',
        'image': 'assets/images/bio_fertilizer.png',
      },
      {
        'title': 'Premium Tomato Seeds',
        'price': 4.50,
        'basePrice': 4.50,
        'change': 0.0,
        'rating': '★ 4.9',
        'desc': 'High-yield disease resistant seeds.',
        'image': 'assets/images/tomato_seeds.png',
      },
      {
        'title': 'Irrigation Drip Kit',
        'price': 89.99,
        'basePrice': 89.99,
        'change': 0.0,
        'rating': '★ 4.7',
        'desc': 'Complete drip irrigation for 50 plants.',
        'image': 'assets/images/drip_irrigation.png',
      },
      {
        'title': 'Mini Greenhouse Tent',
        'price': 119.50,
        'basePrice': 119.50,
        'change': 0.0,
        'rating': '★ 4.6',
        'desc': 'Polyethylene frame protective cover.',
        'image': 'assets/images/aloe_vera.png', // Fallback mockup
      },
    ];

    // Initial medicinal/organic crops data (typed with CropModel)
    _crops = List.from(CropService.defaultInitialCrops);
    _initUserAndCrops();

    // Set up price fluctuation scheduler (Real-time live prices)
    if (DashboardScreen.enablePriceTimer) {
      _priceTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted) {
          setState(() {
            for (var item in _products) {
              double percent =
                  (_random.nextDouble() * 3.5 - 1.6) / 100; // -1.6% to +1.9%
              item['price'] = double.parse(
                (item['price'] * (1 + percent)).toStringAsFixed(2),
              );
              item['change'] = double.parse(
                (((item['price'] - item['basePrice']) / item['basePrice']) * 100)
                    .toStringAsFixed(1),
              );
            }
            for (int i = 0; i < _crops.length; i++) {
              final crop = _crops[i];
              double percent = (_random.nextDouble() * 3.5 - 1.6) / 100;
              double newPrice = double.parse(
                (crop.price * (1 + percent)).toStringAsFixed(2),
              );
              double newChange = double.parse(
                (((newPrice - crop.basePrice) / crop.basePrice) * 100)
                    .toStringAsFixed(1),
              );
              _crops[i] = crop.copyWith(price: newPrice, change: newChange);
            }
          });
        }
      });
    }
  }

  Future<void> _initUserAndCrops() async {
    final user = await AuthService.getStoredUser();
    if (user != null && mounted) {
      final role = (user.role.toLowerCase() == 'admin' && user.email.toLowerCase() != 'system.admin@agrimedlink.com')
          ? 'customer'
          : user.role;
      setState(() {
        _userId = user.id;
        _userEmail = user.email;
        _userRole = role;
        _userName = user.displayName;
      });
    }
    await _loadCrops(showLoading: false);
  }

  Future<void> _loadCrops({bool showLoading = false}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _isLoadingCrops = true);
    try {
      final all = await CropService.getCrops(
        category: _selectedCropCategory == 'All' ? null : _selectedCropCategory,
        query: _cropSearchQuery.isEmpty ? null : _cropSearchQuery,
      );
      List<CropModel> mine = [];
      if (_isFarmer) {
        mine = await CropService.getMyCrops();
      }
      if (mounted) {
        setState(() {
          _crops = all;
          _myCrops = mine;
          _isLoadingCrops = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCrops = false);
    }
  }

  @override
  void dispose() {
    _cropSearchController.dispose();
    _uploadImageUrlController.dispose();
    _scannerAnimationController.dispose();
    _priceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final incomingEmail = (args['email'] ?? _userEmail).toString();
      String incomingRole = (args['role'] ?? _userRole).toString();
      if (incomingRole.toLowerCase() == 'admin' && incomingEmail.toLowerCase() != 'system.admin@agrimedlink.com') {
        incomingRole = 'customer';
      }
      setState(() {
        _userEmail = incomingEmail;
        _userRole = incomingRole;
        _userName = args['name'] ?? '';
        _userId = args['id'] ?? _userId;
      });
      if (_crops.isEmpty) {
        _loadCrops(showLoading: false);
      }
    }
  }

  Map<String, dynamic> _generateCropDiagnosis(String imagePath, String label) {
    final lowerImg = imagePath.toLowerCase();
    final lowerLbl = label.toLowerCase();

    if (lowerImg.contains('moringa') || lowerLbl.contains('moringa')) {
      return {
        'name': 'Organic Moringa Oleifera',
        'botanical': 'Moringa oleifera Lam.',
        'family': 'Moringaceae',
        'confidence': '99.2%',
        'healthStatus': 'Healthy Organic - Superfood Grade A',
        'isHealthy': true,
        'pathogen': 'Zero fungal or pest infestation detected. Optimal chlorophyll index.',
        'compounds': 'Moringine, Quercetin, Chlorogenic acid, 46 Antioxidants',
        'applications': 'Nutraceutical superfood, blood glucose regulation, medicinal teas',
        'basePriceUSD': 14.50,
        'unit': 'bundle',
        'treatment': 'Optimal growth conditions. Maintain organic compost and drip irrigation.',
        'image': 'assets/images/crop_moringa.jpg',
      };
    } else if (lowerImg.contains('blight') || lowerLbl.contains('blight') || lowerLbl.contains('diseased')) {
      return {
        'name': 'Infected Solanaceae / Crop Leaf',
        'botanical': 'Alternaria solani (Early Blight Pathogen)',
        'family': 'Solanaceae',
        'confidence': '96.4%',
        'healthStatus': '⚠️ Pathogen Alert: Early Blight Detected',
        'isHealthy': false,
        'pathogen': 'Alternaria solani fungal spores; concentric target rings on lower foliage',
        'compounds': 'Stress phytoalexins, reduced leaf chlorophyll ratio',
        'applications': 'Requires immediate organic bio-fungicide isolation and pruning',
        'basePriceUSD': 3.50,
        'unit': 'kg',
        'treatment': 'Spray Copper Octanoate bio-fungicide at 15ml/L every 7 days. Prune bottom leaves.',
        'image': imagePath,
      };
    } else if (lowerImg.contains('fertilizer') || lowerLbl.contains('fertilizer')) {
      return {
        'name': 'Organic Bio-Fertilizer Batch',
        'botanical': 'Microbial Inoculant & Organic Compost',
        'family': 'Bio-Agrochemicals',
        'confidence': '99.5%',
        'healthStatus': 'Certified Organic Soil Conditioner',
        'isHealthy': true,
        'pathogen': 'Beneficial microbiology verified (Rhizobium & Mycorrhizae)',
        'compounds': '4-2-3 NPK, Humic acids, Beneficial Bacillus subtilis',
        'applications': 'Soil microbiome enrichment, root expansion, organic yield booster',
        'basePriceUSD': 24.99,
        'unit': 'bag',
        'treatment': 'Store in dry shade below 30°C. Apply 50g per root zone.',
        'image': 'assets/images/bio_fertilizer.png',
      };
    } else if (lowerImg.contains('seed') || lowerLbl.contains('seed')) {
      return {
        'name': 'Certified Hybrid Crop Seeds',
        'botanical': 'Solanum lycopersicum (High-Yield F1)',
        'family': 'Solanaceae',
        'confidence': '97.1%',
        'healthStatus': 'Certified Disease-Free (Germination 94%)',
        'isHealthy': true,
        'pathogen': 'Zero viral seed transmission detected',
        'compounds': 'Natural seed coat lignins, high embryonic vigor',
        'applications': 'Commercial vegetable farming & nursery seedling propagation',
        'basePriceUSD': 4.50,
        'unit': 'pack',
        'treatment': 'Sow in moist potting tray at 24°C. Transplant in 21 days.',
        'image': 'assets/images/tomato_seeds.png',
      };
    }

    // Default: Organic Aloe Vera
    return {
      'name': 'Organic Aloe Vera (Purity: 98.4%)',
      'botanical': 'Aloe barbadensis Miller',
      'family': 'Asphodelaceae',
      'confidence': '98.4%',
      'healthStatus': 'Healthy Organic - Pharmaceutical Grade',
      'isHealthy': true,
      'pathogen': 'Zero foliar disease, high leaf turgor and active gel volume',
      'compounds': 'Acemannan (polysaccharide), Aloin, Anthraquinones, Vit A, C, E',
      'applications': 'Skin tissue soothing, mucosal protection, pharmaceutical gel',
      'basePriceUSD': 12.00,
      'unit': 'kg',
      'treatment': 'Water every 14 days; maintain warm solar exposure.',
      'image': 'assets/images/aloe_vera.png',
    };
  }

  void _triggerScan({String? customImage, String? customName, Uint8List? customBytes}) {
    final targetBytes = customBytes ?? _deviceImageBytes;
    final targetImage = customImage ?? _activeScanImage;
    final targetName = customName ?? (_deviceImageName ?? _activeScanLabel);

    setState(() {
      _isScanning = true;
      _activeScanImage = targetImage;
      _activeScanLabel = targetName;
      _scanResult = null;
    });

    if (!CropService.isTestMode) {
      _scannerAnimationController.repeat(reverse: true);
    }

    if (CropService.isTestMode) {
      final diagnosis = _generateCropDiagnosis(targetImage, targetName);
      setState(() {
        _isScanning = false;
        _lastDiagnosis = diagnosis;
        _scanResult =
            "${diagnosis['name']} (${diagnosis['confidence']})\nStatus: ${diagnosis['healthStatus']}\nActive: ${diagnosis['compounds']}";
      });
      _showScanResultDialog(diagnosis);
      return;
    }

    // Call live Gemini AI Scanner service with device image bytes or asset
    GeminiScannerService.instance.diagnose(
      imageAssetOrPath: targetBytes == null ? targetImage : null,
      rawBytes: targetBytes,
      labelHint: targetName,
    ).then((diagnosis) {
      if (mounted) {
        _scannerAnimationController.stop();
        setState(() {
          _isScanning = false;
          _lastDiagnosis = diagnosis;
          _scanResult =
              "${diagnosis['name']} (${diagnosis['confidence']})\nStatus: ${diagnosis['healthStatus']}\nActive: ${diagnosis['compounds']}";
        });
        _showScanResultDialog(diagnosis);
      }
    }).catchError((err) {
      debugPrint('[DashboardScreen] Gemini diagnosis fallback: $err');
      if (mounted) {
        _scannerAnimationController.stop();
        final diagnosis = _generateCropDiagnosis(targetImage, targetName);
        setState(() {
          _isScanning = false;
          _lastDiagnosis = diagnosis;
          _scanResult =
              "${diagnosis['name']} (${diagnosis['confidence']})\nStatus: ${diagnosis['healthStatus']}\nActive: ${diagnosis['compounds']}";
        });
        _showScanResultDialog(diagnosis);
      }
    });
  }

  void _showScanResultDialog([Map<String, dynamic>? diag]) {
    final diagnosis = diag ??
        _lastDiagnosis ??
        _generateCropDiagnosis(_activeScanImage, _activeScanLabel);

    final double baseUSD = (diagnosis['basePriceUSD'] as num?)?.toDouble() ?? 12.0;
    final String unit = diagnosis['unit']?.toString() ?? 'kg';
    final bool isHealthy = diagnosis['isHealthy'] == true;

    // Currency values in all 3 requested currencies
    final String priceUSD = CurrencyService.instance.formatAmount(
      baseUSD,
      AppCurrency.usd,
    );
    final String priceEUR = CurrencyService.instance.formatAmount(
      CurrencyService.instance.convert(baseUSD, from: AppCurrency.usd, to: AppCurrency.eur),
      AppCurrency.eur,
    );
    final String priceFCFA = CurrencyService.instance.formatAmount(
      CurrencyService.instance.convert(baseUSD, from: AppCurrency.usd, to: AppCurrency.fcfa),
      AppCurrency.fcfa,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          title: Row(
            children: [
              Icon(
                isHealthy
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                color: isHealthy ? AppTheme.secondaryGreen : AppTheme.accentAmber,
                size: 28.0,
              ),
              const SizedBox(width: 8.0),
              const Expanded(
                child: Text(
                  'Scan Complete',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 12, color: AppTheme.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      diagnosis['aiModel'] ?? 'Gemini AI',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Specimen Image Preview & Badges
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isHealthy ? AppTheme.primaryGreen : AppTheme.accentAmber,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isHealthy ? AppTheme.primaryGreen : AppTheme.accentAmber)
                              .withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _deviceImageBytes != null
                          ? Image.memory(
                              _deviceImageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.lightGreen,
                                child: const Icon(Icons.eco_rounded, size: 40, color: AppTheme.primaryGreen),
                              ),
                            )
                          : Image.asset(
                              diagnosis['image']?.toString() ?? 'assets/images/aloe_vera.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.lightGreen,
                                child: const Icon(Icons.eco_rounded, size: 40, color: AppTheme.primaryGreen),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Item Identified
                const Text(
                  'Item Identified:',
                  style: TextStyle(color: AppTheme.lightText, fontSize: 13.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4.0),
                Text(
                  diagnosis['name']?.toString() ?? (_scanResult ?? ''),
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${diagnosis['botanical']} • Family: ${diagnosis['family']} (${diagnosis['confidence']})',
                  style: const TextStyle(
                    color: AppTheme.secondaryGreen,
                    fontSize: 12.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12.0),

                // Health Status & Pathology
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: (isHealthy ? AppTheme.lightGreen : Colors.amber.shade50),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: (isHealthy ? AppTheme.secondaryGreen : AppTheme.accentAmber).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isHealthy ? Icons.eco_rounded : Icons.healing_rounded,
                            color: isHealthy ? AppTheme.primaryGreen : AppTheme.accentAmber,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              diagnosis['healthStatus']?.toString() ?? '',
                              style: TextStyle(
                                color: isHealthy ? AppTheme.primaryGreen : Colors.orange.shade900,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        diagnosis['pathogen']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.darkText),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.black.withOpacity(0.06)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isHealthy ? Icons.eco_rounded : Icons.medical_services_rounded,
                              size: 15,
                              color: isHealthy ? AppTheme.primaryGreen : AppTheme.errorRed,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Proposed Treatment: ${diagnosis['treatment'] != null && diagnosis['treatment'].toString().isNotEmpty ? diagnosis['treatment'] : "Optimal conditions. Maintain regular hydration and organic compost nutrition."}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.darkText,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14.0),

                // Active Phytochemicals
                const Text(
                  'Active Phytochemicals:',
                  style: TextStyle(color: AppTheme.darkText, fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2.0),
                Text(
                  diagnosis['compounds']?.toString() ?? '',
                  style: const TextStyle(color: AppTheme.lightText, fontSize: 11.5),
                ),
                const SizedBox(height: 14.0),

                // Multi-Currency Valuation Box (FCFA, EURO, DOLLAR)
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(color: Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Commercial Valuation',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              showCurrencyConverterDialog(context);
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.currency_exchange_rounded, size: 14, color: AppTheme.secondaryGreen),
                                SizedBox(width: 4),
                                Text(
                                  'Converter',
                                  style: TextStyle(
                                    fontSize: 11.0,
                                    color: AppTheme.secondaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          // DOLLAR
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              decoration: BoxDecoration(
                                color: CurrencyService.instance.currency == AppCurrency.usd
                                    ? AppTheme.primaryGreen.withOpacity(0.1)
                                    : AppTheme.lightGreen.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: CurrencyService.instance.currency == AppCurrency.usd
                                      ? AppTheme.primaryGreen
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text('🇺🇸 USD', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '$priceUSD / $unit',
                                    style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6.0),

                          // EURO
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              decoration: BoxDecoration(
                                color: CurrencyService.instance.currency == AppCurrency.eur
                                    ? AppTheme.primaryGreen.withOpacity(0.1)
                                    : AppTheme.lightGreen.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: CurrencyService.instance.currency == AppCurrency.eur
                                      ? AppTheme.primaryGreen
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text('🇪🇺 EUR', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '$priceEUR / $unit',
                                    style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6.0),

                          // FCFA
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              decoration: BoxDecoration(
                                color: CurrencyService.instance.currency == AppCurrency.fcfa
                                    ? AppTheme.primaryGreen.withOpacity(0.1)
                                    : AppTheme.lightGreen.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: CurrencyService.instance.currency == AppCurrency.fcfa
                                      ? AppTheme.primaryGreen
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text('🌍 FCFA', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '$priceFCFA / $unit',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Add to list and farm
                final newCrop = CropModel(
                  id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
                  name: diagnosis['name']?.toString() ?? 'Identified Crop',
                  category: 'Medicinal',
                  price: baseUSD,
                  basePrice: baseUSD,
                  change: 0.0,
                  quantity: 50,
                  unit: unit,
                  description: '${diagnosis['botanical']} - ${diagnosis['healthStatus']}',
                  imageUrl: diagnosis['image']?.toString(),
                  farmerId: _userId,
                  farmerName: _userName.isNotEmpty ? _userName : 'Verified Grower',
                );

                setState(() {
                  _crops.insert(0, newCrop);
                  if (_isFarmer) _myCrops.insert(0, newCrop);
                });

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ${diagnosis['name']} to your crop watchlist & inventory!'),
                    backgroundColor: AppTheme.secondaryGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text('Add to List'),
            ),
          ],
        );
      },
    );
  }

  String _getRoleImage(String role) {
    switch (role.toLowerCase()) {
      case 'farmer':
        return 'assets/images/role_farmer.jpg';
      case 'buyer':
      case 'customer':
        return 'assets/images/role_buyer.jpg';
      case 'supplier':
        return 'assets/images/role_supplier.jpg';
      case 'admin':
        return 'assets/images/role_admin.jpg';
      case 'advisor':
        return 'assets/images/role_advisor.jpg';
      case 'investor':
        return 'assets/images/role_investor.jpg';
      default:
        return 'assets/images/role_farmer.jpg';
    }
  }

  void _showRoleProfileModal() {
    final currentRoleImage = _getRoleImage(_userRole);
    final roleName = _userRole == 'farmer'
        ? context.tr('role_farmer')
        : _userRole == 'buyer'
        ? context.tr('role_buyer')
        : _userRole == 'supplier'
        ? context.tr('role_supplier')
        : _userRole == 'admin'
        ? context.tr('role_admin')
        : _userRole == 'advisor'
        ? context.tr('role_advisor')
        : _userRole == 'investor'
        ? context.tr('role_investor')
        : _userRole.toUpperCase();

    final roleDesc = _userRole == 'farmer'
        ? context.tr('role_farmer_desc')
        : _userRole == 'buyer'
        ? context.tr('role_buyer_desc')
        : _userRole == 'supplier'
        ? context.tr('role_supplier_desc')
        : _userRole == 'admin'
        ? context.tr('role_admin_desc')
        : _userRole == 'advisor'
        ? context.tr('role_advisor_desc')
        : _userRole == 'investor'
        ? context.tr('role_investor_desc')
        : '';

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          contentPadding: const EdgeInsets.all(20.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Real-life role image portrait
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryGreen, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    currentRoleImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _userName.isNotEmpty ? _userName : 'AgriMed Member',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  roleName.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _userEmail,
                style: const TextStyle(fontSize: 12, color: AppTheme.lightText),
              ),
              if (roleDesc.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  roleDesc,
                  style: const TextStyle(fontSize: 12, color: AppTheme.darkText, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
              const Divider(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Switch Role Preview:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.lightText),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildRoleSwitcherItem(ctx, 'farmer', 'Farmer', 'assets/images/role_farmer.jpg'),
                  _buildRoleSwitcherItem(ctx, 'buyer', 'Buyer', 'assets/images/role_buyer.jpg'),
                  _buildRoleSwitcherItem(ctx, 'supplier', 'Supplier', 'assets/images/role_supplier.jpg'),
                  _buildRoleSwitcherItem(ctx, 'advisor', 'Advisor', 'assets/images/role_advisor.jpg'),
                  _buildRoleSwitcherItem(ctx, 'investor', 'Investor', 'assets/images/role_investor.jpg'),
                  if (_userEmail.toLowerCase() == 'system.admin@agrimedlink.com')
                    _buildRoleSwitcherItem(ctx, 'admin', 'Admin', 'assets/images/role_admin.jpg'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleSwitcherItem(BuildContext ctx, String roleId, String label, String imagePath) {
    final isSelected = _userRole.toLowerCase() == roleId.toLowerCase();
    return InkWell(
      onTap: () {
        if (roleId.toLowerCase() == 'admin' && _userEmail.toLowerCase() != 'system.admin@agrimedlink.com') {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin privileges are restricted exclusively to system.admin@agrimedlink.com'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          return;
        }
        setState(() {
          _userRole = roleId;
        });
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                ClipOval(child: Image.asset(imagePath, width: 22, height: 22, fit: BoxFit.cover)),
                const SizedBox(width: 8),
                Text('Switched preview role to $label'),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(child: Image.asset(imagePath, width: 18, height: 18, fit: BoxFit.cover)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? context.tr('marketplace_products')
              : _currentIndex == 1
              ? context.tr('medicinal_crops')
              : context.tr('scan_title'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_currentIndex == 1 && _isFarmer) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Crops',
              onPressed: _loadCrops,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: context.tr('add_crop'),
              onPressed: _showAddCropDialog,
            ),
          ],
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.accentAmber),
              tooltip: context.tr('nav_admin_portal'),
              onPressed: () => Navigator.pushNamed(context, '/admin_portal'),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: LanguagePickerButton(isTransparent: true),
          ),
          ValueListenableBuilder<AppCurrency>(
            valueListenable: CurrencyService.instance.currentCurrency,
            builder: (context, activeCurrency, _) {
              return Padding(
                padding: const EdgeInsets.only(left: 4.0, right: 6.0),
                child: Tooltip(
                  message: 'Currency: ${activeCurrency.name} (${activeCurrency.code}) - Tap to Convert',
                  child: InkWell(
                    onTap: () => showCurrencyConverterDialog(context),
                    borderRadius: BorderRadius.circular(16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(activeCurrency.flag, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            activeCurrency.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_rounded, color: Colors.white),
            tooltip: context.tr('nav_maps'),
            onPressed: () => Navigator.pushNamed(context, '/maps'),
          ),
          IconButton(
            icon: const Icon(Icons.forum_rounded, color: Colors.white),
            tooltip: 'Community & Chats',
            onPressed: () => Navigator.pushNamed(context, '/chat'),
          ),
          GestureDetector(
            onTap: _showRoleProfileModal,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, right: 12.0),
              child: Tooltip(
                message: 'Profile (${_userRole.toUpperCase()})',
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _getRoleImage(_userRole),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        elevation: 0,
      ),
      floatingActionButton: (_currentIndex == 1 && _isFarmer)
          ? FloatingActionButton.extended(
              onPressed: _showFarmerActionMenu,
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                context.tr('add_or_upload'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/chat'),
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Community & Private Chats',
              child: const Icon(Icons.forum_rounded),
            ),
      drawer: _buildSidebar(),
      body: OfflineBanner(
        child: Column(
          children: [
            // Live scrolling ticker bar
            _buildLiveTickerRow(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildProductsView(),
                  _buildCropsView(),
                  _buildScanView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTickerRow() {
    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _crops.length,
        itemBuilder: (context, index) {
          final crop = _crops[index];
          final price = crop.price;
          final change = crop.change;
          final isPositive = change >= 0;

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.black12, width: 0.8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.show_chart_rounded,
                  size: 16.0,
                  color: AppTheme.secondaryGreen,
                ),
                const SizedBox(width: 6.0),
                Text(
                  crop.name.split(' ')[0],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.0,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  CurrencyService.instance.format(price),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.0,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 4.0),
                Icon(
                  isPositive
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: isPositive ? Colors.green : Colors.red,
                  size: 20.0,
                ),
                Text(
                  '${isPositive ? "+" : ""}${change.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.0,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Drawer(
      backgroundColor: AppTheme.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            currentAccountPicture: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showRoleProfileModal();
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    _getRoleImage(_userRole),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryGreen,
                        size: 40.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            accountName: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                _userRole == 'farmer'
                    ? context.tr('role_badge_farmer')
                    : _userRole == 'buyer'
                    ? context.tr('role_badge_buyer')
                    : _userRole == 'supplier'
                    ? context.tr('role_badge_supplier')
                    : _userRole == 'admin'
                    ? context.tr('role_badge_admin')
                    : _userRole == 'advisor'
                    ? context.tr('role_badge_advisor')
                    : _userRole == 'investor'
                    ? context.tr('role_badge_investor')
                    : _userRole.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
            accountEmail: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userName.isNotEmpty)
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    _userEmail,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            dense: true,
            leading: Icon(
              Icons.shopping_basket_rounded,
              color: _currentIndex == 0
                  ? AppTheme.primaryGreen
                  : AppTheme.lightText,
            ),
            title: Text(
              context.tr('nav_products'),
              style: TextStyle(
                fontWeight: _currentIndex == 0
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _currentIndex == 0
                    ? AppTheme.primaryGreen
                    : AppTheme.darkText,
              ),
            ),
            selected: _currentIndex == 0,
            onTap: () {
              setState(() => _currentIndex = 0);
              Navigator.pop(context); // Close Drawer
            },
          ),
          ListTile(
            dense: true,
            leading: Icon(
              Icons.eco_rounded,
              color: _currentIndex == 1
                  ? AppTheme.primaryGreen
                  : AppTheme.lightText,
            ),
            title: Text(
              context.tr('nav_crops'),
              style: TextStyle(
                fontWeight: _currentIndex == 1
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _currentIndex == 1
                    ? AppTheme.primaryGreen
                    : AppTheme.darkText,
              ),
            ),
            selected: _currentIndex == 1,
            onTap: () {
              setState(() => _currentIndex = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            dense: true,
            leading: Icon(
              Icons.qr_code_scanner_rounded,
              color: _currentIndex == 2
                  ? AppTheme.primaryGreen
                  : AppTheme.lightText,
            ),
            title: Text(
              context.tr('nav_scan'),
              style: TextStyle(
                fontWeight: _currentIndex == 2
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _currentIndex == 2
                    ? AppTheme.primaryGreen
                    : AppTheme.darkText,
              ),
            ),
            selected: _currentIndex == 2,
            onTap: () {
              setState(() => _currentIndex = 2);
              Navigator.pop(context);
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.forum_rounded,
              color: AppTheme.primaryGreen,
            ),
            title: const Text(
              'Community & Chats',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/chat');
            },
          ),
          if (_userRole == 'admin')
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppTheme.accentAmber,
              ),
              title: Text(
                context.tr('nav_admin_portal'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentAmber.withOpacity(0.5)),
                ),
                child: const Text(
                  'CONSOLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFC67D00),
                  ),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin_portal');
              },
            ),
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.map_rounded,
              color: AppTheme.primaryGreen,
            ),
            title: Text(
              context.tr('nav_maps'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppTheme.lightText,
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/maps');
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.language_rounded,
              color: AppTheme.primaryGreen,
            ),
            title: Text(
              context.tr('language'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            subtitle: Text(
              '${LocalizationService.instance.currentLanguage.flag} ${LocalizationService.instance.currentLanguage.nativeName}',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.lightText,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppTheme.lightText,
            ),
            onTap: () {
              Navigator.pop(context);
              showLanguageSelector(context);
            },
          ),
          ValueListenableBuilder<AppCurrency>(
            valueListenable: CurrencyService.instance.currentCurrency,
            builder: (context, activeCurrency, _) {
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.currency_exchange_rounded,
                  color: AppTheme.primaryGreen,
                ),
                title: Text(
                  context.tr('currency'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                subtitle: Text(
                  '${activeCurrency.flag} ${activeCurrency.name} (${activeCurrency.code})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.lightText,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.lightText,
                ),
                onTap: () {
                  Navigator.pop(context);
                  showCurrencyConverterDialog(context);
                },
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
            title: Text(
              context.tr('nav_logout'),
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),

          const SizedBox(height: 20.0),
        ],
      ),
    );
  }

  Widget _buildProductsView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFilter(),
          const SizedBox(height: 20.0),
          const Text(
            'Featured Supplies',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 12.0),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.72,
              ),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                final price = product['price'] as double;
                final change = product['change'] as double;
                final isPositive = change >= 0;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: AppTheme.secondaryGreen.withOpacity(0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  product['image']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: AppTheme.lightGreen,
                                        child: const Icon(
                                          Icons.eco_rounded,
                                          size: 40.0,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                ),
                                Positioned(
                                  top: 8.0,
                                  right: 8.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 2.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Text(
                                      product['rating']!,
                                      style: const TextStyle(
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentAmber,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        Text(
                          product['title']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                            color: AppTheme.darkText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2.0),
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primaryGreen, width: 1.0),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/role_supplier.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 10, color: AppTheme.primaryGreen),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verified ${context.tr('role_supplier')}',
                              style: const TextStyle(
                                color: AppTheme.secondaryGreen,
                                fontSize: 10.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          product['desc']!,
                          style: const TextStyle(
                            color: AppTheme.lightText,
                            fontSize: 11.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              CurrencyService.instance.format(price),
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: (isPositive ? Colors.green : Colors.red)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPositive
                                        ? Icons.arrow_drop_up_rounded
                                        : Icons.arrow_drop_down_rounded,
                                    color: isPositive
                                        ? Colors.green
                                        : Colors.red,
                                    size: 14.0,
                                  ),
                                  Text(
                                    '${change >= 0 ? "+" : ""}${change.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: isPositive
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                DigiPayCheckoutSheet.show(
                                  context,
                                  itemName: (product['title'] ?? 'Marketplace Item').toString(),
                                  unitPriceUSD: (product['price'] as num).toDouble(),
                                  imageUrl: product['image']?.toString(),
                                  onPaymentSuccess: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Payment confirmed for ${product['title']}!'),
                                        backgroundColor: AppTheme.primaryGreen,
                                      ),
                                    );
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                              ),
                              child: const Text(
                                'Buy with DigiPay',
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropsView() {
    final displayList = _cropTabFilter == 1 && _isFarmer ? _myCrops : _crops;
    final filtered = displayList.where((c) {
      if (_selectedCropCategory != 'All' && c.category != _selectedCropCategory) {
        return false;
      }
      if (_cropSearchQuery.isNotEmpty) {
        final q = _cropSearchQuery.toLowerCase();
        final matchName = c.name.toLowerCase().contains(q);
        final matchDesc = c.description?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchDesc) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadCrops,
      color: AppTheme.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Crop Search Box
          _buildCropSearchBar(),
          const SizedBox(height: 12.0),

          // Category Chips Bar
          _buildCategoryFilterChips(),
          const SizedBox(height: 14.0),

          // Farmer Management Strip
          if (_isFarmer) ...[
            _buildFarmerManagementStrip(),
            const SizedBox(height: 14.0),
          ],

          // Section Title & Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _cropTabFilter == 1 && _isFarmer
                    ? 'My Farm Crops (${filtered.length})'
                    : 'Available Organic Crops (${filtered.length})',
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              if (_isLoadingCrops)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGreen,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Empty state or Crop Cards
          if (filtered.isEmpty)
            _buildEmptyCropState()
          else
            ...filtered.map((crop) => _buildCropCard(crop)),
          const SizedBox(height: 80.0), // Padding for FAB
        ],
      ),
    );
  }

  Widget _buildCropSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _cropSearchController,
        onChanged: (val) {
          setState(() {
            _cropSearchQuery = val.trim();
          });
        },
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.secondaryGreen,
          ),
          suffixIcon: _cropSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _cropSearchController.clear();
                    setState(() => _cropSearchQuery = '');
                  },
                )
              : null,
          hintText: 'Search crops by name or properties...',
          hintStyle: const TextStyle(color: AppTheme.lightText, fontSize: 13.0),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    const categories = [
      'All',
      'Medicinal',
      'Adaptogenic',
      'Commercial Crop',
      'Vegetables',
      'Fruits',
      'Herbs',
      'Spices',
    ];

    return SizedBox(
      height: 38.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8.0),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCropCategory == cat;

          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedCropCategory = cat);
              }
            },
            selectedColor: AppTheme.primaryGreen,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.darkText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryGreen
                    : AppTheme.secondaryGreen.withOpacity(0.2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFarmerManagementStrip() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppTheme.secondaryGreen.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _cropTabFilter = 0),
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: _cropTabFilter == 0
                          ? AppTheme.primaryGreen
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${context.tr('tab_marketplace')} (${_crops.length})',
                      style: TextStyle(
                        color: _cropTabFilter == 0 ? Colors.white : AppTheme.darkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _cropTabFilter = 1),
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: _cropTabFilter == 1
                          ? AppTheme.primaryGreen
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${context.tr('tab_my_farm')} (${_myCrops.length})',
                      style: TextStyle(
                        color: _cropTabFilter == 1 ? Colors.white : AppTheme.darkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddCropDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.tr('add_crop'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showBulkUploadDialog,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(context.tr('bulk_upload'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCropState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: const BoxDecoration(
              color: AppTheme.lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.nature_rounded,
              size: 48,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16.0),
          Text(
            _cropTabFilter == 1 && _isFarmer
                ? 'No crops in your farm inventory yet'
                : 'No crops found matching your filters',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            _cropTabFilter == 1 && _isFarmer
                ? 'Tap "Add Crop" or "Bulk Upload" to list your harvests and sell directly to buyers.'
                : 'Try adjusting your search keywords or category filters.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.0,
              color: AppTheme.lightText,
            ),
          ),
          if (_isFarmer && _cropTabFilter == 1) ...[
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              onPressed: _showAddCropDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Your First Crop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCropCard(CropModel crop) {
    final isPositive = crop.change >= 0;
    final isOwner = _isFarmer && (_cropTabFilter == 1 || crop.farmerId == _userId || _userRole == 'admin');

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8.0,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isOwner
              ? AppTheme.primaryGreen.withOpacity(0.3)
              : AppTheme.secondaryGreen.withOpacity(0.08),
          width: isOwner ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        leading: Container(
          width: 64.0,
          height: 64.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.0),
            child: crop.isNetworkImage
                ? Image.network(
                    crop.displayImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppTheme.lightGreen,
                      child: const Icon(Icons.nature_rounded, color: AppTheme.primaryGreen),
                    ),
                  )
                : Image.asset(
                    crop.displayImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppTheme.lightGreen,
                      child: const Icon(Icons.nature_rounded, color: AppTheme.primaryGreen),
                    ),
                  ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                crop.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                  color: AppTheme.darkText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                crop.category,
                style: const TextStyle(
                  color: Color(0xFFC07000),
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (crop.description != null && crop.description!.isNotEmpty) ...[
              const SizedBox(height: 3.0),
              Text(
                crop.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12.0,
                ),
              ),
            ],
            const SizedBox(height: 6.0),
            Row(
              children: [
                Text(
                  '${CurrencyService.instance.format(crop.price)} / ${crop.unit}',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  '• ${crop.quantity.toStringAsFixed(0)} ${crop.unit} in stock',
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                  decoration: BoxDecoration(
                    color: (isPositive ? Colors.green : Colors.red).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Text(
                    '${isPositive ? "+" : ""}${crop.change.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 9.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.secondaryGreen, width: 1.0),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/role_farmer.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 12, color: AppTheme.secondaryGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${context.tr('role_farmer')}: ${(crop.farmerName != null && crop.farmerName!.isNotEmpty) ? crop.farmerName : "Verified Grower"}',
                  style: const TextStyle(
                    color: AppTheme.secondaryGreen,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isOwner
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppTheme.primaryGreen,
                    tooltip: 'Modify Crop',
                    onPressed: () => _showEditCropDialog(crop),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AppTheme.errorRed,
                    tooltip: 'Delete Crop',
                    onPressed: () => _showDeleteCropDialog(crop),
                  ),
                ],
              )
            : Container(
                decoration: const BoxDecoration(
                  color: AppTheme.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20.0,
                  ),
                  tooltip: 'Buy with DigiPay (Mobile Money)',
                  onPressed: () {
                    DigiPayCheckoutSheet.show(
                      context,
                      itemName: crop.name,
                      unitPriceUSD: crop.price,
                      cropId: crop.id,
                      imageUrl: crop.displayImageUrl,
                      onPaymentSuccess: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Order & DigiPay payment confirmed for ${crop.name}!'),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _showFarmerActionMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    'Farmer Crop Hub',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.lightGreen,
                    child: Icon(Icons.add_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Add Single Crop', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('List a new crop with price, quantity, and photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddCropDialog();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.lightGreen,
                    child: Icon(Icons.upload_file_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Bulk Upload / Import Crops', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Import multiple crops at once from batch list or pack'),
                  onTap: () {
                    Navigator.pop(context);
                    _showBulkUploadDialog();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.lightGreen,
                    child: Icon(Icons.photo_camera_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Upload Crop Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Upload photo to crop media storage'),
                  onTap: () {
                    Navigator.pop(context);
                    _showUploadPhotoDialog();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.lightGreen,
                    child: Icon(Icons.forum_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Community Discussion & Advisory', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Connect with other growers and share cultivation advice'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/chat');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCropDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '50');
    final descCtrl = TextEditingController();
    final imgUrlCtrl = TextEditingController();

    String selectedCat = 'Medicinal';
    String selectedUnit = 'kg';
    String selectedPresetImage = 'assets/images/aloe_vera.png';

    const presetImages = [
      {'label': 'Aloe Vera', 'path': 'assets/images/aloe_vera.png'},
      {'label': 'Tomato Seeds', 'path': 'assets/images/tomato_seeds.png'},
      {'label': 'Bio Fertilizer', 'path': 'assets/images/bio_fertilizer.png'},
      {'label': 'Drip Kit', 'path': 'assets/images/drip_irrigation.png'},
    ];

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              title: Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Text(context.tr('add_new_crop'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: '${context.tr('crop_name')} *',
                            hintText: 'e.g. Organic Moringa Leaf',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter crop name' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: priceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: context.tr('price_dollar'),
                                  hintText: '12.50',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter price';
                                  if (double.tryParse(val) == null || double.parse(val) < 0) return 'Invalid price';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: selectedUnit,
                                decoration: InputDecoration(
                                  labelText: context.tr('unit'),
                                  border: const OutlineInputBorder(),
                                ),
                                items: ['kg', 'bundle', 'unit', 'ton', 'box', 'gram'].map((u) {
                                  return DropdownMenuItem(value: u, child: Text(u));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedUnit = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: qtyCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: context.tr('quantity_in_stock'),
                                  hintText: '100',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedCat,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  'Medicinal',
                                  'Adaptogenic',
                                  'Commercial Crop',
                                  'Vegetables',
                                  'Fruits',
                                  'Herbs',
                                  'Spices',
                                  'General'
                                ].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedCat = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            hintText: 'Organic certification, farm details, medicinal use...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text('Select Photo / Icon:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          children: presetImages.map((img) {
                            final isSel = selectedPresetImage == img['path'];
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => selectedPresetImage = img['path']!),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSel ? AppTheme.primaryGreen : Colors.black12,
                                      width: isSel ? 2.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Image.asset(img['path']!, height: 36, fit: BoxFit.cover),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: imgUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Or Custom Image URL',
                            hintText: 'https://example.com/crop.jpg',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          try {
                            final finalImg = imgUrlCtrl.text.trim().isNotEmpty
                                ? imgUrlCtrl.text.trim()
                                : selectedPresetImage;

                            final newCrop = await CropService.createCrop(
                              name: nameCtrl.text.trim(),
                              price: double.parse(priceCtrl.text.trim()),
                              category: selectedCat,
                              unit: selectedUnit,
                              quantity: double.tryParse(qtyCtrl.text.trim()) ?? 0,
                              description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                              imageUrl: finalImg,
                            );

                            if (mounted) {
                              setState(() {
                                _crops.insert(0, newCrop);
                                _myCrops.insert(0, newCrop);
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Crop "${newCrop.name}" created successfully!'),
                                  backgroundColor: AppTheme.secondaryGreen,
                                ),
                              );
                            }
                          } catch (err) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $err'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(context.tr('add_crop')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCropDialog(CropModel crop) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: crop.name);
    final priceCtrl = TextEditingController(text: crop.price.toStringAsFixed(2));
    final qtyCtrl = TextEditingController(text: crop.quantity.toStringAsFixed(0));
    final descCtrl = TextEditingController(text: crop.description ?? '');
    final imgUrlCtrl = TextEditingController(text: crop.imageUrl ?? '');

    String selectedCat = crop.category;
    String selectedUnit = crop.unit;
    String selectedStatus = crop.status;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              title: const Row(
                children: [
                  Icon(Icons.edit_rounded, color: AppTheme.primaryGreen),
                  SizedBox(width: 8),
                  Text('Modify Crop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Crop Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Enter crop name' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: priceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Price (\$) *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter price';
                                  if (double.tryParse(val) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: ['kg', 'bundle', 'unit', 'ton', 'box', 'gram'].contains(selectedUnit)
                                    ? selectedUnit
                                    : 'kg',
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                  border: OutlineInputBorder(),
                                ),
                                items: ['kg', 'bundle', 'unit', 'ton', 'box', 'gram'].map((u) {
                                  return DropdownMenuItem(value: u, child: Text(u));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedUnit = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: qtyCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Stock Qty',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: ['available', 'reserved', 'sold_out', 'harvested'].contains(selectedStatus)
                                    ? selectedStatus
                                    : 'available',
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  {'label': 'Available', 'val': 'available'},
                                  {'label': 'Reserved', 'val': 'reserved'},
                                  {'label': 'Sold Out', 'val': 'sold_out'},
                                  {'label': 'Harvested', 'val': 'harvested'},
                                ].map((s) => DropdownMenuItem(value: s['val']!, child: Text(s['label']!, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedStatus = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: imgUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Image Path / URL',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          try {
                            final updated = await CropService.updateCrop(
                              id: crop.id,
                              name: nameCtrl.text.trim(),
                              price: double.parse(priceCtrl.text.trim()),
                              category: selectedCat,
                              unit: selectedUnit,
                              quantity: double.tryParse(qtyCtrl.text.trim()) ?? 0,
                              description: descCtrl.text.trim(),
                              status: selectedStatus,
                              imageUrl: imgUrlCtrl.text.trim().isNotEmpty ? imgUrlCtrl.text.trim() : null,
                            );

                            if (mounted) {
                              setState(() {
                                final idxAll = _crops.indexWhere((c) => c.id == crop.id);
                                if (idxAll != -1) _crops[idxAll] = updated;
                                final idxMine = _myCrops.indexWhere((c) => c.id == crop.id);
                                if (idxMine != -1) _myCrops[idxMine] = updated;
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Crop "${updated.name}" updated!'),
                                  backgroundColor: AppTheme.secondaryGreen,
                                ),
                              );
                            }
                          } catch (err) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Update failed: $err'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteCropDialog(CropModel crop) {
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 28),
                  SizedBox(width: 8),
                  Text('Delete Crop?', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'Are you sure you want to remove "${crop.name}" from your farm inventory? This listing will no longer be visible to marketplace buyers.',
                style: const TextStyle(fontSize: 14, color: AppTheme.darkText, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            await CropService.deleteCrop(crop.id);
                            if (mounted) {
                              setState(() {
                                _crops.removeWhere((c) => c.id == crop.id);
                                _myCrops.removeWhere((c) => c.id == crop.id);
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Crop "${crop.name}" deleted from your inventory.'),
                                  backgroundColor: AppTheme.secondaryGreen,
                                ),
                              );
                            }
                          } catch (err) {
                            setDialogState(() => isDeleting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Delete failed: $err'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBulkUploadDialog() {
    bool isImporting = false;
    final jsonCtrl = TextEditingController();

    // Starter pack preview
    final samplePack = [
      {
        'name': 'Organic Turmeric (Curcuma Longa)',
        'category': 'Medicinal',
        'price': 11.50,
        'quantity': 100,
        'unit': 'kg',
        'description': 'High curcumin content golden roots for pharmaceutical processing.',
        'imageUrl': 'assets/images/aloe_vera.png',
      },
      {
        'name': 'Moringa Oleifera Leaves',
        'category': 'Medicinal',
        'price': 9.20,
        'quantity': 75,
        'unit': 'bundle',
        'description': 'Sun-dried nutrient dense superfood leaves.',
        'imageUrl': 'assets/images/aloe_vera.png',
      },
      {
        'name': 'Peppermint Herbal Tea Grade',
        'category': 'Herbs',
        'price': 14.00,
        'quantity': 60,
        'unit': 'kg',
        'description': 'Aromatic digestive tea leaves harvested organically.',
        'imageUrl': 'assets/images/aloe_vera.png',
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              title: const Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: AppTheme.primaryGreen),
                  SizedBox(width: 8),
                  Text('Bulk Upload Crops', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Import several crops into your farm inventory in a single click.',
                        style: TextStyle(fontSize: 13, color: AppTheme.lightText),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Option A: Import Starter Pack (3 Crops)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text('Includes: Turmeric, Moringa, and Peppermint.', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: isImporting
                                  ? null
                                  : () async {
                                      setDialogState(() => isImporting = true);
                                      try {
                                        final created = await CropService.bulkUploadCrops(samplePack);
                                        if (mounted) {
                                          setState(() {
                                            _crops.insertAll(0, created);
                                            _myCrops.insertAll(0, created);
                                          });
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Successfully imported ${created.length} crops!'),
                                              backgroundColor: AppTheme.secondaryGreen,
                                            ),
                                          );
                                        }
                                      } catch (err) {
                                        setDialogState(() => isImporting = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Bulk upload failed: $err'),
                                              backgroundColor: AppTheme.errorRed,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.bolt_rounded, size: 16),
                              label: const Text('Import Starter Pack', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Option B: Custom JSON Batch Paste',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: jsonCtrl,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: '[{"name": "Crop 1", "price": 10.0, "category": "Herbs"}]',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isImporting ? null : () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: isImporting
                      ? null
                      : () async {
                          if (jsonCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please paste a JSON array or use Option A.')),
                            );
                            return;
                          }
                          setDialogState(() => isImporting = true);
                          try {
                            final List raw = jsonDecode(jsonCtrl.text.trim()) as List;
                            final list = raw.map((e) => e as Map<String, dynamic>).toList();
                            final created = await CropService.bulkUploadCrops(list);

                            if (mounted) {
                              setState(() {
                                _crops.insertAll(0, created);
                                _myCrops.insertAll(0, created);
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully imported ${created.length} custom crops!'),
                                  backgroundColor: AppTheme.secondaryGreen,
                                ),
                              );
                            }
                          } catch (err) {
                            setDialogState(() => isImporting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('JSON import failed: $err'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: isImporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Import JSON'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUploadPhotoDialog([CropModel? crop]) {
    final urlCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              title: const Row(
                children: [
                  Icon(Icons.photo_camera_rounded, color: AppTheme.primaryGreen),
                  SizedBox(width: 8),
                  Text('Upload Crop Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select or enter an image URL for high-resolution crop identification:',
                    style: TextStyle(fontSize: 13, color: AppTheme.lightText),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Image Web URL or /uploads/ path',
                      hintText: 'https://images.unsplash.com/... or /uploads/crops/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Presets: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ActionChip(
                        label: const Text('Aloe Vera', style: TextStyle(fontSize: 11)),
                        onPressed: () => urlCtrl.text = 'assets/images/aloe_vera.png',
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Seeds', style: TextStyle(fontSize: 11)),
                        onPressed: () => urlCtrl.text = 'assets/images/tomato_seeds.png',
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (urlCtrl.text.trim().isEmpty) return;
                          setDialogState(() => isSaving = true);

                          if (crop != null) {
                            try {
                              final updated = await CropService.updateCrop(
                                id: crop.id,
                                imageUrl: urlCtrl.text.trim(),
                              );
                              if (mounted) {
                                setState(() {
                                  final idxAll = _crops.indexWhere((c) => c.id == crop.id);
                                  if (idxAll != -1) _crops[idxAll] = updated;
                                  final idxMine = _myCrops.indexWhere((c) => c.id == crop.id);
                                  if (idxMine != -1) _myCrops[idxMine] = updated;
                                });
                              }
                            } catch (_) {}
                          }

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Crop image configured!'),
                                backgroundColor: AppTheme.secondaryGreen,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Photo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScanView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: retains 'Scan Crop/Product' for widget test compatibility
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryGreen, size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('scan_heading'), // 'Smart Crop & Health Scanner'
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            context.tr('scan_subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.lightText),
          ),
          const SizedBox(height: 16.0),

          // Scan Mode Selector (Camera Viewfinder vs Upload Image)
          Container(
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _scanInputMode = 0),
                    borderRadius: BorderRadius.circular(12.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      decoration: BoxDecoration(
                        color: _scanInputMode == 0 ? AppTheme.primaryGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: _scanInputMode == 0
                            ? [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: _scanInputMode == 0 ? Colors.white : AppTheme.darkText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('scan_mode_camera'),
                            style: TextStyle(
                              color: _scanInputMode == 0 ? Colors.white : AppTheme.darkText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _scanInputMode = 1),
                    borderRadius: BorderRadius.circular(12.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      decoration: BoxDecoration(
                        color: _scanInputMode == 1 ? AppTheme.primaryGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: _scanInputMode == 1
                            ? [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_rounded,
                            size: 16,
                            color: _scanInputMode == 1 ? Colors.white : AppTheme.darkText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('scan_mode_upload'),
                            style: TextStyle(
                              color: _scanInputMode == 1 ? Colors.white : AppTheme.darkText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Camera toolbar when in Camera mode
          if (_scanInputMode == 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Flash toggle
                  InkWell(
                    onTap: () => setState(() => _isFlashOn = !_isFlashOn),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Row(
                        children: [
                          Icon(
                            _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: _isFlashOn ? AppTheme.accentAmber : AppTheme.lightText,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isFlashOn ? 'Flash ON' : 'Flash',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isFlashOn ? AppTheme.accentAmber : AppTheme.lightText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Grid toggle
                  InkWell(
                    onTap: () => setState(() => _showGrid = !_showGrid),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Row(
                        children: [
                          Icon(
                            _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                            color: _showGrid ? AppTheme.primaryGreen : AppTheme.lightText,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showGrid ? 'Grid ON' : 'Grid',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _showGrid ? AppTheme.primaryGreen : AppTheme.lightText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Camera flip
                  InkWell(
                    onTap: () => setState(() => _isFrontCamera = !_isFrontCamera),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flip_camera_ios_rounded,
                            color: AppTheme.secondaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isFrontCamera ? 'Front Lens' : 'Macro Lens',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12.0),
          ],

          // Upload options when in Upload mode
          if (_scanInputMode == 1) ...[
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.0),
                border: Border.all(color: AppTheme.secondaryGreen.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device Upload Section
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(
                        color: _deviceImageBytes != null
                            ? AppTheme.primaryGreen
                            : AppTheme.secondaryGreen.withOpacity(0.25),
                        width: _deviceImageBytes != null ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Upload Image from Your Device',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.darkText,
                                    ),
                                  ),
                                  Text(
                                    'Select photos from gallery or device storage to scan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.lightText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_deviceImageBytes != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.errorRed),
                                tooltip: 'Clear Selected Image',
                                onPressed: _clearDeviceImage,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImageFromDevice(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_rounded, size: 17),
                                label: const Text(
                                  'Device Gallery',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryGreen,
                                  side: const BorderSide(color: AppTheme.primaryGreen),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImageFromDevice(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_rounded, size: 17),
                                label: const Text(
                                  'Take Photo',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.secondaryGreen,
                                  side: const BorderSide(color: AppTheme.secondaryGreen),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_deviceImageBytes != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    _deviceImageBytes!,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 36,
                                      height: 36,
                                      color: AppTheme.lightGreen,
                                      child: const Icon(Icons.image_rounded, size: 20, color: AppTheme.primaryGreen),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _deviceImageName ?? 'Device photo',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppTheme.darkText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Ready to diagnose • ${(_deviceImageBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen, size: 20),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: _clearDeviceImage,
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select Specimen to Upload & Scan:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Preset specimen tiles
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildUploadSpecimenThumb(
                          name: 'Aloe Vera',
                          label: 'Organic Aloe Vera (Healthy)',
                          image: 'assets/images/aloe_vera.png',
                          badge: '🌿 Grade A',
                        ),
                        _buildUploadSpecimenThumb(
                          name: 'Moringa Leaf',
                          label: 'Moringa Oleifera (Superfood)',
                          image: 'assets/images/crop_moringa.jpg',
                          badge: '🌱 Pure',
                        ),
                        _buildUploadSpecimenThumb(
                          name: 'Diseased Leaf',
                          label: 'Blight Fungal Pathogen Test',
                          image: 'assets/images/crop_moringa.jpg',
                          badge: '⚠️ Pathogen Alert',
                          isAlert: true,
                        ),
                        _buildUploadSpecimenThumb(
                          name: 'Bio-Fertilizer',
                          label: 'Organic Bio-Fertilizer Compound',
                          image: 'assets/images/bio_fertilizer.png',
                          badge: '📦 Agrochemical',
                        ),
                        _buildUploadSpecimenThumb(
                          name: 'Tomato Seeds',
                          label: 'Certified Hybrid Crop Seeds',
                          image: 'assets/images/tomato_seeds.png',
                          badge: '🍅 Seeds',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Custom URL / File Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('scanner_image_path_input'),
                          controller: _uploadImageUrlController,
                          decoration: InputDecoration(
                            hintText: 'Enter local file path or image URL...',
                            hintStyle: const TextStyle(fontSize: 12, color: AppTheme.lightText),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          final text = _uploadImageUrlController.text.trim();
                          if (text.isNotEmpty) {
                            try {
                              final f = File(text);
                              if (f.existsSync()) {
                                final bytes = f.readAsBytesSync();
                                final filename = text.split(RegExp(r'[\\/]')).last;
                                setState(() {
                                  _deviceImageBytes = bytes;
                                  _deviceImageName = filename;
                                  _deviceImagePath = text;
                                  _activeScanLabel = filename;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Device file loaded: $filename (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)'),
                                    backgroundColor: AppTheme.secondaryGreen,
                                  duration: const Duration(seconds: 1),
                                  ),
                                );
                                return;
                              }
                            } catch (_) {}
                            setState(() {
                              _deviceImageBytes = null;
                              _activeScanImage = text;
                              _activeScanLabel = 'Custom Crop Upload';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Custom crop image loaded in scanner!'),
                                backgroundColor: AppTheme.secondaryGreen,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Load'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),
          ],

          // Viewfinder Container
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.7),
                        width: 3.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Viewfinder Backdrop: Current active crop or uploaded device image
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.85,
                            child: _deviceImageBytes != null
                                ? Image.memory(
                                    _deviceImageBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppTheme.lightGreen,
                                      child: const Icon(
                                        Icons.eco_rounded,
                                        size: 64,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    _activeScanImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppTheme.lightGreen,
                                      child: const Icon(
                                        Icons.eco_rounded,
                                        size: 64,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                          ),
                        ),

                        // Flashlight illumination overlay
                        if (_isFlashOn && _scanInputMode == 0)
                          Container(
                            color: Colors.yellow.withOpacity(0.18),
                          ),

                        // Rule of Thirds 3x3 Grid
                        if (_showGrid && _scanInputMode == 0)
                          Positioned.fill(
                            child: Column(
                              children: [
                                const Spacer(),
                                Container(height: 1, color: Colors.white24),
                                const Spacer(),
                                Container(height: 1, color: Colors.white24),
                                const Spacer(),
                              ],
                            ),
                          ),
                        if (_showGrid && _scanInputMode == 0)
                          Positioned.fill(
                            child: Row(
                              children: [
                                const Spacer(),
                                Container(width: 1, color: Colors.white24),
                                const Spacer(),
                                Container(width: 1, color: Colors.white24),
                                const Spacer(),
                              ],
                            ),
                          ),

                        // Dimming while active scan
                        if (_isScanning)
                          Container(color: Colors.black.withOpacity(0.4)),

                        // Corner Alignment Reticles (Amber)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppTheme.accentAmber, width: 4.5),
                                left: BorderSide(color: AppTheme.accentAmber, width: 4.5),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppTheme.accentAmber, width: 4.5),
                                right: BorderSide(color: AppTheme.accentAmber, width: 4.5),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 14,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppTheme.accentAmber, width: 4.5),
                                left: BorderSide(color: AppTheme.accentAmber, width: 4.5),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          right: 14,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppTheme.accentAmber, width: 4.5),
                                right: BorderSide(color: AppTheme.accentAmber, width: 4.5),
                              ),
                            ),
                          ),
                        ),

                        // Center Focus Crosshair
                        if (!_isScanning)
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, size: 16, color: Colors.white70),
                            ),
                          ),

                        // Active Laser Scanning sweep line
                        if (_isScanning)
                          AnimatedBuilder(
                            animation: _scannerAnimationController,
                            builder: (context, child) {
                              return Positioned(
                                top: 14 + (190 * _scannerAnimationController.value),
                                left: 14,
                                right: 14,
                                child: Container(
                                  height: 3.5,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(2.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent.withOpacity(0.9),
                                        blurRadius: 10.0,
                                        spreadRadius: 2.0,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        // Scanning Indicator
                        if (_isScanning)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 12.0),
                                Text(
                                  'Analyzing Botanical DNA...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Target specimen label tag
                        Positioned(
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _deviceImageBytes != null
                                  ? (_deviceImageName ?? 'Device Photo')
                                  : _activeScanLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18.0),

          // Primary Scan Action Button
          Container(
            height: 52.0,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  blurRadius: 12.0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isScanning
                  ? null
                  : () => _triggerScan(
                        customImage: _activeScanImage,
                        customName: _deviceImageBytes != null
                            ? (_deviceImageName ?? 'Device Specimen')
                            : _activeScanLabel,
                        customBytes: _deviceImageBytes,
                      ),
              icon: Icon(
                _deviceImageBytes != null
                    ? Icons.auto_awesome_rounded
                    : (_scanInputMode == 0 ? Icons.camera_alt_rounded : Icons.cloud_upload_rounded),
                color: Colors.white,
              ),
              label: Text(
                _deviceImageBytes != null
                    ? 'Scan Device Photo with Gemini AI'
                    : (_scanInputMode == 0
                        ? context.tr('scan_capture_btn')
                        : context.tr('scan_upload_btn')),
                style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: AppTheme.primaryButtonStyle,
            ),
          ),
          const SizedBox(height: 14.0),

          // Multi-Currency Converter Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: AppTheme.secondaryGreen.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.currency_exchange_rounded, color: AppTheme.primaryGreen, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AgriMed Multi-Currency Trade',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      Text(
                        'Convert live crop prices in FCFA, EURO & DOLLAR',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.lightText),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showCurrencyConverterDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: AppTheme.lightGreen,
                  ),
                  child: const Text(
                    'Converter',
                    style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
        ],
      ),
    );
  }

  Widget _buildUploadSpecimenThumb({
    required String name,
    required String label,
    required String image,
    required String badge,
    bool isAlert = false,
  }) {
    final isSelected = _activeScanLabel == label;
    return Container(
      margin: const EdgeInsets.only(right: 10.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _deviceImageBytes = null;
            _deviceImageName = null;
            _deviceImagePath = null;
            _activeScanImage = image;
            _activeScanLabel = label;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : Colors.black12,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  image,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 52,
                    height: 52,
                    color: AppTheme.lightGreen,
                    child: const Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isAlert ? Colors.red.shade50 : AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isAlert ? AppTheme.errorRed : AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.secondaryGreen,
                ),
                hintText: 'Search seeds, fertilizers, medicinal plants...',
                hintStyle: TextStyle(color: AppTheme.lightText, fontSize: 13.0),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14.0),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.filter_list_rounded,
            color: AppTheme.secondaryGreen,
          ),
        ),
      ],
    );
  }
}
