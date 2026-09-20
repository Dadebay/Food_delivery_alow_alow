import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import 'auth_provider.dart';

/// Turkmen mobile numbers are 8 digits after the +993 country code.
const int _phoneDigits = 8;

/// Full-bleed artwork behind the sign-in card. Swapping it is a one-line
/// change: drop the new file in `assets/`, list it in `pubspec.yaml`, and
/// point this constant at it. The card below carries every piece of text, so
/// the picture only has to look good — it never has to stay readable.
const String _backgroundAsset = 'assets/onboard.png';

/// Phone + SMS code — no passwords. The name is asked alongside the phone
/// number, once, on sign-up: it's sent as `firstName` on the verify call
/// and only echoed back for a brand-new account, so an existing customer
/// signing back in never sees or overwrites it.
///
/// Always pushed on top of whatever the customer was doing (browsing the
/// menu, building a cart) rather than shown as a gate before anything else —
/// only placing an order actually needs an account. Pops with `true` once
/// signed in, so the caller can resume exactly where it left off; pops with
/// `false`/nothing if the customer backs out instead.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.addListener(_onFieldChanged);
    _phone.addListener(_onFieldChanged);
    _code.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  bool get _phoneValid => _phone.text.length == _phoneDigits;
  bool get _nameValid => _name.text.trim().isNotEmpty;
  bool get _isValidOtpLength =>
      _code.text.length == 4 || _code.text.length == 6;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final s = locale.strings;
    final onCodeStage = auth.stage == AuthStage.code;

    return Scaffold(
      backgroundColor: AppColors.green,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(_backgroundAsset, fit: BoxFit.cover),
          ),
          // Photographs are busy, and text laid straight over one is a
          // coin toss. Everything readable lives on the card below; this
          // gradient only has to carry the picture into the card's edge so
          // the two do not meet on a hard line.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x660B3B2E),
                    Color(0x00000000),
                    Color(0xCC0B3B2E),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
          // The scroll skeleton is deliberately unchanged: with the keyboard
          // up, the name and phone fields together are already taller than a
          // short phone, and this is what keeps them reachable.
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Row(
                            children: [
                              _GlassButton(
                                // At the code stage, back steps back to the phone
                                // field; at the phone stage it closes the prompt
                                // and returns the customer to what they were doing
                                // (still browsing, cart intact).
                                onTap: onCodeStage
                                    ? () => context
                                          .read<AuthProvider>()
                                          .backToPhone()
                                    : () =>
                                          Navigator.of(context).maybePop(false),
                                child: const HugeIcon(
                                  icon: AppIcons.back,
                                  color: AppColors.white,
                                  size: 22,
                                ),
                              ),
                              const Spacer(),
                              _LanguageSwitch(
                                current: s.languageCode,
                                onSelect: (strings) => locale.select(strings),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              child: Image.asset(
                                'assets/only_text_logo.png',
                                height: 72,
                              ),
                            ),
                          ),
                        ),
                        _AuthCard(
                          title: s.loginTitle,
                          subtitle: onCodeStage
                              ? s.smsCodeHint
                              : s.loginSubtitle,
                          children: [
                            if (onCodeStage)
                              _CodeField(
                                controller: _code,
                                label: s.smsCode,
                                errorMessage:
                                    auth.verifyError ??
                                    (auth.codeRejected ? s.codeInvalid : null),
                              )
                            else ...[
                              // Asked once, here, rather than on its own step —
                              // this is the only screen a first-time customer
                              // sees before they are signed in.
                              _NameField(
                                controller: _name,
                                label: s.nameLabel,
                                hint: s.nameHint,
                              ),
                              const SizedBox(height: 16),
                              _PhoneField(
                                controller: _phone,
                                label: s.phoneNumber,
                              ),
                            ],
                            const SizedBox(height: 22),
                            AppButton(
                              label: onCodeStage ? s.verify : s.requestCode,
                              busy: auth.busy,
                              onPressed: onCodeStage
                                  ? (_isValidOtpLength
                                        ? () => _verify(auth)
                                        : null)
                                  : (_phoneValid && _nameValid
                                        ? () => context
                                              .read<AuthProvider>()
                                              .requestCode(
                                                '+993${_phone.text}',
                                                name: _name.text,
                                              )
                                        : null),
                            ),
                            if (!onCodeStage && auth.requestError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                auth.requestError!,
                                textAlign: TextAlign.center,
                                style: AppText.bodyMuted.copyWith(
                                  color: AppColors.red,
                                ),
                              ),
                            ],
                            if (AppConfig.useMockData) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  s.demoHint,
                                  style: AppText.bodyMuted.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verify(AuthProvider auth) async {
    final ok = await auth.verify(_code.text.trim());
    if (!mounted) return;
    if (!ok) {
      _code.clear();
      return;
    }
    // Signed in — hand control back to whoever pushed this screen (the
    // checkout flow resumes placing the order, a direct open just closes).
    Navigator.of(context).maybePop(true);
  }
}

/// Caption above a field instead of a Material floating label — a floating
/// label that snaps to its raised position immediately (both fields
/// autofocus, and the phone field always has a fixed prefix) ends up drawn
/// straddling the border line and reads as ghosted. A plain caption above the
/// box never has that problem.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: AppText.label.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          style: AppText.h2.copyWith(
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.h2.copyWith(
              color: AppColors.textMuted,
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        Container(
          padding: const EdgeInsets.only(left: 18, right: 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Drawn as a plain Text rather than InputDecoration's
              // `prefixText` — that only renders once the field has focus or
              // content, so it flickered in and out; this stays put always.
              Text(
                '+993 ',
                style: AppText.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: AppText.h2.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    hintText: '62 99 03 44',
                    // Without an explicit style the hint inherits the same dark input
                    // colour and reads as if a number were already typed.
                    hintStyle: AppText.h2.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 20,
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_phoneDigits),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.label,
    required this.errorMessage,
  });

  final TextEditingController controller;
  final String label;

  /// `null` when the last attempt hasn't failed. Shown as real error text, not
  /// just a border colour — the field is still focused (keyboard still up)
  /// right after the customer taps "Войти", and a focused field ignores
  /// `enabledBorder`, so a border-only signal would go unseen.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: AppText.h1.copyWith(
            color: AppColors.textPrimary,
            fontSize: 30,
            letterSpacing: 14,
          ),
          decoration: InputDecoration(
            errorText: errorMessage,
            errorMaxLines: 2,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.red, width: 1.6),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.red, width: 1.6),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
      ],
    );
  }
}

class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.current, required this.onSelect});

  final String current;
  final void Function(AppStrings strings) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final strings in LocaleProvider.supported)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => onSelect(strings),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: strings.languageCode == current
                      ? AppColors.orange
                      : AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  strings.languageCode.toUpperCase(),
                  style: AppText.chip.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The sheet every readable thing sits on.
///
/// Before this the fields and copy floated straight on the artwork, which
/// works only as long as nobody changes the picture. A solid card makes the
/// background a free choice: the only contrast that matters is between the
/// card and its own contents.
class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.h1.copyWith(
              color: AppColors.textPrimary,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }
}

/// Round control that stays legible wherever the artwork happens to be light.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x33000000),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(11), child: child),
      ),
    );
  }
}
