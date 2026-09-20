/// What the backend says about the versions of this app that are still
/// allowed to run — mirrors `GET /app/version` (see
/// `docs/APP_FORCE_UPDATE.md` for the admin-side contract).
class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    this.storeUrl,
    this.releaseNotesRu,
    this.releaseNotesTk,
  });

  /// Newest build published to the store. Anything below this is offered an
  /// update, but may carry on.
  final String latestVersion;

  /// Oldest build the backend still serves. Below this the app is blocked:
  /// it is the only thing here that takes the customer's choice away, so it
  /// is raised when an old client would misbehave, not on every release.
  final String minSupportedVersion;

  /// Store page for this platform. Null means the app falls back to the id
  /// it was built with — see `AppUpdateService`.
  final String? storeUrl;

  final String? releaseNotesRu;
  final String? releaseNotesTk;

  String? releaseNotes(String languageCode) =>
      languageCode == 'tk' ? releaseNotesTk : releaseNotesRu;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: json['latestVersion'] as String? ?? '0.0.0',
      minSupportedVersion: json['minSupportedVersion'] as String? ?? '0.0.0',
      storeUrl: json['storeUrl'] as String?,
      releaseNotesRu: json['releaseNotesRu'] as String?,
      releaseNotesTk: json['releaseNotesTk'] as String?,
    );
  }

  /// Compares dotted numeric versions — `1.10.0` is newer than `1.9.3`, which
  /// a plain string comparison gets backwards.
  ///
  /// Build metadata (`1.2.0+45`) and anything else after the numbers is
  /// ignored: the store shows customers the marketing version, so that is
  /// what the admin types in and what has to match.
  static int compare(String a, String b) {
    final left = _parts(a);
    final right = _parts(b);
    for (var i = 0; i < 3; i++) {
      final diff = (i < left.length ? left[i] : 0) -
          (i < right.length ? right[i] : 0);
      if (diff != 0) return diff < 0 ? -1 : 1;
    }
    return 0;
  }

  static List<int> _parts(String version) => version
      .split('+')
      .first
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
}
