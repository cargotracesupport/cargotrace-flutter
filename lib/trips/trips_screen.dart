import 'package:flutter/material.dart';

import '../data/db.dart';

/// Driver home — the list of assigned deliveries.
///
/// Placeholder for this milestone: it proves login + role-gate work. The live
/// Supabase query and realtime subscription land in the next milestone.
class TripsScreen extends StatelessWidget {
  final String? driverName;
  const TripsScreen({super.key, this.driverName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 12),
              Text(
                driverName == null
                    ? 'Signed in as a driver.'
                    : 'Welcome, $driverName.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your assigned deliveries will appear here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
