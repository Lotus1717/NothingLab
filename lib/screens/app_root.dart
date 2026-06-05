import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';
import 'main_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    // 后台静默检查模型，不阻塞启动
    context.read<AiService>().checkModelAvailability();
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
