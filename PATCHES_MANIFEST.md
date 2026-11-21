# 补丁清单

脚本：`apply_patches.py` · 阶段：p1 · 模式：原地修改

| 阶段 | 文件 | 操作 | 说明 |
|---|---|---|---|
| P1 | `schema.sql` | 新增 | D1 建表脚本（仓库原本没有） |
| P1 | `wrangler.toml` | 新增 | D1 绑定配置（仓库原本没有） |
| P1 | `NOTICE` | 新增 | 许可证分片适用与部署配置说明 |
| P1 | `test/widget_test.dart` | 替换 | 模板计数器测试 → 3 组真实纯函数测试 |
| P1 | `.github/workflows/deploy-web.yml` | 替换 | CI 增加 analyze + test 门禁 |
| P1 | `.wrangler/cache/pages.json` | 删除 | 移除误提交的真实 Cloudflare account_id（.gitignore 已有规则，需 git rm --cached） |
| P1 | `README.md` | 替换 | 勘误：删除未适配的 HarmonyOS 4.x 声明 |
| P1 | `README.md` | 替换 | 勘误：删除未适配的 HarmonyOS NEXT 声明 |
| P1 | `README.md` | 替换 | 勘误：内置词书实际只有 1 本 |
| P1 | `README.md` | 替换 | 勘误：简介不再声称内置多版本 |

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
