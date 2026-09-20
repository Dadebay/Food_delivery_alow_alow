import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/app_version_info.dart';

void main() {
  test('orders versions by number, not by string', () {
    // The whole reason this is not a string comparison: "1.10.0" sorts
    // *before* "1.9.3" alphabetically, which would leave every customer on
    // 1.10.x blocked by a minimum of 1.9.3.
    expect(AppVersionInfo.compare('1.10.0', '1.9.3'), 1);
    expect(AppVersionInfo.compare('1.9.3', '1.10.0'), -1);
    expect(AppVersionInfo.compare('2.0.0', '1.99.99'), 1);
  });

  test('treats equal versions as equal', () {
    expect(AppVersionInfo.compare('1.4.0', '1.4.0'), 0);
    // A missing patch component means zero, not "unknown".
    expect(AppVersionInfo.compare('1.4', '1.4.0'), 0);
  });

  test('ignores the build number the store never shows', () {
    expect(AppVersionInfo.compare('1.4.0+37', '1.4.0'), 0);
    expect(AppVersionInfo.compare('1.4.0+1', '1.4.1+99'), -1);
  });

  test('a malformed version sorts as 0.0.0 rather than throwing', () {
    // The admin types this by hand, so a typo must not crash start-up; the
    // app then reads as "older than everything", which the fail-open check in
    // AppUpdateService turns into no action at all.
    expect(AppVersionInfo.compare('oops', '1.0.0'), -1);
    expect(AppVersionInfo.compare('', '0.0.0'), 0);
  });

  test('parses the documented response shape', () {
    final info = AppVersionInfo.fromJson(const {
      'latestVersion': '1.4.0',
      'minSupportedVersion': '1.2.0',
      'storeUrl': 'https://play.google.com/store/apps/details?id=x',
      'releaseNotesRu': 'Новое',
      'releaseNotesTk': 'Täze',
    });

    expect(info.latestVersion, '1.4.0');
    expect(info.minSupportedVersion, '1.2.0');
    expect(info.releaseNotes('tk'), 'Täze');
    expect(info.releaseNotes('ru'), 'Новое');
  });

  test('a body missing both versions can never block anyone', () {
    // An older backend answering 200 with an unrelated body must not lock the
    // app: both versions default to 0.0.0, so no real build is below them.
    final info = AppVersionInfo.fromJson(const {});
    expect(AppVersionInfo.compare('1.0.0', info.minSupportedVersion), 1);
    expect(AppVersionInfo.compare('1.0.0', info.latestVersion), 1);
  });
}
