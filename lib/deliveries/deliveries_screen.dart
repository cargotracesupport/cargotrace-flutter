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
              return CtMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load deliveries',
                body: 'Check your connection. This screen retries on its own.',
                tint: c.red,
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!.map(Delivery.fromMap).toList();
            final upcoming =
                all.where((d) => !d.isDone && d.status != 'cancelled').toList();
            final past = all
                .where((d) => d.isDone || d.status == 'cancelled')
                .toList()
                .reversed
                .toList();

            if (upcoming.isEmpty && past.isEmpty) {
              return const CtMessage(
                icon: Icons.inventory_2_outlined,
                title: 'No deliveries yet',
                body: 'Assignments from your dispatcher show up here.',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  CtSpace.md, CtSpace.md, CtSpace.md, CtSpace.xl),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const _SectionLabel('UPCOMING'),
                  ...upcoming.map((d) => _DeliveryRow(d)),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: CtSpace.md),
                  const _SectionLabel('PAST'),
                  ...past.map((d) => _DeliveryRow(d)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Padding(
      padding: const EdgeInsets.only(bottom: CtSpace.sm, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: c.muted,
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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => TripDetailScreen(initial: trip)),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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
