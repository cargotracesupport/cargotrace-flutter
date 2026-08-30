import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/delivery.dart';
import '../theme/tokens.dart';
import '../trips/trip_detail_screen.dart';
import '../widgets/ct_widgets.dart';

/// Notifications, derived live from the driver's own deliveries.
///
/// The project has a `notifications` table, but wiring it needs its RLS story
/// and a writer on the web side. For now each delivery's current state becomes
/// one activity item — new assignment, started, awaiting drop-off, delivered,
/// cancelled — so the tab is useful with zero backend work. Same realtime
/// `.stream()` as the trips list, so items appear/update without a refresh.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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

  /// Newest-status-first: cancelled/delivered are terminal so they sink below
  /// the active ones, matching how a driver scans an activity feed.
  List<_Note> _notes(List<Map<String, dynamic>> rows) {
    final notes = rows
        .map(Delivery.fromMap)
        .map(_Note.fromDelivery)
        .where((n) => n != null)
        .cast<_Note>()
        .toList();
    notes.sort((a, b) {
      if (a.terminal != b.terminal) return a.terminal ? 1 : -1;
      return 0;
    });
    return notes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CtHeader(
        title: 'Notifications',
        subtitle: 'Updates on your deliveries',
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
                title: 'Could not load notifications',
                body: 'Check your connection. This screen retries on its own.',
                tint: context.ct.red,
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final notes = _notes(snap.data!);
            if (notes.isEmpty) {
              return const CtMessage(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications',
                body: 'Assignments and delivery updates show up here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  CtSpace.md, CtSpace.md, CtSpace.md, CtSpace.xl),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: CtSpace.sm),
              itemBuilder: (_, i) => _NoteCard(notes[i]),
            );
          },
        ),
      ),
    );
  }
}

/// One derived notification: an icon, a tint, a headline and a supporting line,
/// plus the delivery it refers to so the card can open the trip.
class _Note {
  final Delivery trip;
  final IconData icon;
  final Color Function(CtColors) tint;
  final String title;
  final String body;
  final bool terminal;

  const _Note({
    required this.trip,
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    required this.terminal,
  });

  static _Note? fromDelivery(Delivery d) {
    final ref = d.reference ?? 'your delivery';
    switch (d.status) {
      case 'assigned':
      case 'pending':
        return _Note(
          trip: d,
          icon: Icons.assignment_turned_in_outlined,
          tint: (c) => c.blue,
          title: 'New delivery assigned',
          body: '$ref is ready to start.',
          terminal: false,
        );
      case 'en_route':
        return _Note(
          trip: d,
          icon: Icons.local_shipping_outlined,
          tint: (c) => c.green,
          title: 'Trip in progress',
          body: '$ref is en route.',
          terminal: false,
        );
      case 'awaiting_dropoff':
        return _Note(
          trip: d,
          icon: Icons.pin_drop_outlined,
          tint: (c) => c.amber,
          title: 'Awaiting drop-off',
          body: 'The customer has not set the drop-off for $ref yet.',
          terminal: false,
        );
      case 'delivered':
        return _Note(
          trip: d,
          icon: Icons.check_circle_outline,
          tint: (c) => c.green,
          title: 'Delivered',
          body: '$ref was delivered.',
          terminal: true,
        );
      case 'cancelled':
        return _Note(
          trip: d,
          icon: Icons.cancel_outlined,
          tint: (c) => c.red,
          title: 'Delivery cancelled',
          body: '$ref was cancelled.',
          terminal: true,
        );
      default:
        return null;
    }
  }
}

class _NoteCard extends StatelessWidget {
  final _Note note;
  const _NoteCard(this.note);

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final tint = note.tint(c);
    return CtCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(initial: note.trip)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(note.icon, size: 20, color: tint),
          ),
          const SizedBox(width: CtSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note.body,
                  style: TextStyle(fontSize: 13, color: c.muted2, height: 1.35),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted, size: 20),
        ],
      ),
    );
  }
}
