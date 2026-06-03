import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';

/// 通知类型
enum AppNotificationType {
  error,
  warning,
  info,
}

/// 通知数据
class AppNotification {
  final String message;
  final AppNotificationType type;
  final VoidCallback? onTap;

  AppNotification({
    required this.message,
    required this.type,
    this.onTap,
  });
}

/// 全局通知服务
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  OverlayEntry? _currentEntry;

  /// 显示通知
  void show({
    required BuildContext context,
    required String message,
    required AppNotificationType type,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    // 先移除已有的通知
    dismiss();

    final overlay = Overlay.of(context);
    final notification = AppNotification(
      message: message,
      type: type,
      onTap: onTap,
    );

    _currentEntry = OverlayEntry(
      builder: (context) => _NotificationOverlay(
        notification: notification,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    // 自动消失
    Future.delayed(duration, () {
      dismiss();
    });
  }

  /// 移除通知
  void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// 通知浮层组件
class _NotificationOverlay extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;

  const _NotificationOverlay({
    required this.notification,
    required this.onDismiss,
  });

  Color _getBackgroundColor() {
    switch (notification.type) {
      case AppNotificationType.error:
        return AppColors.error;
      case AppNotificationType.warning:
        return AppColors.warning;
      case AppNotificationType.info:
        return AppColors.accent;
    }
  }

  IconData _getIcon() {
    switch (notification.type) {
      case AppNotificationType.error:
        return Icons.error_outline;
      case AppNotificationType.warning:
        return Icons.warning_amber;
      case AppNotificationType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 56,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: notification.onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, minWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Icon(_getIcon(), color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notification.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
