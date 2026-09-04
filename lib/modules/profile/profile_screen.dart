import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/contact_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../catalog/catalog_provider.dart';
import '../favorites/favorites_screen.dart';
import '../checkout/address_provider.dart';
import 'saved_addresses_screen.dart';
import 'widgets/flame_avatar_video.dart';

/// The customer's own screen — identity, addresses, promo codes, settings,
/// support, and sign-in/out. There's no name field behind the phone-only
/// auth yet (proposal slide 5 doesn't collect one), so the identity card's
/// name and order count are [MockData] placeholders, not real account data.
///
/// Orders and payment method aren't duplicated here — Orders already has its
/// own bottom-nav tab, and there's only cash payment for now, so there's
/// nothing to configure yet.
///
/// Everything under "Аккаунт" (saved addresses, promo codes) is presented
/// with mock data for now — there is no backend for any of it yet, but the
/// screen the customer sees is finished and testable ahead of that.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final locale = context.read<LocaleProvider>();
    final auth = context.watch<AuthProvider>();
    final favorites = context.watch<CatalogProvider>().favorites.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(s.profile),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              tooltip: s.support,
              onPressed: () => _callSupport(context),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.white.withValues(alpha: 0.14),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.greenMuted),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
              ),
              icon: const HugeIcon(
                icon: AppIcons.call,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (auth.isSignedIn)
            _IdentityCard(
              name: auth.displayName,
              phone: auth.phone,
              avatarPath: auth.avatarPath,
              busy: auth.profileBusy,
              onChangePhoto: () => _pickAvatar(context, s),
              onEditName: () => _editName(context, s, auth.storedName),
            )
          else
            _SignInPrompt(hint: s.signInPromptProfile, label: s.signIn),

          const SizedBox(height: 20),
          _Tile(
            icon: AppIcons.favorite,
            title: s.navFavorites,
            subtitle: '$favorites',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          if (auth.isSignedIn)
            _Tile(
              icon: AppIcons.location,
              title: s.savedAddresses,
              subtitle: context.watch<AddressProvider>().saved.isEmpty
                  ? null
                  : '${context.watch<AddressProvider>().saved.length}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
              ),
            ),

          _Tile(
            icon: AppIcons.language,
            title: s.language,
            subtitle: s.languageName,
            onTap: () => _showLanguagePicker(context, s, locale),
          ),
          _Tile(
            icon: AppIcons.call,
            title: s.support,
            onTap: () => _showSupport(context, s),
          ),
          _Tile(
            icon: AppIcons.info,
            title: s.aboutApp,
            subtitle: '${s.appVersionLabel} 1.0.0',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _AboutAppDialog(),
            ),
          ),

          if (auth.isSignedIn) ...[
            const SizedBox(height: 28),
            AppButton(
              label: s.deleteAccount,
              icon: AppIcons.signOut,
              color: AppColors.redSoft,
              textColor: AppColors.red,
              onPressed: () => _confirmSignOut(context, s),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => _confirmDeleteAccount(context, s),
                child: Text(
                  s.deleteAccount,
                  style: AppText.body.copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AppStrings s) async {
    final confirmed = await _ConfirmDialog.show(
      context,
      icon: AppIcons.signOut,
      title: s.signOutConfirmTitle,
      message: s.signOutConfirmMessage,
      confirmLabel: s.signOut,
    );
    if (!confirmed || !context.mounted) return;
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().signOut();
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AppStrings s) async {
    final confirmed = await _ConfirmDialog.show(
      context,
      icon: AppIcons.delete,
      title: s.deleteAccountConfirmTitle,
      message: s.deleteAccountConfirmMessage,
      confirmLabel: s.deleteAccount,
    );
    if (!confirmed || !context.mounted) return;
    // No account-deletion endpoint on the backend yet — signs the customer
    // out locally, the same as "Çyk", until server-side deletion exists.
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().signOut();
    navigator.popUntil((route) => route.isFirst);
  }

  void _showLanguagePicker(
    BuildContext context,
    AppStrings s,
    LocaleProvider locale,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(s.language, style: AppText.h2),
              const SizedBox(height: 16),
              for (final strings in LocaleProvider.supported)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LanguageOption(
                    strings: strings,
                    selected: strings.languageCode == s.languageCode,
                    onTap: () {
                      locale.select(strings);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context, AppStrings s) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(s.changePhoto, style: AppText.h2),
              const SizedBox(height: 16),
              _SupportAction(
                icon: AppIcons.gallery,
                label: s.chooseFromGallery,
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              _SupportAction(
                icon: AppIcons.camera,
                label: s.takePhoto,
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !context.mounted) return;

    await context.read<AuthProvider>().updateProfile(
      avatarFile: File(picked.path),
    );
  }

  Future<void> _editName(
    BuildContext context,
    AppStrings s,
    String currentName,
  ) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditNameSheet(strings: s, initialName: currentName),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await context.read<AuthProvider>().updateProfile(firstName: name);
  }

  void _showSupport(BuildContext context, AppStrings s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) =>
          _SupportSheet(repository: context.read<ContactRepository>()),
    );
  }

  Future<void> _callSupport(BuildContext context) async {
    try {
      final contact = await context.read<ContactRepository>().get();
      if (!context.mounted) return;
      final opened = await launchUrl(Uri(scheme: 'tel', path: contact.phone));
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arama uygulaması açılamadı.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destek numarası alınamadı. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }
}

/// Replaces Flutter's generic [showAboutDialog] with a card styled to match
/// the rest of the app — brand mark, tagline, and a version pill instead of
/// the stock Material licence-page dialog.
class _AboutAppDialog extends StatelessWidget {
  const _AboutAppDialog();

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
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/logo_no_text.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('A7-TAGAM', style: AppText.h2),
            const SizedBox(height: 6),
            Text(
              s.aboutAppTagline,
              textAlign: TextAlign.center,
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${s.appVersionLabel} 1.0.0',
                style: AppText.chip.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: s.close,
                height: 48,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A destructive action's own confirmation — icon, title, a plain-language
/// consequence line, then Cancel next to a red confirm rather than a single
/// "are you sure" OK. Used for both sign-out and account deletion, since
/// both end the session and deserve the same weight of a deliberate second
/// tap instead of firing straight off the profile tile.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final HugeIconData icon;
  final String title;
  final String message;
  final String confirmLabel;

  static Future<bool> show(
    BuildContext context, {
    required HugeIconData icon,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
    return result ?? false;
  }

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
                color: AppColors.redSoft,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(icon: icon, color: AppColors.red, size: 26),
            ),
            const SizedBox(height: 18),
            Text(title, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
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
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    height: 48,
                    color: AppColors.red,
                    textColor: AppColors.white,
                    onPressed: () => Navigator.of(context).pop(true),
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

class _SupportSheet extends StatelessWidget {
  const _SupportSheet({required this.repository});
  final ContactRepository repository;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: FutureBuilder<ContactInfo>(
      future: repository.get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final contact = snapshot.data!;
        Future<void> open(String value, String scheme) =>
            launchUrl(Uri(scheme: scheme, path: value));
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(contact.name, style: AppText.h2),
              const SizedBox(height: 6),
              Text('Size yardımcı olmaya hazırız', style: AppText.bodyMuted),
              const SizedBox(height: 18),
              _SupportAction(
                icon: AppIcons.call,
                label: contact.phone,
                onTap: () => open(contact.phone, 'tel'),
              ),
              if (contact.telegram != null)
                _SupportAction(
                  icon: AppIcons.telegram,
                  label: 'Telegram',
                  onTap: () => launchUrl(Uri.parse(contact.telegram!)),
                ),
              if (contact.email != null)
                _SupportAction(
                  icon: AppIcons.email,
                  label: contact.email!,
                  onTap: () => open(contact.email!, 'mailto'),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final HugeIconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(icon: icon, color: AppColors.green, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const HugeIcon(
                icon: AppIcons.chevronRight,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Owns its own [TextEditingController] so Flutter disposes it once this
/// widget actually leaves the tree — disposing it manually right after
/// `Navigator.pop` races the sheet's closing animation and crashes with
/// "used after being disposed".
class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({required this.strings, required this.initialName});

  final AppStrings strings;
  final String initialName;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(s.editProfileTitle, style: AppText.h2),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: s.nameLabel,
                  hintText: s.nameHint,
                ),
              ),
              const SizedBox(height: 20),
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
                      label: s.save,
                      height: 48,
                      onPressed: () =>
                          Navigator.of(context).pop(_controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.phone,
    required this.avatarPath,
    required this.busy,
    required this.onChangePhoto,
    required this.onEditName,
  });

  final String name;
  final String phone;
  final String? avatarPath;
  final bool busy;
  final VoidCallback onChangePhoto;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: busy ? null : onChangePhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.white,
                  backgroundImage: avatarPath != null
                      ? FileImage(File(avatarPath!))
                      : null,
                ),
                // The widescreen clip is zoomed and clipped inside the same
                // 52 px circle as a regular customer photo.
                if (avatarPath == null)
                  const Positioned.fill(child: FlameAvatarVideo(size: 52)),
                if (busy)
                  const Positioned.fill(
                    child: CircleAvatar(
                      backgroundColor: Colors.black38,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.white),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const HugeIcon(
                      icon: AppIcons.camera,
                      color: AppColors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppText.h2.copyWith(fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(phone, style: AppText.bodyMuted.copyWith(fontSize: 13)),
              ],
            ),
          ),
          InkWell(
            onTap: onEditName,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: AppIcons.edit,
                color: AppColors.green,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.hint, required this.label});

  final String hint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.divider,
                child: HugeIcon(
                  icon: AppIcons.user,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(hint, style: AppText.bodyMuted)),
            ],
          ),
          const SizedBox(height: 16),
          // A full-width primary button rather than a small inline chip —
          // login/sign-up is the same phone+SMS step (proposal slide 5), so
          // one clear call to action covers both.
          AppButton(
            label: label,
            icon: AppIcons.user,
            onPressed: () => _openLogin(context),
          ),
        ],
      ),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final HugeIconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.green.withValues(alpha: 0.12),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: HugeIcon(
                      icon: icon,
                      color: AppColors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: AppText.body)),
                  if (subtitle != null) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        subtitle!,
                        style: AppText.bodyMuted,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const HugeIcon(
                    icon: AppIcons.chevronRight,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final AppStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.green : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? AppColors.green
              : AppColors.green.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SvgPicture.asset(
                  'assets/images/flags/${strings.languageCode}.svg',
                  width: 30,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  strings.languageName,
                  style: AppText.button.copyWith(
                    fontSize: 15,
                    color: selected ? AppColors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                HugeIcon(
                  icon: AppIcons.check,
                  color: AppColors.white,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
