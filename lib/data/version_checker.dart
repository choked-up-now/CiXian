import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionChecker {
  // 从自己的网站读取版本信息（自动跟随 Cloudflare Pages 部署）
  static const String _versionUrl = 'https://cixian.pages.dev/version.json';

  static Future<VersionCheckResult> check() async {
    try {
      final response = await http.get(Uri.parse(_versionUrl));

      if (response.statusCode != 200) {
        return VersionCheckResult(
          error: '无法获取版本信息 (${response.statusCode})',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['version'] as String? ?? '';
      final androidUrl = data['android_url'] as String? ?? '';
      final releaseUrl = data['release_url'] as String? ?? '';

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final hasUpdate = _isNewer(latestVersion, currentVersion);

      return VersionCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        androidUrl: androidUrl,
        releaseUrl: releaseUrl,
      );
    } catch (e) {
      return VersionCheckResult(error: '检查更新失败: $e');
    }
  }

  /// 判断 latest 是否比 current 新（按 x.y.z 逐位比较）
  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}

class VersionCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String androidUrl;
  final String releaseUrl;
  final String? error;

  VersionCheckResult({
    this.hasUpdate = false,
    this.currentVersion = '',
    this.latestVersion = '',
    this.androidUrl = '',
    this.releaseUrl = '',
    this.error,
  });
}
