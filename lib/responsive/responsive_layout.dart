import 'package:flutter/material.dart';
import 'package:cityzen/responsive/breakpoints.dart';

/// 响应式布局管理器
/// 根据屏幕尺寸自动切换布局模式
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final deviceType = ResponsiveHelper.getDeviceType(width);

        switch (deviceType) {
          case DeviceType.mobile:
            return mobileLayout;
          case DeviceType.tablet:
            return tabletLayout ?? mobileLayout;
          case DeviceType.desktop:
            return desktopLayout ?? tabletLayout ?? mobileLayout;
        }
      },
    );
  }
}

/// 屏幕尺寸工具类
class ScreenSize {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < Breakpoints.mobile;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= Breakpoints.mobile && width < Breakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= Breakpoints.desktop;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static bool isCompactHeight(BuildContext context) {
    return MediaQuery.of(context).size.height < Breakpoints.compactHeight;
  }
}

/// Responsive container that adapts its layout based on screen size
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final bool centerContent;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final responsivePadding = padding ?? EdgeInsets.all(ResponsiveHelper.getResponsivePadding(width));
        final contentMaxWidth = maxWidth ?? Breakpoints.contentMaxWidth;

        Widget content = Container(
          padding: responsivePadding,
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: child,
        );

        if (centerContent && width > contentMaxWidth) {
          content = Center(child: content);
        }

        return content;
      },
    );
  }
}

/// Responsive grid that adapts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? forceColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.forceColumns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = forceColumns ?? ResponsiveHelper.getGridColumns(width);
        
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            final itemWidth = (width - (spacing * (columns - 1))) / columns;
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
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