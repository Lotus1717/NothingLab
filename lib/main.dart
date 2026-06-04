import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer_2/pedometer_2.dart';
import 'config/theme.dart';
import 'services/prophecy_generator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ═══════════════════════════════════════════
//  传感器数据模型
// ═══════════════════════════════════════════

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
    final h = now.hour;
    String t;
    if (h < 6) {
      t = '凌晨发呆模式';
    } else if (h < 9) {
      t = '刚睡醒迷糊中';
    } else if (h < 12) {
      t = '上午搬砖中';
    } else if (h < 14) {
      t = '午饭消化期';
    } else if (h < 18) {
      t = '下午摸鱼中';
    } else if (h < 22) {
      t = '晚上放松中';
    } else {
      t = '深夜修仙中';
    }
    String p;
    if (h >= 6 && h < 12) {
      p = '早晨';
    } else if (h >= 12 && h < 14) {
      p = '中午';
    } else if (h >= 14 && h < 18) {
      p = '下午';
    } else if (h >= 18 && h < 22) {
      p = '傍晚';
    } else {
      p = '夜晚';
    }
    return SensorData(
      battery: 50 + (now.minute % 50),
      charging: false,
      brightness: 50 + (now.minute % 30),
      steps: now.minute * 100 + 500,
      isMoving: now.minute % 3 != 0,
      ambientLight: 100 + (now.minute % 200),
      timestamp: now,
      timeHint: t,
      dayPhase: p,
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

// ═══════════════════════════════════════════
//  传感器服务
// ═══════════════════════════════════════════

class SensorService extends ChangeNotifier {
  SensorData _data = SensorData.mock();
  final Battery _battery = Battery();
  StreamSubscription? _accelSub;
  StreamSubscription? _pedoSub;
  Timer? _stepTimer;
  int _stepOffset = 0;

  SensorData get data => _data;

  Future<void> init() async {
    _initBattery();
    _initAccelerometer();
    _initPedometer();
    _startMockSteps();
  }

  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      _data = _data.copyWith(
        battery: level,
        charging:
            state == BatteryState.charging || state == BatteryState.full,
        isRealBattery: true,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Battery error: $e');
    }
    _battery.onBatteryStateChanged.listen((s) {
      _battery.batteryLevel.then((l) {
        _data = _data.copyWith(
          battery: l,
          charging: s == BatteryState.charging || s == BatteryState.full,
        );
        notifyListeners();
      });
    });
  }

  void _initAccelerometer() {
    try {
      _accelSub = accelerometerEventStream().listen((e) {
        final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if ((mag - 9.8).abs() > 3) {
          _data = _data.copyWith(
            isMoving: true,
            isRealMotion: true,
            timestamp: DateTime.now(),
          );
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Accel error: $e');
    }
  }

  void _initPedometer() {
    try {
      final pedometer = Pedometer();
      _pedoSub = pedometer.stepCountStream().listen(
        (stepCount) {
          if (_stepOffset == 0) {
            _stepOffset = stepCount;
            return;
          }
          final steps = stepCount - _stepOffset;
          if (steps >= 0) {
            _data = _data.copyWith(steps: steps, isRealSteps: true);
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('Pedometer error: $e');
        },
      );
    } catch (e) {
      debugPrint('Pedometer error: $e');
    }
  }

  void _startMockSteps() {
    _stepTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_data.isRealSteps) {
        final random = Random();
        _data = _data.copyWith(
          steps: _data.steps + random.nextInt(3),
          timestamp: DateTime.now(),
        );
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _pedoSub?.cancel();
    _stepTimer?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════
//  AI 预言服务（支持真实 ML 模型 + 本地回退）
// ═══════════════════════════════════════════

class AiService extends ChangeNotifier {
  bool _loading = false;
  bool _modelLoaded = false;
  bool _isModelAvailable = false; // 是否 iOS 且支持 MLX
  String _currentProphecy = '';
  List<Map<String, dynamic>> _history = [];

  final ProphecyGeneratorBridge _bridge = ProphecyGeneratorBridge();

  bool get loading => _loading;
  bool get modelLoaded => _modelLoaded;
  bool get isModelAvailable => _isModelAvailable;
  String get currentProphecy => _currentProphecy;
  List<Map<String, dynamic>> get history => _history;

  static const _animalLoading = [
    '🐱 小猫正在抓阄中...',
    '🦊 小狐狸在编废话...',
    '🐢 乌龟在认真思考...',
    '🐰 小兔子在翻预言书...',
    '🦡 獾子在推算命运...',
  ];

  /// 检查 MLX 模型是否可用（仅 iOS）
  Future<void> checkModelAvailability() async {
    try {
      // 尝试调用 MethodChannel，如果平台不支持会抛出异常
      final loaded = await _bridge.isLoaded();
      _isModelAvailable = true;
      _modelLoaded = loaded;
      notifyListeners();
    } catch (e) {
      _isModelAvailable = false;
      _modelLoaded = false;
      debugPrint('MLX model not available: $e');
    }
  }

  /// 加载 ML 模型（首次需下载约 200MB）
  Future<void> loadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (_modelLoaded || !_isModelAvailable) return;

    _loading = true;
    notifyListeners();

    try {
      await _bridge.loadModel();
      _modelLoaded = true;
    } catch (e) {
      debugPrint('Model load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 本地回退预言库（当 ML 模型不可用时）
  static final _fallbackProphecies = [
    (d) =>
        '电量${d.battery ?? 50}%时，你的拇指滑屏速度会比平时快${((d.battery ?? 50) % 5 + 1) * 0.2}倍',
    (d) =>
        '今日步数${d.steps}步，你的手指比预期早了${((d.battery ?? 50) % 7) * 0.1}秒划到下一张图',
    (d) =>
        '屏幕亮度${d.brightness}%时，你的下一口呼吸比上一口重${(((d.battery ?? 50) % 3) + 1) * 0.001}克',
    (d) =>
        '电量${d.battery ?? 50}%且${d.isMoving ? "正在移动" : "静止"}，你接下来的路会踩到一片落叶',
    (d) =>
        '步数破${(d.steps / 1000).ceil()}k时，你划过的第${((d.battery ?? 50) % 5) + 1}条视频会讲一只猫的名字',
    (d) =>
        '当前状态${d.timeHint}，你的眼角余光会捕捉到一只路过的小鸟',
    (d) =>
        '电量${d.battery ?? 50}%的此刻，你口袋里有一张被遗忘的小票在等你发现',
    (d) =>
        '${d.dayPhase}好！根据你${d.isMoving ? "正在移动" : "静止"}的状态推算，你下一次打哈欠会在${((d.battery ?? 50) % 8) + 2}分钟后',
    (d) =>
        '你的手机壳温度比平时高了${(((d.battery ?? 50) % 3) + 1) * 0.3}℃，说明你刚才握得比较紧',
    (d) =>
        '步数${d.steps}，你今天少走的${((d.battery ?? 50) % 200 + 50)}步会在明天变成小零食补回来',
    (d) =>
        '电量${d.battery ?? 50}%时，你更适合做需要耐心的决定——比如先刷哪条视频',
    (d) =>
        '现在是${d.dayPhase}，你大脑的多巴胺水平比上午低了${((d.battery ?? 50) % 20) + 5}%',
    (d) =>
        '你的手机处于${d.brightness > 60 ? "高亮度" : "省电模式"}状态，你的心情指数也类似',
    (d) =>
        '检测到你在${d.timeHint}，接下来适合做创意的白日梦',
  ];

  /// 生成预言（优先使用 ML 模型，不可用时回退到本地库）
  Future<String> generateProphecy(SensorData sensor) async {
    _loading = true;
    notifyListeners();

    String prophecy;

    // 尝试使用 MLX 模型
    if (_modelLoaded && _isModelAvailable) {
      try {
        prophecy = await _bridge.generateProphecy(
          battery: sensor.battery ?? 50,
          brightness: sensor.brightness,
          steps: sensor.steps,
          isMoving: sensor.isMoving,
          ambientLight: sensor.ambientLight,
          timeHint: sensor.timeHint,
          dayPhase: sensor.dayPhase,
        );
      } catch (e) {
        debugPrint('ML generation failed, using fallback: $e');
        prophecy = _getFallbackProphecy(sensor);
      }
    } else {
      // 本地回退
      await Future.delayed(const Duration(milliseconds: 800));
      prophecy = _getFallbackProphecy(sensor);
    }

    _currentProphecy = prophecy;
    _history.insert(0, {
      'text': prophecy,
      'battery': sensor.battery,
      'brightness': sensor.brightness,
      'steps': sensor.steps,
      'isMoving': sensor.isMoving,
      'time': DateTime.now().millisecondsSinceEpoch,
    });
    if (_history.length > 30) _history.removeLast();

    _loading = false;
    notifyListeners();
    return prophecy;
  }

  String _getFallbackProphecy(SensorData sensor) {
    final idx = ((sensor.battery ?? 50) +
            sensor.brightness +
            sensor.steps % 10 +
            sensor.timestamp.minute)
        .abs() %
        _fallbackProphecies.length;
    return _fallbackProphecies[idx](sensor);
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  void deleteHistory(int i) {
    if (i >= 0 && i < _history.length) {
      _history.removeAt(i);
      notifyListeners();
    }
  }

  String getLoadingText(int s) => _animalLoading[s % _animalLoading.length];
}

// ═══════════════════════════════════════════
//  主应用
// ═══════════════════════════════════════════

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SensorService()..init()),
        ChangeNotifierProvider(create: (_) => AiService()),
      ],
      child: MaterialApp(
        title: '🐣 废话预言家',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppRoot(),
      ),
    );
  }
}

/// 启动时检查 ML 模型可用性，然后进入主界面
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _checkingModel = true;
  bool _loadingModel = false;
  double _modelProgress = 0;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    final ai = context.read<AiService>();
    await ai.checkModelAvailability();

    if (ai.isModelAvailable && !ai.modelLoaded) {
      // 询问用户是否要下载模型
      if (mounted) {
        setState(() => _checkingModel = false);
      }
    } else {
      if (mounted) {
        setState(() => _checkingModel = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingModel) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadingModel) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🧠', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 24),
                const Text(
                  '正在下载 AI 模型…',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '首次需要下载约 200MB\n后续使用无需再次下载',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _modelProgress > 0 ? _modelProgress : null,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _modelProgress > 0
                      ? '${(_modelProgress * 100).toStringAsFixed(0)}%'
                      : '准备中…',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<AiService>(
      builder: (context, ai, _) {
        // 如果有 ML 模型可用但未加载，在主页显示提示
        // 但先直接进主页
        return const MainScreen();
      },
    );
  }
}

// ═══════════════════════════════════════════
//  主屏幕
// ═══════════════════════════════════════════

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [HomePage(), HistoryPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFFFF8A7A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '首页'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded), label: '历史'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), label: '设置'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  首页
// ═══════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _dicePressed = false;
  int _loadingStep = 0;
  Timer? _loadingTimer;

  void _onDicePressed() async {
    if (_dicePressed) return;
    setState(() => _dicePressed = true);
    final ai = context.read<AiService>();
    final sensor = context.read<SensorService>().data;
    int step = 0;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted || !ai.loading) {
        _loadingTimer?.cancel();
        return;
      }
      setState(() => _loadingStep = step++);
    });
    await ai.generateProphecy(sensor);
    _loadingTimer?.cancel();
    if (mounted) setState(() => _dicePressed = false);
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SensorService, AiService>(
      builder: (context, sensorSvc, aiSvc, _) {
        final s = sensorSvc.data;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text('🐣', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 8),
                    const Text(
                      '废话预言家',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const Spacer(),
                    // 模型状态指示器
                    if (aiSvc.isModelAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: aiSvc.modelLoaded
                              ? AppTheme.secondary.withOpacity(0.2)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          aiSvc.modelLoaded ? '🧠 本地AI' : '📡 本地',
                          style: TextStyle(
                            fontSize: 11,
                            color: aiSvc.modelLoaded
                                ? AppTheme.textDark
                                : AppTheme.textLight,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 24),
                      onPressed: () {},
                      color: AppTheme.textLight,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SensorCard(sensor: s),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      _DiceButton(
                        pressed: _dicePressed,
                        loading: aiSvc.loading,
                        onPressed: _onDicePressed,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        aiSvc.loading
                            ? aiSvc.getLoadingText(_loadingStep)
                            : '[ 戳一下 ]',
                        style: const TextStyle(
                            fontSize: 15, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (aiSvc.currentProphecy.isNotEmpty && !aiSvc.loading)
                  _ProphecyCard(
                    prophecy: aiSvc.currentProphecy,
                    onRefresh: _onDicePressed,
                  ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯',
                    style: TextStyle(
                      color: Color(0xFFDDDDDD),
                      fontSize: 13,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
//  传感器卡片
// ═══════════════════════════════════════════

class _SensorCard extends StatelessWidget {
  final SensorData sensor;
  const _SensorCard({required this.sensor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgMint,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _item('🔋', '电量', '${sensor.battery ?? "--"}%')),
              Expanded(child: _item('☀️', '亮度', '${sensor.brightness}%')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _item('🚶', '步数', '${sensor.steps}')),
              Expanded(
                  child:
                      _item('📳', '状态', sensor.isMoving ? '移动中' : '静止')),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0x11000000), width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${sensor.dayPhase} · ${sensor.timeHint}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                ),
                const Spacer(),
                Text(
                  sensor.isRealBattery ? '🔋真' : '🔋模',
                  style: TextStyle(
                    fontSize: 11,
                    color: sensor.isRealBattery
                        ? AppTheme.secondary
                        : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
//  掷骰按钮
// ═══════════════════════════════════════════

class _DiceButton extends StatefulWidget {
  final bool pressed;
  final bool loading;
  final VoidCallback onPressed;

  const _DiceButton({
    required this.pressed,
    required this.loading,
    required this.onPressed,
  });

  @override
  State<_DiceButton> createState() => _DiceButtonState();
}

class _DiceButtonState extends State<_DiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _anim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(_DiceButton old) {
    super.didUpdateWidget(old);
    if (widget.loading && !old.loading) {
      _ctrl.repeat();
    } else if (!widget.loading && old.loading) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.loading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Transform.rotate(
          angle: widget.loading ? _anim.value * 6.2832 : 0,
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD3B5), Color(0xFFFFB7B2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB7B2).withOpacity(0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text('🎲', style: TextStyle(fontSize: 52)),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  预言卡片
// ═══════════════════════════════════════════

class _ProphecyCard extends StatelessWidget {
  final String prophecy;
  final VoidCallback onRefresh;

  const _ProphecyCard({
    required this.prophecy,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, v, _) => Transform.scale(
        scale: 0.92 + 0.08 * v,
        child: Opacity(opacity: v, child: this),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          Text(
            '"$prophecy"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              color: AppTheme.textDark,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _btn('🔄 再来一条', onRefresh, primary: true),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _btn(String text, VoidCallback onPressed, {bool primary = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: primary
              ? AppTheme.primary
              : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primary ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  历史记录页
// ═══════════════════════════════════════════

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  String _fmt(int ts) {
    final diff = DateTime.now().millisecondsSinceEpoch - ts;
    if (diff < 60000) return '刚刚';
    if (diff < 3600000) return '${(diff / 60000).floor()}分钟前';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiService>(
      builder: (context, ai, _) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    const Text(
                      '📋 小本本',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => ai.clearHistory(),
                      child: const Text('🗑️', style: TextStyle(fontSize: 22)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ai.history.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🍃', style: TextStyle(fontSize: 52)),
                            SizedBox(height: 16),
                            Text('暂无记录',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.textLight,
                                )),
                            SizedBox(height: 6),
                            Text(
                              '开始你的第一条预言吧～',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: ai.history.length,
                        itemBuilder: (ctx, i) {
                          final item = ai.history[i];
                          return GestureDetector(
                            onDoubleTap: () => ai.deleteHistory(i),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.07),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _fmt(item['time'] as int),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textLight,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Text('✨',
                                          style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (item['battery'] != null)
                                        _chip('🔋', '${item['battery']}%'),
                                      if (item['steps'] != null)
                                        _chip('🚶', '${item['steps']}'),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '"${item['text']}"',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppTheme.textDark,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '双击删除',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFCCCCCC),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.bgMint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$emoji$text',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.secondary,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  设置页
// ═══════════════════════════════════════════

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorService>().data;
    final ai = context.watch<AiService>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            const Text(
              '⚙️ 小设置',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            _settingCard('🔋 电池', sensor.isRealBattery ? '真实数据' : '模拟数据',
                sensor.isRealBattery),
            _settingCard('📳 运动', sensor.isRealMotion ? '真实数据' : '模拟数据',
                sensor.isRealMotion),
            _settingCard('🦶 步数', sensor.isRealSteps ? '真实数据' : '模拟数据',
                sensor.isRealSteps),
            // ML 模型状态
            _settingCard(
              '🧠 AI 引擎',
              ai.isModelAvailable
                  ? (ai.modelLoaded ? '本地 MLX 模型' : '可用，未加载')
                  : '本地回退模式',
              ai.isModelAvailable && ai.modelLoaded,
            ),
            if (ai.isModelAvailable && !ai.modelLoaded)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      await context.read<AiService>().loadModel();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      foregroundColor: AppTheme.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('📥 下载 AI 模型（约 200MB）'),
                  ),
                ),
              ),
            _settingCard('🗑️ 擦掉所有废话', '点击清空', false, danger: true),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                '废话预言家 v2.0\n基于传感器数据 + 本地 MLX 模型',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textLight),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _settingCard(String title, String value, bool isReal,
      {bool danger = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: danger ? Colors.red : AppTheme.textDark,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isReal ? AppTheme.bgMint : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isReal ? AppTheme.secondary : AppTheme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
