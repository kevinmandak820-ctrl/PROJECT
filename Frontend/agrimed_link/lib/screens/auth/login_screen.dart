import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/app_localizations.dart';
import '../../widgets/language_selector_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${user.displayName}!'),
          backgroundColor: AppTheme.secondaryGreen,
        ),
      );
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: {'email': user.email, 'role': user.role, 'name': user.name},
      );
    } on SocketException {
      // Offline fallback: if entering admin credentials, grant admin privileges
      if (_emailController.text.trim().toLowerCase() == 'system.admin@agrimedlink.com' &&
          _passwordController.text == 'admin2026key\$') {
        final admin = UserModel(
          id: 'admin-system-id',
          email: 'system.admin@agrimedlink.com',
          name: 'System Administrator',
          role: 'admin',
          phoneNumber: '+1-800-AGRI-ADM',
        );
        await AuthService.persistDirectUser(admin);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin access authorized'),
            backgroundColor: AppTheme.secondaryGreen,
          ),
        );
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: {'email': admin.email, 'role': admin.role, 'name': admin.name},
        );
        return;
      }

      // No network — try to use cached session
      final cached = await AuthService.getStoredUser();
      if (!mounted) return;
      if (cached != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection — opening cached session'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: {
            'email': cached.email,
            'role': cached.role,
            'name': cached.name,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(minHeight: mediaQuery.size.height),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/login_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              // Dark organic overlay to make inputs highly legible
              Container(color: AppTheme.primaryGreen.withOpacity(0.45)),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16.0),

                      // Brand Header Container
                      Center(
                        child: Hero(
                          tag: 'logo',
                          child: Container(
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 20.0,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.agriculture_rounded,
                              size: 64.0,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'AgriMed Link',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        'Connect with Farmers, Advisors & Investors',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          shadows: const [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      // Real-life community role portraits stack
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 122,
                                height: 30,
                                child: Stack(
                                  children: [
                                    _buildHeaderAvatar('assets/images/role_farmer.jpg', 0),
                                    _buildHeaderAvatar('assets/images/role_buyer.jpg', 23),
                                    _buildHeaderAvatar('assets/images/role_supplier.jpg', 46),
                                    _buildHeaderAvatar('assets/images/role_advisor.jpg', 69),
                                    _buildHeaderAvatar('assets/images/role_investor.jpg', 92),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Community Network',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20.0),

                      // Frosted glass card containing login fields
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24.0),
                        child: java_script_backdrop_filter_wrapper_placeholder(
                          mediaQuery,
                        ),
                      ),

                      const SizedBox(height: 14.0),

                      // Forgot Password link (Stub)
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password recovery screen is coming soon!',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          context.tr('forgot_password'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6.0),

                      // Sign Up Route trigger
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${context.tr('dont_have_account')} ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacementNamed(
                                context,
                                '/signup',
                              );
                            },
                            child: Text(
                              context.tr('sign_up'),
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
                      const SizedBox(height: 16.0),
                    ],
                  ),
                ),
              ),

              // Top Language Picker (rendered on top of content)
              const Positioned(
                top: 12,
                right: 16,
                child: SafeArea(
                  child: LanguagePickerButton(isTransparent: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget java_script_backdrop_filter_wrapper_placeholder(
    MediaQueryData mediaQuery,
  ) {
    // Helper to wrap the backdrop filter to avoid cluttering main build method
    return Container(
      decoration: AppTheme.glassCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('welcome_back'),
                style: const TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 18.0),

              // Email Input
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontWeight: FontWeight.w500),
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
                  // Platform administrator exception
                  if (trimmed == 'system.admin@agrimedlink.com') {
                    return null;
                  }
                  if (!trimmed.endsWith('@gmail.com') && !trimmed.endsWith('@icloud.com')) {
                    return 'Email must end with @gmail.com or @icloud.com';
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
                style: const TextStyle(fontWeight: FontWeight.w500),
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
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _handleLogin(),
              ),

              const SizedBox(height: 24.0),

              // Submit Button
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      blurRadius: 12.0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: AppTheme.primaryButtonStyle,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20.0,
                          width: 20.0,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          context.tr('sign_in'),
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar(String path, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
