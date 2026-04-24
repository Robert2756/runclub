import 'package:flutter/material.dart';

class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      height: 55,
      backgroundColor: Colors.white,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, size: 28, color: Colors.black),
          selectedIcon: Icon(Icons.home, size: 28, color: Colors.black),
          label: '',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined, size: 28, color: Colors.black),
          selectedIcon: Icon(Icons.history, size: 28, color: Colors.black),
          label: '',
        ),
      ],
    );
  }
}