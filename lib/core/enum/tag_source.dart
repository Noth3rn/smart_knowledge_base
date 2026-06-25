/// 标签来源枚举。
///
/// [manual] 表示用户手动添加的标签，[llm] 表示 LLM 自动生成的标签。
enum TagSource {
  /// 用户手动添加。
  manual('manual'),

  /// LLM 自动生成。
  llm('llm');

  const TagSource(this.value);

  /// 数据库中存储的字符串值。
  final String value;
}
