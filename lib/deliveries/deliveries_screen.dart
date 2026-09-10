import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/delivery.dart';
import '../theme/tokens.dart';
import '../trips/trip_detail_screen.dart';
import '../widgets/ct_widgets.dart';

/// Every delivery assigned to this driver — upcoming/active first, then past
/// (delivered or cancelled). Live via the same realtime `.stream()`, so a new
/// assignment or a status change moves between sections without a refresh.
class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
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

  /// Pull-to-refresh: one round-trip to prove the connection, then resubscribe.
  Future<void> _refresh() async {
    await supabase
        .from('deliveries')
        .select('id')
        .eq('driver_id', supabase.auth.currentUser!.id)
        .limit(1);
    if (mounted) setState(() => _stream = _build());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Scaffold(
      appBar: const CtHeader(
        title: 'Deliveries',
        subtitle: 'Upcoming and past',
        automaticallyImplyLeading: false,
        actions: [CtDriverBadge()],
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
                  title: 'Could not load deliveries',
                  body:
                      'Check your connection. This screen retries on its own.',
                  tint: c.red,
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!.map(Delivery.fromMap).toList();
            final upcoming = all
                .where((d) => !d.isDone && d.status != 'cancelled')
                .toList();
            final past = all
                .where((d) => d.isDone || d.status == 'cancelled')
                .toList()
                .reversed
                .toList();

            if (upcoming.isEmpty && past.isEmpty) {
              return CtPullable(
                onRefresh: _refresh,
                child: const CtMessage(
                  icon: Icons.inventory_2_outlined,
                  title: 'No deliveries yet',
                  body: 'Assignments from your dispatcher show up here.',
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  CtSpace.md,
                  CtSpace.md,
                  CtSpace.md,
                  CtSpace.xl,
                ),
                children: [
                  if (upcoming.isNotEmpty) ...[
                    const CtSectionLabel('UPCOMING'),
                    ...upcoming.map((d) => _DeliveryRow(d)),
                  ],
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: CtSpace.md),
                    const CtSectionLabel('PAST'),
                    ...past.map((d) => _DeliveryRow(d)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  final Delivery trip;
  const _DeliveryRow(this.trip);

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Padding(
      padding: const EdgeInsets.only(bottom: CtSpace.sm),
      child: Opacity(
        opacity: trip.isDone || trip.status == 'cancelled' ? 0.7 : 1,
        child: CtCard(
          onTap: () => Navigator.of(
            context,
          ).push(CtPageRoute(builder: (_) => TripDetailScreen(initial: trip))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.reference ?? 'No reference',
                      style: CtType.cardTitle.copyWith(
                        fontSize: 15,
                        color: c.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: CtSpace.sm),
                  CtStatusPill(trip.status),
                ],
              ),
              const SizedBox(height: CtSpace.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.route_rounded, size: 15, color: c.muted),
                  const SizedBox(width: CtSpace.sm),
                  Expanded(
                    child: Text(
                      '${trip.originLabel ?? 'Pickup not set'}  →  '
                      '${trip.destLabel ?? 'Drop-off not set'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.muted2,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
