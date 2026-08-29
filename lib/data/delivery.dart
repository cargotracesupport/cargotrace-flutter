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
  final String? customerPhone;
  final double? originLat, originLng;
  final double? destLat, destLng;
  final double? lastLat, lastLng;
  final DateTime? pickedUpAt;

  const Delivery({
    required this.id,
    required this.status,
    this.reference,
    this.goods,
    this.originLabel,
    this.destLabel,
    this.customerName,
    this.customerPhone,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.lastLat,
    this.lastLng,
    this.pickedUpAt,
  });

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

  factory Delivery.fromMap(Map<String, dynamic> m) => Delivery(
        id: m['id'] as String,
        status: (m['status'] as String?) ?? 'pending',
        reference: m['reference'] as String?,
        goods: m['goods'] as String?,
        originLabel: m['origin_label'] as String?,
        destLabel: m['dest_label'] as String?,
        customerName: m['customer_name'] as String?,
        customerPhone: m['customer_phone'] as String?,
        originLat: _d(m['origin_lat']),
        originLng: _d(m['origin_lng']),
        destLat: _d(m['dest_lat']),
        destLng: _d(m['dest_lng']),
        lastLat: _d(m['last_lat']),
        lastLng: _d(m['last_lng']),
        pickedUpAt: m['picked_up_at'] == null
            ? null
            : DateTime.tryParse(m['picked_up_at'] as String),
      );

  bool get hasOrigin => originLat != null && originLng != null;
  bool get hasDest => destLat != null && destLng != null;
  bool get hasPosition => lastLat != null && lastLng != null;
  bool get isDone => status == 'delivered';
}
