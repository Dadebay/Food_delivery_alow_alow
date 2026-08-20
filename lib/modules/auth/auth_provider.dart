import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/data/auth_repository.dart';

enum AuthStage { phone, code, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository) {
    _repository.restore();
    _repository.onSessionExpired = _handleSessionExpired;
    _stage = _repository.isSignedIn ? AuthStage.authenticated : AuthStage.phone;
    _phone = _repository.signedInPhone ?? '';
  }

  final AuthRepository _repository;

  late AuthStage _stage;
  String _phone = '';
  String _name = '';
  bool _busy = false;
  bool _codeRejected = false;
  String? _requestError;
  String? _verifyError;
  bool _profileBusy = false;

  AuthStage get stage => _stage;
  String get phone => _phone;
  bool get busy => _busy;
  bool get codeRejected => _codeRejected;
  String? get requestError => _requestError;
  String? get verifyError => _verifyError;
  bool get isSignedIn => _stage == AuthStage.authenticated;
  String get displayName => _repository.displayName;
  String get storedName => _repository.storedName;
  String? get avatarPath => _repository.avatarPath;
  bool get profileBusy => _profileBusy;

  /// Updates the customer's name and/or photo. `null` leaves a field
  /// untouched (`""` clears the name), and the avatar image is optional so
  /// the caller can save just the name.
  Future<void> updateProfile({String? firstName, File? avatarFile}) async {
    _profileBusy = true;
    notifyListeners();
    try {
      await _repository.updateProfile(
        firstName: firstName,
        avatarFile: avatarFile,
      );
    } finally {
      _profileBusy = false;
      notifyListeners();
    }
  }

  Future<void> requestCode(String phone, {String name = ''}) async {
    _phone = phone;
    _name = name.trim();
    _requestError = null;
    _setBusy(true);
    try {
      await _repository.requestCode(phone);
      _stage = AuthStage.code;
    } catch (error) {
      _requestError = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> verify(String code) async {
    _codeRejected = false;
    _verifyError = null;
    _setBusy(true);
    try {
      final ok = await _repository.verify(
        phone: _phone,
        code: code,
        firstName: _name.isEmpty ? null : _name,
      );
      if (ok) {
        _stage = AuthStage.authenticated;
      } else {
        _codeRejected = true;
      }
      return ok;
    } catch (error) {
      _codeRejected = true;
      _verifyError = _friendlyVerifyError(error.toString());
      return false;
    } finally {
      _setBusy(false);
    }
  }

  void backToPhone() {
    _stage = AuthStage.phone;
    _codeRejected = false;
    _verifyError = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _stage = AuthStage.phone;
    _phone = '';
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  String _friendlyVerifyError(String error) {
    final message = error.replaceFirst('Bad state: ', '').trim();
    final lower = message.toLowerCase();
    if (lower.contains('expired') || lower.contains('unavailable')) {
      return 'Kod geçersiz veya süresi dolmuş. Yeni kod isteyip tekrar deneyin.';
    }
    if (lower.contains('too many') || lower.contains('rate limit')) {
      return 'Çok fazla deneme yapıldı. 1 dakika bekleyip tekrar deneyin.';
    }
    if (lower.contains('could not be sent')) {
      return 'Kod şu anda gönderilemedi. Lütfen kısa süre sonra tekrar deneyin.';
    }
    return message.isEmpty
        ? 'Kod doğrulanamadı. Lütfen tekrar deneyin.'
        : message;
  }

  /// The refresh token itself was rejected (expired/revoked) — the session
  /// is genuinely gone, so drop straight back to the phone screen instead
  /// of leaving the UI showing a "signed in" state that no longer works.
  void _handleSessionExpired() {
    if (_stage != AuthStage.authenticated) return;
    _stage = AuthStage.phone;
    _phone = '';
    notifyListeners();
  }
}
