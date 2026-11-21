// Copyright 2026 choked-up-now
// SPDX-License-Identifier: MulanPSL-2.0

/// 全局配置。p2 阶段把散落在各文件的 URL 收拢到这里。
class AppConfig {
  static const String baseUrl = 'https://cixian.pages.dev';
  static const String atomgitApi = 'https://api.atomgit.com/api/v5/repos';
  static const String atomgitSite = 'https://atomgit.com';

  static const String helpUrl = '$baseUrl/docs/';
  static const String marketUrl = '$baseUrl/market.html';
  static const String releasePageUrl =
      '$atomgitSite/choked-up-now/CiXian/releases';
  static const String feedbackUrl =
      '$atomgitSite/choked-up-now/CiXian/issues';
  static const String sponsorUrl = 'https://afdian.com/a/choked-up-now';
}

/// APK 下载来源白名单：只允许 HTTPS + 指定域名 + .apk 结尾。
/// 防止 AtomGit release 被投毒后客户端静默安装任意包。
class ApkPolicy {
  static const Set<String> allowedHosts = {
    'atomgit.com',
    'api.atomgit.com',
  };

  static bool isTrusted(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    if (!allowedHosts.contains(uri.host)) return false;
    return uri.path.toLowerCase().endsWith('.apk');
  }
}
