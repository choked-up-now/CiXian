import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class ApkDownloader {
  /// 下载 APK 并调起系统安装器。
  /// [onProgress] 回调 0.0 ~ 1.0 的进度。
  /// 返回 null 表示成功，返回字符串表示错误信息。
  static Future<String?> downloadAndInstall({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    if (kIsWeb) {
      return 'Web 端不支持应用内安装';
    }

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/cixian_update.apk';

      // 如果之前下过，先删掉
      final oldFile = File(savePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      // 调起系统安装器
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        return '无法打开安装器：${result.message}';
      }
      return null;
    } catch (e) {
      return '下载失败：$e';
    }
  }
}
