# 词冼 CiXian

> 一个极简的背单词软件，内置多版本教材词书，支持云同步与自定义词书。

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B?logo=flutter)](https://flutter.dev)

---

## 简介

**词冼**是一个用 Flutter 开发的跨平台背单词工具，目标是**极简、专注、无干扰**。

它不是百词斩、不是墨墨、不是不背单词。它只做一件事：**把你该背的单词，用最科学的方式递到你面前**。

---

## 功能特性

- **多版本教材词书**：外研版、译林版、人教版、北师大版（九年级上册）
- **五种题型**：英选中、中选英、看中译英、听音选意、听音选词，可自由开关
- **每日学习**：新词 + 旧词混合，答完即出成绩
- **智能出题**：
  - 带权重随机（错得多、忘得快的词优先）
  - 接入艾宾浩斯遗忘曲线（1 / 2 / 6 / 31 天节点）
- **我的单词**：错题 / 已掌握 / 收藏，三类分开管理
- **单词发音**：点击喇叭听读音，可调速、可试听
- **云同步**：用同步码，学习进度跨设备同步，换手机不丢数据
- **自定义词书**：导入自己的 JSON 词书
- **词书市场**：从官方词书库浏览、下载更多教材词书
- **应用内更新**：检测新版本，一键下载安装
- **帮助中心**：完整的在线使用文档

---

## 下载与访问

### Android / HarmonyOS 4.x

前往 [Releases](https://atomgit.com/choked-up-now/CiXian/releases) 下载最新版 `app-arm64-v8a-release.apk`。

> 安装时请允许"未知来源应用"。

### iPhone / HarmonyOS NEXT / 其他设备

用浏览器打开网页版：

**https://cixian.pages.dev**

在 Safari 中点击"分享" → "添加到主屏幕"，即可像原生 App 一样全屏使用。

### 帮助文档

**https://cixian.pages.dev/docs/**

---

## 词书格式

词冼使用 JSON 格式存储词书。一个标准的词书文件长这样：

```json
[
  {
    "word": "textbook",
    "phonetic": "/ˈtekstbʊk/",
    "pos": "n.",
    "meaning": "教科书；课本",
    "example": "This is an English textbook."
  }
]
```

字段说明：

| 字段 | 必填 | 说明 |
|------|------|------|
| `word` | 是 | 单词 |
| `meaning` | 是 | 中文释义 |
| `phonetic` | 否 | 音标 |
| `pos` | 否 | 词性 |
| `example` | 否 | 例句 |

官方词书库地址：[CiXianWordBook](https://atomgit.com/choked-up-now/CiXianWordBook)

---

## 开发

### 环境要求

- Flutter 3.47.2 或更高
- Dart 3.0 或更高
- Android Studio（用于 Android 打包）
- Node.js（用于 wrangler 部署）

### 本地运行

```bash
flutter pub get
flutter run -d web-server --web-port=5000
```

### 打包发布

```bash
# Web 版
flutter build web --release
npx wrangler pages deploy build/web --project-name=cixian

# Android 版
flutter build apk --release --split-per-abi
```

### 项目结构

```
lib/
├── data/               数据层
│   ├── cloud_sync.dart       云同步 API
│   ├── ebbinghaus.dart       遗忘曲线
│   ├── my_words_storage.dart 单词记录存储
│   ├── sync_manager.dart     同步管理
│   ├── tts_service.dart      发音服务
│   ├── user_settings.dart    用户设置（题型、学习量）
│   ├── version_checker.dart  版本检测
│   └── wordbook_storage.dart 词书管理
├── models/
│   └── word.dart             单词模型
├── screens/            页面
│   ├── daily_learning_screen.dart  每日学习（五种题型）
│   ├── my_words_screen.dart        我的单词
│   ├── settings_screen.dart        设置
│   ├── word_list_screen.dart       单词列表
│   └── wordbook_manager_screen.dart 词书管理
└── main.dart           入口

functions/
└── [[path]].js         Cloudflare Pages Functions（后端 API）

web/
├── market.html         词书市场
└── docs/               用户帮助文档
```

### 后端架构

- **Cloudflare Pages Functions** —— Serverless API
- **Cloudflare D1** —— SQLite 数据库（用户、进度、词书选择）
- **AtomGit** —— 词书文件托管

---

## 支持作者

如果觉得词冼有用，欢迎请作者喝杯奶茶：

**https://afdian.com/a/choked-up-now**

你的支持是持续更新的动力。

---

## 更新日志

### v0.12.2
- 自动检测设备 ABI，下载对应架构的 APK
- 新增反馈与建议入口
- 所有源文件添加 Apache 2.0 许可证头

### v0.12.0
- 新增五种题型（英选中、中选英、看中译英、听音选意、听音选词），可自由开关
- 词书市场入口（网页版）
- 修复 Android 端外链跳转失败

### v0.11.0
- 词书市场（网页版）
- 用户词书 API

### v0.10.0
- 帮助中心
- 词书代理接口
- 爱发电入口

### v0.9.0
- 带权重出题（错得多、忘得快的词优先）
- 接入艾宾浩斯遗忘曲线
- 每日学习量可自定义

### v0.8.1
- 云同步（同步码）
- 我的单词（错题 / 已掌握 / 收藏）
- 词书管理重构

### v0.7.1
- 支持预发布版本号比较
- 接收测试版本开关

### v0.7.0
- 应用内下载更新

### v0.6.1
- 语速设置
- 平台差异化默认语速

### v0.6.0
- 单词发音

### v0.5.3
- 修复检查更新

### v0.4.0
- 错题本

### v0.1.0
- 每日学习（四选一）

### v0.0.1
- 初始版本：单词列表 + 详情弹窗

---

## 开源许可

本项目基于 **Apache License 2.0** 开源，详见 [LICENSE](LICENSE)。

词书内容仅用于个人学习参考，版权归原出版方所有。如权利人认为侵权，请联系删除。

---

## 致谢

- 感谢 [Flutter](https://flutter.dev) 提供跨平台开发框架
- 感谢 [Cloudflare](https://cloudflare.com) 提供免费的后端服务
- 感谢 [AtomGit](https://atomgit.com) 提供代码托管
- 感谢每一位使用词冼的同学

---

<p align="center">
  <b>词冼 CiXian</b>
  <br>
  一个极简的背单词软件
</p>