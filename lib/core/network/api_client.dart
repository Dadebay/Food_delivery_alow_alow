import 'dart:convert';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';

import '../constants/app_config.dart';

/// Thin Dio wrapper. Timeouts are generous — Ashgabat's mobile data is slow
/// (proposal slide 10), so a slow answer beats a false failure.
class ApiClient {
  /// The address the app is actually talking to right now.
  ///
  /// Not the same thing as [AppConfig.apiBaseUrl], which is only the first
  /// address on the list: once a request has fallen back to another one, the
  /// client keeps using it for the rest of the session. Media URLs arrive
  /// from the API as paths and have to be resolved against this, or the
  /// catalogue loads over the address that works while every photo in it
  /// points at the one that does not.
  static String currentBaseUrl = AppConfig.apiBaseUrl;

  ApiClient() {
    // `directory: null` — Hive is already pointed at its home directory by
    // `Hive.initFlutter()`/`TileCacheService` before this runs; calling
    // `Hive.init()` again here with a second path would silently move
    // *every* box (tiles included) to wherever was initialized last.
    _cacheStore = HiveCacheStore(null, hiveBoxName: _cacheBoxName);

    _baseUrls = AppConfig.apiBaseUrls;

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrls.first,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: const {'Accept': 'application/json'},
        validateStatus: (code) => code != null && code < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          // `validateStatus` above accepts every 4xx as a normal response
          // (several call sites read the error body directly), so an
          // expired access token surfaces here rather than in `onError`.
          // The access token is short-lived by design (15 min) — refreshing
          // once and replaying the same request is the expected path, not
          // an edge case.
          final alreadyRetried =
              response.requestOptions.extra['retried'] == true;
          final isRefreshCall =
              response.requestOptions.path == ApiPaths.refresh;
          // Some calls are housekeeping the customer never asked for — push
          // registration is the one that bit us. A 401 there used to drag the
          // whole session through a refresh, and a refresh that failed wiped
          // the credentials the customer had just signed in with. Whatever is
          // wrong with a background PUT, the answer is never to sign someone
          // out of the app they are standing in.
          final isBestEffort =
              response.requestOptions.extra[_bestEffortKey] == true;
          if (response.statusCode == 401 &&
              !alreadyRetried &&
              !isRefreshCall &&
              !isBestEffort &&
              onUnauthorized != null) {
            final refreshed = await onUnauthorized!();
            if (refreshed) {
              try {
                final retried = await _dio.fetch<dynamic>(
                  response.requestOptions..extra['retried'] = true,
                );
                return handler.resolve(retried);
              } catch (error) {
                if (error is DioException) return handler.reject(error);
                rethrow;
              }
            }
          }
          handler.next(response);
        },
        onError: (error, handler) {
          // Never put API response text, tokens, addresses, or request bodies
          // into device logs. Status and requestId are enough to correlate a
          // failure with backend logs.
          final body = error.response?.data;
          final requestId = body is Map<String, dynamic>
              ? body['requestId']
              : null;
          dev.log(
            '${error.requestOptions.method} ${error.requestOptions.uri.path} → '
            '${error.type.name} HTTP ${error.response?.statusCode ?? '-'}'
            '${requestId is String ? ' requestId=$requestId' : ''}',
            name: 'ApiClient',
          );
          handler.next(error);
        },
      ),
    );

    // Sits before the cache interceptor so a dropped connection is retried
    // *before* the cache is allowed to answer with a stale copy — otherwise a
    // single failed TLS handshake would quietly show week-old data instead of
    // simply asking again.
    _dio.interceptors.add(
      InterceptorsWrapper(onError: _retryUnreachableRequest),
    );

    // Added last so it sees the *final* response/error — after the 401
    // refresh-and-retry above has already had its say — and only ever
    // touches GET requests (dio_cache_interceptor skips every other verb by
    // default), so nothing that writes data can be served from a stale copy.
    // On a real request failure (offline, timeout, 5xx) this hands back
    // whichever response it last cached instead of throwing, so the menu
    // and order history stay visible without a connection — see
    // `CatalogProvider`/`OrderProvider`, which need no offline-specific code
    // themselves because the failure never reaches them.
    _dio.interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: _cacheStore,
          policy: CachePolicy.refreshForceCache,
          maxStale: AppConfig.apiCacheMaxStale,
          hitCacheOnErrorExcept: const [],
        ),
      ),
    );
  }

  static const String _cacheBoxName = 'api_response_cache';
  static const String _retryExtraKey = 'unreachable_retry';

  /// `store: null` falls through to the interceptor's own store, so this only
  /// changes the one thing it means to: no cached answer on error.
  static final CacheOptions _retryCacheOptions = CacheOptions(
    store: null,
    policy: CachePolicy.refreshForceCache,
    maxStale: AppConfig.apiCacheMaxStale,
  );

  late final Dio _dio;
  late final HiveCacheStore _cacheStore;
  late final List<String> _baseUrls;
  String? _token;

  /// Whichever address is answering right now. Starts at the primary on every
  /// launch, so the app returns to the domain name once it is healthy again.
  String get activeBaseUrl => _dio.options.baseUrl;

  /// Set once `AuthRepository` exists — tries to trade the stored refresh
  /// token for a new access token, returns whether that worked.
  Future<bool> Function()? onUnauthorized;

  set token(String? value) => _token = value;

  /// Whether a customer is signed in right now — the authenticated endpoints
  /// answer 401 without this, so callers that are optional (push device
  /// registration) check before spending a request.
  bool get hasToken => _token != null;

  /// The `role` claim inside the current access token, for debug logging only.
  ///
  /// A 403 from an endpoint the customer app is supposed to be allowed to call
  /// means the token belongs to some other kind of account — an admin or a
  /// courier signed in on the same phone, or a backend whose guard does not
  /// list the role its own login hands out. Reading the claim turns that from
  /// a guess into a fact. Nothing is verified here: the signature is the
  /// server's business, this is only ever printed.
  String? get tokenRole {
    final token = _token;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      return (payload['role'] ?? payload['roles'] ?? payload['type'])
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  Dio get raw => _dio;

  /// Drops cached GET responses whose path matches [pathPattern] — call on
  /// sign-out so the next account on this device can't see the previous
  /// customer's cached orders (etc.) before its own first successful fetch.
  /// The public menu is intentionally left alone.
  Future<void> clearCache(RegExp pathPattern) =>
      _cacheStore.deleteFromPath(pathPattern);

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response<dynamic>> post(String path, {Object? data}) =>
      _dio.post(path, data: data);

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _dio.patch(path, data: data);

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
    bool bestEffort = false,
  }) => _dio.put(
    path,
    data: data,
    options: bestEffort ? Options(extra: {_bestEffortKey: true}) : null,
  );

  /// Marks a request whose failure must never cost the customer their
  /// session — see the refresh interceptor.
  static const String _bestEffortKey = 'bestEffort';

  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      _dio.delete(path, data: data);

  /// Replays a request the network refused: first against the address that
  /// just failed, then against the other entries in `AppConfig.apiBaseUrls`,
  /// keeping whichever answers for the rest of the session.
  ///
  /// The same address is retried *first* on purpose. The failures seen here
  /// are intermittent TLS ones — the server drops a handshake and completes
  /// the very next one, reproducible with two identical `curl` calls a second
  /// apart — and that is recovered by trying again, not by going somewhere
  /// else. The other addresses only help when the first one is genuinely
  /// unreachable (an unresolvable name, a blocked route), so they come after.
  ///
  /// Only fires when the request never got a usable answer — the name never
  /// resolved, the socket never opened, TLS failed, or whatever replied cannot
  /// serve the API. A reachable server replying 4xx, or a cancelled request,
  /// is a real answer and is passed through untouched.
  Future<void> _retryUnreachableRequest(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;
    if (options.extra[_retryExtraKey] == true ||
        !_isUnreachable(error) ||
        // A finalized FormData body cannot be sent a second time; the avatar
        // upload is the only such call, and failing it beats sending a
        // truncated file.
        options.data is FormData) {
      return handler.next(error);
    }

    final current = _dio.options.baseUrl;
    final attempts = <String>[
      current,
      ..._baseUrls.where((url) => url != current),
    ];

    final failures = <String>[];
    for (final candidate in attempts) {
      // A handshake the server just dropped is likelier to succeed after a
      // breath than immediately.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      try {
        final response = await _dio.fetch<dynamic>(
          options.copyWith(
            baseUrl: candidate,
            extra: {
              ...options.extra,
              _retryExtraKey: true,
              // `fetch` re-enters the whole interceptor chain, cache
              // interceptor included. With the ordinary options that
              // interceptor answers a failed GET from its store, so the retry
              // "succeeded" with a stale copy and this loop stopped — the
              // fallback address was never reached on any cacheable request,
              // which is every GET in the app. `hitCacheOnErrorExcept: null`
              // turns that off for the retry only: a failure stays a failure
              // here, the next address gets its turn, and a success is still
              // written to the store as usual.
              ..._retryCacheOptions.toExtra(),
            },
          ),
        );
        if (candidate != current) {
          dev.log('base url $current → $candidate', name: 'ApiClient');
          _dio.options.baseUrl = candidate;
          currentBaseUrl = candidate;
        }
        return handler.resolve(response);
      } on DioException catch (retryError) {
        failures.add('$candidate (${retryError.type.name})');
      }
    }

    // Names every address that was tried, in order. The point of the log is
    // to tell "this one address is sick" apart from "the phone has no
    // network at all", and only the full list can do that.
    dev.log(
      '${options.path}: all addresses failed — ${failures.join(', ')}',
      name: 'ApiClient',
    );
    // Deliberately the *original* error, not the fallback's. The cache
    // interceptor behind this one looks a stored response up by request URI,
    // and the fallback's URI is a different key with nothing under it —
    // forwarding its error would throw away the offline copy the app is
    // supposed to fall back on when every address is unreachable.
    handler.next(error);
  }

  static bool _isUnreachable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.badCertificate:
      // Wraps SocketException — "Failed host lookup", the exact iOS symptom
      // this fallback exists for.
      case DioExceptionType.unknown:
        return true;
      // `validateStatus` lets every 4xx through as a normal response, so a
      // badResponse that reaches here is 5xx: the name resolved to something
      // that cannot serve the API.
      case DioExceptionType.badResponse:
        return true;
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.cancel:
        return false;
    }
  }
}

/// Server paths, kept next to the client so a backend rename is a one-file
/// change.
class ApiPaths {
  const ApiPaths._();

  static const String requestCode = 'auth/otp/request';
  static const String verifyCode = 'auth/otp/verify';
  static const String refresh = 'auth/refresh';
  static const String logout = 'auth/logout';
  static const String cafes = 'catalog/cafes';
  static const String categories = 'catalog/categories';
  static const String products = 'catalog/products';
  static const String banners = 'marketing/banners';
  static const String pushDevices = 'notifications/devices';
  static const String favorites = 'favorites';
  static const String addresses = 'users/me/addresses';
  static const String contacts = 'contacts';
  static const String me = 'users/me';
  static const String appVersion = 'app/version';
  static const String mediaUpload = 'media/images';
  static const String orders = 'orders';
  static const String placeOrder = 'orders';
  static const String orderQuote = 'orders/quote';
  static const String deliveryQuote = 'delivery/quote';

  // ─── Loyalty, tariff and ordering hours ──────────────────────
  // Added for MOBILE_LOYALTY_DELIVERY_HANDOFF.md. The API carrying these is
  // not deployed yet, so every caller has to treat a 404 here as "this
  // server does not have the feature" rather than as a failure.
  static const String loyaltyGifts = 'loyalty/gifts';
  static const String loyaltyMe = 'loyalty/me';
  static const String orderingHours = 'ordering-hours';
  static const String deliveryConfig = 'delivery/config';
  static const String deliveryTariffQuote = 'delivery/tariff-quote';
  static const String geocodingReverse = 'geocoding/reverse';
  static const String geocodingSearch = 'geocoding/search';

  static String favoriteToggle(String dishId) => 'favorites/$dishId';
  static String order(String id) => 'orders/$id';
  static String cancelOrder(String id) => 'orders/$id/cancel';
  static String rateOrder(String id) => 'orders/$id/rating';
  static String courierLocation(String id) =>
      'tracking/orders/$id/courier-location';
  static String courierRoute(String id) => 'tracking/orders/$id/route';

  /// The id here is an FCM registration token, which carries a `:` separating
  /// the instance id from the rest. Encoding it is part of the documented
  /// contract (MOBILE_PUSH_NOTIFICATIONS.md) — an unescaped token is at the
  /// mercy of whatever nginx and the router make of that colon.
  static String pushDevice(String installationId) =>
      'notifications/devices/${Uri.encodeComponent(installationId)}';
}
