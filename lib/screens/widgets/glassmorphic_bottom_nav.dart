import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const Color primaryRed = Color(0xFF751018);
const Color accentYellow = Color(0xFFFDBF44);

enum AdminTab { sections, roster, zones, profile, none }

class GlassmorphicBottomNav extends StatelessWidget {
  final AdminTab currentTab;
  final ValueChanged<AdminTab> onTabSelected; // Added callback

  const GlassmorphicBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: BottomAppBar(
          color: Colors.white.withValues(alpha: 0.8),
          elevation: 0,
          notchMargin: 12,
          shape: const CircularNotchedRectangle(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(CupertinoIcons.square_grid_2x2_fill, 'Sections', AdminTab.sections),
              _buildNavItem(CupertinoIcons.person_3_fill, 'Roster', AdminTab.roster),
              const SizedBox(width: 48), // Space for the Center FAB
              _buildNavItem(CupertinoIcons.shield_fill, 'Zones', AdminTab.zones),
              _buildNavItem(CupertinoIcons.person_crop_circle_fill, 'Profile', AdminTab.profile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, AdminTab tab) {
    final isSelected = currentTab == tab;
    return GestureDetector(
      onTap: () {
        if (currentTab != tab) {
          onTabSelected(tab); // Trigger state change instead of routing
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryRed : Colors.grey.shade500,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? primaryRed : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}