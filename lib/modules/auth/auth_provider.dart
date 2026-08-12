import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/data/auth_repository.dart';

enum AuthStage { phone, code, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository) {
    _repository.restore();
    _repository.onSessionExpired = _handleSessionExpired;
    _stage = _repository.isSignedIn ? AuthStage.authenticated : AuthStage.phone;
  }

  final AuthRepository _repository;

  late AuthStage _stage;
  String _phone = '';
  String _name = '';
  bool _busy = false;
  bool _codeRejected = false;
  bool _profileBusy = false;

  AuthStage get stage => _stage;
  String get phone => _phone;
  bool get busy => _busy;
  bool get codeRejected => _codeRejected;
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
    _setBusy(true);
    try {
      await _repository.requestCode(phone);
      _stage = AuthStage.code;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> verify(String code) async {
    _codeRejected = false;
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
    } finally {
      _setBusy(false);
    }
  }

  void backToPhone() {
    _stage = AuthStage.phone;
    _codeRejected = false;
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
