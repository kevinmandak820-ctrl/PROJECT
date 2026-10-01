import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/app_localizations.dart';
import '../theme/app_theme.dart';

/// Shows an attractive modal bottom sheet allowing the user to select
/// one of the 4 supported languages.
Future<void> showLanguageSelector(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (modalContext) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modalContext.tr('select_language'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AgriMed Link (${LocalizationService.supportedLanguages.length} Languages)',
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
                  onPressed: () => Navigator.pop(modalContext),
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // List of the 4 supported languages
            ...LocalizationService.supportedLanguages.map((lang) {
              final isSelected =
                  LocalizationService.instance.currentLocale.value.languageCode ==
                      lang.code;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.lightGreen.withValues(alpha: 0.7)
                      : Colors.grey.shade50,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(modalContext);
                    LocalizationService.instance.setLanguage(lang.code);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // Flag emoji
                        Text(
                          lang.flag,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 14),

                        // Language Names
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.nativeName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.primaryGreen
                                      : AppTheme.darkText,
                                ),
                              ),
                              Text(
                                lang.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Checkmark indicator
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.primaryGreen,
                            size: 22,
                          )
                        else
                          Icon(
                            Icons.radio_button_unchecked_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

/// An elegant button displaying the active language flag and code,
/// opening the language switcher modal on tap.
class LanguagePickerButton extends StatelessWidget {
  final bool isTransparent;
  final Color? textColor;

  const LanguagePickerButton({
    super.key,
    this.isTransparent = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocalizationService.instance.currentLocale,
      builder: (context, locale, _) {
        final currentLang = LocalizationService.instance.currentLanguage;

        return Tooltip(
          message: context.tr('select_language'),
          child: InkWell(
            onTap: () => showLanguageSelector(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isTransparent
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isTransparent
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.grey.shade300,
                ),
                boxShadow: isTransparent
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLang.flag,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    currentLang.code.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor ??
                          (isTransparent
                              ? Colors.white
                              : AppTheme.darkText),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 16,
                    color: textColor ??
                        (isTransparent
                            ? Colors.white70
                            : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
