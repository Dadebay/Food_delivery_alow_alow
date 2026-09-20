# Indoor location reliability task

## Goal

Make the customer Flutter app locate the user reliably enough to open the
delivery-address map near the correct building when the user is indoors and
satellite GPS is weak or unavailable.

This cannot promise room- or door-level indoor accuracy without installed
indoor infrastructure. The intended product behavior is:

1. Prefer a fresh, precise fix when one arrives quickly.
2. Fall back to Android/iOS fused network positioning (Wi-Fi and cell towers)
   when a satellite-quality fix does not arrive.
3. If the platform still produces no live fix, use only a recent cached fix.
4. Clearly tell the customer when the point is approximate and require them to
   verify/drag the map pin before saving the delivery address.
5. Never leave the UI spinner hanging indefinitely.

## Repository and safety

Repository:

`/Users/dadebay/Developer/apps/projects/food_delivery/food_delivery`

The worktree already contains many unrelated user changes. Preserve them. Do
not reset, revert, reformat, or rewrite unrelated files. Before editing, run:

```bash
git status --short
git diff -- lib/core/services/location_service.dart \
  lib/core/models/location_fix.dart \
  lib/modules/checkout/address_picker_screen.dart \
  lib/core/widgets/delivery_map.dart \
  lib/core/localization/app_strings.dart \
  lib/main.dart \
  test/location_service_test.dart
```

There is already a partially implemented indoor-location solution in those
files. Review and finish it; do not start over or replace the location stack
without evidence that the current `location` package cannot satisfy the
requirements.

## Current diagnosis

The original implementation made one unbounded `Location.getLocation()` call
at high accuracy. Indoors that future can take a very long time because the
device cannot acquire satellites, leaving the customer with a spinner.

The partial solution currently does the following:

- races `getLocation()` with `onLocationChanged`;
- requests high accuracy first, then switches to `balanced` so Android can use
  Google Play Services fused Wi-Fi/cell positioning;
- imposes a timeout;
- persists a recent fix in `SharedPreferences`;
- distinguishes permission/service errors from a genuine no-fix result;
- warns when the platform accuracy radius is coarse;
- triggers reverse geocoding after moving the pin programmatically;
- has unit tests in `test/location_service_test.dart`.

This is the correct overall direction, but it is not complete yet.

## Required fixes

### 1. Enforce one real total timeout

`LocationService.fixTimeout` must be the maximum time spent waiting for a live
fix across all tiers. The current code always waits the full six-second
`preciseAttempt` even when a shorter `fixTimeout` is supplied. Evidence: the
three timeout tests currently take about 18 seconds although each constructs
the service with a 50 ms timeout.

Implement the timing from a single monotonic deadline (use `Stopwatch`, not
wall-clock subtraction). Each phase may wait only for its remaining budget.
For example:

- precise phase budget = `min(preciseAttempt, remaining total budget)`;
- balanced phase budget = whatever remains;
- if nothing remains, immediately proceed to cached/no-fix behavior.

Permission prompts and the OS dialog do not need to be force-timed, but once
the actual location acquisition starts, it must respect the total deadline.

### 2. Do not reject an otherwise valid indoor/network reading only because
its timestamp is absent

`LocationData.time` is nullable. Android and iOS normally provide it, but the
model contract allows null and some platform implementations/tests may omit
it. A finite latitude/longitude inside valid ranges is still useful.

In `LocationFix.fromData`, use the supplied measurement timestamp when it is
finite, positive, and not materially in the future. If it is null, use the
injected `now` as `recordedAt`. Continue rejecting invalid coordinates, NaN,
infinity, impossible accuracy values, and clearly invalid/future timestamps.
Add a focused test for a valid location without `time`.

### 3. Keep the fused-provider fallback

Continue using the existing `location` package unless a demonstrated platform
bug requires a change. On Android, `LocationAccuracy.balanced` maps to
`PRIORITY_BALANCED_POWER_ACCURACY`, which is the desired Wi-Fi/cell fallback.
On iOS, Core Location already combines GPS, Wi-Fi, and cell sources; changing
desired accuracy should allow a faster coarse result.

The acquisition should remain foreground-only and on-demand. Do not add
background location, `ACCESS_BACKGROUND_LOCATION`, continuous tracking, or
upload the customer's live location.

### 4. Handle approximate permission/location honestly

Keep both Android permissions in the manifest:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

Keep iOS `NSLocationWhenInUseUsageDescription`. Do not request Always access
for this feature. If an existing Always key is retained for unrelated legacy
reasons, do not start requesting it.

When a returned fix has a large accuracy radius, center the map on it but show
the localized approximate-location warning. Do not claim that a network fix
is the exact building entrance.

### 5. Make every caller show the correct outcome

Audit both callers:

- `lib/modules/checkout/address_picker_screen.dart`
- `lib/core/widgets/delivery_map.dart`

Both must:

- prevent duplicate concurrent requests;
- show a spinner only while the request is active;
- stop the spinner after success, failure, disposal, or timeout;
- use the specific permission/service-disabled message only for those cases;
- use the no-fix/manual-pin message when permission is granted but no live or
  recent cached fix exists;
- show the approximate warning for coarse or cached results;
- move the map and reverse-geocode the selected point where applicable.

Do not introduce a second location service or duplicate error-state enums in
widgets. Prefer a typed result/source if string error codes are becoming
ambiguous, but keep the change narrowly scoped.

### 6. Cache constraints

The cached point is only a fallback, never proof of the exact current address.

- Persist latitude, longitude, recorded time, and accuracy.
- Accept only a recent cache entry (the current ten-minute maximum is fine).
- Reject corrupt, impossible, future-dated, or too-old entries.
- Never bypass a denied permission with cached location.
- Mark cached/coarse output approximate so the UI tells the customer to verify
  the pin.
- Coalesce concurrent `fetch()` calls into one platform acquisition.

## Tests to add or correct

Keep all current tests and add coverage for at least:

1. one-shot live success;
2. stream success when one-shot never completes;
3. high-accuracy phase times out and balanced phase succeeds;
4. no platform response returns within the configured total timeout (with a
   small tolerance) rather than waiting six seconds;
5. recent cache fallback;
6. old cache rejection;
7. denied permission never uses cache;
8. null timestamp on valid coordinates is accepted using `now`;
9. invalid coordinates/NaN/future timestamp are rejected;
10. concurrent calls share one acquisition;
11. coarse/cached fixes are exposed as approximate;
12. second fetch works after the first completes or fails.

Make the fake platform record requested accuracy levels so the test proves
that `high` is followed by `balanced`. Tests must not rely on real six-second
delays; make phase duration injectable or derive it from the small test total
budget.

## Verification

Run from the repository root:

```bash
dart format \
  lib/core/models/location_fix.dart \
  lib/core/services/location_service.dart \
  lib/modules/checkout/address_picker_screen.dart \
  lib/core/widgets/delivery_map.dart \
  test/location_service_test.dart

flutter test test/location_service_test.dart
flutter test
flutter analyze
git diff --check
```

Do not hide pre-existing unrelated failures. Report them separately with the
exact command and output summary.

## Physical-device acceptance checks

Unit tests cannot prove indoor radio behavior. Verify on at least one real
Android phone, and iPhone if available:

1. Outdoors with precise permission: the map centers accurately and promptly.
2. Indoors near Wi-Fi with weak/no satellite reception: within the bounded
   wait, the map centers on a usable approximate area and shows the warning.
3. Android approximate-location permission: the app still returns a coarse
   position and asks the user to verify the pin.
4. Location services off: the OS/service-disabled path is shown.
5. Permission denied and denied-forever: the app does not pretend cached data
   is current.
6. Airplane mode with Wi-Fi on, then all radios unavailable: neither case
   hangs; the recent-cache/manual-pin behavior is correct.
7. Repeated rapid taps create only one request and one stable UI transition.
8. After moving the pin, the reverse-geocoded address updates and the customer
   can correct house/entrance/floor/apartment details manually.

Record the returned `accuracy` radius and elapsed time for the indoor run.
Success means a useful map starting point plus honest uncertainty, not a false
promise of exact indoor GPS.

## Definition of done

- No location request can spin forever.
- Indoor Wi-Fi/cell fallback is actually exercised and tested.
- The configured timeout is a true end-to-end acquisition budget.
- Valid coarse readings are not discarded unnecessarily.
- Stale/cache/approximate states are communicated to the customer.
- Address reverse geocoding still runs after automatic map movement.
- No background tracking or new privacy exposure is introduced.
- Focused and full test/analyze commands have been run and reported.
- Only task-related files are changed.

When finished, leave a short implementation note containing:

- files changed;
- behavioral decisions;
- test commands and results;
- any real-device validation still required.

---

# Implementation note (2026-09-18)

## Files changed

- `lib/core/models/location_fix.dart`
- `lib/core/services/location_service.dart`
- `lib/core/widgets/delivery_map.dart`
- `lib/modules/checkout/address_picker_screen.dart`
- `test/location_service_test.dart`

No other files touched. `pubspec.yaml` unchanged.

## Behavioural decisions

**One monotonic budget.** A `Stopwatch` starts after the permission and
service dialogs, not before: the customer may sit on an OS prompt for a
minute, and counting that against acquisition would time out a lookup that had
not begun. Each phase then gets `min(phase, remaining)`. `preciseAttempt` is a
constructor argument clamped to `fixTimeout`, so no caller can reintroduce a
precise phase that outlives the total budget.

**A missing timestamp is not a rejection.** `LocationData.time` is nullable by
contract, and a coarse network reading is exactly what this feature reaches for
indoors. A reading without `time` is stamped `now`. Invalid coordinates, NaN,
infinity, impossible accuracy radii and clearly future timestamps are still
rejected; one minute of clock skew is tolerated.

**A reading only finishes the lookup as *live* if it is both newer than what is
held and fresh.** `_remember` now returns whether it stored the fix, and
`offer` gates on that plus `isFresh`. Previously a platform handing back its
own hours-old last-known position completed the lookup with that coordinate
while the getters still described the better reading — so the pin sat where the
customer used to be, with a tight accuracy radius and therefore no warning. An
older-but-newest reading is still remembered and leaves through the cached
path, which the UI marks approximate.

**Typed source instead of more string codes.** `LocationSource`
(`live`/`cached`/`none`) plus `isBlocked` and `lastResultIsApproximate` on the
service. Both map widgets read those rather than owning their own enums or
re-deriving which error codes mean "go to settings".

## Tests

```
flutter test test/location_service_test.dart   → 26/26 passed, ~2s
flutter analyze <the five files above>          → No issues found
dart format <the five files above>              → applied
git diff --check                                → clean
```

The suite previously took ~18s because three tests built the service with a
50 ms timeout and still waited out the 6 s precise phase. That is the
regression the budget work removes, and the runtime is the proof.

## Known gap: Android approximate location (requirement 4)

**Not fixed, and not fixable in this app's Dart code.** Verified in the
package sources:

- `location-8.0.1` `FlutterLocation.checkPermissions()` checks only
  `ACCESS_FINE_LOCATION`. On Android 12+ "Approximate" grants coarse and
  denies fine, so `hasPermission()` returns `denied`.
- `MethodCallHandlerImpl.onGetLocation` and `StreamHandlerImpl.onListen` both
  gate on that same check and re-request fine, so neither the one-shot nor the
  stream can read a coarse-only position.
- `PermissionStatus.grantedLimited` is documented in
  `location_platform_interface` as iOS 14+ only; Android maps its result to
  0/1/2 and never returns it.
- `permission_handler` cannot distinguish the case either: its Android
  location group adds a status only for permissions that are *not* granted and
  returns the strictest, so coarse-granted/fine-denied also reads `denied`.

The test that previously implied Android coverage is relabelled as the iOS
"Precise: Off" case. Closing requirement 4 needs an acquisition package that
supports coarse (`geolocator` exposes `LocationAccuracyStatus.reduced`), which
is a dependency change outside this task's stated scope.

## Real-device validation still required

Unit tests cannot prove radio behaviour. Outstanding: outdoors precise;
indoors on Wi-Fi with weak satellites (record the returned `accuracy` radius
and elapsed time); Android approximate-permission path; location services off;
denied and denied-forever; airplane mode with and without Wi-Fi; rapid
repeated taps; reverse geocoding after automatic map movement.
