import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/service_data.dart';
import '../../core/router/app_router.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Container(
      color: AppColors.backgroundDark,
      child: Column(
        children: [
          // Divider line
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.cyan.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24 : 60,
              vertical: 48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isMobile
                    ? _buildMobileLayout(context)
                    : _buildDesktopLayout(context),
              ),
            ),
          ),
          // Bottom bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.glassBorder),
              ),
            ),
            child: Center(
              child: Text(
                AppStrings.copyright,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textOnDarkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _BrandColumn()),
        const SizedBox(width: 40),
        Expanded(flex: 2, child: _ServicesColumn()),
        Expanded(flex: 2, child: _PagesColumn(context: context)),
        Expanded(flex: 2, child: _ContactColumn()),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BrandColumn(),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ServicesColumn()),
            Expanded(child: _PagesColumn(context: context)),
          ],
        ),
        const SizedBox(height: 32),
        _ContactColumn(),
      ],
    );
  }
}

class _BrandColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.cyan],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.apps_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'SuperCyp',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.tagline,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textOnDarkSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.textOnDarkMuted, size: 16),
            const SizedBox(width: 4),
            Text(
              AppStrings.location,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textOnDarkMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServicesColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hizmetler',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnDark,
          ),
        ),
        const SizedBox(height: 16),
        ...ServiceData.services.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                s.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textOnDarkSecondary,
                ),
              ),
            )),
      ],
    );
  }
}

class _PagesColumn extends StatelessWidget {
  final BuildContext context;
  const _PagesColumn({required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sayfalar',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnDark,
          ),
        ),
        const SizedBox(height: 16),
        _FooterLink(label: 'Ana Sayfa', onTap: () => context.go(AppRoutes.home)),
        _FooterLink(
            label: 'Hizmetler', onTap: () => context.go(AppRoutes.services)),
        _FooterLink(
            label: 'İşletmeler İçin',
            onTap: () => context.go(AppRoutes.business)),
        _FooterLink(label: 'İndir', onTap: () => context.go(AppRoutes.download)),
      ],
    );
  }
}

class _ContactColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'İletişim',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnDark,
          ),
        ),
        const SizedBox(height: 16),
        _FooterLink(
          label: AppUrls.email,
          onTap: () => launchUrl(Uri.parse('mailto:${AppUrls.email}')),
          icon: Icons.email_outlined,
        ),
        _FooterLink(
          label: 'supercyp.com',
          onTap: () => launchUrl(Uri.parse(AppUrls.website)),
          icon: Icons.language_rounded,
        ),
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const _FooterLink({required this.label, required this.onTap, this.icon});

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 14,
                    color: _hovered
                        ? AppColors.primaryLight
                        : AppColors.textOnDarkMuted),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _hovered
                      ? AppColors.primaryLight
                      : AppColors.textOnDarkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
