import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudSync {
  static const String _baseUrl = 'https://cixian.pages.dev';

  /// 注册新用户，返回 {user_id, sync_code}
  static Future<Map<String, dynamic>> register() async {
    final response = await http.post(Uri.parse('$_baseUrl/register'));
    if (response.statusCode != 200) {
      throw Exception('注册失败 (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 用同步码恢复账号，返回 {user_id}
  static Future<Map<String, dynamic>> bind(String syncCode) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/bind'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sync_code': syncCode}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? '同步码无效');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 上传进度
  static Future<void> upload(String syncCode, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sync'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sync_code': syncCode, 'data': data}),
    );
    if (response.statusCode != 200) {
      throw Exception('上传失败 (${response.statusCode})');
    }
  }

  /// 下载进度，返回 data 字段；没有数据返回 null
  static Future<Map<String, dynamic>?> download(String syncCode) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/sync?sync_code=$syncCode'),
    );
    if (response.statusCode != 200) {
      throw Exception('下载失败 (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>?;
  }
}
