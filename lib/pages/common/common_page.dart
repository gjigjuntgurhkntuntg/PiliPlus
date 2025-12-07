import 'dart:async';
import 'dart:ui' show clampDouble;

import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart'
    as custom_refresh;
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

abstract class CommonPageState<
  T extends StatefulWidget,
  R extends CommonController
>
    extends State<T> {
  R get controller;
  StreamController<bool>? mainStream;
  StreamController<bool>? searchBarStream;
  // late double _downScrollCount = 0.0; // 向下滚动计数器
  late double _upScrollCount = 0.0; // 向上滚动计数器
  double? _lastScrollPosition; // 记录上次滚动位置

  // 恢复：子类依赖这些字段
  final enableScrollThreshold = Pref.enableScrollThreshold;
  late final double scrollThreshold = Pref.scrollThreshold; // 滚动阈值

  // 新增：平滑过渡范围
  late final double scrollRange = enableScrollThreshold
      ? scrollThreshold
      : 100.0;

  late final scrollController = controller.scrollController;

  /// 刷新指示器的 Key，用于编程式触发刷新动画
  final refreshIndicatorKey = GlobalKey<custom_refresh.RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    try {
      mainStream = Get.find<MainController>().bottomBarStream;
      searchBarStream = Get.find<HomeController>().searchBarStream;
    } catch (_) {}

    // 强制添加监听，不再依赖 enableScrollThreshold 配置，以实现跟随手指滑动
    // 注意：即使 enableScrollThreshold 为 false，我们也添加监听器
    controller.scrollController.addListener(listener);

    // 设置刷新回调
    controller.showRefreshIndicator = () {
      return refreshIndicatorKey.currentState?.show() ?? controller.onRefresh();
    };
  }

  Widget onBuild(Widget child) {
    // 恢复：某些子类可能依赖 onNotification 被调用
    // 虽然我们现在主要靠 listener，但为了兼容性保留
    if (!enableScrollThreshold &&
        (mainStream != null || searchBarStream != null)) {
      return NotificationListener<UserScrollNotification>(
        onNotification: onNotification,
        child: child,
      );
    }
    return child;
  }

  // 恢复：子类覆盖了此方法
  bool onNotification(UserScrollNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) return false;
    final direction = notification.direction;
    if (direction == ScrollDirection.forward) {
      mainStream?.add(true);
      searchBarStream?.add(true);
    } else if (direction == ScrollDirection.reverse) {
      mainStream?.add(false);
      searchBarStream?.add(false);
    }
    return false;
  }

  void listener() {
    if (!scrollController.hasClients) return;

    final direction = scrollController.position.userScrollDirection;
    final double currentPosition = scrollController.position.pixels;

    // 初始化上次位置
    _lastScrollPosition ??= currentPosition;

    // 计算滚动距离
    final double scrollDelta = currentPosition - _lastScrollPosition!;

    // 更新上次位置
    _lastScrollPosition = currentPosition;

    // 如果变化很小，忽略
    if (scrollDelta.abs() < 0.01) return;

    // 获取控制器
    MainController? mainCtr;
    HomeController? homeCtr;
    DynamicsController? dynCtr;
    try {
      mainCtr = Get.find<MainController>();
    } catch (_) {}
    try {
      homeCtr = Get.find<HomeController>();
    } catch (_) {}
    try {
      dynCtr = Get.find<DynamicsController>();
    } catch (_) {}

    // Debug logs
    // if (scrollDelta.abs() > 0.5) {
    //   debugPrint(
    //     'CommonPage: delta=${scrollDelta.toStringAsFixed(2)} bottom=${mainCtr?.bottomBarRatio.value.toStringAsFixed(2)} search=${homeCtr?.searchBarRatio.value.toStringAsFixed(2)}',
    //   );
    // }

    // 更新各个 Ratio
    // 逻辑：向下滑动 (delta > 0) -> ratio 减小
    //       向上滑动 (delta < 0) -> ratio 增加
    //       ratio 范围 [0, 1]

    final double change = deltaToRatioChange(scrollDelta);

    if (mainCtr != null) {
      final newRatio = clampDouble(
        mainCtr.bottomBarRatio.value + change,
        0.0,
        1.0,
      );
      mainCtr.bottomBarRatio.value = newRatio;
      // 兼容旧逻辑：发送布尔值
      if (newRatio == 0) mainStream?.add(false);
      if (newRatio == 1) mainStream?.add(true);
    }

    if (homeCtr != null) {
      final newRatio = clampDouble(
        homeCtr.searchBarRatio.value + change,
        0.0,
        1.0,
      );
      homeCtr.searchBarRatio.value = newRatio;
      // 兼容旧逻辑
      if (newRatio == 0) searchBarStream?.add(false);
      if (newRatio == 1) searchBarStream?.add(true);
    }

    if (dynCtr != null) {
      final newRatio = clampDouble(
        dynCtr.upPanelRatio.value + change,
        0.0,
        1.0,
      );
      dynCtr.upPanelRatio.value = newRatio;
      // 兼容旧逻辑
      if (newRatio == 0 && dynCtr.upPanelStream != null)
        dynCtr.upPanelStream!.add(false);
      if (newRatio == 1 && dynCtr.upPanelStream != null)
        dynCtr.upPanelStream!.add(true);
    }

    // 复用原来的部分逻辑保持反向兼容（如果需要）
    if (direction == ScrollDirection.reverse) {
      _upScrollCount = 0.0;
    } else if (direction == ScrollDirection.forward) {
      if (scrollDelta < 0) {
        _upScrollCount += (-scrollDelta);
      }
    }
  }

  /// 将滚动 delta 转换为 ratio 变化量
  /// 向下滚动 (delta > 0) -> ratio 减少 -> 返回负值
  /// 向上滚动 (delta < 0) -> ratio 增加 -> 返回正值
  double deltaToRatioChange(double delta) {
    if (delta == 0) return 0;
    // ratio 变化 = -delta / range
    return -delta / scrollRange;
  }

  @override
  void dispose() {
    controller.scrollController.removeListener(listener);
    super.dispose();
  }
}
