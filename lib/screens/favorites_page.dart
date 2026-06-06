import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/prophecy_record.dart';
import '../services/ai_service.dart';
import '../widgets/app_card.dart';
import '../widgets/oracle_background.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

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
                  child: Text('收藏', style: AppTheme.pageTitle(context)),
                ),
                Expanded(
                  child: ai.favorites.isEmpty
                      ? Center(
                          child: Text(
                            '暂无收藏\n喜欢某条废话后，会出现在这里',
                            textAlign: TextAlign.center,
                            style: AppTheme.caption(context),
                          ),
                        )
                      : _FavoritesList(favorites: ai.favorites, ai: ai),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FavoritesList extends StatelessWidget {
  final List<ProphecyRecord> favorites;
  final AiService ai;

  const _FavoritesList({required this.favorites, required this.ai});

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(favorites);
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
                child: _FavoriteItem(
                  item: entry.record,
                  timeLabel: _formatTime(entry.record.time),
                  onDelete: () => ai.deleteFavorite(entry.index),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _FavoriteEntry {
  final int index;
  final ProphecyRecord record;

  const _FavoriteEntry({required this.index, required this.record});
}

class _DateGroup {
  final String label;
  final List<_FavoriteEntry> entries;

  const _DateGroup({required this.label, required this.entries});
}

List<_DateGroup> _groupByDate(List<ProphecyRecord> favorites) {
  if (favorites.isEmpty) return [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final groups = <String, List<_FavoriteEntry>>{};
  final order = <String>[];

  for (var i = 0; i < favorites.length; i++) {
    final item = favorites[i];
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
    groups[label]!.add(_FavoriteEntry(index: i, record: item));
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

class _FavoriteItem extends StatelessWidget {
  final ProphecyRecord item;
  final String timeLabel;
  final VoidCallback onDelete;

  const _FavoriteItem({
    required this.item,
    required this.timeLabel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${item.time}_${item.text}'),
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
                const Icon(Icons.favorite_rounded,
                    size: 14, color: AppTheme.primaryDark),
                const SizedBox(width: 6),
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
                StatusChip(
                  label: item.battery != null ? '${item.battery}%' : '--',
                  icon: Icons.battery_full_rounded,
                  active: item.battery != null,
                ),
                StatusChip(
                  label: '${item.steps}',
                  icon: Icons.directions_walk_rounded,
                  active: true,
                ),
                StatusChip(
                  label: item.volume != null ? '${item.volume}%' : '--',
                  icon: Icons.volume_up_rounded,
                  active: item.volume != null,
                ),
                StatusChip(
                  label: item.ambientLight != null
                      ? '${item.ambientLight}lx'
                      : '--',
                  icon: Icons.wb_sunny_outlined,
                  active: item.ambientLight != null,
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
