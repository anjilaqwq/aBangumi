import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'calendar_page.dart';
import 'discovery_page.dart';
import 'home_page.dart';
import 'my_page.dart';
import 'search_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;
  bool _navigationVisible = true;

  static const List<Widget> _pages = [
    HomePage(),
    CalendarPage(),
    DiscoveryPage(),
    SearchPage(),
    MyPage(),
  ];

  bool _handleScroll(ScrollNotification notification) {
    if (MediaQuery.sizeOf(context).width >= 720) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.extentBefore <= 8) {
      _setNavigationVisible(true);
      return false;
    }
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 1.5) {
        _setNavigationVisible(false);
      } else if (delta < -1.5) {
        _setNavigationVisible(true);
      }
    } else if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        _setNavigationVisible(false);
      } else if (notification.direction == ScrollDirection.forward) {
        _setNavigationVisible(true);
      }
    }
    return false;
  }

  void _setNavigationVisible(bool value) {
    if (_navigationVisible == value || !mounted) return;
    setState(() => _navigationVisible = value);
  }

  void _selectPage(int index) {
    if (index == _index) {
      _setNavigationVisible(true);
      return;
    }
    setState(() {
      _index = index;
      _navigationVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return _tabletScaffold(
            colors,
            extended: constraints.maxWidth >= 1180,
          );
        }
        return _phoneScaffold(colors);
      },
    );
  }

  Widget _pageHost() => NotificationListener<ScrollNotification>(
    onNotification: _handleScroll,
    child: SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < _pages.length; i++)
            IgnorePointer(
              ignoring: i != _index,
              child: ExcludeSemantics(
                excluding: i != _index,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  offset: i == _index
                      ? Offset.zero
                      : Offset(i < _index ? -0.035 : 0.035, 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: i == _index ? 1 : 0,
                    child: TickerMode(enabled: i == _index, child: _pages[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _tabletScaffold(ColorScheme colors, {required bool extended}) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: Material(
              color: colors.surface,
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _selectPage,
                extended: extended,
                minWidth: 68,
                minExtendedWidth: 164,
                groupAlignment: -0.76,
                backgroundColor: colors.surface,
                indicatorColor: colors.primaryContainer,
                selectedIconTheme: IconThemeData(
                  size: 22,
                  color: colors.primary,
                ),
                unselectedIconTheme: IconThemeData(
                  size: 21,
                  color: colors.onSurfaceVariant,
                ),
                selectedLabelTextStyle: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                unselectedLabelTextStyle: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 14),
                  child: extended
                      ? Text(
                          'aBangumi',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        )
                      : Icon(Icons.auto_awesome_rounded, color: colors.primary),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.leaderboard_outlined),
                    selectedIcon: Icon(Icons.leaderboard_rounded),
                    label: Text('排行'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: Text('放送'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore_rounded),
                    label: Text('发现'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.search_rounded),
                    selectedIcon: Icon(Icons.manage_search_rounded),
                    label: Text('搜索'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: Text('我的'),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: colors.outlineVariant),
          Expanded(child: _pageHost()),
        ],
      ),
    );
  }

  Widget _phoneScaffold(ColorScheme colors) {
    return Scaffold(
      body: _pageHost(),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: _navigationVisible
            ? SafeArea(
                key: const ValueKey('main-navigation'),
                top: false,
                minimum: const EdgeInsets.only(bottom: 4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                  child: Material(
                    color: colors.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    child: NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: _selectPage,
                      height: 66,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      indicatorColor: colors.primaryContainer,
                      indicatorShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.leaderboard_outlined),
                          selectedIcon: Icon(Icons.leaderboard_rounded),
                          label: '排行',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.calendar_month_outlined),
                          selectedIcon: Icon(Icons.calendar_month_rounded),
                          label: '放送',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore_rounded),
                          label: '发现',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.search_rounded),
                          selectedIcon: Icon(Icons.manage_search_rounded),
                          label: '搜索',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: '我的',
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('navigation-hidden')),
      ),
    );
  }
}
