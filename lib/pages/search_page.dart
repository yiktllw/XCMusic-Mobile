import 'package:flutter/material.dart';
import '../services/api_manager.dart';
import '../utils/app_logger.dart';
import '../config/search_bar_config.dart';
import '../services/search_history_service.dart';
import 'search_result_page.dart';

/// 搜索页面
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _hotSearches = [];
  List<Map<String, dynamic>> _searchSuggestions = [];
  List<String> _searchHistory = [];
  bool _isLoadingHotSearches = true;
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  bool _isHistoryExpanded = false;
  String? _showDeleteButtonFor; // 显示删除按钮的历史项

  @override
  void initState() {
    super.initState();
    _loadHotSearches();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载热搜榜
  Future<void> _loadHotSearches() async {
    try {
      setState(() {
        _isLoadingHotSearches = true;
      });

      final api = ApiManager();
      final result = await api.api.searchHotDetail();
      
      if (result['body']['code'] == 200) {
        final data = result['body']['data'] as List;
        setState(() {
          _hotSearches = data.cast<Map<String, dynamic>>();
          _isLoadingHotSearches = false;
        });
        AppLogger.info('热搜榜加载完成: ${_hotSearches.length} 条');
      } else {
        throw Exception('API返回错误: ${result['body']['code']}');
      }
    } catch (e) {
      AppLogger.error('加载热搜榜失败', e);
      setState(() {
        _isLoadingHotSearches = false;
        _hotSearches = [];
      });
    }
  }

  /// 加载搜索建议
  Future<void> _loadSearchSuggestions(String keywords) async {
    if (keywords.trim().isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoadingSuggestions = true;
        _showSuggestions = true;
      });

      final api = ApiManager();
      final result = await api.api.searchSuggest(keywords: keywords, type: 'mobile');
      
      if (result['body']['code'] == 200 && result['body']['result'] != null) {
        final allMatch = result['body']['result']['allMatch'] as List?;
        if (allMatch != null) {
          setState(() {
            _searchSuggestions = allMatch.cast<Map<String, dynamic>>();
            _isLoadingSuggestions = false;
          });
          AppLogger.info('搜索建议加载完成: ${_searchSuggestions.length} 条');
        } else {
          setState(() {
            _searchSuggestions = [];
            _isLoadingSuggestions = false;
          });
        }
      } else {
        setState(() {
          _searchSuggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      AppLogger.error('加载搜索建议失败', e);
      setState(() {
        _searchSuggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  /// 加载搜索历史
  void _loadSearchHistory() {
    try {
      final history = SearchHistoryService.getSearchHistory();
      setState(() {
        _searchHistory = history;
      });
      AppLogger.info('搜索历史加载完成: ${_searchHistory.length} 条');
    } catch (e) {
      AppLogger.error('加载搜索历史失败', e);
    }
  }

  /// 添加搜索历史
  Future<void> _addSearchHistory(String query) async {
    await SearchHistoryService.addSearchHistory(query);
    _loadSearchHistory();
  }

  /// 删除搜索历史项
  Future<void> _removeSearchHistory(String query) async {
    await SearchHistoryService.removeSearchHistory(query);
    _loadSearchHistory();
  }

  /// 清空搜索历史
  Future<void> _clearSearchHistory() async {
    await SearchHistoryService.clearSearchHistory();
    _loadSearchHistory();
  }

  /// 获取热搜榜图标
  Widget _getHotSearchIcon(Map<String, dynamic> item, int index) {
    // 前三名显示特殊图标
    if (index < 3) {
      Color iconColor;
      switch (index) {
        case 0:
          iconColor = Colors.red;
          break;
        case 1:
          iconColor = Colors.orange;
          break;
        case 2:
          iconColor = Colors.yellow.shade700;
          break;
        default:
          iconColor = Colors.grey;
      }
      
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: iconColor,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    
    // 其他项显示排名数字
    return Text(
      '${index + 1}',
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// 处理搜索
  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    AppLogger.info('执行搜索: $query');
    
    // 添加到搜索历史
    await _addSearchHistory(query.trim());
    
    // 跳转到搜索结果页面，并监听返回值
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultPage(
          query: query.trim(),
          initialType: 1, // 默认搜索歌曲
        ),
      ),
    );
    
    // 如果从搜索结果页面返回了搜索关键词，更新搜索框内容
    if (result != null && result.isNotEmpty) {
      setState(() {
        _searchController.text = result;
      });
    }
    
    // 隐藏搜索建议
    setState(() {
      _showSuggestions = false;
    });
  }

  /// 构建搜索建议列表
  Widget _buildSearchSuggestions() {
    if (_isLoadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchSuggestions.isEmpty) {
      return const Center(
        child: Text(
          '暂无搜索建议',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索建议标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                '搜索建议',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // 搜索建议列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _searchSuggestions.length,
            itemBuilder: (context, index) {
              final item = _searchSuggestions[index];
              final keyword = item['keyword'] as String? ?? '';
              
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _searchController.text = keyword;
                    _performSearch(keyword);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.grey.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            keyword,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // 将建议置入搜索框并继续显示建议
                            _searchController.text = keyword;
                            setState(() {});
                            _loadSearchSuggestions(keyword);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.call_made,
                              color: Colors.grey.shade400,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建主要内容区域
  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索历史
          if (_searchHistory.isNotEmpty) ...[
            _buildSearchHistory(),
            const SizedBox(height: 24),
          ],
          
          // 热搜榜
          if (_hotSearches.isNotEmpty) _buildHotSearches(),
          
          // 如果没有任何内容显示提示
          if (_searchHistory.isEmpty && _hotSearches.isEmpty)
            const Center(
              child: Text(
                '暂无数据',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建搜索历史
  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              '搜索历史',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                _showClearHistoryDialog();
              },
              child: Text(
                '清空',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 历史记录列表
        _buildHistoryItemsWithExpansion(),
      ],
    );
  }

  /// 构建历史记录项和展开功能
  Widget _buildHistoryItemsWithExpansion() {
    // 计算一行能容纳多少个历史项
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // 减去左右padding
    
    // 估算每个历史项的宽度
    List<String> firstRowQueries = [];
    double currentRowWidth = 0;
    
    for (int i = 0; i < _searchHistory.length; i++) {
      final query = _searchHistory[i];
      // 估算文本宽度 (大概每个字符12像素，加上padding)
      final estimatedWidth = query.length * 12.0 + 24 + 8; // 文本 + padding + 间距
      
      if (currentRowWidth + estimatedWidth <= availableWidth) {
        firstRowQueries.add(query);
        currentRowWidth += estimatedWidth;
      } else {
        break;
      }
    }
    
    // 确定显示的历史项
    final displayQueries = _isHistoryExpanded ? _searchHistory : firstRowQueries;
    final hasMoreItems = firstRowQueries.length < _searchHistory.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displayQueries.map((query) => _buildHistoryItem(query)).toList(),
        ),
        if (hasMoreItems) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _isHistoryExpanded = !_isHistoryExpanded;
                _showDeleteButtonFor = null; // 隐藏删除按钮
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isHistoryExpanded 
                        ? '收起' 
                        : '展开更多 (${_searchHistory.length - firstRowQueries.length})',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isHistoryExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建历史记录项
  Widget _buildHistoryItem(String query) {
    final showDeleteButton = _showDeleteButtonFor == query;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (showDeleteButton) {
                // 如果正在显示删除按钮，点击时隐藏删除按钮
                setState(() {
                  _showDeleteButtonFor = null;
                });
              } else {
                // 正常搜索
                _searchController.text = query;
                _performSearch(query);
              }
            },
            onLongPress: () {
              setState(() {
                _showDeleteButtonFor = showDeleteButton ? null : query;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: showDeleteButton 
                      ? Theme.of(context).colorScheme.error.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
                color: showDeleteButton 
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                    : null,
              ),
              child: Text(
                query,
                style: TextStyle(
                  fontSize: 14,
                  color: showDeleteButton 
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        if (showDeleteButton)
          Positioned(
            right: -8,
            top: -8,
            child: GestureDetector(
              onTap: () {
                _removeSearchHistory(query);
                setState(() {
                  _showDeleteButtonFor = null;
                });
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 显示清空历史记录对话框
  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('清空搜索历史'),
          content: const Text('确定要清空所有搜索历史吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSearchHistory();
              },
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
  }

  /// 构建热搜榜
  Widget _buildHotSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 热搜榜标题
        Row(
          children: [
            const Icon(
              Icons.local_fire_department,
              color: Colors.red,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              '热搜榜',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 热搜列表
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: _hotSearches.length,
          itemBuilder: (context, index) {
            final item = _hotSearches[index];
            final searchWord = item['searchWord'] as String? ?? '';
            final content = item['content'] as String? ?? '';
            
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _searchController.text = searchWord;
                  _performSearch(searchWord);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      // 排名图标
                      SizedBox(
                        width: 24,
                        child: _getHotSearchIcon(item, index),
                      ),
                      const SizedBox(width: 12),
                      // 搜索内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              searchWord,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (content.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  content,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // 趋势图标（仅前三名）
                      if (index < 3)
                        Icon(
                          Icons.trending_up,
                          color: Colors.red.shade400,
                          size: 14,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Container(
          height: SearchBarConfig.height,
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: SearchBarConfig.getInputDecoration(
              context,
              hintText: '搜索音乐、歌手、专辑',
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear, 
                        size: SearchBarConfig.iconSize,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            style: SearchBarConfig.getInputTextStyle(context),
            onChanged: (value) {
              setState(() {});
              // 加载搜索建议
              if (value.trim().isNotEmpty) {
                _loadSearchSuggestions(value);
              } else {
                setState(() {
                  _showSuggestions = false;
                  _searchSuggestions = [];
                });
              }
            },
            onSubmitted: _performSearch,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _performSearch(_searchController.text);
            },
            child: Text(
              '搜索',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: _showSuggestions
          ? _buildSearchSuggestions()
          : _isLoadingHotSearches
              ? const Center(child: CircularProgressIndicator())
              : _buildMainContent(),
    );
  }
}
