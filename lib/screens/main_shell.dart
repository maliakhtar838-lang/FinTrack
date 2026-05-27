import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dashboard_view.dart';
import 'events_savings_view.dart';
import 'khaata_view.dart';
import 'subscriptions_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  final pages = const [
    DashboardView(),
    EventsSavingsView(),
    SubscriptionsView(),
    KhaataView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (value) => setState(() => index = value),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.event_note_rounded), label: 'Events'),
            BottomNavigationBarItem(icon: Icon(Icons.repeat_rounded), label: 'Bills'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'eKhaata'),
          ],
        ),
      ),
    );
  }
}
