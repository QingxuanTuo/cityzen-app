import 'package:flutter/material.dart';

/// 响应式布局管理器
/// 根据屏幕尺寸自动切换布局模式
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget tabletLayout;
  final Widget? desktopLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    required this.tabletLayout,
    this.desktopLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // 手机布局 (< 600dp)
          return mobileLayout;
        } else if (constraints.maxWidth < 1200) {
          // 平板布局 (600dp - 1200dp)
          return tabletLayout;
        } else {
          // 桌面布局 (> 1200dp)
          return desktopLayout ?? tabletLayout;
        }
      },
    );
  }
}

/// 屏幕尺寸工具类
class ScreenSize {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
}

/// Master-Detail 布局组件
class MasterDetailLayout extends StatefulWidget {
  final Widget masterPanel;
  final Widget detailPanel;
  final Widget? emptyDetailPanel;
  final double masterPanelWidth;

  const MasterDetailLayout({
    super.key,
    required this.masterPanel,
    required this.detailPanel,
    this.emptyDetailPanel,
    this.masterPanelWidth = 320.0,
  });

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  @override
  Widget build(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      // 手机：单页面导航
      return widget.masterPanel;
    } else {
      // 平板/桌面：Master-Detail布局
      return Row(
        children: [
          // Master Panel (左侧列表)
          SizedBox(
            width: widget.masterPanelWidth,
            child: widget.masterPanel,
          ),
          // 分割线
          const VerticalDivider(width: 1),
          // Detail Panel (右侧详情)
          Expanded(
            child: widget.detailPanel,
          ),
        ],
      );
    }
  }
}