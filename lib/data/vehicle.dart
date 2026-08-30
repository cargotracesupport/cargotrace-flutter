/// A vehicle record from the `vehicles` table. A driver is linked to one via
/// `profiles.vehicle_id`; the plate is what a human reads as the "vehicle
/// number". Pure Dart, no Flutter imports.
class Vehicle {
  final String id;
  final String? plate;
  final String? name;

  const Vehicle({required this.id, this.plate, this.name});

  factory Vehicle.fromMap(Map<String, dynamic> m) => Vehicle(
        id: m['id'] as String,
        plate: m['plate'] as String?,
        name: m['name'] as String?,
      );

  /// What the driver reads as the vehicle number, e.g. "KA01AB1234".
  String get number => plate ?? name ?? 'Vehicle';

  /// Optional friendlier line, e.g. "Tata Ace" under the plate.
  String? get subtitle => (plate != null && name != null) ? name : null;
}
