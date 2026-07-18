import 'package:flutter/material.dart';

// Import your existing screens
import 'admin_dashboard_screen.dart';
import 'admin_roster_screen.dart';
import 'safe_zone_map_screen.dart';
import 'admin_profile_screen.dart';

// Import widgets
import '../widgets/glassmorphic_bottom_nav.dart';
import '../widgets/emergency_action_widget.dart';

class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});

  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  AdminTab _currentTab = AdminTab.sections;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _getSelectedIndex(_currentTab));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getSelectedIndex(AdminTab tab) {
    switch (tab) {
      case AdminTab.sections: return 0;
      case AdminTab.roster: return 1;
      case AdminTab.zones: return 2;
      case AdminTab.profile: return 3;
      case AdminTab.none: return 0;
    }
  }

  void _onTabSelected(AdminTab tab) {
    if (_currentTab == tab) return;

    final newIndex = _getSelectedIndex(tab);

    // Animate to the new screen with a smooth sliding effect
    _pageController.animateToPage(
      newIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

    setState(() {
      _currentTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        // Prevents the user from swiping manually so the nav bar remains the source of truth
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          AdminDashboardScreen(),
          AdminRosterScreen(),
          SafeZoneMapScreen(),
          AdminProfileScreen(),
        ],
      ),
      floatingActionButton: const EmergencyFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: GlassmorphicBottomNav(
        currentTab: _currentTab,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}