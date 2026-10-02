import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Modal dialog allowing users, admins, or QA testers to inspect,
/// test, and dynamically switch the backend server URL at runtime.
class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ServerSettingsDialog(),
    );
  }

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late final TextEditingController _urlController;
  bool _isTesting = false;
  bool? _testSuccess;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _statusMessage = 'Pinging backend health endpoint...';
    });

    final success = await ApiService.testConnection(_urlController.text);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testSuccess = success;
      _statusMessage = success
          ? 'Live & reachable (HTTP 200 OK)'
          : 'Failed to connect. Check internet & server status.';
    });
  }

  Future<void> _applyUrl() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;

    await ApiService.setCustomBaseUrl(newUrl);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Server URL updated to: ${ApiService.baseUrl}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.secondaryGreen,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _resetToDefault() async {
    await ApiService.resetBaseUrl();
    setState(() {
      _urlController.text = ApiService.baseUrl;
      _testSuccess = null;
      _statusMessage = 'Reset to default URL';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E281F).withOpacity(0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.secondaryGreen.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.cloud_sync_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Server Configuration',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Connect to Deployed Backend',
                              style: TextStyle(
                                color: Color(0xFFB0BEC5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Quick presets
                  const Text(
                    'QUICK PRESETS',
                    style: TextStyle(
                      color: AppTheme.accentAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip(
                        label: '🚀 Railway Cloud',
                        url: 'https://project-production.up.railway.app/api',
                      ),
                      _buildPresetChip(
                        label: '📱 Android (10.0.2.2)',
                        url: 'http://10.0.2.2:3000/api',
                      ),
                      _buildPresetChip(
                        label: '💻 Localhost (3000)',
                        url: 'http://localhost:3000/api',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Backend URL Input
                  const Text(
                    'BACKEND API URL',
                    style: TextStyle(
                      color: AppTheme.accentAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _urlController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.35),
                      hintText: 'https://your-service.up.railway.app/api',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: const Icon(Icons.link, color: AppTheme.secondaryGreen),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.secondaryGreen, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Connection status feedback
                  if (_statusMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _testSuccess == true
                            ? AppTheme.secondaryGreen.withOpacity(0.2)
                            : (_testSuccess == false
                                ? Colors.red.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _testSuccess == true
                              ? AppTheme.secondaryGreen
                              : (_testSuccess == false ? Colors.redAccent : Colors.blueAccent),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isTesting)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          else
                            Icon(
                              _testSuccess == true ? Icons.check_circle : Icons.error_outline,
                              color: _testSuccess == true ? Colors.greenAccent : Colors.redAccent,
                              size: 16,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Action Buttons
                  Row(
                    children: [
                      // Test Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_ping, size: 16),
                          label: const Text('Test Ping'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Apply Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _applyUrl,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Save & Apply'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Reset Link
                  Center(
                    child: TextButton(
                      onPressed: _resetToDefault,
                      child: Text(
                        'Reset to Default (${ApiService.defaultBaseUrl})',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          decoration: TextDecoration.underline,
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
    );
  }

  Widget _buildPresetChip({required String label, required String url}) {
    final isSelected = _urlController.text.trim() == url;
    return InkWell(
      onTap: () {
        setState(() {
          _urlController.text = url;
          _testSuccess = null;
          _statusMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondaryGreen.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.secondaryGreen : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
