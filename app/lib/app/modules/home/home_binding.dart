import 'package:get/get.dart';

import '../../../services/player_service.dart';

/// HomePage 的依赖绑定
/// 在页面加载时注入 PlayerService（如果尚未注入）
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // PlayerService 已经在 main.dart 中以 permanent 方式注册
    // 这里只需要确保 Get 可以访问到它
    Get.lazyPut<PlayerService>(() => PlayerService.instance);
  }
}