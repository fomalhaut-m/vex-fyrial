import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab 索引状态
class TabIndexState {
  final int currentIndex;
  const TabIndexState({this.currentIndex = 0});
}

/// Tab 控制器 Notifier
class TabIndexNotifier extends Notifier<TabIndexState> {
  TabIndexState build() => const TabIndexState();

  void switchTab(int index) {
    state = TabIndexState(currentIndex: index);
  }
}

/// TabIndexNotifier 的 Provider
final tabIndexProvider = NotifierProvider<TabIndexNotifier, TabIndexState>(() {
  return TabIndexNotifier();
});