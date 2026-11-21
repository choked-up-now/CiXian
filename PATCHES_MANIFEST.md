# 补丁清单

脚本：`apply_patches.py` · 阶段：p0 · 模式：原地修改

| 阶段 | 文件 | 操作 | 说明 |
|---|---|---|---|
| P0 | `lib/data/api_client.dart` | 新增 | 新增统一网络层（10s 超时） |
| P0 | `lib/config.dart` | 新增 | 新增全局配置与 APK 来源白名单 |
| P0 | `lib/data/my_words_storage.dart` | 替换 | 引入 dart:math（mergeRemote 需要 max） |
| P0 | `lib/data/my_words_storage.dart` | 替换 | 新增 mergeRemote / _isNewer |
| P0 | `lib/data/sync_manager.dart` | 替换 | uploadNow 携带上次同步时间（乐观锁） |
| P0 | `lib/data/sync_manager.dart` | 替换 | _applyData 改成逐词合并 |
| P0 | `lib/data/cloud_sync.dart` | 替换 | http → ApiClient |
| P0 | `lib/data/cloud_sync.dart` | 替换 | register 走统一超时 |
| P0 | `lib/data/cloud_sync.dart` | 替换 | bind 走统一超时 |
| P0 | `lib/data/cloud_sync.dart` | 替换 | download 走统一超时 |
| P0 | `lib/data/cloud_sync.dart` | 替换 | upload 携带 client_updated_at 并处理 409 |
| P0 | `lib/data/version_checker.dart` | 替换 | import 换成 ApiClient + config |
| P0 | `lib/data/version_checker.dart` | 替换 | 版本检查走统一超时 |
| P0 | `lib/data/version_checker.dart` | 替换 | APK asset 增加来源白名单 |
| P0 | `lib/data/apk_downloader.dart` | 替换 | 引入 config.dart |
| P0 | `lib/data/apk_downloader.dart` | 替换 | 下载前二次校验来源 |
| P0 | `lib/main.dart` | 替换 | 同步加超时兜底 + mounted 检查，杜绝白屏 |
| P0 | `functions/[[path]].js` | 替换 | 服务端乐观锁：旧客户端不得覆盖新进度 |

## 怎么跑

```bash
# 先看「替换全文」，不碰原仓库
python3 apply_patches.py --repo ./CiXian --stage all

# 确认后原地执行
python3 apply_patches.py --repo ./CiXian --stage all --in-place
git -C ./CiXian diff
```

## 回滚

```bash
git -C ./CiXian checkout -- .
git -C ./CiXian clean -fd   # 清掉新增文件
```

## 脚本不做、必须人工决策的事项

1. `android/app/build.gradle.kts` 的 `applicationId = "com.example.cixian"` **不要自动改**：改包名等于换应用，老用户无法升级、数据留在旧包名下。确定要上架时再一次性改，并配正式 keystore（当前 release 用的是 debug key）。
2. `wrangler.toml` 里的 `REPLACE_WITH_YOUR_D1_DATABASE_ID` 填真实值；Pages 控制台的 D1 binding 名必须是 `DB`。
3. 5 个 CI secrets 重新配置：CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID / NETLIFY_AUTH_TOKEN / NETLIFY_SITE_ID（GITHUB_TOKEN 自动注入）。
4. `.wrangler/cache/pages.json` 曾提交真实 account_id，脚本已删文件，还需执行一次 `git rm --cached .wrangler/cache/pages.json`。
5. `web/docs/install.html` 里仍有 HarmonyOS 措辞，需人工改。
6. P2 之后仍需手工：settings_screen.dart / word_list_screen.dart 里剩余 4 处硬编码 URL、大界面拆组件、空 catch 补日志、APK SHA256 校验（需加 package:crypto）。

## 验收

- 飞行模式冷启动，3 秒内进入单词列表
- 双设备交替学习后同步，错题 / 收藏 / 复习次数都不丢
- 伪造 `https://evil.example/x.apk`，更新入口不触发下载
- `flutter analyze` 零 warning、`flutter test` 全绿并接入 CI

## 勘误（重要）

早前一份体检报告因浅克隆中断、工作区检出不全，误判以下内容「缺失」，实际**全部存在**：`web/`（market.html + 7 个 docs 页面）、`windows/`、`test/`、`netlify.toml`、`pubspec.lock`。
另：「零测试」应更正为「有 1 个 Flutter 模板计数器测试，与本项目 MyApp 不符，在 CI 里必然失败」——本脚本 p1 已将其替换。
