import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportHelper {
  /// 将笔记内容导出为 .md 文件并唤起系统分享
  static Future<void> exportNote(String title, String content) async {
    // 文件名：标题中特殊字符替换为下划线
    final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = '$safeName.md';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');

    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: title,
      ),
    );
  }
}
