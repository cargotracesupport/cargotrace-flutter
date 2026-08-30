import 'package:flutter/material.dart';

import '../data/vehicle.dart';
import '../deliveries/deliveries_screen.dart';
import '../profile/profile_screen.dart';
import '../trips/trips_screen.dart';

/// The signed-in driver's home: three tabs behind a bottom navigation bar —
/// Home (trips), Notifications, Profile. An [IndexedStack] keeps each tab's
/// state (and its live Supabase stream) alive while switching.
class HomeShell extends StatefulWidget {
  final String? driverName;
  final String? phone;
  final Vehicle? vehicle;

  const HomeShell({
    super.key,
    this.driverName,
    this.phone,
    this.vehicle,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TripsScreen(driverName: widget.driverName),
      const DeliveriesScreen(),
      ProfileScreen(
        driverName: widget.driverName,
        phone: widget.phone,
        vehicle: widget.vehicle,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
