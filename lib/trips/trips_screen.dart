import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/delivery.dart';
import 'trip_detail_screen.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Driver home — the live list of deliveries assigned to this driver.
///
/// Only live work is listed — a trip leaves Home the moment it is delivered or
/// cancelled, and the Deliveries tab keeps the full history.
///
/// Data comes straight from Supabase via a realtime `.stream()`: new
/// assignments appear, finished ones disappear, and status changes update the
/// pill, all without a manual refresh. Row-Level Security guarantees the query
/// only ever returns THIS driver's deliveries.
class TripsScreen extends StatefulWidget {
  final String? driverName;
  const TripsScreen({super.key, this.driverName});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _build();
  }

  Stream<List<Map<String, dynamic>>> _build() => supabase
      .from('deliveries')
      .stream(primaryKey: ['id'])
      .eq('driver_id', supabase.auth.currentUser!.id)
      .order('assigned_at');

  /// Pull-to-refresh. The list is already realtime, so this is a reconnect:
  /// one round-trip to prove the connection is alive (and to surface an error
  /// if it isn't), then a fresh subscription.
  Future<void> _refresh() async {
    await supabase
        .from('deliveries')
        .select('id')
        .eq('driver_id', supabase.auth.currentUser!.id)
        .limit(1);
    if (mounted) setState(() => _stream = _build());
  }

  /// Home is the driver's live work only: finished and cancelled trips drop
  /// off the list. The full history, completed included, is the Deliveries tab.
  List<Delivery> _active(List<Map<String, dynamic>> rows) => rows
      .map(Delivery.fromMap)
      .where((d) => !d.isDone && d.status != 'cancelled')
      .toList();

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final name = widget.driverName?.split(' ').first;
    return Scaffold(
      appBar: CtHeader(
        title: name == null ? 'My trips' : 'Hi, $name',
        subtitle: 'Your assigned deliveries',
        automaticallyImplyLeading: false,
        actions: const [CtDriverBadge()],
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return CtPullable(
                onRefresh: _refresh,
                child: CtMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load your trips',
                  body:
                      'Check your connection. This screen retries on its own.',
                  tint: c.red,
                ),
              );
            }
            if (!snap.hasData) {
              return ListView.separated(
                padding: const EdgeInsets.all(CtSpace.md),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: CtSpace.md),
                itemBuilder: (_, __) => const CtTripSkeleton(),
              );
            }
            final trips = _active(snap.data!);
            if (trips.isEmpty) {
              return CtPullable(
                onRefresh: _refresh,
                child: const CtMessage(
                  icon: Icons.local_shipping_outlined,
                  title: 'Nothing on the road',
                  body:
                      'New assignments appear here right away. Completed '
                      'deliveries live in the Deliveries tab.',
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  CtSpace.md,
                  CtSpace.md,
                  CtSpace.md,
                  CtSpace.xl,
                ),
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: CtSpace.md),
                itemBuilder: (_, i) => _TripCard(trips[i]),
              ),
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
    return CtCard(
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
            Text(trip.goods!, style: TextStyle(color: c.muted2, fontSize: 13)),
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
