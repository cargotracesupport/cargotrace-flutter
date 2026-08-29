/// A delivery assigned to the driver — one "trip". Mirrors the columns the
/// driver needs from the `deliveries` table. Pure Dart: no Flutter imports, so
/// it stays easy to test.
class Delivery {
  final String id;
  final String? reference;
  final String status;
  final String? goods;
  final String? originLabel;
  final String? destLabel;
  final String? customerName;

  const Delivery({
    required this.id,
    required this.status,
    this.reference,
    this.goods,
    this.originLabel,
    this.destLabel,
    this.customerName,
  });

  factory Delivery.fromMap(Map<String, dynamic> m) => Delivery(
        id: m['id'] as String,
        status: (m['status'] as String?) ?? 'pending',
        reference: m['reference'] as String?,
        goods: m['goods'] as String?,
        originLabel: m['origin_label'] as String?,
        destLabel: m['dest_label'] as String?,
        customerName: m['customer_name'] as String?,
      );

  /// Human label for the status badge.
  String get statusLabel => switch (status) {
        'pending' => 'Pending',
        'assigned' => 'Assigned',
        'en_route' => 'On the way',
        'awaiting_dropoff' => 'Awaiting drop-off',
        'delivered' => 'Delivered',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  bool get isDone => status == 'delivered';
}
