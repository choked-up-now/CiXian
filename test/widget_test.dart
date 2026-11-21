// Copyright 2026 choked-up-now
// SPDX-License-Identifier: MulanPSL-2.0

// 原文件是 Flutter 模板自带的「计数器测试」，与本项目 MyApp 不符，
// 在 CI 里必然失败。替换为不依赖插件、不需要 pumpWidget 的纯函数测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:cixian/data/ebbinghaus.dart';
import 'package:cixian/data/version_checker.dart';

void main() {
  group('compareVersions', () {
    test('主版本号按数值比较', () {
      expect(compareVersions('0.12.3', '0.12.2') > 0, isTrue);
      expect(compareVersions('0.9.0', '0.10.0') < 0, isTrue);
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('0.12', '0.12.0'), 0);
    });

    test('正式版高于预发布版', () {
      expect(compareVersions('0.12.3', '0.12.3-beta.1') > 0, isTrue);
      expect(compareVersions('0.12.3-rc.1', '0.12.3-beta.9') > 0, isTrue);
      expect(compareVersions('0.12.3-rc.2', '0.12.3-rc.1') > 0, isTrue);
    });
  });

  group('Ebbinghaus.retention', () {
    test('节点值', () {
      expect(Ebbinghaus.retention(0), 1.0);
      expect(Ebbinghaus.retention(1), 0.33);
      expect(Ebbinghaus.retention(2), 0.28);
      expect(Ebbinghaus.retention(6), 0.25);
      expect(Ebbinghaus.retention(31), 0.21);
      expect(Ebbinghaus.retention(100), 0.21);
    });

    test('节点之间线性插值且单调不增', () {
      expect(Ebbinghaus.retention(3), closeTo(0.2725, 1e-9));
      var prev = Ebbinghaus.retention(0);
      for (var d = 1; d <= 40; d++) {
        final y = Ebbinghaus.retention(d);
        expect(y <= prev, isTrue, reason: '第 $d 天出现回升');
        expect(y > 0 && y <= 1, isTrue);
        prev = y;
      }
    });
  });
}

