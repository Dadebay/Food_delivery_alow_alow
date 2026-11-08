part of 'checkout_screen.dart';

/// Shown instead of silently failing when a signed-out customer taps place
/// order — the cart, address, and totals below all render fine without an
/// account, so this is the first point that actually needs one.
class _SignInRequiredDialog extends StatelessWidget {
  const _SignInRequiredDialog();

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const _SignInRequiredDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: AppIcons.user,
                color: AppColors.onBrand,
                size: 26,
              ),
            ),
            const SizedBox(height: 18),
            Text(s.loginTitle, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              s.signInPromptCheckout,
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: s.cancel,
                    height: 48,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: s.signIn,
                    height: 48,
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Celebratory confirmation shown the moment an order goes through — closes
/// itself after a beat so it reads as a status flash rather than a dialog
/// the customer has to dismiss, but stays tappable for anyone who doesn't
/// want to wait.
class _OrderAcceptedDialog extends StatefulWidget {
  const _OrderAcceptedDialog();

  @override
  State<_OrderAcceptedDialog> createState() => _OrderAcceptedDialogState();
}

class _OrderAcceptedDialogState extends State<_OrderAcceptedDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 370),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 194,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.brand, AppColors.brandLight],
                          ),
                        ),
                        child: SizedBox.expand(),
                      ),
                      Positioned(
                        right: -28,
                        top: -44,
                        child: Container(
                          width: 154,
                          height: 154,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/create_order.png',
                          height: 165,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        bottom: 14,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.onBrand,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.orderPlacedTitle,
                        style: AppText.h2.copyWith(fontSize: 23),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        s.orderPlacedHint,
                        style: AppText.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          color: AppColors.brand,
                          backgroundColor: AppColors.cream,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
