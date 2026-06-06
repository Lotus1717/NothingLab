class ProphecyRecord {
  final String text;
  final int? battery;
  final int brightness;
  final int steps;
  final bool isMoving;
  final int? volume;
  final int? ambientLight;
  final int time;

  const ProphecyRecord({
    required this.text,
    this.battery,
    required this.brightness,
    required this.steps,
    required this.isMoving,
    this.volume,
    this.ambientLight,
    required this.time,
  });

  factory ProphecyRecord.fromSensor({
    required String text,
    required int? battery,
    required int brightness,
    required int steps,
    required bool isMoving,
    int? volume,
    int? ambientLight,
    DateTime? at,
  }) {
    return ProphecyRecord(
      text: text,
      battery: battery,
      brightness: brightness,
      steps: steps,
      isMoving: isMoving,
      volume: volume,
      ambientLight: ambientLight,
      time: (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  factory ProphecyRecord.fromJson(Map<String, dynamic> json) {
    return ProphecyRecord(
      text: json['text'] as String? ?? '',
      battery: json['battery'] as int?,
      brightness: json['brightness'] as int? ?? 50,
      steps: json['steps'] as int? ?? 0,
      isMoving: json['isMoving'] as bool? ?? false,
      volume: json['volume'] as int?,
      ambientLight: json['ambientLight'] as int?,
      time: json['time'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'battery': battery,
        'brightness': brightness,
        'steps': steps,
        'isMoving': isMoving,
        if (volume != null) 'volume': volume,
        if (ambientLight != null) 'ambientLight': ambientLight,
        'time': time,
      };
}
