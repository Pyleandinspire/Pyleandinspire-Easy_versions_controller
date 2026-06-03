import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 自动保存状态枚举
enum AutoSaveStatus {
  saved,    // 已保存 - 绿色勾选
  saving,   // 正在保存 - 黄色圆点
  failed,   // 保存失败 - 红色警告
}

/// 自动保存状态数据
class AutoSaveState {
  final AutoSaveStatus status;
  final DateTime? lastSaveTime;
  final String? errorMessage;

  const AutoSaveState({
    this.status = AutoSaveStatus.saved,
    this.lastSaveTime,
    this.errorMessage,
  });

  AutoSaveState copyWith({
    AutoSaveStatus? status,
    DateTime? lastSaveTime,
    String? errorMessage,
  }) {
    return AutoSaveState(
      status: status ?? this.status,
      lastSaveTime: lastSaveTime ?? this.lastSaveTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 自动保存状态 Notifier
class AutoSaveStatusNotifier extends Notifier<AutoSaveState> {
  @override
  AutoSaveState build() {
    return const AutoSaveState();
  }

  void markSaving() {
    state = state.copyWith(
      status: AutoSaveStatus.saving,
      errorMessage: null,
    );
  }

  void markSaved() {
    state = state.copyWith(
      status: AutoSaveStatus.saved,
      lastSaveTime: DateTime.now(),
      errorMessage: null,
    );
  }

  void markFailed(String error) {
    state = state.copyWith(
      status: AutoSaveStatus.failed,
      errorMessage: error,
    );
  }
}

final autoSaveStatusProvider = NotifierProvider<AutoSaveStatusNotifier, AutoSaveState>(
  AutoSaveStatusNotifier.new,
);
