import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/admin_service.dart';
import '../../services/app_localizations.dart';
import '../../widgets/language_selector_dialog.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data states
  bool _isLoading = false;
  Map<String, dynamic>? _stats = AdminService.defaultStats;
  List<Map<String, dynamic>> _users = AdminService.defaultUsers;
  List<Map<String, dynamic>> _pendingRequests = AdminService.defaultPendingRequests;
  Map<String, dynamic>? _appSettings = AdminService.defaultAppSettings;

  // Filter states
  String _userSearchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  // Settings form controllers
  final TextEditingController _appNameController =
      TextEditingController(text: 'AgriMed Link');
  final TextEditingController _appVersionController =
      TextEditingController(text: '2.1.0');
  final TextEditingController _buildNumberController =
      TextEditingController(text: '104');
  final TextEditingController _announcementController = TextEditingController(
      text: 'Welcome to AgriMed Link Platform - Empowering Agricultural Trade');
  final TextEditingController _commissionController =
      TextEditingController(text: '3.50');
  final TextEditingController _supportEmailController =
      TextEditingController(text: 'support@agrimedlink.com');
  bool _maintenanceMode = false;
  bool _allowRegistrations = true;
  bool _isAuthorized = true;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final email = args['email']?.toString().toLowerCase().trim();
      final role = args['role']?.toString().toLowerCase().trim();
      if ((email != null && email != 'system.admin@agrimedlink.com') ||
          (role != null && role != 'admin')) {
        _isAuthorized = false;
      }
    }
    if (_isAuthorized && !_dataLoaded) {
      _dataLoaded = true;
      _loadAllData(showSpinner: false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _appNameController.dispose();
    _appVersionController.dispose();
    _buildNumberController.dispose();
    _announcementController.dispose();
    _commissionController.dispose();
    _supportEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _isLoading = true);
    try {
      final stats = await AdminService.getStats();
      final users = await AdminService.getUsers(
        role: _selectedRoleFilter,
        status: _selectedStatusFilter,
        search: _userSearchQuery,
      );
      final requests = await AdminService.getPendingRequests();
      final settings = await AdminService.getAppSettings();

      if (mounted) {
        setState(() {
          _stats = stats;
          _users = users;
          _pendingRequests = requests;
          _appSettings = settings;

          // Populate settings controllers
          _appNameController.text = settings['appName']?.toString() ?? 'AgriMed Link';
          _appVersionController.text = settings['appVersion']?.toString() ?? '2.1.0';
          _buildNumberController.text = settings['buildNumber']?.toString() ?? '104';
          _announcementController.text = settings['announcement']?.toString() ?? '';
          _commissionController.text = settings['commissionRate']?.toString() ?? '3.50';
          _supportEmailController.text = settings['supportEmail']?.toString() ?? 'support@agrimedlink.com';
          _maintenanceMode = settings['maintenanceMode'] == true;
          _allowRegistrations = settings['allowRegistrations'] != false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 72, color: AppTheme.errorRed),
                const SizedBox(height: 16),
                const Text(
                  'Unauthorized Administrator Access',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Admin privileges are strictly restricted to the platform\'s sole system administrator (system.admin@agrimedlink.com).',
                  style: TextStyle(fontSize: 14, color: AppTheme.lightText, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Safety'),
                  style: AppTheme.primaryButtonStyle,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('admin_portal_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              context.tr('admin_portal_subtitle'),
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          const LanguagePickerButton(isTransparent: true),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _loadAllData(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.analytics_rounded, size: 20),
              text: context.tr('admin_tab_stats'),
            ),
            Tab(
              icon: const Icon(Icons.people_alt_rounded, size: 20),
              text: context.tr('admin_tab_users'),
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _pendingRequests.isNotEmpty,
                label: Text('${_pendingRequests.length}'),
                backgroundColor: AppTheme.accentAmber,
                textColor: AppTheme.primaryGreen,
                child: const Icon(Icons.verified_user_rounded, size: 20),
              ),
              text: context.tr('admin_tab_requests'),
            ),
            Tab(
              icon: const Icon(Icons.settings_system_daydream_rounded, size: 20),
              text: context.tr('admin_tab_settings'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(),
          _buildUsersTab(),
          _buildRequestsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: SYSTEM STATISTICS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatsTab() {
    final overview = _stats?['overview'] as Map<String, dynamic>? ?? {};
    final health = _stats?['systemHealth'] as Map<String, dynamic>? ?? {};
    final roles = _stats?['usersByRole'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: context.tr('stat_total_users'),
                    value: '${overview['totalUsers'] ?? 0}',
                    icon: Icons.people_outline_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: context.tr('stat_active_crops'),
                    value: '${overview['totalCrops'] ?? 0}',
                    icon: Icons.eco_rounded,
                    color: AppTheme.secondaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: context.tr('stat_pending_approvals'),
                    value: '${overview['pendingRequests'] ?? _pendingRequests.length}',
                    icon: Icons.pending_actions_rounded,
                    color: AppTheme.accentAmber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: context.tr('stat_suspended_users'),
                    value: '${overview['suspendedUsers'] ?? 0}',
                    icon: Icons.block_rounded,
                    color: AppTheme.errorRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Server & System Health Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dns_rounded, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('system_health_overview'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(radius: 4, backgroundColor: Colors.green),
                              SizedBox(width: 6),
                              Text(
                                'ONLINE',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildHealthRow(context.tr('stat_server_uptime'), health['uptimeFormatted']?.toString() ?? 'Active'),
                    _buildHealthRow(context.tr('stat_db_status'), 'Connected (MySQL)'),
                    _buildHealthRow(context.tr('stat_memory'), '${health['memoryUsageMB'] ?? 42} MB'),
                    _buildHealthRow('Node Environment', health['nodeVersion']?.toString() ?? 'v20.x'),
                    _buildHealthRow(context.tr('maintenance_mode'), health['maintenanceMode'] == true ? 'ENABLED' : 'DISABLED'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Role Distribution Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pie_chart_rounded, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('role_distribution'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildRoleChip('Farmers', roles['farmer'] ?? 0, 'farmer', Icons.agriculture_rounded),
                        _buildRoleChip('Buyers', roles['customer'] ?? 0, 'buyer', Icons.shopping_bag_rounded),
                        _buildRoleChip('Suppliers', roles['supplier'] ?? 0, 'supplier', Icons.local_shipping_rounded),
                        _buildRoleChip('Advisors', roles['advisor'] ?? 0, 'advisor', Icons.psychology_rounded),
                        _buildRoleChip('Investors', roles['investor'] ?? 0, 'investor', Icons.monetization_on_rounded),
                        _buildRoleChip('Admins', roles['admin'] ?? 1, 'admin', Icons.admin_panel_settings_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppTheme.lightText, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.lightText, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String label, dynamic count, String roleKey, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryGreen, width: 1.2),
            ),
            child: ClipOval(
              child: Image.asset(
                _getRoleImage(roleKey),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(icon, size: 14, color: AppTheme.primaryGreen),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: USER MANAGEMENT (Create, Suspend, Unsuspend)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    return Column(
      children: [
        // Action bar: Search + Create User Button
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.tr('user_search_placeholder'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onChanged: (val) {
                        _userSearchQuery = val;
                        _loadAllData(showSpinner: false);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showCreateUserDialog,
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: Text(context.tr('create_user_btn')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All'),
                    _buildFilterChip('active', 'Active'),
                    _buildFilterChip('suspended', 'Suspended'),
                    _buildFilterChip('farmer', 'Farmers'),
                    _buildFilterChip('advisor', 'Advisors'),
                    _buildFilterChip('investor', 'Investors'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // User list
        Expanded(
          child: _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('no_data'),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return _buildUserCard(user);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedRoleFilter == key || _selectedStatusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppTheme.darkText)),
        selected: isSelected,
        selectedColor: AppTheme.primaryGreen,
        backgroundColor: Colors.grey.shade100,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onSelected: (_) {
          setState(() {
            if (['active', 'suspended'].contains(key)) {
              _selectedStatusFilter = _selectedStatusFilter == key ? 'all' : key;
            } else {
              _selectedRoleFilter = _selectedRoleFilter == key ? 'all' : key;
            }
          });
          _loadAllData(showSpinner: false);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final String status = (user['status'] ?? 'active').toString().toLowerCase();
    final String role = (user['role'] ?? 'customer').toString();
    final bool isSuspended = status == 'suspended';
    final String userId = user['id']?.toString() ?? '';

    Color statusColor;
    String statusText;
    if (status == 'active') {
      statusColor = Colors.green;
      statusText = context.tr('status_active');
    } else if (status == 'suspended') {
      statusColor = AppTheme.errorRed;
      statusText = context.tr('status_suspended');
    } else {
      statusColor = AppTheme.accentAmber;
      statusText = context.tr('status_pending');
    }

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.12),
              backgroundImage: AssetImage(_getRoleImage(role)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['name']?.toString() ?? 'Unnamed User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['email']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: AppTheme.lightText),
                  ),
                  if (user['phone_number'] != null && user['phone_number'].toString().isNotEmpty)
                    Text(
                      user['phone_number'].toString(),
                      style: const TextStyle(fontSize: 11, color: AppTheme.lightText),
                    ),
                ],
              ),
            ),

            // Suspend / Unsuspend action button
            if (role != 'admin')
              isSuspended
                  ? ElevatedButton(
                      onPressed: () => _handleUnsuspendUser(userId, user['email'] ?? ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(context.tr('unsuspend_btn'), style: const TextStyle(fontSize: 12)),
                    )
                  : OutlinedButton(
                      onPressed: () => _handleSuspendUser(userId, user['email'] ?? ''),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(context.tr('suspend_btn'), style: const TextStyle(fontSize: 12)),
                    ),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'farmer':
        return Icons.agriculture_rounded;
      case 'supplier':
        return Icons.local_shipping_rounded;
      case 'advisor':
        return Icons.psychology_rounded;
      case 'investor':
        return Icons.monetization_on_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.person_rounded;
    }
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

  Future<void> _handleSuspendUser(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.tr('suspend_btn')} $email?'),
        content: const Text('This will block the user from logging in or performing any actions on the platform.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            child: Text(context.tr('suspend_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await AdminService.suspendUser(userId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('user_suspended_success')),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        _loadAllData(showSpinner: false);
      }
    }
  }

  Future<void> _handleUnsuspendUser(String userId, String email) async {
    final success = await AdminService.unsuspendUser(userId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('user_unsuspended_success')),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData(showSpinner: false);
    }
  }

  void _showCreateUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'farmer';
    String selectedStatus = 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(context.tr('create_user_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('full_name'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.tr('email_address'),
                    hintText: 'user@gmail.com or @icloud.com',
                    helperText: 'Non-admin users must use @gmail.com or @icloud.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('password'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: context.tr('select_role'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'farmer',
                      child: Row(
                        children: [
                          ClipOval(child: Image.asset('assets/images/role_farmer.jpg', width: 22, height: 22, fit: BoxFit.cover)),
                          const SizedBox(width: 8),
                          const Text('Farmer'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'customer',
                      child: Row(
                        children: [
                          ClipOval(child: Image.asset('assets/images/role_buyer.jpg', width: 22, height: 22, fit: BoxFit.cover)),
                          const SizedBox(width: 8),
                          const Text('Buyer / Customer'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'supplier',
                      child: Row(
                        children: [
                          ClipOval(child: Image.asset('assets/images/role_supplier.jpg', width: 22, height: 22, fit: BoxFit.cover)),
                          const SizedBox(width: 8),
                          const Text('Supplier'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'advisor',
                      child: Row(
                        children: [
                          ClipOval(child: Image.asset('assets/images/role_advisor.jpg', width: 22, height: 22, fit: BoxFit.cover)),
                          const SizedBox(width: 8),
                          const Text('Advisor (Professional)'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'investor',
                      child: Row(
                        children: [
                          ClipOval(child: Image.asset('assets/images/role_investor.jpg', width: 22, height: 22, fit: BoxFit.cover)),
                          const SizedBox(width: 8),
                          const Text('Investor'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Row(
                        children: [
                          ClipOval(child: Image.asset('assets/images/role_admin.jpg', width: 22, height: 22, fit: BoxFit.cover)),
                          const SizedBox(width: 8),
                          const Text('Administrator'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: context.tr('status'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    DropdownMenuItem(value: 'pending_approval', child: Text('Pending Approval')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedStatus = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final emailInput = emailCtrl.text.trim();
                final passwordInput = passwordCtrl.text.trim();
                if (emailInput.isEmpty || passwordInput.isEmpty) {
                  return;
                }
                final emailLower = emailInput.toLowerCase();
                final isTargetAdmin = selectedRole.toLowerCase() == 'admin' || emailLower == 'system.admin@agrimedlink.com';
                if (!isTargetAdmin && !emailLower.endsWith('@gmail.com') && !emailLower.endsWith('@icloud.com')) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All users except admin must have a @gmail.com or @icloud.com email address.'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await AdminService.createUser(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: passwordCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  role: selectedRole,
                  status: selectedStatus,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('user_created_success')),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                  _loadAllData(showSpinner: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: PROFESSIONAL APPROVALS (Advisors & Investors)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt_rounded, size: 56, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('no_pending_requests'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'All professional applications have been reviewed.',
                style: TextStyle(color: AppTheme.lightText, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final req = _pendingRequests[index];
        final String reqId = req['id']?.toString() ?? '';
        final String role = (req['role'] ?? 'advisor').toString();
        final bool isAdvisor = role.toLowerCase() == 'advisor';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isAdvisor ? Colors.purple : Colors.indigo,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isAdvisor ? Colors.purple : Colors.indigo).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          isAdvisor ? 'assets/images/role_advisor.jpg' : 'assets/images/role_investor.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            isAdvisor ? Icons.psychology_rounded : Icons.monetization_on_rounded,
                            color: isAdvisor ? Colors.purple : Colors.indigo,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['name']?.toString() ?? 'Applicant',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            isAdvisor
                                ? 'Professional Agricultural Advisor Request'
                                : 'Agricultural Investor Account Request',
                            style: TextStyle(
                              fontSize: 12,
                              color: isAdvisor ? Colors.purple.shade700 : Colors.indigo.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.tr('status_pending'),
                        style: const TextStyle(
                          color: Color(0xFFC67D00),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 16, color: AppTheme.lightText),
                    const SizedBox(width: 6),
                    Text(req['email']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                  ],
                ),
                if (req['phone_number'] != null && req['phone_number'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16, color: AppTheme.lightText),
                      const SizedBox(width: 6),
                      Text(req['phone_number'].toString(), style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _handleRejectRequest(reqId),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(context.tr('reject_btn')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _handleAcceptRequest(reqId),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(context.tr('accept_btn')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAcceptRequest(String reqId) async {
    final success = await AdminService.acceptRequest(reqId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('request_accepted_success')),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      _loadAllData(showSpinner: false);
    }
  }

  Future<void> _handleRejectRequest(String reqId) async {
    final success = await AdminService.rejectRequest(reqId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('request_rejected_success')),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      _loadAllData(showSpinner: false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 4: UPDATE APPLICATION SETTINGS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppTheme.primaryGreen),
                      SizedBox(width: 8),
                      Text(
                        'Platform Configuration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _appNameController,
                    decoration: InputDecoration(
                      labelText: 'Application Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _appVersionController,
                          decoration: InputDecoration(
                            labelText: 'Version',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _buildNumberController,
                          decoration: InputDecoration(
                            labelText: 'Build Number',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commissionController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('commission_rate'),
                      suffixText: '%',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supportEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'System Support Email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _announcementController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: context.tr('announcement_banner'),
                      hintText: 'Broadcast notification banner for all users...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Toggles Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    context.tr('maintenance_mode'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Temporarily prevent non-admin users from creating new transactions'),
                  value: _maintenanceMode,
                  activeColor: AppTheme.errorRed,
                  onChanged: (val) => setState(() => _maintenanceMode = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text(
                    'Allow New Registrations',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Allow external users to submit new account registrations'),
                  value: _allowRegistrations,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (val) => setState(() => _allowRegistrations = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: Text(
              context.tr('save_settings_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 3,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final double? parsedCommission = double.tryParse(_commissionController.text.trim());
    final settingsPayload = {
      'appName': _appNameController.text.trim(),
      'appVersion': _appVersionController.text.trim(),
      'buildNumber': _buildNumberController.text.trim(),
      'announcement': _announcementController.text.trim(),
      'commissionRate': parsedCommission ?? 3.50,
      'supportEmail': _supportEmailController.text.trim(),
      'maintenanceMode': _maintenanceMode,
      'allowRegistrations': _allowRegistrations,
    };

    final success = await AdminService.updateAppSettings(settingsPayload);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? context.tr('settings_saved_success') : 'Failed to save settings',
          ),
          backgroundColor: success ? AppTheme.primaryGreen : AppTheme.errorRed,
        ),
      );
    }
  }
}
