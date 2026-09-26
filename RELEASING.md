# Sürüm çıkarma

Bu dosya tek bir sorunu çözmek için var: **uygulamanın kendini bildirdiği
sürüm ile admin paneline yazılan sürüm birbirini tutmazsa, müşteri hiç
bitmeyen bir "güncelleme var" uyarısı görür.** Güncellese de geçmez, çünkü
indirdiği yeni sürüm de aynı numarayı bildirir.

22 Eylül 2026'da tam bu oldu: App Store sayfasında **1.8** yazıyordu, ama o
sayfaya bağlı build'in kendi sürümü **1.1.1**'di. Panele 1.8.0 girilince
1.1.1 çalıştıran herkes sonsuza kadar uyarı aldı.

## Tek kaynak: `pubspec.yaml`

```yaml
version: 1.1.2+12
#        ^^^^^ ^^
#        |     build numarası  → iOS CFBundleVersion, Android versionCode
#        sürüm adı             → iOS CFBundleShortVersionString, Android versionName
```

Her iki platform da bu satırdan okur, başka hiçbir yerde sürüm tanımlı
değildir:

| Platform | Nereden okur |
|---|---|
| iOS | `Info.plist` → `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` |
| Android | `build.gradle.kts` → `flutter.versionName` / `flutter.versionCode` |

**Asla `--build-name` / `--build-number` parametreleriyle build alma.** 1.1.1
sürümü böyle çıkmıştı; depoda izi kalmadı ve numaralar birbirinden koptu.

## Sürüm çıkarma sırası

1. **`pubspec.yaml`'ı yükselt.** Sürüm adı bir öncekinden büyük olmalı; build
   numarası da her mağaza yüklemesinde mutlaka artmalı (ikisi de tek yönlü,
   geri düşürülemez).

2. **Build al ve mağazaya yükle.**
   ```bash
   flutter build ipa
   flutter build appbundle
   ```

3. **App Store Connect'te "Version" alanına `pubspec`'teki sürüm adının
   aynısını yaz.** Buradaki en kritik adım bu. Mağaza sayfasındaki numara ile
   binary'nin numarası farklı olursa hata yeniden doğar.

4. **Yayınla ve dağıtımın tamamlandığından emin ol.** Kademeli dağıtım
   (staged rollout) sürerken sürümü panele girme: henüz güncelleme alamayan
   kullanıcılar boş yere uyarı görür.

5. **Ondan sonra admin paneline gir** — Настройки → Версии приложения.

## Admin paneline ne yazılır

| Alan | Değer |
|---|---|
| Последняя версия | Yayımlanan **sürüm adı**, build numarası olmadan. `1.1.2` |
| Минимальная версия | Hâlâ çalışmasına izin verilen en eski sürüm. Genelde `1.0.0` |
| Ссылка на App Store | `https://apps.apple.com/app/id6803538512` |
| Ссылка на Google Play | `https://play.google.com/store/apps/details?id=com.gurbanov.alowalow` |

Dikkat edilecekler:

- **Build numarası yazılmaz.** `1.1.2` doğru, `1.1.2+12` ya da `12` yanlış.
- **Android tarafında `versionCode` değil `versionName` yazılır.** Play
  Console'da "Sürüm adı" olarak görünen değerdir.
- **Минимальная версия'yı ancak eski sürümler gerçekten bozulduğunda
  yükselt.** Yükseltmek o sürümlerin altındaki herkesi tamamen kilitler —
  uygulamayı açamazlar, sadece güncelleme ekranını görürler.

## Doğrulama

Uygulama açılışında konsola mavi `UPDATE` satırı düşer:

```
 UPDATE  current=1.1.2  backend=1.1.2  store=1.1.2  min=1.0.0  → none
```

- `current` — telefondaki build'in bildirdiği sürüm
- `backend` — admin panele girilen değer
- `store` — App Store / Play'den okunan değer
- `→ none` — uyarı yok. `optional` görünüyorsa üç sayıdan biri tutmuyordur.

Telefondaki gerçek sürümü dışarıdan da okuyabilirsin:

```bash
xcrun devicectl device info apps --device <UDID> --include-all-apps | grep alowalow
```

```bash
adb shell dumpsys package com.gurbanov.alowalow | grep versionName
```

## Panel tanımlı değilse ne olur

`GET /api/v1/app/version` 404 dönerse (politika hiç girilmemişse) uygulama
hata vermez — kararı tamamen mağaza aramasına bırakır. Bu bilinçli bir
tasarım, ama mağaza araması yanılabilir; bu yüzden politikayı **her iki
platform için de** tanımlı tutmak gerekir.
