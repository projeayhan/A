import 'package:flutter/material.dart';

/// Breakpoint definitions for responsive design
class AppBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double largeDesktop = 1440;

  /// Check if current width is mobile
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tablet;

  /// Check if current width is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tablet && width < desktop;
  }

  /// Check if current width is desktop
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  /// Get device type
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < tablet) return DeviceType.mobile;
    if (width < desktop) return DeviceType.tablet;
    return DeviceType.desktop;
  }
}

enum DeviceType { mobile, tablet, desktop }

/// Responsive spacing system
class AppSpacing {
  // Base spacing values (mobile-first)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Get horizontal page padding based on screen size
  static double pagePaddingH(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 16;
    if (width < AppBreakpoints.desktop) return 24;
    return 32;
  }

  /// Get vertical page padding based on screen size
  static double pagePaddingV(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 16;
    if (width < AppBreakpoints.desktop) return 20;
    return 24;
  }

  /// Get card padding based on screen size
  static double cardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 12;
    if (width < AppBreakpoints.desktop) return 16;
    return 20;
  }

  /// Get section gap based on screen size
  static double sectionGap(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 24;
    if (width < AppBreakpoints.desktop) return 32;
    return 40;
  }

  /// Get item gap in lists
  static double itemGap(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 12;
    if (width < AppBreakpoints.desktop) return 16;
    return 20;
  }

  /// Get bottom nav safe area
  static double bottomNavPadding(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return 80 + bottomPadding; // Nav height + safe area
  }
}

/// Responsive grid configuration
class AppGrid {
  /// Get grid column count based on screen size
  static int columns(BuildContext context, {int mobileColumns = 2}) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return mobileColumns;
    if (width < AppBreakpoints.desktop) return mobileColumns + 1;
    return mobileColumns + 2;
  }

  /// Get grid column count for service cards
  static int serviceColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 2;
    if (width < AppBreakpoints.desktop) return 3;
    return 4;
  }

  /// Get grid column count for product cards
  static int productColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.mobile) return 2;
    if (width < AppBreakpoints.tablet) return 2;
    if (width < AppBreakpoints.desktop) return 3;
    return 4;
  }

  /// Get grid spacing
  static double spacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 12;
    if (width < AppBreakpoints.desktop) return 16;
    return 20;
  }

  /// Get child aspect ratio for cards
  static double cardAspectRatio(BuildContext context, {double baseRatio = 0.75}) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return baseRatio;
    if (width < AppBreakpoints.desktop) return baseRatio + 0.05;
    return baseRatio + 0.1;
  }
}

/// Responsive typography scaling
class AppTypography {
  /// Get heading size based on screen
  static double heading1(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 24;
    if (width < AppBreakpoints.desktop) return 28;
    return 32;
  }

  static double heading2(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 20;
    if (width < AppBreakpoints.desktop) return 22;
    return 24;
  }

  static double heading3(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 16;
    if (width < AppBreakpoints.desktop) return 18;
    return 20;
  }

  static double body(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 14;
    if (width < AppBreakpoints.desktop) return 15;
    return 16;
  }

  static double caption(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 12;
    if (width < AppBreakpoints.desktop) return 13;
    return 14;
  }
}

/// Responsive sizing for UI elements
class AppSizing {
  /// Get icon size based on screen
  static double iconSmall(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 16;
    if (width < AppBreakpoints.desktop) return 18;
    return 20;
  }

  static double iconMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 20;
    if (width < AppBreakpoints.desktop) return 22;
    return 24;
  }

  static double iconLarge(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 24;
    if (width < AppBreakpoints.desktop) return 28;
    return 32;
  }

  /// Get avatar size
  static double avatarSmall(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 32;
    if (width < AppBreakpoints.desktop) return 36;
    return 40;
  }

  static double avatarMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 40;
    if (width < AppBreakpoints.desktop) return 48;
    return 56;
  }

  static double avatarLarge(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 56;
    if (width < AppBreakpoints.desktop) return 64;
    return 72;
  }

  /// Get card image height
  static double cardImageHeight(BuildContext context, {double baseHeight = 120}) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return baseHeight;
    if (width < AppBreakpoints.desktop) return baseHeight * 1.2;
    return baseHeight * 1.4;
  }

  /// Get touch target minimum size (Material guidelines: 48dp)
  static double touchTarget(BuildContext context) {
    return 48;
  }

  /// Get button height
  static double buttonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 48;
    if (width < AppBreakpoints.desktop) return 52;
    return 56;
  }

  /// Get dropdown/overlay max width
  static double dropdownMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return width * 0.9;
    if (width < AppBreakpoints.desktop) return 400;
    return 450;
  }
}

/// BuildContext extension for easy access
extension ResponsiveExtension on BuildContext {
  // Breakpoint checks
  bool get isMobile => AppBreakpoints.isMobile(this);
  bool get isTablet => AppBreakpoints.isTablet(this);
  bool get isDesktop => AppBreakpoints.isDesktop(this);
  DeviceType get deviceType => AppBreakpoints.getDeviceType(this);

  // Screen dimensions
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get viewPadding => MediaQuery.of(this).viewPadding;

  // Spacing shortcuts
  double get pagePaddingH => AppSpacing.pagePaddingH(this);
  double get pagePaddingV => AppSpacing.pagePaddingV(this);
  double get cardPadding => AppSpacing.cardPadding(this);
  double get sectionGap => AppSpacing.sectionGap(this);
  double get itemGap => AppSpacing.itemGap(this);
  double get bottomNavPadding => AppSpacing.bottomNavPadding(this);

  // Page padding as EdgeInsets
  EdgeInsets get pageInsets => EdgeInsets.symmetric(
        horizontal: pagePaddingH,
        vertical: pagePaddingV,
      );

  EdgeInsets get pageInsetsHorizontal => EdgeInsets.symmetric(
        horizontal: pagePaddingH,
      );

  // Grid shortcuts
  int get gridColumns => AppGrid.columns(this);
  int get serviceGridColumns => AppGrid.serviceColumns(this);
  int get productGridColumns => AppGrid.productColumns(this);
  double get gridSpacing => AppGrid.spacing(this);

  // Typography shortcuts
  double get heading1Size => AppTypography.heading1(this);
  double get heading2Size => AppTypography.heading2(this);
  double get heading3Size => AppTypography.heading3(this);
  double get bodySize => AppTypography.body(this);
  double get captionSize => AppTypography.caption(this);

  // Sizing shortcuts
  double get iconSmall => AppSizing.iconSmall(this);
  double get iconMedium => AppSizing.iconMedium(this);
  double get iconLarge => AppSizing.iconLarge(this);
  double get avatarSmall => AppSizing.avatarSmall(this);
  double get avatarMedium => AppSizing.avatarMedium(this);
  double get avatarLarge => AppSizing.avatarLarge(this);
  double get buttonHeight => AppSizing.buttonHeight(this);
  double get dropdownMaxWidth => AppSizing.dropdownMaxWidth(this);

  // Card image height with custom base
  double cardImageHeight([double baseHeight = 120]) =>
      AppSizing.cardImageHeight(this, baseHeight: baseHeight);
}

/// Responsive widget that rebuilds on size changes
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, context.deviceType);
      },
    );
  }
}

/// Responsive value selector
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  T get(BuildContext context) {
    final deviceType = context.deviceType;
    switch (deviceType) {
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }
}

/// Responsive SizedBox for spacing
class ResponsiveGap extends StatelessWidget {
  final double? height;
  final double? width;
  final bool useItemGap;
  final bool useSectionGap;

  const ResponsiveGap({
    super.key,
    this.height,
    this.width,
    this.useItemGap = false,
    this.useSectionGap = false,
  });

  const ResponsiveGap.item({super.key})
      : height = null,
        width = null,
        useItemGap = true,
        useSectionGap = false;

  const ResponsiveGap.section({super.key})
      : height = null,
        width = null,
        useItemGap = false,
        useSectionGap = true;

  @override
  Widget build(BuildContext context) {
    double? h = height;
    double? w = width;

    if (useItemGap) {
      h = context.itemGap;
    } else if (useSectionGap) {
      h = context.sectionGap;
    }

    return SizedBox(height: h, width: w);
  }
}

/// Responsive padding wrapper
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final bool horizontal;
  final bool vertical;
  final bool all;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.horizontal = false,
    this.vertical = false,
    this.all = true,
  });

  const ResponsivePadding.horizontal({
    super.key,
    required this.child,
  })  : horizontal = true,
        vertical = false,
        all = false;

  const ResponsivePadding.vertical({
    super.key,
    required this.child,
  })  : horizontal = false,
        vertical = true,
        all = false;

  @override
  Widget build(BuildContext context) {
    EdgeInsets padding;
    if (all) {
      padding = context.pageInsets;
    } else if (horizontal) {
      padding = context.pageInsetsHorizontal;
    } else {
      padding = EdgeInsets.symmetric(vertical: context.pagePaddingV);
    }

    return Padding(padding: padding, child: child);
  }
}
