import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/delivery.dart';

/// Driver home — the live list of deliveries assigned to this driver.
///
/// Data comes straight from Supabase via a realtime `.stream()`: new
/// assignments appear, cancellations disappear, and status changes update the
/// badge, all without a manual refresh. Row-Level Security guarantees the query
/// only ever returns THIS driver's deliveries.
class TripsScreen extends StatefulWidget {
  final String? driverName;
  const TripsScreen({super.key, this.driverName});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    final uid = supabase.auth.currentUser!.id;
    _stream = supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('driver_id', uid)
        .order('assigned_at');
  }

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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Centered(
              icon: Icons.error_outline,
              text: 'Could not load your trips.\n${snap.error}',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snap.data!
              .map(Delivery.fromMap)
              .where((d) => d.status != 'cancelled')
              .toList();
          if (trips.isEmpty) {
            return const _Centered(
              icon: Icons.local_shipping_outlined,
              text: 'No trips assigned yet.\nNew deliveries will appear here.',
            );
          }
          return ListView.separated(
            itemCount: trips.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _TripTile(trips[i]),
          );
        },
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final Delivery trip;
  const _TripTile(this.trip);

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Opacity(
      opacity: trip.isDone ? 0.55 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                trip.reference ?? 'No reference',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _StatusBadge(trip),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (trip.goods != null) Text(trip.goods!, style: subtitleStyle),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.circle, size: 9, color: Color(0xFF2F9BD1)),
                const SizedBox(width: 6),
                Expanded(child: Text(trip.originLabel ?? '—', style: subtitleStyle)),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.place, size: 11, color: Colors.redAccent),
                const SizedBox(width: 4),
                Expanded(child: Text(trip.destLabel ?? '—', style: subtitleStyle)),
              ],
            ),
          ],
        ),
        // Tapping opens trip detail — next milestone.
        onTap: () {},
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Delivery trip;
  const _StatusBadge(this.trip);

  Color get _color => switch (trip.status) {
        'en_route' => const Color(0xFF2F9BD1),
        'assigned' => Colors.orange,
        'awaiting_dropoff' => Colors.deepPurple,
        'delivered' => Colors.green,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        trip.statusLabel,
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Centered({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
