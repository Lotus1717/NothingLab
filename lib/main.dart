import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'screens/app_root.dart';
import 'services/ai_service.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/sensor_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final analyticsService = AnalyticsService();
  final notificationService = NotificationService();
  await analyticsService.init();
  runApp(MyApp(
    analyticsService: analyticsService,
    notificationService: notificationService,
  ));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notificationService.init();
  });
}

class MyApp extends StatelessWidget {
  final AnalyticsService analyticsService;
  final NotificationService notificationService;

  const MyApp({
    super.key,
    required this.analyticsService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: analyticsService),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider(create: (_) => SensorService()..init()),
        ChangeNotifierProvider(
          create: (_) => AiService(analyticsService: analyticsService),
        ),
      ],
      child: MaterialApp(
        title: '废话预言家',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppRoot(),
      ),
    );
  }
}
