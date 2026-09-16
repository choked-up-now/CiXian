import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionChecker {
  static const String _owner = 'choked-up-now';
  static const String _repo = 'CiXian';

  // 最新稳定版
  static const String _latestApiUrl =
      'https://api.atomgit.com/api/v5/repos/$_owner/$_repo/releases/latest';
  // 全部版本（含预发布）
  static const String _allApiUrl =
      'https://api.atomgit.com/api/v5/repos/$_owner/$_repo/releases';

  static const String _acceptPreReleaseKey = 'accept_prerelease';

  /// 用户是否接收预发布版本（默认关闭）
  static Future<bool> isAcceptPreRelease() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptPreReleaseKey) ?? false;
  }

  /// 设置用户是否接收预发布版本
  static Future<void> setAcceptPreRelease(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptPreReleaseKey, value);
  }

  /// 检查更新
  static Future<VersionCheckResult> check() async {
    try {
      final acceptPre = await isAcceptPreRelease();

      // 根据用户设置，选择查询"稳定版"还是"全部版本"
      final url = acceptPre ? _allApiUrl : _latestApiUrl;
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        return VersionCheckResult(error: '无法获取版本信息 (${response.statusCode})');
      }

      // 拿到 tag_name 和 assets
      String? latestVersion;
      String apkUrl = '';
      const releaseUrl = 'https://atomgit.com/$_owner/$_repo/releases';

      if (acceptPre) {
        // /releases 返回数组，需要自己找最新的
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isEmpty) {
          return VersionCheckResult(error: '暂无任何版本');
        }

        // 找版本号最大的（用我们的 SemVer 比较器）
        Map<String, dynamic>? best;
        String bestVersion = '';
        for (final item in list) {
          final tag = (item['tag_name'] as String? ?? '').replaceFirst('v', '');
          if (tag.isEmpty) continue;
          // 跳过草稿
          if (item['draft'] == true) continue;
          if (best == null || compareVersions(tag, bestVersion) > 0) {
            best = item as Map<String, dynamic>;
            bestVersion = tag;
          }
        }
        if (best == null) {
          return VersionCheckResult(error: '暂无可用版本');
        }
        latestVersion = bestVersion;
        apkUrl = _findApkUrl(best);
      } else {
        // /releases/latest 直接返回一个对象
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tag = data['tag_name'] as String? ?? '';
        latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
        apkUrl = _findApkUrl(data);
      }

      // 获取当前 App 版本
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      // 比较
      final hasUpdate = compareVersions(latestVersion, currentVersion) > 0;

      return VersionCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        androidUrl: apkUrl,
        releaseUrl: releaseUrl,
      );
    } catch (e) {
      return VersionCheckResult(error: '检查更新失败: $e');
    }
  }

  /// 从 release 对象的 assets 里找 APK 下载链接
  static String _findApkUrl(Map<String, dynamic> data) {
    final assets = data['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        return asset['browser_download_url'] as String? ?? '';
      }
    }
    return '';
  }
}

/// ============================================================
///  SemVer 比较器
///  支持格式：
///    1.2.3
///    1.2.3-alpha
///    1.2.3-alpha.1
///    1.2.3-beta.2
///    1.2.3-rc.1
///  规则：
///    - 主版本号按数字比较
///    - 有预发布后缀的 < 无后缀的正式版
///    - alpha < beta < rc
///    - 同类型内比数字
/// ============================================================
int compareVersions(String a, String b) {
  // 1. 拆分主版本和预发布
  final aDash = a.split('-');
  final bDash = b.split('-');

  final aMain = _parseMain(aDash[0]);
  final bMain = _parseMain(bDash[0]);

  // 2. 比较主版本号
  for (int i = 0; i < 3; i++) {
    if (aMain[i] != bMain[i]) {
      return aMain[i].compareTo(bMain[i]);
    }
  }

  // 3. 主版本号相同，比较预发布部分
  final aPre = aDash.length > 1 ? aDash.sublist(1).join('-') : null;
  final bPre = bDash.length > 1 ? bDash.sublist(1).join('-') : null;

  // 都没预发布 → 相等
  if (aPre == null && bPre == null) return 0;
  // 只有 a 没预发布 → a 是正式版，a 大
  if (aPre == null) return 1;
  // 只有 b 没预发布 → b 是正式版，b 大
  if (bPre == null) return -1;

  // 都有预发布，先比类型
  final aType = _preType(aPre);
  final bType = _preType(bPre);
  if (aType != bType) return aType.compareTo(bType);

  // 同类型，比数字
  return _preNum(aPre).compareTo(_preNum(bPre));
}

/// 解析 "1.2.3" → [1, 2, 3]，不足补 0
List<int> _parseMain(String s) {
  final parts = s.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.sublist(0, 3);
}

/// 预发布类型优先级：alpha=1 < beta=2 < rc=3 < 其他=0
int _preType(String pre) {
  final lower = pre.toLowerCase();
  if (lower.startsWith('alpha')) return 1;
  if (lower.startsWith('beta')) return 2;
  if (lower.startsWith('rc')) return 3;
  return 0; // 未知类型，按最低处理
}

/// 提取预发布后缀里的数字，如 "alpha.1" → 1
int _preNum(String pre) {
  final match = RegExp(r'(\d+)').firstMatch(pre);
  return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
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