import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:say_hi_flutter/model/chat_info_model.dart';
import 'package:say_hi_flutter/service/chat_service.dart';
import 'package:say_hi_flutter/service/storage_service.dart';
import 'package:say_hi_flutter/widget/swipeable_chat_item.dart';

// 消息页面
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  List<ChatInfo> _chatList = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasMore = true;
  int? _lastActiveTime;

  @override
  void initState() {
    super.initState();
    _loadChatList();
    _scrollController.addListener(_onScroll);
  }

  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = 200.0; // 距离底部200px时开始加载

    if (maxScroll - currentScroll <= delta && !_isLoading && !_isLoadingMore && _hasMore) {
      print('📜 滚动到底部，开始加载更多数据');
      _loadMoreChatList();
    }
  }

  Future<void> _loadMoreChatList() async {
    if (_isLoadingMore || !_hasMore) return;

    print('🔄 _loadMoreChatList - 开始加载更多数据');

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // 如果_lastActiveTime为null，使用当前时间的毫秒时间戳
      final timestamp = _lastActiveTime ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final response = await _chatService.getChatList(
        timestamp: timestamp,
        limit: 10,
      );

      print('🌐 加载更多请求: timestamp=$timestamp, limit=10');
      print('🌐 加载更多响应完成: success=${response.success}, code=${response.code}');
      print('🌐 数据条数: ${response.chatInfos.length}, hasMore: ${response.hasMore}');

      if (mounted && response.success && (response.code == 0 || response.code == 200)) {
        // 计算当前批次的最小活跃时间，用于下次分页请求
        if (response.chatInfos.isNotEmpty) {
          final minActiveTime = response.chatInfos
              .map((chat) => chat.lastActiveTime)
              .reduce((a, b) => a < b ? a : b);

          print('📊 加载更多 - 当前批次最小活跃时间: $minActiveTime');

          setState(() {
            _lastActiveTime = minActiveTime;
            _hasMore = response.hasMore;
            _chatList.addAll(response.chatInfos);

            // 重新排序整个列表
            _chatList.sort((a, b) {
              if (a.stickyTop != b.stickyTop) {
                return a.stickyTop ? -1 : 1;
              }
              if (a.lastActiveTime != b.lastActiveTime) {
                return b.lastActiveTime.compareTo(a.lastActiveTime);
              }
              return b.priority.compareTo(a.priority);
            });

            _isLoadingMore = false;
          });

          print('✅ 加载更多完成，当前总数据量: ${_chatList.length}');
        } else {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      print('❌ _loadMoreChatList 异常: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadChatList({bool isRefresh = false}) async {
    print('🔄 ChatPage._loadChatList - 开始加载会话列表 (isRefresh: $isRefresh)');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
        if (isRefresh) {
          _hasMore = true;
          _lastActiveTime = null;
        }
      });
    }

    try {
      // 如果是刷新，先从本地数据库加载数据
      if (isRefresh) {
        print('📱 从本地数据库加载数据...');
        final localChatList = await StorageService.getChatList();
        print('📱 本地数据数量: ${localChatList.length}');

        if (mounted && localChatList.isNotEmpty) {
          print('📱 使用本地数据更新UI');
          setState(() {
            _chatList = localChatList;
            _isLoading = false;
          });
        }
      }

      // 从服务器获取数据
      // 如果_lastActiveTime为null，使用当前时间的毫秒时间戳
      final timestamp = _lastActiveTime ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      print('🌐 从服务器获取数据...');
      print('🌐 查询参数: timestamp=$timestamp, limit=10, hasMore=$_hasMore');

      final response = await _chatService.getChatList(
        timestamp: timestamp,
        limit: 10,
      );

      print('🌐 服务器响应完成: success=${response.success}, code=${response.code}');
      print('🌐 数据条数: ${response.chatInfos.length}, hasMore: ${response.hasMore}');

      if (mounted) {
        if (response.success && (response.code == 0 || response.code == 200)) {
          print('✅ 服务器数据获取成功');

          // 计算当前批次的最小活跃时间，用于下次分页请求
          if (response.chatInfos.isNotEmpty) {
            final minActiveTime = response.chatInfos
                .map((chat) => chat.lastActiveTime)
                .reduce((a, b) => a < b ? a : b);

            print('📊 当前批次最小活跃时间: $minActiveTime');

            setState(() {
              _lastActiveTime = minActiveTime;
              _hasMore = response.hasMore;
            });
          } else {
            setState(() {
              _hasMore = false;
            });
          }

          List<ChatInfo> updatedChatList;
          if (isRefresh) {
            // 刷新：直接使用新数据
            updatedChatList = List<ChatInfo>.from(response.chatInfos);
            print('✅ 刷新模式，直接使用新数据');
          } else {
            // 分页：追加到现有数据
            updatedChatList = List<ChatInfo>.from(_chatList)..addAll(response.chatInfos);
            print('✅ 分页模式，追加数据到现有列表');
          }

          // 排序逻辑：置顶会话在前，非置顶会话在后
          // 在置顶和非置顶两组内，都按活跃时间和优先级降序排列
          updatedChatList.sort((a, b) {
            // 1. 先按置顶状态分组：置顶的在前，非置顶的在后
            if (a.stickyTop != b.stickyTop) {
              return a.stickyTop ? -1 : 1;
            }

            // 2. 在相同置顶状态内，按活跃时间降序排列（最近活跃的在前）
            if (a.lastActiveTime != b.lastActiveTime) {
              return b.lastActiveTime.compareTo(a.lastActiveTime);
            }

            // 3. 活跃时间相同时，按优先级降序排列（优先级高的在前）
            return b.priority.compareTo(a.priority);
          });

          print('✅ 保存到本地数据库');
          // 保存到本地数据库
          await StorageService.saveChatList(updatedChatList);

          print('✅ 使用服务器数据更新UI，最终数据量: ${updatedChatList.length}');
          setState(() {
            _chatList = updatedChatList;
            _isLoading = false;
          });
        } else {
          print('⚠️ 服务器响应异常: success=${response.success}, code=${response.code}, message=${response.message}');

          final localChatList = await StorageService.getChatList();
          // 如果服务器请求失败，且有本地数据，则不显示错误
          if (localChatList.isNotEmpty) {
            print('⚠️ 使用本地数据，不显示错误');
            setState(() {
              _isLoading = false;
            });
          } else {
            print('❌ 没有本地数据，显示错误');
            setState(() {
              _hasError = true;
              _errorMessage = response.message.isNotEmpty
                  ? response.message
                  : '获取会话列表失败';
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('❌ ChatPage._loadChatList 异常: $e');

      // 如果服务器请求失败，且有本地数据，则不显示错误
      final localChatList = await StorageService.getChatList();
      print('📱 异常处理中，本地数据数量: ${localChatList.length}');

      if (mounted && localChatList.isNotEmpty) {
        print('❌ 使用本地数据，不显示错误');
        setState(() {
          _chatList = localChatList;
          _isLoading = false;
        });
      } else if (mounted) {
        print('❌ 没有本地数据，显示错误: $e');
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }

    print('🔄 ChatPage._loadChatList - 完成');
  }

  String _formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    // 将日期转换为20250102格式的整数
    final todayInt = now.year * 10000 + now.month * 100 + now.day;
    final messageInt = dateTime.year * 10000 + dateTime.month * 100 + dateTime.day;
    final dayDiff = todayInt - messageInt;

    // 计算时间差（毫秒）
    final differenceMs = now.millisecondsSinceEpoch - timestamp;
    final differenceMinutes = differenceMs ~/ (1000 * 60);

    // 3分钟以内显示"刚刚"
    if (differenceMinutes < 3) {
      return '刚刚';
    }

    // 当天的消息显示 "HH:mm" 格式
    if (dayDiff == 0) {
      return DateFormat('HH:mm').format(dateTime);
    }

    // 昨天的消息显示 "昨天 HH:mm" 格式
    if (dayDiff == 1) {
      return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
    }

    // 前天的消息显示 "前天 HH:mm" 格式
    if (dayDiff == 2) {
      return '前天 ${DateFormat('HH:mm').format(dateTime)}';
    }

    // 3-6天内的消息显示"X天前"
    if (dayDiff >= 3 && dayDiff <= 6) {
      return '$dayDiff天前';
    }

    // 更远的消息显示 "MM月dd日" 格式
    return DateFormat('MM月dd日').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 实现搜索功能
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 实现新建会话功能
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadChatList,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_chatList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无会话',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角的加号创建新会话',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadChatList(isRefresh: true),
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _chatList.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          thickness: 0.5,
          color: Color(0xFFD1D5DB),
          indent: 68, // 缩进68像素，避免分割线出现在头像下方
        ),
        itemBuilder: (context, index) {
          // 如果是最后一个项目且还有更多数据，显示加载指示器
          if (index == _chatList.length && _hasMore) {
            return Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '没有更多数据了',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
            );
          }

          final chatInfo = _chatList[index];
          return _buildChatItem(chatInfo);
        },
      ),
    );
  }

  Widget _buildChatItem(ChatInfo chatInfo) {
    final chatItemContent = Material(
      color: chatInfo.stickyTop
          ? const Color(0xFFF0F0F5)  // 置顶会话使用#f0f0f5背景色
          : Colors.transparent, // 普通会话使用透明背景
      child: InkWell(
        onTap: () {
          // TODO: 导航到聊天详情页面
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            backgroundImage: chatInfo.avatar != null && chatInfo.avatar!.isNotEmpty
                ? NetworkImage(chatInfo.avatar!)
                : null,
            child: chatInfo.avatar == null || chatInfo.avatar!.isEmpty
                ? Text(
                    chatInfo.chatTitle.isNotEmpty
                        ? chatInfo.chatTitle[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            chatInfo.chatTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            chatInfo.lastMessageContent,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(chatInfo.lastMessageTime),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 免打扰图标
                if (chatInfo.doNotDisturb) ...[
                  const Icon(
                    Icons.notifications_off,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                ],
                // 未读数徽章
                if (chatInfo.unreadCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      chatInfo.unreadCount > 99 ? '99+' : chatInfo.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        ),
      ),
    );

    return SwipeableChatItem(
      chatInfo: chatInfo,
      onDelete: _handleDeleteChat,
      onTogglePin: _handleTogglePin,
      onToggleMute: _handleToggleMute,
      child: chatItemContent,
    );
  }

  void _handleDeleteChat(ChatInfo chatInfo) async {
    print('🗑️ 删除会话: ${chatInfo.chatId}');

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定要删除会话"${chatInfo.chatTitle}"吗？\n删除后将清空所有聊天记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _chatService.deleteChat(chatInfo.chatId);

        if (success) {
          setState(() {
            _chatList.removeWhere((chat) => chat.chatId == chatInfo.chatId);
          });

          // 更新本地数据库
          await StorageService.saveChatList(_chatList);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('会话已删除')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除失败，请重试')),
            );
          }
        }
      } catch (e) {
        print('❌ 删除会话异常: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败，请重试')),
          );
        }
      }
    }
  }

  void _handleTogglePin(ChatInfo chatInfo) async {
    print('📌 切换置顶状态: ${chatInfo.chatId}, current: ${chatInfo.stickyTop}');

    final newPinState = !chatInfo.stickyTop;

    try {
      final success = await _chatService.togglePin(chatInfo.chatId, newPinState);

      if (success) {
        setState(() {
          final index = _chatList.indexWhere((chat) => chat.chatId == chatInfo.chatId);
          if (index != -1) {
            _chatList[index] = chatInfo.copyWith(stickyTop: newPinState);

            // 重新排序
            _chatList.sort((a, b) {
              if (a.stickyTop != b.stickyTop) {
                return a.stickyTop ? -1 : 1;
              }
              if (a.lastActiveTime != b.lastActiveTime) {
                return b.lastActiveTime.compareTo(a.lastActiveTime);
              }
              return b.priority.compareTo(a.priority);
            });
          }
        });

        // 更新本地数据库
        await StorageService.saveChatList(_chatList);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(newPinState ? '已置顶' : '已取消置顶')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('操作失败，请重试')),
          );
        }
      }
    } catch (e) {
      print('❌ 切换置顶状态异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请重试')),
        );
      }
    }
  }

  void _handleToggleMute(ChatInfo chatInfo) async {
    print('🔕 切换免打扰状态: ${chatInfo.chatId}, current: ${chatInfo.doNotDisturb}');

    final newMuteState = !chatInfo.doNotDisturb;

    try {
      final success = await _chatService.toggleMute(chatInfo.chatId, newMuteState);

      if (success) {
        setState(() {
          final index = _chatList.indexWhere((chat) => chat.chatId == chatInfo.chatId);
          if (index != -1) {
            _chatList[index] = chatInfo.copyWith(doNotDisturb: newMuteState);
          }
        });

        // 更新本地数据库
        await StorageService.saveChatList(_chatList);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(newMuteState ? '已开启免打扰' : '已关闭免打扰')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('操作失败，请重试')),
          );
        }
      }
    } catch (e) {
      print('❌ 切换免打扰状态异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请重试')),
        );
      }
    }
  }
}