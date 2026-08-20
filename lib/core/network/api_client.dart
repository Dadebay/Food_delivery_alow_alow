import 'dart:developer' as dev;

import 'package:dio/dio.dart';

import '../constants/app_config.dart';

/// Thin Dio wrapper. Timeouts are generous — Ashgabat's mobile data is slow
/// (proposal slide 10), so a slow answer beats a false failure.
class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
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
          if (response.statusCode == 401 &&
              !alreadyRetried &&
              !isRefreshCall &&
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
          final body = error.response?.data;
          final message = body is Map<String, dynamic> ? body['message'] : null;
          dev.log(
            '${error.requestOptions.method} ${error.requestOptions.path} → '
            '${error.type.name} HTTP ${error.response?.statusCode ?? '-'}'
            '${message == null ? '' : ': $message'}',
            name: 'ApiClient',
          );
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  String? _token;

  /// Set once `AuthRepository` exists — tries to trade the stored refresh
  /// token for a new access token, returns whether that worked.
  Future<bool> Function()? onUnauthorized;

  set token(String? value) => _token = value;

  Dio get raw => _dio;

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response<dynamic>> post(String path, {Object? data}) =>
      _dio.post(path, data: data);

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _dio.patch(path, data: data);

  Future<Response<dynamic>> put(String path, {Object? data}) =>
      _dio.put(path, data: data);

  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      _dio.delete(path, data: data);
}

/// Server paths, kept next to the client so a backend rename is a one-file
/// change.
class ApiPaths {
  const ApiPaths._();

  static const String requestCode = 'auth/otp/request';
  static const String verifyCode = 'auth/otp/verify';
  static const String refresh = 'auth/refresh';
  static const String logout = 'auth/logout';
  static const String categories = 'catalog/categories';
  static const String products = 'catalog/products';
  static const String banners = 'marketing/banners';
  static const String pushDevices = 'notifications/devices';
  static const String favorites = 'favorites';
  static const String addresses = 'users/me/addresses';
  static const String contacts = 'contacts';
  static const String me = 'users/me';
  static const String mediaUpload = 'media/images';
  static const String orders = 'orders';
  static const String placeOrder = 'orders';
  static const String geocodingReverse = 'geocoding/reverse';

  static String favoriteToggle(String dishId) => 'favorites/$dishId';
  static String order(String id) => 'orders/$id';
  static String rateOrder(String id) => 'orders/$id/rating';
  static String courierLocation(String id) =>
      'tracking/orders/$id/courier-location';
  static String pushDevice(String installationId) =>
      'notifications/devices/$installationId';
}
