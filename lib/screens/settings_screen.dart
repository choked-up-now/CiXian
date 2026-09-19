import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../data/wordbook_storage.dart';
import '../data/my_words_storage.dart';
import '../data/version_checker.dart';
import '../data/tts_service.dart';
import '../data/apk_downloader.dart';
import '../data/sync_manager.dart';
import '../data/user_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('缓存已清理完毕！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  void _clearData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空当前词书记录'),
        content: const Text('确定要清空当前词书的全部学习记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final bookId = await WordbookStorage.currentId();
              await MyWordsStorage.clearBook(bookId);
              SyncManager.scheduleUpload();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清空当前词书记录')),
                );
              }
            },
            child: const Text('确定清除'),
          ),
        ],
      ),
    );
  }

  // 每日学习量设置
  Future<void> _showDailyCountDialog() async {
    final newCount = await UserSettings.dailyNew();
    final reviewCount = await UserSettings.dailyReview();

    final newCtrl = TextEditingController(text: newCount.toString());
    final reviewCtrl = TextEditingController(text: reviewCount.toString());

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('每日学习量'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每日新词数量',
                hintText: '默认 10',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reviewCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每日复习数量',
                hintText: '默认 10',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
        ],
      ),
    );

    if (ok != true) return;
    final n1 = int.tryParse(newCtrl.text.trim()) ?? 10;
    final n2 = int.tryParse(reviewCtrl.text.trim()) ?? 10;
    await UserSettings.setDailyNew(n1.clamp(1, 100));
    await UserSettings.setDailyReview(n2.clamp(1, 100));
    if (mounted) setState(() {});
  }

  Future<void> _toggleCloudSync() async {
    final enabled = await SyncManager.isEnabled();

    if (enabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('关闭云同步'),
          content: const Text('关闭后本地数据仍保留，但不再自动上传到云端。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('关闭')),
          ],
        ),
      );
      if (confirm == true) {
        await SyncManager.disable();
        if (mounted) setState(() {});
      }
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开启云同步'),
        content: const Text('请选择：\n\n· 首次开启请选择「新建同步码」\n· 换设备时选择「输入已有同步码」'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'restore'),
              child: const Text('输入同步码')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'new'),
              child: const Text('新建同步码')),
        ],
      ),
    );

    if (choice == 'new') {
      try {
        final code = await SyncManager.enableAndRegister();
        if (mounted) {
          setState(() {});
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('云同步已开启 🎉'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('这是你的同步码，请妥善保存：'),
                  const SizedBox(height: 12),
                  SelectableText(
                    code,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '换设备时输入这个同步码即可恢复数据。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('我知道了')),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('开启失败：$e')),
          );
        }
      }
    } else if (choice == 'restore') {
      final controller = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('输入同步码'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '例如：ABC-DEF-123'),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('恢复')),
          ],
        ),
      );
      if (code != null && code.trim().isNotEmpty) {
        try {
          await SyncManager.bindWithCode(code);
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已恢复云端数据')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('恢复失败：$e')),
            );
          }
        }
      }
    }
  }

  void _checkUpdate() async {
    final acceptPre = await VersionChecker.isAcceptPreRelease();
    if (!mounted) return;

    final shouldCheck = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('检查更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('接收测试版本'),
                subtitle: const Text('开启后可收到开发中的抢先版本，可能不够稳定'),
                value: acceptPre,
                onChanged: (value) async {
                  await VersionChecker.setAcceptPreRelease(value);
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('开始检查'),
            ),
          ],
        ),
      ),
    );
    if (shouldCheck != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await VersionChecker.check();
    if (!mounted) return;
    Navigator.pop(context);

    if (result.error != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('检查失败'),
          content: Text(result.error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('好的'),
            ),
          ],
        ),
      );
      return;
    }

    if (result.hasUpdate) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('发现新版本 🎉'),
          content: Text(
            '当前版本：${result.currentVersion}\n'
            '最新版本：${result.latestVersion}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final url = result.androidUrl.isNotEmpty
                    ? result.androidUrl
                    : result.releaseUrl;
                if (url.isEmpty) return;
                if (kIsWeb) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } else {
                  await _downloadAndInstall(url);
                }
              },
              child: const Text('去下载'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('已是最新版本'),
          content: Text('当前版本：${result.currentVersion}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('好的'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _downloadAndInstall(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载链接无效')),
      );
      return;
    }

    final progress = ValueNotifier<double>(0);
    bool isClosing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('正在下载更新'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value == 0 ? null : value),
                const SizedBox(height: 12),
                Text('${(value * 100).toStringAsFixed(0)}%'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              isClosing = true;
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );

    final error = await ApkDownloader.downloadAndInstall(
      url: url,
      onProgress: (p) => progress.value = p,
    );
    if (!mounted) return;
    if (!isClosing) Navigator.pop(context);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  void _showRateDialog() {
    double tempRate = TtsService().rate;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('语速设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前语速：${tempRate.toStringAsFixed(2)}'),
              Slider(
                value: tempRate,
                min: 0.2,
                max: 1.0,
                divisions: 16,
                label: tempRate.toStringAsFixed(2),
                onChanged: (value) {
                  setDialogState(() => tempRate = value);
                },
                onChangeEnd: (value) async {
                  await TtsService().setRate(value);
                  SyncManager.scheduleUpload();
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  TtsService().speak('Hello everyone');
                },
                icon: const Icon(Icons.volume_up),
                label: const Text('试听：Hello everyone'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: const Text('查看是否有新版本'),
            onTap: _checkUpdate,
          ),
          FutureBuilder<List<int>>(
            future: Future.wait(
                [UserSettings.dailyNew(), UserSettings.dailyReview()]),
            builder: (context, snapshot) {
              final n = snapshot.data?[0] ?? 10;
              final r = snapshot.data?[1] ?? 10;
              return ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('每日学习量'),
                subtitle: Text('新词 $n 个 · 复习 $r 个'),
                onTap: _showDailyCountDialog,
              );
            },
          ),
          FutureBuilder<bool>(
            future: SyncManager.isEnabled(),
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? false;
              return ListTile(
                leading: Icon(enabled ? Icons.cloud_done : Icons.cloud_off),
                title: const Text('云同步'),
                subtitle: Text(enabled ? '已开启，学习进度自动同步' : '未开启，点击启用多设备同步'),
                onTap: _toggleCloudSync,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('语速设置'),
            subtitle: const Text('调整发音速度，可试听'),
            onTap: _showRateDialog,
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('缓存清理'),
            subtitle: const Text('清理临时文件，释放空间'),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('清空当前词书记录'),
            subtitle: const Text('删除当前词书的错题/已掌握/收藏'),
            onTap: _clearData,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '词冼 CiXian\n一个极简背单词软件\n基于 Apache License 2.0 开源',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
