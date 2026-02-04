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

/// Responsive spacing system - Mobile-first compact design
class AppSpacing {
  // Base spacing values (mobile-first, compact)
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 24;

  /// Get horizontal page padding based on screen size
  static double pagePaddingH(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 12;
    if (width < AppBreakpoints.desktop) return 20;
    return 28;
  }

  /// Get vertical page padding based on screen size
  static double pagePaddingV(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 8;
    if (width < AppBreakpoints.desktop) return 16;
    return 20;
  }

  /// Get card padding based on screen size
  static double cardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 8;
    if (width < AppBreakpoints.desktop) return 12;
    return 16;
  }

  /// Get compact card padding for list items
  static double cardPaddingCompact(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 6;
    if (width < AppBreakpoints.desktop) return 10;
    return 12;
  }

  /// Get section gap based on screen size
  static double sectionGap(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 16;
    if (width < AppBreakpoints.desktop) return 24;
    return 32;
  }

  /// Get item gap in lists
  static double itemGap(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 8;
    if (width < AppBreakpoints.desktop) return 12;
    return 16;
  }

  /// Get compact item gap for dense lists
  static double itemGapCompact(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 4;
    if (width < AppBreakpoints.desktop) return 8;
    return 10;
  }

  /// Get bottom nav safe area
  static double bottomNavPadding(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return 56 + bottomPadding; // Compact nav height + safe area
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

/// Responsive typography scaling - Compact mobile-first
class AppTypography {
  /// Get heading size based on screen
  static double heading1(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 18;
    if (width < AppBreakpoints.desktop) return 22;
    return 26;
  }

  static double heading2(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 15;
    if (width < AppBreakpoints.desktop) return 18;
    return 20;
  }

  static double heading3(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 13;
    if (width < AppBreakpoints.desktop) return 15;
    return 17;
  }

  static double body(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 13;
    if (width < AppBreakpoints.desktop) return 14;
    return 15;
  }

  static double bodySmall(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 12;
    if (width < AppBreakpoints.desktop) return 13;
    return 14;
  }

  static double caption(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 11;
    if (width < AppBreakpoints.desktop) return 12;
    return 13;
  }

  static double captionSmall(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 10;
    if (width < AppBreakpoints.desktop) return 11;
    return 12;
  }

  /// Price text - slightly larger for visibility
  static double price(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 14;
    if (width < AppBreakpoints.desktop) return 15;
    return 16;
  }
}

/// Responsive sizing for UI elements - Compact mobile-first
class AppSizing {
  /// Get icon size based on screen
  static double iconSmall(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 14;
    if (width < AppBreakpoints.desktop) return 16;
    return 18;
  }

  static double iconMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 18;
    if (width < AppBreakpoints.desktop) return 20;
    return 22;
  }

  static double iconLarge(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 22;
    if (width < AppBreakpoints.desktop) return 26;
    return 30;
  }

  /// Get avatar size
  static double avatarSmall(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 28;
    if (width < AppBreakpoints.desktop) return 32;
    return 36;
  }

  static double avatarMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 36;
    if (width < AppBreakpoints.desktop) return 44;
    return 52;
  }

  static double avatarLarge(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 48;
    if (width < AppBreakpoints.desktop) return 56;
    return 64;
  }

  /// Get card image height
  static double cardImageHeight(BuildContext context, {double baseHeight = 80}) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return baseHeight;
    if (width < AppBreakpoints.desktop) return baseHeight * 1.15;
    return baseHeight * 1.3;
  }

  /// Get list item image size (square)
  static double listItemImage(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 64;
    if (width < AppBreakpoints.desktop) return 80;
    return 96;
  }

  /// Get compact list item image size
  static double listItemImageCompact(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 56;
    if (width < AppBreakpoints.desktop) return 68;
    return 80;
  }

  /// Get hero/banner image height
  static double heroImageHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 180;
    if (width < AppBreakpoints.desktop) return 220;
    return 280;
  }

  /// Get touch target minimum size (Material guidelines: 48dp, but we use 44 for compact)
  static double touchTarget(BuildContext context) {
    return 44;
  }

  /// Get button height
  static double buttonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 44;
    if (width < AppBreakpoints.desktop) return 48;
    return 52;
  }

  /// Get compact button height
  static double buttonHeightCompact(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 36;
    if (width < AppBreakpoints.desktop) return 40;
    return 44;
  }

  /// Get dropdown/overlay max width
  static double dropdownMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return width * 0.9;
    if (width < AppBreakpoints.desktop) return 360;
    return 400;
  }

  /// Get list item height (for consistent row heights)
  static double listItemHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 72;
    if (width < AppBreakpoints.desktop) return 84;
    return 96;
  }

  /// Get compact list item height
  static double listItemHeightCompact(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.tablet) return 56;
    if (width < AppBreakpoints.desktop) return 64;
    return 72;
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
  double get cardPaddingCompact => AppSpacing.cardPaddingCompact(this);
  double get sectionGap => AppSpacing.sectionGap(this);
  double get itemGap => AppSpacing.itemGap(this);
  double get itemGapCompact => AppSpacing.itemGapCompact(this);
  double get bottomNavPadding => AppSpacing.bottomNavPadding(this);

  // Page padding as EdgeInsets
  EdgeInsets get pageInsets => EdgeInsets.symmetric(
        horizontal: pagePaddingH,
        vertical: pagePaddingV,
      );

  EdgeInsets get pageInsetsHorizontal => EdgeInsets.symmetric(
        horizontal: pagePaddingH,
      );

  // Compact card padding as EdgeInsets
  EdgeInsets get cardInsets => EdgeInsets.all(cardPadding);
  EdgeInsets get cardInsetsCompact => EdgeInsets.all(cardPaddingCompact);

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
  double get bodySmallSize => AppTypography.bodySmall(this);
  double get captionSize => AppTypography.caption(this);
  double get captionSmallSize => AppTypography.captionSmall(this);
  double get priceSize => AppTypography.price(this);

  // Sizing shortcuts
  double get iconSmall => AppSizing.iconSmall(this);
  double get iconMedium => AppSizing.iconMedium(this);
  double get iconLarge => AppSizing.iconLarge(this);
  double get avatarSmall => AppSizing.avatarSmall(this);
  double get avatarMedium => AppSizing.avatarMedium(this);
  double get avatarLarge => AppSizing.avatarLarge(this);
  double get buttonHeight => AppSizing.buttonHeight(this);
  double get buttonHeightCompact => AppSizing.buttonHeightCompact(this);
  double get dropdownMaxWidth => AppSizing.dropdownMaxWidth(this);
  double get listItemImage => AppSizing.listItemImage(this);
  double get listItemImageCompact => AppSizing.listItemImageCompact(this);
  double get heroImageHeight => AppSizing.heroImageHeight(this);
  double get listItemHeight => AppSizing.listItemHeight(this);
  double get listItemHeightCompact => AppSizing.listItemHeightCompact(this);

  // Card image height with custom base
  double cardImageHeight([double baseHeight = 80]) =>
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
