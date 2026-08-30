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
  final DateTime? startedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

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
    this.startedAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
  static DateTime? _t(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

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
        startedAt: _t(m['started_at']),
        pickedUpAt: _t(m['picked_up_at']),
        deliveredAt: _t(m['delivered_at']),
      );

  bool get hasOrigin => originLat != null && originLng != null;
  bool get hasDest => destLat != null && destLng != null;
  bool get hasPosition => lastLat != null && lastLng != null;
  bool get isDone => status == 'delivered';
  bool get isEnRoute => status == 'en_route';
  bool get isPickedUp => pickedUpAt != null;

  /// Where the driver is heading right now: the pickup until goods are on
  /// board, the drop-off after. Null when that point has no coordinates.
  ({double lat, double lng})? get navTarget {
    if (!isPickedUp && hasOrigin) return (lat: originLat!, lng: originLng!);
    if (hasDest) return (lat: destLat!, lng: destLng!);
    if (hasOrigin) return (lat: originLat!, lng: originLng!);
    return null;
  }
}
