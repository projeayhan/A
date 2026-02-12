import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class NavBar extends StatefulWidget {
  final ScrollController scrollController;
  final void Function(String section) onNavTap;
  const NavBar({super.key, required this.scrollController, required this.onNavTap});

  @override
  State<NavBar> createState() => _NavBarState();

  @override
  // ignore: override_on_non_overriding_member
  bool get isSliver => true;
}

class _NavBarState extends State<NavBar> {
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() => _scrollOffset = widget.scrollController.offset);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isScrolled = _scrollOffset > 50;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _NavBarDelegate(
        isScrolled: isScrolled,
        isMobile: isMobile,
        onNavTap: widget.onNavTap,
      ),
    );
  }
}

class _NavBarDelegate extends SliverPersistentHeaderDelegate {
  final bool isScrolled;
  final bool isMobile;
  final void Function(String section) onNavTap;
  _NavBarDelegate({required this.isScrolled, required this.isMobile, required this.onNavTap});

  @override
  double get minExtent => 70;
  @override
  double get maxExtent => 70;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: isScrolled ? 20 : 0, sigmaY: isScrolled ? 20 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 70,
          decoration: BoxDecoration(
            color: isScrolled ? AppColors.surface.withAlpha(180) : Colors.transparent,
            border: Border(bottom: BorderSide(color: isScrolled ? AppColors.glassBorder : Colors.transparent)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // Logo
              GestureDetector(
                onTap: () => onNavTap('hero'),
                child: Image.asset(
                  'assets/images/supercyp_logo_horizontal.png',
                  height: 40,
                ),
              ),
              const Spacer(),
              if (!isMobile) ...[
                _NavLink('Hizmetler', () => onNavTap('services')),
                _NavLink('Uygulamalar', () => onNavTap('apps')),
                _NavLink('Paneller', () => onNavTap('panels')),
                _NavLink('Teknoloji', () => onNavTap('tech')),
                const SizedBox(width: 16),
                _SmallCTA(onTap: () => onNavTap('apps')),
              ] else
                Builder(builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                  onPressed: () => _showMobileMenu(ctx),
                )),
            ],
          ),
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MobileMenuItem('Hizmetler', Icons.grid_view_rounded, () { Navigator.pop(context); onNavTap('services'); }),
            _MobileMenuItem('Uygulamalar', Icons.phone_android, () { Navigator.pop(context); onNavTap('apps'); }),
            _MobileMenuItem('Paneller', Icons.dashboard, () { Navigator.pop(context); onNavTap('panels'); }),
            _MobileMenuItem('Teknoloji', Icons.memory, () { Navigator.pop(context); onNavTap('tech'); }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _NavBarDelegate oldDelegate) =>
      oldDelegate.isScrolled != isScrolled || oldDelegate.isMobile != isMobile;
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              color: _hovered ? AppColors.primary : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: _hovered ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _SmallCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _SmallCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Text('Indir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

class _MobileMenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MobileMenuItem(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
