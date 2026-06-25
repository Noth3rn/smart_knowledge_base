import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/database/app_database.dart';
import '../../core/embedding/embedding_service.dart';
import '../../shared/utils/vector_utils.dart';
import '../../theme/app_theme.dart';

/// 搜索模式。
enum SearchMode {
  /// 空闲（未搜索）。
  idle,

  /// 语义搜索（嵌入向量可用时）。
  semantic,

  /// 关键词搜索（嵌入不可用时的降级模式）。
  keyword,
}

/// 搜索结果条目。
class SearchResult {
  final Note note;
  final double similarity; // 仅语义模式有效，关键词模式为 0

  SearchResult({required this.note, this.similarity = 0});
}

/// 搜索控制器——管理搜索输入、防抖、语义/关键词搜索逻辑。
class NoteSearchController extends GetxController {
  final queryController = TextEditingController();

  final _queryText = ''.obs;
  String get queryText => _queryText.value;

  final _results = <SearchResult>[].obs;
  List<SearchResult> get results => _results;

  final _isSearching = false.obs;
  bool get isSearching => _isSearching.value;

  final _searchMode = SearchMode.idle.obs;
  SearchMode get searchMode => _searchMode.value;

  final _hasSearched = false.obs;
  bool get hasSearched => _hasSearched.value;

  Timer? _debounce;

  AppDatabase get _db => Get.find<AppDatabase>();

  @override
  void onClose() {
    queryController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  /// 在搜索框文本变化时调用，300ms 防抖。
  void onQueryChanged(String query) {
    _queryText.value = query;
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _results.clear();
      _searchMode.value = SearchMode.idle;
      _hasSearched.value = false;
      return;
    }
    _debounce = Timer(
      Duration(milliseconds: AppTheme.constants.debounceMs),
      () {
      search(query.trim());
    });
  }

  /// 执行搜索。
  Future<void> search(String query) async {
    if (query.isEmpty) return;

    _isSearching.value = true;
    _hasSearched.value = true;

    try {
      // 检查嵌入服务是否可用
      EmbeddingService? embeddingService;
      if (Get.isRegistered<EmbeddingService>()) {
        embeddingService = Get.find<EmbeddingService>();
      }

      if (embeddingService != null && embeddingService.isAvailable) {
        await _semanticSearch(query, embeddingService);
      } else {
        await _keywordSearch(query);
      }
    } catch (_) {
      // 语义搜索失败，降级为关键词搜索
      try {
        await _keywordSearch(query);
      } catch (_) {
        _results.clear();
        _searchMode.value = SearchMode.idle;
      }
    } finally {
      _isSearching.value = false;
    }
  }

  /// 语义搜索：嵌入查询 → 余弦相似度 → 排序 → Top 20。
  Future<void> _semanticSearch(
    String query,
    EmbeddingService embeddingService,
  ) async {
    _searchMode.value = SearchMode.semantic;

    // 1. 嵌入查询文本
    final queryVector = await embeddingService.embed(query);

    // 2. 获取有嵌入向量的笔记
    final notes = await _db.getNotesWithEmbedding();
    if (notes.isEmpty) {
      _results.clear();
      return;
    }

    // 3. 计算余弦相似度
    final scored = <SearchResult>[];
    for (final note in notes) {
      if (note.embedding == null) continue;
      try {
        final noteVector = VectorUtils.decode(note.embedding!);
        final similarity =
            VectorUtils.cosineSimilarity(queryVector, noteVector);
        if (similarity > AppTheme.constants.similarityThreshold) {
          // 过滤低相关
          scored.add(SearchResult(note: note, similarity: similarity));
        }
      } catch (_) {
        // 解码失败，跳过此条
      }
    }

    // 4. 按相似度降序排列，取 Top 20
    scored.sort((a, b) => b.similarity.compareTo(a.similarity));
    final topK = AppTheme.constants.topK;
    _results.value = scored.length > topK ? scored.sublist(0, topK) : scored;
  }

  /// 关键词搜索：使用 SQL LIKE 进行全文匹配。
  Future<void> _keywordSearch(String query) async {
    _searchMode.value = SearchMode.keyword;
    final notes = await _db.searchByKeyword(query);
    _results.value = notes.map((n) => SearchResult(note: n)).toList();
  }

  /// 清空搜索结果和输入框。
  void clear() {
    queryController.clear();
    _queryText.value = '';
    _results.clear();
    _searchMode.value = SearchMode.idle;
    _hasSearched.value = false;
  }
}
