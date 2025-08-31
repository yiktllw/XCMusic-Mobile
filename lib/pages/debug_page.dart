import 'package:flutter/material.dart';
import '../utils/global_config.dart';
import '../services/api_manager.dart';
import '../utils/top_banner.dart';

/// 调试信息页面
/// 显示全局配置状态和API状态信息
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  /// 获取全局配置实例（确保使用已初始化的单例）
  GlobalConfig get _globalConfig => GlobalConfig();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试信息'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildApiStatusSection(),
            const SizedBox(height: 24),
            _buildGlobalConfigSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// 构建API状态部分
  Widget _buildApiStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API 状态',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatusItem(
              'API 初始化状态',
              ApiManager().isInitialized ? '已初始化' : '未初始化',
            ),
            _buildStatusItem(
              'API 日志状态',
              ApiManager().getApiLogging() ? '开启' : '关闭',
            ),
            if (ApiManager().isInitialized) ...[
              _buildStatusItem(
                '可用模块数量',
                '${ApiManager().getAvailableModules().length}',
              ),
              const SizedBox(height: 8),
              const Text(
                '可用模块:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: ApiManager()
                    .getAvailableModules()
                    .take(10) // 只显示前10个模块，避免界面过长
                    .map(
                      (module) => Chip(
                        label: Text(
                          module,
                          style: const TextStyle(fontSize: 10),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
              if (ApiManager().getAvailableModules().length > 10)
                Text(
                  '...还有 ${ApiManager().getAvailableModules().length - 10} 个模块',
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建全局配置部分
  Widget _buildGlobalConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GlobalConfig 状态',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatusItem(
              '初始化状态',
              _globalConfig.isInitialized ? '已初始化' : '未初始化',
            ),
            if (_globalConfig.isInitialized) ...[
              _buildStatusItem('配置项数量', '${_globalConfig.length}'),
              _buildStatusItem(
                '登录状态',
                _globalConfig.isLoggedIn() ? '已登录' : '未登录',
              ),
              _buildStatusItem(
                '用户Cookie',
                _globalConfig.getUserCookie() != null ? '已保存' : '未保存',
              ),
              _buildStatusItem('主题模式', _globalConfig.getThemeMode()),
              _buildStatusItem('语言', _globalConfig.getLanguage()),
              _buildStatusItem(
                '音量',
                '${(_globalConfig.getVolume() * 100).toInt()}%',
              ),
              const SizedBox(height: 12),
              const Text(
                '所有配置键:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              if (_globalConfig.keys.isEmpty)
                const Text('无配置数据')
              else
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _globalConfig.keys
                      .map(
                        (key) => Chip(
                          label: Text(
                            key,
                            style: const TextStyle(fontSize: 10),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('详细配置数据'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _globalConfig.getAllConfig().toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _toggleApiLogging,
                  icon: Icon(
                    ApiManager().getApiLogging()
                        ? Icons.volume_off
                        : Icons.volume_up,
                  ),
                  label: Text(
                    ApiManager().getApiLogging() ? '关闭API日志' : '开启API日志',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testApiCall,
                  icon: const Icon(Icons.api),
                  label: const Text('测试API调用'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _clearAllConfig,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('清空所有配置'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建状态项
  Widget _buildStatusItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// 切换API日志状态
  void _toggleApiLogging() {
    final currentState = ApiManager().getApiLogging();
    ApiManager().setApiLogging(!currentState);
    setState(() {});

    TopBanner.showInfo(
      context,
      'API日志已${!currentState ? '开启' : '关闭'}',
      duration: const Duration(seconds: 2),
    );
  }

  /// 测试API调用
  Future<void> _testApiCall() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!ApiManager().isInitialized) {
        throw Exception('API未初始化');
      }

      // 测试一个简单的API调用
      final result = await ApiManager().api.loginQrKey();

      if (mounted) {
        TopBanner.showSuccess(
          context,
          'API测试成功: ${result['status']}',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        TopBanner.showError(
          context,
          'API测试失败: $e',
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 清空所有配置
  Future<void> _clearAllConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有配置数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_globalConfig.isInitialized) {
        await _globalConfig.clear();
        // 重新初始化
        await _globalConfig.initialize();
      }

      if (mounted) {
        TopBanner.showWarning(
          context,
          '配置已清空',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        TopBanner.showError(
          context,
          '清空配置失败: $e',
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
