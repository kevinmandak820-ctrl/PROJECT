import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/mapbox_service.dart';
import '../../services/currency_service.dart';
import '../../services/app_localizations.dart';

class FarmMapScreen extends StatefulWidget {
  final FarmLocation? initialFarm;

  const FarmMapScreen({
    super.key,
    this.initialFarm,
  });

  @override
  State<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends State<FarmMapScreen> {
  final MapboxService _mapbox = MapboxService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<FarmLocation> _farms = [];
  FarmLocation? _selectedFarm;
  List<MapPlace> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingFarms = true;

  // Map Viewport State
  double _currentLat = 5.5083; // Foumbot center by default
  double _currentLng = 10.6311;
  int _currentZoom = 12;
  String _activeStyle = 'outdoors-v12'; // outdoors-v12, satellite-streets-v12, streets-v12

  // Filter State
  String _selectedCropFilter = 'All';

  // Route & Delivery State
  DeliveryRoute? _calculatedRoute;
  bool _isCalculatingRoute = false;
  MapPlace? _selectedDeliveryDestination;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFarms() async {
    setState(() => _isLoadingFarms = true);
    final list = await _mapbox.fetchFarms();
    if (mounted) {
      setState(() {
        _farms = list;
        _isLoadingFarms = false;
        if (widget.initialFarm != null) {
          _selectedFarm = widget.initialFarm;
          _currentLat = widget.initialFarm!.latitude;
          _currentLng = widget.initialFarm!.longitude;
        } else if (list.isNotEmpty) {
          _selectedFarm = list.first;
          _currentLat = list.first.latitude;
          _currentLng = list.first.longitude;
        }
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _mapbox.searchPlaces(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _selectPlace(MapPlace place) {
    setState(() {
      _currentLat = place.latitude;
      _currentLng = place.longitude;
      _currentZoom = 13;
      _searchResults = [];
      _searchController.text = place.placeName;
    });
    FocusScope.of(context).unfocus();
  }

  void _selectFarm(FarmLocation farm) {
    setState(() {
      _selectedFarm = farm;
      _currentLat = farm.latitude;
      _currentLng = farm.longitude;
      _currentZoom = 13;
      _calculatedRoute = null;
      _selectedDeliveryDestination = null;
    });
  }

  void _zoomIn() {
    if (_currentZoom < 18) {
      setState(() => _currentZoom++);
    }
  }

  void _zoomOut() {
    if (_currentZoom > 4) {
      setState(() => _currentZoom--);
    }
  }

  void _resetToCameroon() {
    setState(() {
      _currentLat = 4.8;
      _currentLng = 11.2;
      _currentZoom = 7;
    });
  }

  Future<void> _openDeliveryCalculator() async {
    if (_selectedFarm == null) return;

    final destController = TextEditingController();
    List<MapPlace> destSearchResults = [];
    bool isSearchingDest = false;
    DeliveryRoute? routeResult;
    bool isCalc = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery Route & Fare Calculator',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              Text(
                                'Powered by Mapbox Directions Engine',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Farm Origin Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.agriculture_rounded, color: AppTheme.primaryGreen, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PICKUP ORIGIN (FARM)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryGreen,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedFarm!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.darkText,
                                      ),
                                    ),
                                    Text(
                                      '${_selectedFarm!.farmerName} • ${_selectedFarm!.region}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Destination Input
                        const Text(
                          'Destination (Drop-off Address / City):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText),
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: destController,
                          decoration: InputDecoration(
                            hintText: 'Search city or market (e.g. Douala, Yaoundé, Bafoussam)',
                            prefixIcon: const Icon(Icons.location_on_rounded, color: AppTheme.accentAmber),
                            suffixIcon: isSearchingDest
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : (destController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          destController.clear();
                                          setModalState(() {
                                            destSearchResults = [];
                                            routeResult = null;
                                          });
                                        },
                                      )
                                    : null),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (val) async {
                            if (val.trim().length < 2) {
                              setModalState(() => destSearchResults = []);
                              return;
                            }
                            setModalState(() => isSearchingDest = true);
                            final res = await _mapbox.searchPlaces(val);
                            setModalState(() {
                              destSearchResults = res;
                              isSearchingDest = false;
                            });
                          },
                        ),

                        // Destination Autocomplete Results
                        if (destSearchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: destSearchResults.map((place) {
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place_rounded, color: AppTheme.accentAmber, size: 20),
                                  title: Text(
                                    place.text,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    place.placeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () async {
                                    destController.text = place.placeName;
                                    setModalState(() {
                                      destSearchResults = [];
                                      isCalc = true;
                                    });

                                    final route = await _mapbox.getDirections(
                                      originLat: _selectedFarm!.latitude,
                                      originLng: _selectedFarm!.longitude,
                                      destLat: place.latitude,
                                      destLng: place.longitude,
                                    );

                                    setModalState(() {
                                      routeResult = route;
                                      isCalc = false;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),

                        // Quick presets if not searching
                        if (destSearchResults.isEmpty && routeResult == null) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Quick Destinations in Cameroon:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildQuickDestChip('Douala (Akwa)', 4.0511, 9.7042, setModalState, destController, (r) => routeResult = r),
                              _buildQuickDestChip('Yaoundé (Bastos)', 3.8667, 11.5167, setModalState, destController, (r) => routeResult = r),
                              _buildQuickDestChip('Bafoussam Central', 5.4777, 10.4179, setModalState, destController, (r) => routeResult = r),
                              _buildQuickDestChip('Bamenda Commercial', 5.9631, 10.1591, setModalState, destController, (r) => routeResult = r),
                            ],
                          ),
                        ],

                        if (isCalc) ...[
                          const SizedBox(height: 32),
                          const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: AppTheme.primaryGreen),
                                SizedBox(height: 12),
                                Text('Calculating driving route & delivery fee...'),
                              ],
                            ),
                          ),
                        ],

                        // Calculated Route Results Card
                        if (routeResult != null && !isCalc) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryGreen.withOpacity(0.08),
                                  Colors.white,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'ROUTE SUMMARY',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryGreen,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'DRIVING',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Metric chips
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon: Icons.straighten_rounded,
                                        label: 'Distance',
                                        value: '${routeResult!.distanceKm} km',
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon: Icons.timer_rounded,
                                        label: 'Duration',
                                        value: routeResult!.durationMinutes > 60
                                            ? '${(routeResult!.durationMinutes / 60).toStringAsFixed(1)} hrs'
                                            : '${routeResult!.durationMinutes} mins',
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon: Icons.payments_rounded,
                                        label: 'Est. Fare',
                                        value: CurrencyService.instance.format(routeResult!.deliveryFeeXAF.toDouble()),
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Static Route Map Image Preview
                                if (routeResult!.staticRouteMapUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 140,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                      ),
                                      child: Image.network(
                                        routeResult!.staticRouteMapUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.map_rounded, color: Colors.grey, size: 40),
                                        ),
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                if (routeResult!.steps.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Turn-by-turn Navigation Preview:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  ...routeResult!.steps.take(3).map((st) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.arrow_right_alt_rounded, size: 16, color: AppTheme.primaryGreen),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              st,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Bottom Action
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                routeResult != null
                                    ? 'Delivery route confirmed (${routeResult!.distanceKm} km)! Ready to checkout.'
                                    : 'Delivery calculator closed.',
                              ),
                              backgroundColor: AppTheme.primaryGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(
                          routeResult != null
                              ? 'Confirm Delivery (${CurrencyService.instance.format(routeResult!.deliveryFeeXAF.toDouble())})'
                              : 'Close',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickDestChip(
    String label,
    double lat,
    double lng,
    StateSetter setModalState,
    TextEditingController controller,
    Function(DeliveryRoute?) onCalculated,
  ) {
    return ActionChip(
      avatar: const Icon(Icons.place_rounded, size: 14, color: AppTheme.accentAmber),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.grey.shade100,
      onPressed: () async {
        controller.text = label;
        setModalState(() {});
        final r = await _mapbox.getDirections(
          originLat: _selectedFarm!.latitude,
          originLng: _selectedFarm!.longitude,
          destLat: lat,
          destLng: lng,
        );
        setModalState(() {
          onCalculated(r);
        });
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staticMapUrl = _mapbox.getStaticMapUrl(
      lat: _currentLat,
      lng: _currentLng,
      zoom: _currentZoom,
      style: _activeStyle,
      width: 700,
      height: 500,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Farm & Delivery Map Explorer',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: Colors.white),
            tooltip: 'Reset to Cameroon',
            onPressed: _resetToCameroon,
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. Map Canvas (Mapbox Static HD Imagery with Overlay)
          Positioned.fill(
            child: Container(
              color: Colors.grey.shade200,
              child: Image.network(
                staticMapUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map_rounded, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'Mapbox Map View',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Coords: [$_currentLat, $_currentLng] • Zoom: $_currentZoom'),
                    ],
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Stack(
                    children: [
                      child,
                      Container(
                        color: Colors.black.withOpacity(0.1),
                        child: const Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. Top Search and Geocoding Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search city, farm, or market in Cameroon...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                // Search Results Dropdown
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_rounded, color: AppTheme.primaryGreen, size: 20),
                          title: Text(p.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                            p.placeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => _selectPlace(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Map Controls: Layer Switcher & Zoom (+ / -)
          Positioned(
            right: 16,
            top: 80,
            child: Column(
              children: [
                // Layer Style Toggle Button
                _buildMapActionButton(
                  icon: Icons.layers_rounded,
                  tooltip: 'Change Map Style',
                  onTap: _showStylePicker,
                ),
                const SizedBox(height: 10),

                // Zoom In
                _buildMapActionButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),

                // Zoom Out
                _buildMapActionButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),

          // 4. Map Attribution & Badge
          Positioned(
            left: 16,
            bottom: 215,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, color: Colors.white, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'Mapbox HD • Zoom $_currentZoom',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Agricultural Hubs & Farms Carousel
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Section Title & Delivery Shortcut
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.agriculture_rounded, size: 14, color: AppTheme.primaryGreen),
                            SizedBox(width: 6),
                            Text(
                              'Verified Farms & Hubs',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedFarm != null)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentAmber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: _openDeliveryCalculator,
                          icon: const Icon(Icons.route_rounded, size: 16),
                          label: const Text(
                            'Calculate Route',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),

                // Farm Cards Horizontal Carousel
                SizedBox(
                  height: 165,
                  child: _isLoadingFarms
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _farms.length,
                          itemBuilder: (context, index) {
                            final farm = _farms[index];
                            final isSelected = _selectedFarm?.id == farm.id;

                            return GestureDetector(
                              onTap: () => _selectFarm(farm),
                              child: Container(
                                width: 280,
                                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? AppTheme.primaryGreen.withOpacity(0.2)
                                          : Colors.black.withOpacity(0.08),
                                      blurRadius: isSelected ? 12 : 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryGreen.withOpacity(0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.eco_rounded,
                                            color: AppTheme.primaryGreen,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                farm.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: AppTheme.darkText,
                                                ),
                                              ),
                                              Text(
                                                farm.region,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${farm.rating}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Crops Chips
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: farm.crops.take(3).map((crop) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryGreen.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            crop,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryGreen,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),

                                    const Spacer(),

                                    // Farmer info & Phone
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  farm.farmerName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          farm.phone,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                      ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.darkText, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  void _showStylePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Map Layer Style',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildStyleTile(
                id: 'outdoors-v12',
                title: 'Outdoors & Agricultural Terrain',
                subtitle: 'Topography, hills, vegetation & farm zones',
                icon: Icons.terrain_rounded,
                color: Colors.green,
              ),
              _buildStyleTile(
                id: 'satellite-streets-v12',
                title: 'High-Resolution Satellite',
                subtitle: 'Real aerial imagery of crop plots & fields',
                icon: Icons.satellite_alt_rounded,
                color: Colors.blue,
              ),
              _buildStyleTile(
                id: 'streets-v12',
                title: 'Streets & Navigation',
                subtitle: 'Roads, highways & delivery corridors',
                icon: Icons.alt_route_rounded,
                color: Colors.orange,
              ),
              _buildStyleTile(
                id: 'dark-v11',
                title: 'Dark High-Contrast',
                subtitle: 'Night-mode cartography',
                icon: Icons.nightlight_round,
                color: Colors.purple,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStyleTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _activeStyle == id;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen) : null,
      onTap: () {
        setState(() => _activeStyle = id);
        Navigator.pop(context);
      },
    );
  }
}
