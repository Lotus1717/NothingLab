class SensorData {
  int? battery;
  bool charging = false;
  int brightness = 50;
  int steps = 0;
  bool isMoving = false;
  int ambientLight = 100;
  bool isRealBattery = false;
  bool isRealMotion = false;
  bool isRealSteps = false;
  DateTime timestamp = DateTime.now();
  String timeHint = '';
  String dayPhase = '';

  SensorData({
    this.battery,
    this.charging = false,
    this.brightness = 50,
    this.steps = 0,
    this.isMoving = false,
    this.ambientLight = 100,
    this.isRealBattery = false,
    this.isRealMotion = false,
    this.isRealSteps = false,
    required this.timestamp,
    required this.timeHint,
    required this.dayPhase,
  });

  factory SensorData.mock() {
    final now = DateTime.now();
    return SensorData(
      battery: 50 + (now.minute % 50),
      charging: false,
      brightness: 50 + (now.minute % 30),
      steps: now.minute * 100 + 500,
      isMoving: now.minute % 3 != 0,
      ambientLight: 100 + (now.minute % 200),
      timestamp: now,
      timeHint: timeHintFor(now),
      dayPhase: dayPhaseFor(now),
    );
  }

  static String timeHintFor(DateTime now) {
    final h = now.hour;
    if (h < 6) return '凌晨发呆模式';
    if (h < 9) return '刚睡醒迷糊中';
    if (h < 12) return '上午搬砖中';
    if (h < 14) return '午饭消化期';
    if (h < 18) return '下午摸鱼中';
    if (h < 22) return '晚上放松中';
    return '深夜修仙中';
  }

  static String dayPhaseFor(DateTime now) {
    final h = now.hour;
    if (h >= 6 && h < 12) return '早晨';
    if (h >= 12 && h < 14) return '中午';
    if (h >= 14 && h < 18) return '下午';
    if (h >= 18 && h < 22) return '傍晚';
    return '夜晚';
  }

  SensorData withCurrentTimeHints() {
    final now = DateTime.now();
    return copyWith(
      timestamp: now,
      timeHint: timeHintFor(now),
      dayPhase: dayPhaseFor(now),
    );
  }

  SensorData copyWith({
    int? battery,
    bool? charging,
    int? brightness,
    int? steps,
    bool? isMoving,
    int? ambientLight,
    bool? isRealBattery,
    bool? isRealMotion,
    bool? isRealSteps,
    DateTime? timestamp,
    String? timeHint,
    String? dayPhase,
  }) {
    return SensorData(
      battery: battery ?? this.battery,
      charging: charging ?? this.charging,
      brightness: brightness ?? this.brightness,
      steps: steps ?? this.steps,
      isMoving: isMoving ?? this.isMoving,
      ambientLight: ambientLight ?? this.ambientLight,
      isRealBattery: isRealBattery ?? this.isRealBattery,
      isRealMotion: isRealMotion ?? this.isRealMotion,
      isRealSteps: isRealSteps ?? this.isRealSteps,
      timestamp: timestamp ?? this.timestamp,
      timeHint: timeHint ?? this.timeHint,
      dayPhase: dayPhase ?? this.dayPhase,
    );
  }
}
