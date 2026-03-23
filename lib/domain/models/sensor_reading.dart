/// Modelo de una lectura individual de sensor almacenada en Aiven MySQL.
class SensorReading {
  final int componentId;
  final double value;
  final DateTime timestamp;

  const SensorReading({
    required this.componentId,
    required this.value,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      componentId: json['id_componente'] as int,
      value: (json['valor'] as num).toDouble(),
      timestamp: DateTime.parse(json['fecha'] as String),
    );
  }

  /// Nombre legible del componente basado en el ID del bridge
  String get componentName {
    switch (componentId) {
      case 1: return 'Presión Bomba 1';
      case 2: return 'Presión Bomba 2';
      case 3: return 'Nivel Tanque Lluvia';
      case 4: return 'Nivel Tanque Calle';
      case 5: return 'Turbidez';
      case 6: return 'Estado Bomba';
      default: return 'Desconocido';
    }
  }
}
