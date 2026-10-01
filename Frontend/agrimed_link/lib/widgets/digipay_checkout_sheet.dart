import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/payment_service.dart';

enum PaymentStep {
  form,
  initiating,
  waitingApproval,
  success,
  failed,
}

class DigiPayCheckoutSheet extends StatefulWidget {
  final String itemName;
  final double unitPriceUSD;
  final String? imageUrl;
  final String? cropId;
  final String? orderId;
  final List<String>? bookingIds;
  final VoidCallback? onPaymentSuccess;

  const DigiPayCheckoutSheet({
    super.key,
    required this.itemName,
    required this.unitPriceUSD,
    this.imageUrl,
    this.cropId,
    this.orderId,
    this.bookingIds,
    this.onPaymentSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String itemName,
    required double unitPriceUSD,
    String? imageUrl,
    String? cropId,
    String? orderId,
    List<String>? bookingIds,
    VoidCallback? onPaymentSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DigiPayCheckoutSheet(
        itemName: itemName,
        unitPriceUSD: unitPriceUSD,
        imageUrl: imageUrl,
        cropId: cropId,
        orderId: orderId,
        bookingIds: bookingIds,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  static bool enableAnimations = true;
  static bool mockPendingInTest = false;

  @override
  State<DigiPayCheckoutSheet> createState() => _DigiPayCheckoutSheetState();
}

class _DigiPayCheckoutSheetState extends State<DigiPayCheckoutSheet>
    with SingleTickerProviderStateMixin {
  PaymentStep _step = PaymentStep.form;
  int _quantity = 1;
  String _selectedProvider = 'MTN'; // 'MTN' or 'Orange'
  final TextEditingController _phoneController = TextEditingController(text: '678808831');
  final TextEditingController _emailController = TextEditingController();

  String? _transactionId;
  String? _freemopayRef;
  String? _errorMessage;
  String? _detectedOperator;
  Map<String, dynamic>? _instructions;
  bool _isCheckingManual = false;
  int _pollAttempt = 0;
  StreamSubscription<Map<String, dynamic>>? _pollSub;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (DigiPayCheckoutSheet.enableAnimations) {
      _pulseController.repeat(reverse: true);
    }
    _phoneController.addListener(_onPhoneChanged);
    _onPhoneChanged();
  }

  void _onPhoneChanged() {
    final text = _phoneController.text.trim();
    if (text.isEmpty) {
      setState(() => _detectedOperator = null);
      return;
    }
    final op = PaymentService.detectOperator(text);
    if (op == 'MTN' || op == 'Orange') {
      if (_detectedOperator != op || _selectedProvider != op) {
        setState(() {
          _detectedOperator = op;
          _selectedProvider = op;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollSub?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  double get _totalPriceUSD => widget.unitPriceUSD * _quantity;
  int get _totalPriceFCFA => (_totalPriceUSD * 605).round();

  Future<void> _startPayment() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your mobile money number.');
      return;
    }

    setState(() {
      _step = PaymentStep.initiating;
      _errorMessage = null;
    });

    try {
      final res = await PaymentService.instance.initiatePayment(
        amount: _totalPriceFCFA.toDouble(),
        mobileNumber: rawPhone,
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        cropId: widget.cropId,
        orderId: widget.orderId,
        bookingIds: widget.bookingIds,
        metadata: {
          'itemName': widget.itemName,
          'quantity': _quantity,
          'selectedProvider': _selectedProvider,
          'priceUSD': _totalPriceUSD,
          if (DigiPayCheckoutSheet.mockPendingInTest) 'mockPending': true,
        },
      );

      final data = res['data'] as Map<String, dynamic>? ?? {};
      final txnId = data['transactionId']?.toString();

      if (txnId == null || txnId.isEmpty) {
        throw Exception('No transaction ID returned from DigiPay.');
      }

      final returnedProvider = (data['provider'] ?? '').toString();
      if (returnedProvider.toLowerCase() == 'orange') {
        _selectedProvider = 'Orange';
      } else if (returnedProvider.toLowerCase() == 'mtn') {
        _selectedProvider = 'MTN';
      }

      setState(() {
        _transactionId = txnId;
        _freemopayRef = data['freemopayReference']?.toString();
        _instructions = data['instructions'] as Map<String, dynamic>?;
        _step = PaymentStep.waitingApproval;
      });

      _listenToPoll(txnId);
    } catch (e) {
      setState(() {
        _step = PaymentStep.failed;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  void _listenToPoll(String txnId) {
    _pollSub?.cancel();
    _pollSub = PaymentService.instance.pollPaymentStatus(txnId).listen(
      (statusData) {
        if (!mounted) return;

        final currentStatus = (statusData['status'] ?? '').toString().toLowerCase();
        final attempt = (statusData['attempt'] as num?)?.toInt() ?? 0;

        if (statusData['instructions'] != null && _instructions == null) {
          _instructions = statusData['instructions'] as Map<String, dynamic>?;
        }

        setState(() {
          _pollAttempt = attempt;
        });

        if (currentStatus == 'success' || statusData['isSuccess'] == true) {
          _pollSub?.cancel();
          setState(() {
            _step = PaymentStep.success;
          });
          widget.onPaymentSuccess?.call();
        } else if (currentStatus == 'failed' || currentStatus == 'refunded') {
          _pollSub?.cancel();
          final failMsg = statusData['failureMessage']?.toString() ??
              statusData['failureReason']?.toString() ??
              (_selectedProvider == 'Orange'
                  ? 'Payment was not approved. Ensure you dial #150# and have sufficient Orange Money balance.'
                  : 'Payment was not approved on your phone. Please verify your MoMo balance and try again.');
          setState(() {
            _step = PaymentStep.failed;
            _errorMessage = failMsg;
          });
        } else if (statusData['isTimeout'] == true) {
          _pollSub?.cancel();
          final isOrange = _selectedProvider == 'Orange';
          setState(() {
            _step = PaymentStep.failed;
            _errorMessage = statusData['message']?.toString() ??
                (isOrange
                    ? 'Payment authorization timed out. Orange Money requires dialing #150# within 5 minutes to approve.'
                    : 'Payment authorization timed out. If prompt does not appear, dial *126# immediately after initiating.');
          });
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _errorMessage = err.toString();
        });
      },
    );
  }

  Future<void> _checkStatusNow() async {
    if (_transactionId == null || _isCheckingManual) return;
    setState(() => _isCheckingManual = true);

    try {
      final res = await PaymentService.instance.checkStatus(_transactionId!);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final currentStatus = (data['status'] ?? '').toString().toLowerCase();

      if (currentStatus == 'success' || data['isSuccess'] == true) {
        _pollSub?.cancel();
        setState(() => _step = PaymentStep.success);
        widget.onPaymentSuccess?.call();
      } else if (currentStatus == 'failed' || currentStatus == 'refunded') {
        _pollSub?.cancel();
        final failMsg = data['failureMessage']?.toString() ??
            data['failureReason']?.toString() ??
            'Payment was declined or cancelled on your phone.';
        setState(() {
          _step = PaymentStep.failed;
          _errorMessage = failMsg;
        });
      } else {
        if (mounted) {
          final isOrange = _selectedProvider == 'Orange';
          final code = isOrange ? '#150#' : '*126#';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isOrange
                    ? 'Payment is still awaiting approval. Please dial #150# on your Orange phone to confirm.'
                    : 'Payment is still awaiting approval. Please approve the MoMo prompt (or dial *126#).',
              ),
              backgroundColor: isOrange ? const Color(0xFFFF6600) : Colors.black87,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status check: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingManual = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label ($text) copied to clipboard! Paste it into your Phone dialer.'),
        backgroundColor: AppTheme.primaryGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Drag handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'DigiPay Mobile Money',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '🇨🇲 XAF',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Instant USSD Push • MTN & Orange Money',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Step Content
            if (_step == PaymentStep.form) _buildFormStep(),
            if (_step == PaymentStep.initiating) _buildInitiatingStep(),
            if (_step == PaymentStep.waitingApproval) _buildWaitingStep(),
            if (_step == PaymentStep.success) _buildSuccessStep(),
            if (_step == PaymentStep.failed) _buildFailedStep(),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFormStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Product Summary Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppTheme.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(widget.unitPriceUSD * 605).round()} FCFA / unit (\$${widget.unitPriceUSD.toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.lightText,
                      ),
                    ),
                  ],
                ),
              ),
              // Quantity controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    color: AppTheme.secondaryGreen,
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    color: AppTheme.primaryGreen,
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Operator selector (MTN / Orange)
        const Text(
          'Select Mobile Operator',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildOperatorCard(
                name: 'MTN Mobile Money',
                code: 'MTN',
                color: const Color(0xFFFFCC00),
                textColor: Colors.black87,
                icon: Icons.phone_android_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOperatorCard(
                name: 'Orange Money',
                code: 'Orange',
                color: const Color(0xFFFF6600),
                textColor: Colors.white,
                icon: Icons.network_cell_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Mobile Number Input
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mobile Money Phone Number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            if (_detectedOperator != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _detectedOperator == 'Orange'
                      ? const Color(0xFFFF6600).withOpacity(0.12)
                      : const Color(0xFFFFCC00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$_detectedOperator Detected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _detectedOperator == 'Orange' ? const Color(0xFFFF6600) : Colors.black87,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            prefixIconConstraints: const BoxConstraints(minWidth: 70, minHeight: 0),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🇨🇲', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 4),
                  Text(
                    '+237',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
            ),
            suffixIcon: _phoneController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: AppTheme.lightText),
                    onPressed: () {
                      _phoneController.clear();
                      setState(() {});
                    },
                  )
                : null,
            hintText: '6xx xx xx xx',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Optional Email Input
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.secondaryGreen),
            hintText: 'Email for payment receipt (optional)',
            hintStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.15)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),

        // Total & Submit Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_totalPriceFCFA FCFA',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  Text(
                    '(\$${_totalPriceUSD.toStringAsFixed(2)} USD)',
                    style: const TextStyle(fontSize: 11, color: AppTheme.lightText),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _startPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pay $_totalPriceFCFA FCFA with $_selectedProvider',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorCard({
    required String name,
    required String code,
    required Color color,
    required Color textColor,
    required IconData icon,
  }) {
    final isSelected = _selectedProvider == code;

    return InkWell(
      onTap: () => setState(() => _selectedProvider = code),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.black.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textColor, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                code,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.black87 : AppTheme.lightText,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInitiatingStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 20),
          const Text(
            'Contacting DigiPay & Mobile Network...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Preparing push notification for +237 ${_phoneController.text.trim()}',
            style: const TextStyle(fontSize: 12, color: AppTheme.lightText),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingStep() {
    final isOrange = _selectedProvider.toLowerCase().contains('orange');
    final opName = isOrange ? 'Orange Money' : 'MTN Mobile Money';
    final dialCode = isOrange ? '#150#' : '*126#';
    final opColor = isOrange ? const Color(0xFFFF6600) : const Color(0xFFFFCC00);
    final opTextColor = isOrange ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Animated Radar/Pulsing Indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.10),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: opColor.withOpacity(0.18),
                    border: Border.all(
                      color: opColor.withOpacity(0.5 + _pulseController.value * 0.5),
                      width: 2.5,
                    ),
                  ),
                  child: Icon(
                    isOrange ? Icons.dialpad_rounded : Icons.phonelink_ring_rounded,
                    color: isOrange ? const Color(0xFFFF6600) : Colors.amber.shade900,
                    size: 34,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Provider Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: opColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              opName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: opTextColor,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            isOrange ? 'Validation Required on Your Phone' : 'MoMo Authorization Required',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Amount: $_totalPriceFCFA FCFA  •  Phone: +237 ${_phoneController.text.trim()}',
            style: const TextStyle(fontSize: 12, color: AppTheme.lightText, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          // Detailed Operator Instructions Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isOrange ? const Color(0xFFFFF3E0) : const Color(0xFFFFFDE7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOrange ? const Color(0xFFFFB74D) : const Color(0xFFFFEE58),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOrange ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      color: isOrange ? const Color(0xFFE65100) : Colors.amber.shade900,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOrange
                            ? 'Orange Money requires manual dial validation'
                            : 'Approve prompt on your MTN screen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOrange ? const Color(0xFFE65100) : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isOrange
                      ? 'Orange Money Cameroon does not send automatic popups. You must dial #150# to authorize the pending debit.'
                      : 'Please enter your MoMo PIN on the prompt. If the prompt does not appear within 10 seconds, dial *126# to approve.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOrange ? Colors.brown.shade900 : Colors.brown.shade800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Dial Code Banner with Copy Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.dialer_sip_rounded, size: 18, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Dial: ',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        dialCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: AppTheme.darkText,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _copyToClipboard(dialCode, opName),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 12, color: AppTheme.primaryGreen),
                              SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Step-by-step numbered guide
                _buildInstructionStep(
                  '1',
                  isOrange ? 'Open your phone dialer app' : 'Enter your MoMo PIN on the popup',
                ),
                const SizedBox(height: 4),
                _buildInstructionStep(
                  '2',
                  isOrange ? 'Dial $dialCode and press Call' : 'If prompt didn\'t show: dial $dialCode',
                ),
                const SizedBox(height: 4),
                _buildInstructionStep(
                  '3',
                  isOrange ? 'Select option 4 or "Validations"' : 'Select "Pending Approvals"',
                ),
                const SizedBox(height: 4),
                _buildInstructionStep(
                  '4',
                  'Enter your secret PIN to authorize the payment',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Manual Refresh Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCheckingManual ? null : _checkStatusNow,
              icon: _isCheckingManual
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                _isCheckingManual ? 'Verifying status...' : 'I Have Approved — Check Status Now',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Auto Polling indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.secondaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-checking network confirmation... (Check #$_pollAttempt)',
                style: const TextStyle(fontSize: 11, color: AppTheme.lightText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ref: ${_transactionId ?? ""}',
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: AppTheme.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String stepNumber, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.darkText),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppTheme.darkText),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.lightGreen,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.primaryGreen,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment Successful!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your payment of $_totalPriceFCFA FCFA has been verified.',
            style: const TextStyle(fontSize: 13, color: AppTheme.lightText),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Item', '${widget.itemName} (x$_quantity)'),
                const Divider(height: 14),
                _buildReceiptRow('Paid Amount', '$_totalPriceFCFA FCFA'),
                const Divider(height: 14),
                _buildReceiptRow('Operator', '$_selectedProvider Mobile Money'),
                const Divider(height: 14),
                _buildReceiptRow('Transaction ID', _transactionId ?? 'N/A', isMonospace: true),
                if (_freemopayRef != null) ...[
                  const Divider(height: 14),
                  _buildReceiptRow('Network Ref', _freemopayRef!, isMonospace: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Done & View Receipt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedStep() {
    final isOrange = _selectedProvider.toLowerCase().contains('orange');
    final dialCode = isOrange ? '#150#' : '*126#';
    final err = (_errorMessage ?? '').toLowerCase();
    final isBalanceIssue = err.contains('balance') || err.contains('insufficient');
    final isTimeoutIssue = err.contains('time') || err.contains('timeout');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.errorRed.withOpacity(0.12),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorRed,
              size: 42,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Payment Not Completed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _errorMessage ?? 'The payment could not be processed.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.darkText, height: 1.35),
            ),
          ),
          const SizedBox(height: 14),

          // Contextual Troubleshooting Card
          if (isBalanceIssue)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ensure your $dialCode wallet has enough balance to cover $_totalPriceFCFA FCFA plus network withdrawal fees, then try again.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.3),
                    ),
                  ),
                ],
              ),
            )
          else if (isTimeoutIssue)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFF7B1FA2), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isOrange
                          ? 'Remember: Orange Money never displays an automatic pop-up. Dial #150# immediately after tapping Pay.'
                          : 'If the MoMo authorization pop-up doesn\'t appear, dial *126# -> Pending Approvals right away.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF4A148C), height: 1.3),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, color: AppTheme.lightText, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For $_selectedProvider, ensure the mobile line is registered and active for electronic payments.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.lightText),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _step = PaymentStep.form;
                      _errorMessage = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.lightText,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
              color: AppTheme.darkText,
            ),
          ),
        ),
      ],
    );
  }
}
