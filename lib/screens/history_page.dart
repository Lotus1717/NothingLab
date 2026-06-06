import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/prophecy_record.dart';
import '../services/ai_service.dart';
import '../widgets/app_card.dart';
import '../widgets/oracle_background.dart';
import '../widgets/oracle_empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AiService>(
      builder: (context, ai, _) {
        return OracleBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Text('小本本', style: AppTheme.pageTitle(context)),
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            ai.clearHistory();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('历史已清空'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 22, color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ai.history.isEmpty
                      ? Center(
                          child: OracleEmptyState(
                            emoji: '🍃',
                            title: '暂无记录',
                            subtitle: '戳一下，听句废话',
                          ),
                        )
                      : _HistoryList(history: ai.history, ai: ai),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<ProphecyRecord> history;
  final AiService ai;

  const _HistoryList({required this.history, required this.ai});

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(history);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final group = groups[gi];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: group.label),
            ...group.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryItem(
                  item: entry.record,
                  timeLabel: _formatTime(entry.record.time),
                  onDelete: () => ai.deleteHistory(entry.index),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _HistoryEntry {
  final int index;
  final ProphecyRecord record;

  const _HistoryEntry({required this.index, required this.record});
}

class _DateGroup {
  final String label;
  final List<_HistoryEntry> entries;

  const _DateGroup({required this.label, required this.entries});
}

List<_DateGroup> _groupByDate(List<ProphecyRecord> history) {
  if (history.isEmpty) return [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final groups = <String, List<_HistoryEntry>>{};
  final order = <String>[];

  for (var i = 0; i < history.length; i++) {
    final item = history[i];
    final d = DateTime.fromMillisecondsSinceEpoch(item.time);
    final day = DateTime(d.year, d.month, d.day);
    final String label;
    if (day == today) {
      label = '今天';
    } else if (day == yesterday) {
      label = '昨天';
    } else {
      label = '${d.month}月${d.day}日';
    }
    if (!groups.containsKey(label)) {
      groups[label] = [];
      order.add(label);
    }
    groups[label]!.add(_HistoryEntry(index: i, record: item));
  }

  return order
      .map((label) => _DateGroup(label: label, entries: groups[label]!))
      .toList();
}

String _formatTime(int ts) {
  final diff = DateTime.now().millisecondsSinceEpoch - ts;
  if (diff < 60000) return '刚刚';
  if (diff < 3600000) return '${(diff / 60000).floor()}分钟前';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _HistoryItem extends StatelessWidget {
  final ProphecyRecord item;
  final String timeLabel;
  final VoidCallback onDelete;

  const _HistoryItem({
    required this.item,
    required this.timeLabel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.time),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.danger, size: 28),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.oracleGold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(timeLabel, style: AppTheme.caption(context)),
                const Spacer(),
                const Text('✨', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.battery != null)
                  StatusChip(
                    label: '${item.battery}%',
                    icon: Icons.battery_full_rounded,
                    active: true,
                  ),
                StatusChip(
                  label: '${item.steps}',
                  icon: Icons.directions_walk_rounded,
                  active: true,
                ),
                StatusChip(
                  label: item.isMoving ? '移动' : '静止',
                  icon: Icons.sensors_rounded,
                  active: item.isMoving,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.text,
              style: AppTheme.bodyMedium(context).copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}
