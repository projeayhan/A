import 'package:flutter/material.dart';
import 'navigation/app_nav_bar.dart';
import 'navigation/footer.dart';

class PageShell extends StatefulWidget {
  final List<Widget> sections;
  const PageShell({super.key, required this.sections});

  @override
  State<PageShell> createState() => _PageShellState();
}

class _PageShellState extends State<PageShell> {
  final _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 50;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Top padding for navbar
              const SliverToBoxAdapter(child: SizedBox(height: 70)),
              // Sections
              ...widget.sections.map(
                (section) => SliverToBoxAdapter(child: section),
              ),
              // Footer
              const SliverToBoxAdapter(child: Footer()),
            ],
          ),
          // Sticky navbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppNavBar(isScrolled: _isScrolled),
          ),
        ],
      ),
    );
  }
}
