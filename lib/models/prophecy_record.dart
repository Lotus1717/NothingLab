class ProphecyRecord {
  final String text;
  final int? battery;
  final int brightness;
  final int steps;
  final bool isMoving;
  final int time;

  const ProphecyRecord({
    required this.text,
    this.battery,
    required this.brightness,
    required this.steps,
    required this.isMoving,
    required this.time,
  });

  factory ProphecyRecord.fromSensor({
    required String text,
    required int? battery,
    required int brightness,
    required int steps,
    required bool isMoving,
    DateTime? at,
  }) {
    return ProphecyRecord(
      text: text,
      battery: battery,
      brightness: brightness,
      steps: steps,
      isMoving: isMoving,
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
      time: json['time'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'battery': battery,
        'brightness': brightness,
        'steps': steps,
        'isMoving': isMoving,
        'time': time,
      };
}
