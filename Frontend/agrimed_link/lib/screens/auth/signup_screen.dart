import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/app_localizations.dart';
import '../../widgets/language_selector_dialog.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // Available user roles for the platform
  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'farmer',
      'label': 'Farmer',
      'icon': Icons.agriculture_rounded,
      'image': 'assets/images/role_farmer.jpg',
      'desc': 'Buy inputs, sell crops, manage your farms.',
    },
    {
      'id': 'buyer',
      'label': 'Buyer',
      'icon': Icons.shopping_bag_rounded,
      'image': 'assets/images/role_buyer.jpg',
      'desc': 'Browse and purchase organic crops & products.',
    },
    {
      'id': 'supplier',
      'label': 'Supplier',
      'icon': Icons.local_shipping_rounded,
      'image': 'assets/images/role_supplier.jpg',
      'desc': 'Sell seeds, agricultural tools, fertilizer.',
    },
    {
      'id': 'advisor',
      'label': 'Advisor',
      'icon': Icons.psychology_rounded,
      'image': 'assets/images/role_advisor.jpg',
      'desc': 'Offer professional consultations & tips.',
    },
    {
      'id': 'investor',
      'label': 'Investor',
      'icon': Icons.monetization_on_rounded,
      'image': 'assets/images/role_investor.jpg',
      'desc': 'Fund farming activities & collect returns.',
    },
  ];

  // Default selection is 'farmer'
  String _selectedRoleId = 'farmer';

  Map<String, dynamic> get _currentRoleData {
    return _roles.firstWhere(
      (r) => r['id'] == _selectedRoleId,
      orElse: () => _roles.first,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoleId.trim().toLowerCase() == 'admin' || _selectedRoleId.trim().toLowerCase() == 'administrator') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration as an administrator is prohibited. Admin accounts must be created internally.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final emailLower = _emailController.text.trim().toLowerCase();
    final isRoleAdmin = _selectedRoleId.trim().toLowerCase() == 'admin' ||
        _selectedRoleId.trim().toLowerCase() == 'administrator' ||
        emailLower == 'system.admin@agrimedlink.com';
    if (!isRoleAdmin && !emailLower.endsWith('@gmail.com') && !emailLower.endsWith('@icloud.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email must end with @gmail.com or @icloud.com'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.register(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        role: _selectedRoleId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration successful as ${_selectedRoleId[0].toUpperCase()}${_selectedRoleId.substring(1)}! Please sign in.',
          ),
          backgroundColor: AppTheme.secondaryGreen,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getRoleLabel(BuildContext context, String roleId) {
    if (roleId == 'farmer') return context.tr('role_farmer');
    if (roleId == 'buyer') return context.tr('role_buyer');
    if (roleId == 'supplier') return context.tr('role_supplier');
    if (roleId == 'admin') return context.tr('role_admin');
    if (roleId == 'advisor') return context.tr('role_advisor');
    if (roleId == 'investor') return context.tr('role_investor');
    return roleId[0].toUpperCase() + roleId.substring(1);
  }

  String _getRoleDesc(BuildContext context, String roleId, String fallback) {
    final key = 'role_${roleId}_desc';
    final val = context.tr(key);
    return val != key ? val : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final selectedRoleLabel = _getRoleLabel(context, _selectedRoleId);

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
        actions: const [
          SafeArea(
            child: LanguagePickerButton(isTransparent: true),
          ),
          SizedBox(width: 12),
        ],
      ),
      body: Container(
        height: mediaQuery.size.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Dark overlay
            Container(color: AppTheme.primaryGreen.withOpacity(0.5)),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10.0),
                    // Logo/Title branding
                    const Center(
                      child: Hero(
                        tag: 'logo',
                        child: Icon(
                          Icons.agriculture_rounded,
                          size: 56.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      context.tr('join_agrimed'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      context.tr('join_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Administrator Notice Banner (Disallows self-registration as admin)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              color: AppTheme.accentAmber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Administrator Accounts',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Admin accounts cannot be self-registered and are provisioned internally by AgriMed operations. Already an admin? Log in directly.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accentAmber,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: const Text(
                              'Admin Login',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Choice Card Widget
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24.0),
                      child: Container(
                        decoration: AppTheme.glassCardDecoration,
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.tr('select_role'),
                              style: const TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 16.0),

                            // Role Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12.0,
                                    mainAxisSpacing: 12.0,
                                    childAspectRatio: 0.90,
                                  ),
                              itemCount: _roles.length,
                              itemBuilder: (context, index) {
                                final role = _roles[index];
                                final isSelected =
                                    _selectedRoleId == role['id'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedRoleId = role['id'];
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryGreen
                                            : Colors.grey.withOpacity(0.3),
                                        width: isSelected ? 3.0 : 1.2,
                                      ),
                                      boxShadow: [
                                        if (isSelected)
                                          BoxShadow(
                                            color: AppTheme.primaryGreen
                                                .withOpacity(0.35),
                                            blurRadius: 12.0,
                                            offset: const Offset(0, 4),
                                          )
                                        else
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 6.0,
                                            offset: const Offset(0, 2),
                                          ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(13.0),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Full-bleed real-life role photo occupying the entire button
                                          Image.asset(
                                            role['image'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: AppTheme.primaryGreen.withOpacity(0.15),
                                              child: Center(
                                                child: Icon(
                                                  role['icon'],
                                                  color: isSelected
                                                      ? AppTheme.primaryGreen
                                                      : AppTheme.lightText,
                                                  size: 36.0,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Elegant darkening gradient overlay to ensure text readability
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.black.withOpacity(isSelected ? 0.35 : 0.45),
                                                  Colors.black.withOpacity(0.08),
                                                  Colors.black.withOpacity(0.68),
                                                  Colors.black.withOpacity(0.92),
                                                ],
                                                stops: const [0.0, 0.30, 0.65, 1.0],
                                              ),
                                            ),
                                          ),

                                          // Selection emerald overlay tint when chosen
                                          if (isSelected)
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryGreen.withOpacity(0.18),
                                              ),
                                            ),

                                          // Content layer: top indicators & bottom text
                                          Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Top row: Role icon badge & Checkmark
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6.0),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.45),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white.withOpacity(0.35),
                                                          width: 1.0,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        role['icon'],
                                                        color: Colors.white,
                                                        size: 16.0,
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      Container(
                                                        padding: const EdgeInsets.all(4.0),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primaryGreen,
                                                          shape: BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors.white,
                                                            width: 1.5,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withOpacity(0.3),
                                                              blurRadius: 4,
                                                            ),
                                                          ],
                                                        ),
                                                        child: const Icon(
                                                          Icons.check_rounded,
                                                          color: Colors.white,
                                                          size: 14.0,
                                                        ),
                                                      )
                                                    else
                                                      Container(
                                                        width: 22.0,
                                                        height: 22.0,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors.white.withOpacity(0.6),
                                                            width: 1.5,
                                                          ),
                                                          color: Colors.black.withOpacity(0.25),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                // Bottom: Role label & description
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _getRoleLabel(context, role['id']),
                                                      style: const TextStyle(
                                                        fontSize: 15.0,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                            color: Colors.black,
                                                            offset: Offset(0, 1),
                                                            blurRadius: 3,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2.0),
                                                    Text(
                                                      _getRoleDesc(context, role['id'], role['desc']),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        color: Colors.white.withOpacity(0.92),
                                                        height: 1.2,
                                                        shadows: const [
                                                          Shadow(
                                                            color: Colors.black,
                                                            offset: Offset(0, 1),
                                                            blurRadius: 2,
                                                          ),
                                                        ],
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
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Inputs Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24.0),
                      child: Container(
                        decoration: AppTheme.glassCardDecoration,
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Full Name
                              TextFormField(
                                controller: _nameController,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: AppTheme.inputDecoration(
                                  labelText: context.tr('full_name'),
                                  hintText: context.tr('enter_full_name'),
                                  prefixIcon: Icons.person_outline_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),

                              // Email Input
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: AppTheme.inputDecoration(
                                  labelText: context.tr('email_address'),
                                  hintText: 'name@gmail.com or @icloud.com',
                                  prefixIcon: Icons.email_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  final trimmed = value.trim().toLowerCase();
                                  final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                  if (!regex.hasMatch(trimmed)) {
                                    return 'Please enter a valid email address';
                                  }
                                  final isRoleAdmin = _selectedRoleId.trim().toLowerCase() == 'admin' ||
                                      _selectedRoleId.trim().toLowerCase() == 'administrator' ||
                                      trimmed == 'system.admin@agrimedlink.com';
                                  if (!isRoleAdmin && !trimmed.endsWith('@gmail.com') && !trimmed.endsWith('@icloud.com')) {
                                    return 'Email must end with @gmail.com or @icloud.com';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),

                              // Phone Number Input
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: AppTheme.inputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: 'Enter your phone number',
                                  prefixIcon: Icons.phone_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),

                              // Password Input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: AppTheme.inputDecoration(
                                  labelText: context.tr('password'),
                                  hintText: context.tr('enter_password'),
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppTheme.secondaryGreen,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Sign Up Submit button
                    Container(
                      height: 56.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.35),
                            blurRadius: 12.0,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.0),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Role image occupying the whole button background
                            Image.asset(
                              _currentRoleData['image'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                            // Brand gradient overlay for action button feel
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppTheme.primaryGreen.withOpacity(0.88),
                                    AppTheme.secondaryGreen.withOpacity(0.82),
                                  ],
                                ),
                              ),
                            ),
                            // Interactive button surface
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignup,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20.0,
                                      width: 20.0,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Real-life circular image avatar of the selected user role
                                        Container(
                                          width: 36,
                                          height: 36,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              _currentRoleData['image'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Icon(
                                                _currentRoleData['icon'],
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            context.tr('register_as', {'role': selectedRoleLabel}),
                                            style: const TextStyle(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black45,
                                                  offset: Offset(0, 1),
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Link back to Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${context.tr('already_have_account')} ',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: Text(
                            context.tr('sign_in'),
                            style: const TextStyle(
                              color: AppTheme.accentAmber,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              fontSize: 15.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
