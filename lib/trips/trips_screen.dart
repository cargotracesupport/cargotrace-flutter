import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/delivery.dart';
import 'trip_detail_screen.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Driver home — the live list of deliveries assigned to this driver.
///
/// Data comes straight from Supabase via a realtime `.stream()`: new
/// assignments appear, cancellations disappear, and status changes update the
/// pill, all without a manual refresh. Row-Level Security guarantees the query
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

  /// Active trips first, finished ones last; newest first within each group.
  List<Delivery> _sorted(List<Map<String, dynamic>> rows) {
    final trips = rows
        .map(Delivery.fromMap)
        .where((d) => d.status != 'cancelled')
        .toList();
    trips.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return 0;
    });
    return trips;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final name = widget.driverName?.split(' ').first;
    return Scaffold(
      appBar: CtHeader(
        title: name == null ? 'My trips' : 'Hi, $name',
        subtitle: 'Your assigned deliveries',
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return CtMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load your trips',
                body: 'Check your connection. This screen retries on its own.',
                tint: c.red,
              );
            }
            if (!snap.hasData) {
              return ListView.separated(
                padding: const EdgeInsets.all(CtSpace.md),
                itemCount: 3,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: CtSpace.md),
                itemBuilder: (_, __) => const CtTripSkeleton(),
              );
            }
            final trips = _sorted(snap.data!);
            if (trips.isEmpty) {
              return const CtMessage(
                icon: Icons.local_shipping_outlined,
                title: 'No trips yet',
                body: 'When a dispatcher assigns you a delivery, '
                    'it appears here right away.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  CtSpace.md, CtSpace.md, CtSpace.md, CtSpace.xl),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: CtSpace.md),
              itemBuilder: (_, i) => _TripCard(trips[i]),
            );
          },
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Delivery trip;
  const _TripCard(this.trip);

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Opacity(
      opacity: trip.isDone ? 0.62 : 1,
      child: CtCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripDetailScreen(initial: trip)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.reference ?? 'No reference',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: CtSpace.sm),
                CtStatusPill(trip.status),
              ],
            ),
            if (trip.goods != null) ...[
              const SizedBox(height: CtSpace.xs),
              Text(
                trip.goods!,
                style: TextStyle(color: c.muted2, fontSize: 13),
              ),
            ],
            const SizedBox(height: CtSpace.md),
            _Leg(
              color: c.primary,
              filled: true,
              label: 'Pick up',
              value: trip.originLabel,
            ),
            _Connector(color: c.border2),
            _Leg(
              color: c.accent,
              filled: false,
              label: 'Drop off',
              value: trip.destLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// One end of the journey: a marker, a small caption and the address.
class _Leg extends StatelessWidget {
  final Color color;
  final bool filled;
  final String label;
  final String? value;
  const _Leg({
    required this.color,
    required this.filled,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: filled ? color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
          ),
        ),
        const SizedBox(width: CtSpace.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: c.muted,
                ),
              ),
              Text(
                value ?? 'Not set',
                style: TextStyle(
                  fontSize: 14,
                  color: value == null ? c.muted : c.text,
                  fontStyle: value == null ? FontStyle.italic : null,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The short vertical rule joining pickup to drop-off.
class _Connector extends StatelessWidget {
  final Color color;
  const _Connector({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.5),
      child: Container(width: 2, height: 16, color: color),
    );
  }
}
