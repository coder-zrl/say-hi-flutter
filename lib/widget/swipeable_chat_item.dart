import 'package:flutter/material.dart';
import 'package:say_hi_flutter/model/chat_info_model.dart';

typedef SwipeActionCallback = void Function(ChatInfo chatInfo);

class SwipeableChatItem extends StatefulWidget {
  final ChatInfo chatInfo;
  final Widget child;
  final SwipeActionCallback? onDelete;
  final SwipeActionCallback? onTogglePin;
  final SwipeActionCallback? onToggleMute;

  const SwipeableChatItem({
    super.key,
    required this.chatInfo,
    required this.child,
    this.onDelete,
    this.onTogglePin,
    this.onToggleMute,
  });

  @override
  State<SwipeableChatItem> createState() => _SwipeableChatItemState();
}

class _SwipeableChatItemState extends State<SwipeableChatItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _actionButtonsAnimation;

  bool _isSwiped = false;
  final double _actionWidth = 80.0;
  final double _threshold = 0.2;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // 滑动动画
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: -1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // 操作按钮出现动画
    _actionButtonsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta < 0) { // 只允许左滑
      final progress = (-delta / _actionWidth / 3).clamp(0.0, 1.0);
      _animationController.value = progress;

      // 实时更新滑动状态
      if (progress > 0 && !_isSwiped) {
        setState(() {
          _isSwiped = true;
        });
      } else if (progress == 0 && _isSwiped) {
        setState(() {
          _isSwiped = false;
        });
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_animationController.value > _threshold) {
      _openSwipe();
    } else {
      _closeSwipe();
    }
  }

  void _openSwipe() {
    setState(() {
      _isSwiped = true;
    });
    _animationController.forward();
  }

  void _closeSwipe() {
    setState(() {
      _isSwiped = false;
    });
    _animationController.reverse();
  }

  void _handleTap() {
    if (_isSwiped) {
      _closeSwipe();
    }
  }

  Widget _buildAction({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _actionButtonsAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            onTap();
            _closeSwipe();
          },
          child: Container(
            width: _actionWidth,
            color: color,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: _actionButtonsAnimation.value,
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRect(
                  child: Align(
                    alignment: Alignment.center,
                    heightFactor: _actionButtonsAnimation.value,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 背景操作按钮 - 只有在滑动时才显示
          if (_isSwiped)
            Positioned.fill(
              child: Row(
                children: [
                  const Spacer(),
                  _buildAction(
                    color: widget.chatInfo.doNotDisturb
                        ? Colors.orange
                        : Colors.blue,
                    icon: widget.chatInfo.doNotDisturb
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    label: widget.chatInfo.doNotDisturb ? '取消免打扰' : '免打扰',
                    onTap: () => widget.onToggleMute?.call(widget.chatInfo),
                  ),
                  _buildAction(
                    color: widget.chatInfo.stickyTop
                        ? Colors.grey
                        : Colors.green,
                    icon: widget.chatInfo.stickyTop
                        ? Icons.push_pin_outlined
                        : Icons.push_pin,
                    label: widget.chatInfo.stickyTop ? '取消置顶' : '置顶',
                    onTap: () => widget.onTogglePin?.call(widget.chatInfo),
                  ),
                  _buildAction(
                    color: Colors.red,
                    icon: Icons.delete_outline,
                    label: '删除',
                    onTap: () => widget.onDelete?.call(widget.chatInfo),
                  ),
                ],
              ),
            ),

          // 前景内容
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_slideAnimation.value * _actionWidth * 3, 0),
                child: Container(
                  color: Colors.transparent,
                  child: widget.child,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}