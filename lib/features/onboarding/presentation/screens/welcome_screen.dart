import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// First-launch flow: three short slides, then "What should we call you?".
/// Everything is saved on the phone; no account is needed.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, required this.onDone});

  /// Called after the profile is saved.
  final VoidCallback onDone;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    Icons.menu_book_rounded,
    'Your khata, in your pocket',
    'Log who owes what in a few taps. Private 1-on-1 khatas stay on this phone.',
  ),
  _Slide(
    Icons.groups_rounded,
    'Split bills, zero mental math',
    'Hostel mess, dhaba runs, trips. Dolo splits it and works out who pays whom.',
  ),
  _Slide(
    Icons.receipt_long_rounded,
    'Settle up on WhatsApp',
    'Send a clean receipt or a friendly reminder straight to WhatsApp.',
  ),
];

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pager = PageController();
  int _page = 0;

  // Last page (index == _slides.length) is the profile form.
  int get _lastPage => _slides.length;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _raast = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pager.dispose();
    _name.dispose();
    _phone.dispose();
    _raast.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _pager.jumpToPage(page);
    } else {
      _pager.animateToPage(
        page,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    await ref.read(userProfileProvider.notifier).updateProfile(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          raastId: _raast.text.trim(),
        );
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: Skip (slides only)
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerRight,
                child: _page < _lastPage
                    ? TextButton(
                        onPressed: () => _goTo(_lastPage),
                        child: const Text('Skip'),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                onPageChanged: (p) {
                  FocusScope.of(context).unfocus();
                  setState(() => _page = p);
                },
                children: [
                  for (final s in _slides) _SlideView(slide: s),
                  _ProfileForm(
                    formKey: _formKey,
                    name: _name,
                    phone: _phone,
                    raast: _raast,
                    onSubmit: _save,
                  ),
                ],
              ),
            ),
            _Dots(count: _slides.length + 1, index: _page),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_page < _lastPage) {
                            _goTo(_page + 1);
                          } else {
                            _save();
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _page < _slides.length - 1
                              ? 'Next'
                              : _page == _slides.length - 1
                                  ? 'Get started'
                                  : 'Start using Dolo',
                          style: AppTypography.cardTitle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.cockpitGradientStart,
                  AppColors.cockpitGradientEnd,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mint.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 84, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.screenTitle.copyWith(
              color: primary,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: AppTypography.bodySemiBold.copyWith(
              color: muted,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.formKey,
    required this.name,
    required this.phone,
    required this.raast,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController raast;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final muted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'What should we call you?',
              style: AppTypography.screenTitle.copyWith(
                color: primary,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Friends see this name on receipts and reminders. '
              'It stays on this phone; no account needed.',
              style: AppTypography.caption.copyWith(
                color: muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _Field(
              key: const ValueKey('onboarding_name'),
              controller: name,
              label: 'Your name',
              hint: 'Enter your name',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your name so friends know who sent it'
                  : null,
            ),
            const SizedBox(height: 14),
            _Field(
              key: const ValueKey('onboarding_phone'),
              controller: phone,
              label: 'WhatsApp number (optional)',
              hint: '0300 1234567',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.isEmpty) return null;
                return digits.length >= 10 && digits.length <= 13
                    ? null
                    : 'Use a number like 0300 1234567';
              },
            ),
            const SizedBox(height: 14),
            _Field(
              key: const ValueKey('onboarding_raast'),
              controller: raast,
              label: 'Raast ID or IBAN (optional)',
              hint: 'Shown on your Pay Me QR',
              icon: Icons.qr_code_2_rounded,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You can change these any time in Profile.',
                    style: AppTypography.caption.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: fill,
        enabledBorder: outline(border),
        focusedBorder: outline(AppColors.mint, 2),
        errorBorder: outline(AppColors.rose),
        focusedErrorBorder: outline(AppColors.rose, 2),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final off = isDark ? AppColors.darkPillInactive : AppColors.lightBorder;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.mint : off,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
