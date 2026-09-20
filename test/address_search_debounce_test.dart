import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ekrandaki `_onSearchTextChanged` mantiginin birebir kopyasi. Uc nokta
/// dakikada 10 istekle sinirli, bu yuzden asil olculmesi gereken sey kac
/// istek cikardigi.
class _Debouncer {
  _Debouncer(this.onSearch);

  final void Function(String query) onSearch;
  static const delay = Duration(milliseconds: 600);

  Timer? _timer;
  String _lastSearched = '';
  String _text = '';

  void type(String value) {
    _text = value;
    _timer?.cancel();
    final query = _text.trim();
    if (query.length < 3) return;
    if (query == _lastSearched) return;
    _timer = Timer(delay, () {
      _lastSearched = query;
      onSearch(query);
    });
  }

  /// Enter / arama dugmesi: bekleyen zamanlayiciyi iptal edip hemen arar.
  void submit() {
    _timer?.cancel();
    final query = _text.trim();
    if (query.length < 3) return;
    _lastSearched = query;
    onSearch(query);
  }

  void dispose() => _timer?.cancel();
}

void main() {
  test('kelime yazarken tek istek cikar, her harfte degil', () {
    fakeAsync((async) {
      final calls = <String>[];
      final d = _Debouncer(calls.add);
      for (final part in ['G', 'Go', 'Gor', 'Goro', 'Gorog', 'Görogly']) {
        d.type(part);
        async.elapse(const Duration(milliseconds: 120));
      }
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['Görogly']);
      d.dispose();
    });
  });

  test('uc harften kisa metin hic aramaya gitmez', () {
    fakeAsync((async) {
      final calls = <String>[];
      final d = _Debouncer(calls.add);
      d.type('Go');
      async.elapse(const Duration(seconds: 2));
      expect(calls, isEmpty);
      d.dispose();
    });
  });

  test('ayni sorgu iki kez sorulmaz', () {
    fakeAsync((async) {
      final calls = <String>[];
      final d = _Debouncer(calls.add);
      d.type('Parahat');
      async.elapse(const Duration(seconds: 1));
      d.type('Parahat');
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['Parahat']);
      d.dispose();
    });
  });

  test('arama dugmesi bekleyen zamanlayiciyi iptal eder, ikinci istek olmaz',
      () {
    fakeAsync((async) {
      final calls = <String>[];
      final d = _Debouncer(calls.add);
      d.type('Berzenni');
      async.elapse(const Duration(milliseconds: 100));
      d.submit();
      async.elapse(const Duration(seconds: 2));
      expect(calls, ['Berzenni']);
      d.dispose();
    });
  });
}
