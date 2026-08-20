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
          // The flame/smoke artwork bakes in its own dark-green base, so it
          // doubles as the screen's background rather than sitting on top of
          // a separately-coloured one.
          Positioned.fill(
            child: Image.asset('assets/onboard.png', fit: BoxFit.cover),
          ),
          // Scrollable rather than a bare Column — the phone stage grew a name
          // field, and with the keyboard up behind it that's enough content to
          // overflow a short phone. The LayoutBuilder/ConstrainedBox pairing
          // keeps the Spacers below working exactly as before whenever
          // everything still fits.
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Row(
                            children: [
                              IconButton(
                                // At the code stage, back steps back to the phone field;
                                // at the phone stage, it closes the sign-in prompt
                                // entirely and returns the customer to what they were
                                // doing (e.g. still browsing, cart intact).
                                onPressed: onCodeStage
                                    ? () => context
                                          .read<AuthProvider>()
                                          .backToPhone()
                                    : () =>
                                          Navigator.of(context).maybePop(false),
                                icon: const HugeIcon(
                                  icon: AppIcons.back,
                                  color: AppColors.white,
                                  size: 24,
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
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/only_text_logo.png',
                                height: 80,
                              ),
                              const SizedBox(height: 28),
                              Text(
                                s.loginTitle,
                                style: AppText.h1.copyWith(fontSize: 30),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                onCodeStage ? s.smsCodeHint : s.loginSubtitle,
                                style: AppText.body.copyWith(
                                  color: AppColors.greenMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: onCodeStage
                              ? _CodeField(
                                  controller: _code,
                                  label: s.smsCode,
                                  errorMessage:
                                      auth.verifyError ??
                                      (auth.codeRejected
                                          ? s.codeInvalid
                                          : null),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Asked once, here, rather than on its own step —
                                    // this is the only screen a first-time customer
                                    // sees before they're signed in.
                                    _NameField(
                                      controller: _name,
                                      label: s.nameLabel,
                                      hint: s.nameHint,
                                    ),
                                    const SizedBox(height: 18),
                                    _PhoneField(
                                      controller: _phone,
                                      label: s.phoneNumber,
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: AppButton(
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
                        ),
                        if (!onCodeStage && auth.requestError != null) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              auth.requestError!,
                              textAlign: TextAlign.center,
                              style: AppText.bodyMuted.copyWith(
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                        if (AppConfig.useMockData) ...[
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              s.demoHint,
                              style: AppText.bodyMuted.copyWith(
                                color: AppColors.greenMuted,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(flex: 2),
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
        style: AppText.label.copyWith(color: AppColors.greenMuted),
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
