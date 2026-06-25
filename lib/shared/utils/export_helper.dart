import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 笔记导出工具——将 Markdown 内容写入文件并唤起系统分享。
class ExportHelper {
  ExportHelper._();

  /// 将笔记内容导出为 .md 文件并唤起系统分享。
  static Future<void> exportNote(String title, String content) async {
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
