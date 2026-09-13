import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionChecker {
  // ⚠️ 这里已经按你的仓库信息填好，如需更换仓库请修改
  static const String _owner = 'choked-up-now';
  static const String _repo = 'CiXian';

  static const String _apiUrl =
      'https://api.atomgit.com/api/v5/repos/$_owner/$_repo/releases/latest';

  static Future<VersionCheckResult> check() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode != 200) {
        return VersionCheckResult(
          error: '无法获取版本信息 (${response.statusCode})',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // 从 tag_name 获取最新版本号（例如 "v0.5.0"）
      final latestTag = data['tag_name'] as String? ?? '';
      final latestVersion =
          latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;

      // 从 assets 里找 APK 下载链接
      final assets = data['assets'] as List<dynamic>? ?? [];
      String apkUrl = '';
      for (final asset in assets) {
        final assetName = asset['name'] as String? ?? '';
        if (assetName.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final hasUpdate = _isNewer(latestVersion, currentVersion);

      return VersionCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        androidUrl: apkUrl,
        releaseUrl: 'https://atomgit.com/$_owner/$_repo/releases',
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
