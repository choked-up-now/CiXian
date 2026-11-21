// Copyright 2026 choked-up-now
// SPDX-License-Identifier: MulanPSL-2.0

import 'package:http/http.dart' as http;

/// 统一网络出口：所有请求 10 秒超时。
/// 避免弱网下启动同步卡住导致首页永远转圈。
class ApiClient {
  static const Duration timeout = Duration(seconds: 10);

  static Future<http.Response> get(Uri url) =>
      http.get(url).timeout(timeout);

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      http.post(url, headers: headers, body: body).timeout(timeout);
}
