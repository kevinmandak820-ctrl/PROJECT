import 'package:flutter/material.dart';
import '../services/offline_manager.dart';

/// Displays an amber offline banner whenever [OfflineManager.instance.isOffline]
/// is true. Wraps a child widget so it can be composed into any screen's body.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineManager.instance.isOffline,
      builder: (context, offline, _) {
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              height: offline ? 44.0 : 0.0,
              color: const Color(0xFFF59E0B),
              child: offline
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 18.0,
                        ),
                        SizedBox(width: 8.0),
                        Text(
                          "You're offline — showing cached data",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.0,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
