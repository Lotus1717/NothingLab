import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/prophecy_record.dart';
import '../services/ai_service.dart';
import '../widgets/app_card.dart';

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
                          return _HistoryItem(
                            item: item,
                            timeLabel: _fmt(item.time),
                            onDoubleTap: () => ai.deleteHistory(i),
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
}

class _HistoryItem extends StatelessWidget {
  final ProphecyRecord item;
  final String timeLabel;
  final VoidCallback onDoubleTap;

  const _HistoryItem({
    required this.item,
    required this.timeLabel,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
                const Spacer(),
                const Text('✨', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                if (item.battery != null)
                  _chip('🔋', '${item.battery}%'),
                _chip('🚶', '${item.steps}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '"${item.text}"',
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
