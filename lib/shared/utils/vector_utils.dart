import 'dart:math';
import 'dart:typed_data';

/// 向量编解码工具。
///
/// 统一使用 [Float64List] ↔ [Uint8List] 转换，
/// 用于将嵌入向量存入数据库 BLOB 列以及从 BLOB 解码回浮点列表。
class VectorUtils {
  VectorUtils._();

  /// 将浮点向量编码为 BLOB 兼容的字节数组。
  static Uint8List encode(List<double> vector) {
    return Float64List.fromList(vector).buffer.asUint8List();
  }

  /// 从 BLOB 字节数组解码回浮点向量。
  static List<double> decode(Uint8List bytes) {
    return bytes.buffer.asFloat64List().toList();
  }

  /// 计算两个等长向量的余弦相似度。
  ///
  /// 返回 [-1.0, 1.0] 之间的值，1.0 表示完全相同。
  /// 任一向量模长为 0 时返回 0。
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('向量长度不匹配: ${a.length} vs ${b.length}');
    }

    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }
}
