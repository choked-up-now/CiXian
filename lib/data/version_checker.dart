// Copyright 2026 choked-up-now
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionChecker {
  static const String _owner = 'choked-up-now';
  static const String _repo = 'CiXian';

  static const String _latestApiUrl =
      'https://api.atomgit.com/api/v5/repos/$_owner/$_repo/releases/latest';
  static const String _allApiUrl =
      'https://api.atomgit.com/api/v5/repos/$_owner/$_repo/releases';

  static const String _acceptPreReleaseKey = 'accept_prerelease';

  static Future<bool> isAcceptPreRelease() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptPreReleaseKey) ?? false;
  }

  static Future<void> setAcceptPreRelease(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptPreReleaseKey, value);
  }

  static Future<VersionCheckResult> check() async {
    try {
      final acceptPre = await isAcceptPreRelease();
      final url = acceptPre ? _allApiUrl : _latestApiUrl;
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        return VersionCheckResult(error: '无法获取版本信息 (${response.statusCode})');
      }

      String? latestVersion;
      String apkUrl = '';
      const releaseUrl = 'https://atomgit.com/$_owner/$_repo/releases';

      if (acceptPre) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isEmpty) return VersionCheckResult(error: '暂无任何版本');

        Map<String, dynamic>? best;
        String bestVersion = '';
        for (final item in list) {
          final tag = (item['tag_name'] as String? ?? '').replaceFirst('v', '');
          if (tag.isEmpty) continue;
          if (item['draft'] == true) continue;
          if (best == null || compareVersions(tag, bestVersion) > 0) {
            best = item as Map<String, dynamic>;
            bestVersion = tag;
          }
        }
        if (best == null) return VersionCheckResult(error: '暂无可用版本');
        latestVersion = bestVersion;
        apkUrl = await _findApkUrl(best);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tag = data['tag_name'] as String? ?? '';
        latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
        apkUrl = await _findApkUrl(data);
      }

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
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

  /// 根据当前设备的 CPU 架构，挑选合适的 APK
  static Future<String> _findApkUrl(Map<String, dynamic> data) async {
    final assets = data['assets'] as List<dynamic>? ?? [];
    if (assets.isEmpty) return '';

    // 收集所有 apk
    final apks = <String, String>{}; // name -> url
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      final url = asset['browser_download_url'] as String? ?? '';
      if (name.endsWith('.apk') && url.isNotEmpty) {
        apks[name] = url;
      }
    }
    if (apks.isEmpty) return '';

    // Web 端：直接返回 arm64（Web 端不会真装 APK）
    if (kIsWeb) {
      return _pickApk(apks, 'arm64-v8a');
    }

    // Android 端：检测当前设备支持的首选 ABI
    final abi = await _getDeviceAbi();

    final preference = <String>[];
    switch (abi) {
      case 'arm64-v8a':
        preference.addAll(['arm64-v8a', 'armeabi-v7a']);
        break;
      case 'armeabi-v7a':
      case 'armeabi':
        preference.addAll(['armeabi-v7a', 'arm64-v8a']);
        break;
      case 'x86_64':
        preference.addAll(['x86_64', 'arm64-v8a', 'armeabi-v7a']);
        break;
      case 'x86':
        preference.addAll(['x86', 'x86_64', 'armeabi-v7a']);
        break;
      default:
        preference.addAll(['arm64-v8a', 'armeabi-v7a', 'x86_64']);
    }

    for (final abiName in preference) {
      final url = _pickApk(apks, abiName);
      if (url.isNotEmpty) return url;
    }

    return apks.values.first;
  }

  static String _pickApk(Map<String, String> apks, String abi) {
    for (final entry in apks.entries) {
      if (entry.key.contains(abi)) return entry.value;
    }
    return '';
  }

  /// 获取当前 Android 设备的首选 ABI
  static Future<String> _getDeviceAbi() async {
    try {
      if (Platform.isAndroid) {
        final plugin = DeviceInfoPlugin();
        final info = await plugin.androidInfo;
        final abis = info.supportedAbis;
        if (abis.isNotEmpty) return abis.first;
      }
    } catch (_) {}
    return 'arm64-v8a';
  }
}

// ============ 版本比较器 ============

int compareVersions(String a, String b) {
  final aDash = a.split('-');
  final bDash = b.split('-');

  final aMain = _parseMain(aDash[0]);
  final bMain = _parseMain(bDash[0]);

  for (int i = 0; i < 3; i++) {
    if (aMain[i] != bMain[i]) {
      return aMain[i].compareTo(bMain[i]);
    }
  }

  final aPre = aDash.length > 1 ? aDash.sublist(1).join('-') : null;
  final bPre = bDash.length > 1 ? bDash.sublist(1).join('-') : null;

  if (aPre == null && bPre == null) return 0;
  if (aPre == null) return 1;
  if (bPre == null) return -1;

  final aType = _preType(aPre);
  final bType = _preType(bPre);
  if (aType != bType) return aType.compareTo(bType);
  return _preNum(aPre).compareTo(_preNum(bPre));
}

List<int> _parseMain(String s) {
  final parts = s.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.sublist(0, 3);
}

int _preType(String pre) {
  final lower = pre.toLowerCase();
  if (lower.startsWith('alpha')) return 1;
  if (lower.startsWith('beta')) return 2;
  if (lower.startsWith('rc')) return 3;
  return 0;
}

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
