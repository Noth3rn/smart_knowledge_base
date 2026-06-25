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

/// 时间筛选范围。
enum TimeFilter {
  /// 不限制。
  none('不限'),

  /// 昨天。
  yesterday('昨天'),

  /// 过去七天。
  week('过去七天'),

  /// 过去三十天。
  month('过去三十天');

  const TimeFilter(this.label);
  final String label;
}

/// 搜索结果条目。
class SearchResult {
  final Note note;
  final double similarity;
  final List<String> tags;

  SearchResult({
    required this.note,
    this.similarity = 0,
    this.tags = const [],
  });
}

/// 搜索控制器——管理搜索输入、防抖、筛选、语义/关键词搜索逻辑。
class NoteSearchController extends GetxController {
  final queryController = TextEditingController();

  final _queryText = ''.obs;
  String get queryText => _queryText.value;

  final _allResults = <SearchResult>[].obs;
  final _filteredResults = <SearchResult>[].obs;
  List<SearchResult> get results => _filteredResults;

  final _isSearching = false.obs;
  bool get isSearching => _isSearching.value;

  final _searchMode = SearchMode.idle.obs;
  SearchMode get searchMode => _searchMode.value;

  final _hasSearched = false.obs;
  bool get hasSearched => _hasSearched.value;

  final _filterExpanded = false.obs;
  bool get filterExpanded => _filterExpanded.value;

  final _timeFilter = TimeFilter.none.obs;
  TimeFilter get timeFilter => _timeFilter.value;

  final _selectedTags = <String>{}.obs;
  Set<String> get selectedTags => _selectedTags;

  final _allTags = <String>[].obs;
  List<String> get allTags => _allTags;

  Timer? _debounce;

  AppDatabase get _db => Get.find<AppDatabase>();

  @override
  void onInit() {
    super.onInit();
    _loadAllTags();
  }

  @override
  void onClose() {
    queryController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  /// 加载所有已有标签供筛选栏使用。
  Future<void> _loadAllTags() async {
    try {
      _allTags.value = await _db.getAllDistinctTags();
    } catch (_) {
      _allTags.value = [];
    }
  }

  /// 切换筛选栏展开/收起。
  void toggleFilter() => _filterExpanded.toggle();

  /// 设置时间筛选（再次点击同一项取消选中）。
  void setTimeFilter(TimeFilter filter) {
    _timeFilter.value = _timeFilter.value == filter ? TimeFilter.none : filter;
    _applyFilters();
  }

  /// 切换标签筛选。
  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _applyFilters();
  }

  /// 应用当前筛选条件到全部结果。
  void _applyFilters() {
    var filtered = _allResults.toList();

    if (_timeFilter.value != TimeFilter.none) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final cutoff = switch (_timeFilter.value) {
        TimeFilter.yesterday =>
          todayStart.subtract(const Duration(days: 1)),
        TimeFilter.week =>
          todayStart.subtract(const Duration(days: 7)),
        TimeFilter.month =>
          DateTime(now.year, now.month - 1, now.day),
        _ => todayStart,
      };
      filtered = filtered.where((r) {
        final noteDay = DateTime(
          r.note.updatedAt.year,
          r.note.updatedAt.month,
          r.note.updatedAt.day,
        );
        return !noteDay.isBefore(cutoff);
      }).toList();
    }

    // 标签筛选（笔记包含任一选中标签即可）
    if (_selectedTags.isNotEmpty) {
      filtered = filtered
          .where((r) => r.tags.any((t) => _selectedTags.contains(t)))
          .toList();
    }

    _filteredResults.value = filtered;
  }

  /// 在搜索框文本变化时调用，300ms 防抖。
  void onQueryChanged(String query) {
    _queryText.value = query;
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _allResults.clear();
      _filteredResults.clear();
      _searchMode.value = SearchMode.idle;
      _hasSearched.value = false;
      return;
    }
    _debounce = Timer(
      Duration(milliseconds: AppTheme.constants.debounceMs),
      () => search(query.trim()),
    );
  }

  /// 执行搜索。
  Future<void> search(String query) async {
    if (query.isEmpty) return;

    _isSearching.value = true;
    _hasSearched.value = true;

    try {
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
      try {
        await _keywordSearch(query);
      } catch (_) {
        _allResults.clear();
        _filteredResults.clear();
        _searchMode.value = SearchMode.idle;
      }
    } finally {
      _isSearching.value = false;
    }
  }

  Future<void> _semanticSearch(
    String query,
    EmbeddingService embeddingService,
  ) async {
    _searchMode.value = SearchMode.semantic;

    final queryVector = await embeddingService.embed(query);

    final notes = await _db.getNotesWithEmbedding();
    if (notes.isEmpty) {
      _allResults.clear();
      _filteredResults.clear();
      return;
    }

    final scored = <SearchResult>[];
    for (final note in notes) {
      if (note.embedding == null) continue;
      try {
        final noteVector = VectorUtils.decode(note.embedding!);
        final similarity =
            VectorUtils.cosineSimilarity(queryVector, noteVector);
        if (similarity > AppTheme.constants.similarityThreshold) {
          final noteTags = await _db.getTagsByNoteId(note.id);
          scored.add(SearchResult(
            note: note,
            similarity: similarity,
            tags: noteTags.map((t) => t.name).toList(),
          ));
        }
      } catch (_) {}
    }

    scored.sort((a, b) => b.similarity.compareTo(a.similarity));
    final topK = AppTheme.constants.topK;
    _allResults.value =
        scored.length > topK ? scored.sublist(0, topK) : scored;
    _applyFilters();
  }

  Future<void> _keywordSearch(String query) async {
    _searchMode.value = SearchMode.keyword;
    final notes = await _db.searchByKeyword(query);
    final results = <SearchResult>[];
    for (final n in notes) {
      final noteTags = await _db.getTagsByNoteId(n.id);
      results.add(SearchResult(
        note: n,
        tags: noteTags.map((t) => t.name).toList(),
      ));
    }
    _allResults.value = results;
    _applyFilters();
  }

  /// 清空搜索结果和输入框。
  void clear() {
    queryController.clear();
    _queryText.value = '';
    _allResults.clear();
    _filteredResults.clear();
    _searchMode.value = SearchMode.idle;
    _hasSearched.value = false;
    _timeFilter.value = TimeFilter.none;
    _selectedTags.clear();
    _filterExpanded.value = false;
  }
}
