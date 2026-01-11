/// Responsive design breakpoints for CityZen app
/// Following Material Design 3 guidelines for responsive layouts

class Breakpoints {
  // Screen width breakpoints
  static const double mobile = 600;
  static const double tablet = 840;
  static const double desktop = 1200;
  static const double largeDesktop = 1600;

  // Screen height breakpoints for landscape considerations
  static const double compactHeight = 480;
  static const double mediumHeight = 900;

  // Responsive padding and margins
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  // Grid system
  static const int mobileColumns = 4;
  static const int tabletColumns = 8;
  static const int desktopColumns = 12;

  // Component sizing
  static const double minTouchTarget = 48.0;
  static const double cardMaxWidth = 400.0;
  static const double contentMaxWidth = 1200.0;
}

/// Device type enumeration for responsive behavior
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Screen orientation helper
enum ScreenOrientation {
  portrait,
  landscape,
}

/// Responsive helper class for determining device characteristics
class ResponsiveHelper {
  static DeviceType getDeviceType(double width) {
    if (width < Breakpoints.mobile) {
      return DeviceType.mobile;
    } else if (width < Breakpoints.desktop) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  static ScreenOrientation getOrientation(double width, double height) {
    return width > height ? ScreenOrientation.landscape : ScreenOrientation.portrait;
  }

  static bool isMobile(double width) => width < Breakpoints.mobile;
  static bool isTablet(double width) => width >= Breakpoints.mobile && width < Breakpoints.desktop;
  static bool isDesktop(double width) => width >= Breakpoints.desktop;

  static bool isCompactHeight(double height) => height < Breakpoints.compactHeight;
  static bool isMediumHeight(double height) => height >= Breakpoints.compactHeight && height < Breakpoints.mediumHeight;
  static bool isExpandedHeight(double height) => height >= Breakpoints.mediumHeight;

  /// Get appropriate padding based on screen size
  static double getResponsivePadding(double width) {
    if (isMobile(width)) {
      return Breakpoints.paddingM;
    } else if (isTablet(width)) {
      return Breakpoints.paddingL;
    } else {
      return Breakpoints.paddingXL;
    }
  }

  /// Get appropriate number of columns for grid layouts
  static int getGridColumns(double width) {
    if (isMobile(width)) {
      return Breakpoints.mobileColumns;
    } else if (isTablet(width)) {
      return Breakpoints.tabletColumns;
    } else {
      return Breakpoints.desktopColumns;
    }
  }

  /// Get appropriate card width based on screen size
  static double getCardWidth(double screenWidth) {
    if (isMobile(screenWidth)) {
      return screenWidth - (Breakpoints.paddingM * 2);
    } else if (isTablet(screenWidth)) {
      return (screenWidth - (Breakpoints.paddingL * 3)) / 2;
    } else {
      return Breakpoints.cardMaxWidth;
    }
  }

  /// Get appropriate font size scaling based on screen size
  static double getFontScale(double width) {
    if (isMobile(width)) {
      return 1.0;
    } else if (isTablet(width)) {
      return 1.1;
    } else {
      return 1.2;
    }
  }
}