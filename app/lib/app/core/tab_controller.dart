import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'theme.dart';

/// 全局事件总线（避免循环导入）
/// MiniPlayer 点击 Tab 切换时发送事件
class SwitchTabEvent {
  final int tabIndex;
  SwitchTabEvent(this.tabIndex);
}

/// 首页 Tab 状态管理
/// 全局共享，MiniPlayer 点击时可以修改当前 Tab
class HomePageController extends GetxController {
  static HomePageController get to => Get.find<HomePageController>();

  /// 当前 Tab 索引
  final currentIndex = 0.obs;

  /// 切换 Tab
  void switchTab(int index) {
    currentIndex.value = index;
  }
}
