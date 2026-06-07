import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/prophecy_record.dart';
import '../models/sensor_data.dart';
import '../services/ai_service.dart';
import '../utils/prophecy_image_share.dart';
import '../widgets/app_card.dart';
import '../widgets/oracle_background.dart';
import '../widgets/prophecy_share_card.dart';
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

class _FavoriteItem extends StatefulWidget {
  final ProphecyRecord item;
  final String timeLabel;
  final VoidCallback onDelete;

  const _FavoriteItem({
    required this.item,
    required this.timeLabel,
    required this.onDelete,
  });

  @override
  State<_FavoriteItem> createState() => _FavoriteItemState();
}

class _FavoriteItemState extends State<_FavoriteItem> {
  final GlobalKey _shareImageKey = GlobalKey();
  bool _sharing = false;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.item.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在生成分享图…'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final origin = defaultSharePositionOrigin(context);
    try {
      await shareRepaintBoundaryAsImage(
        _shareImageKey,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  SensorData _sensorFromRecord(ProphecyRecord item) {
    final at = DateTime.fromMillisecondsSinceEpoch(item.time);
    return SensorData(
      battery: item.battery,
      brightness: item.brightness,
      volume: item.volume ?? 50,
      steps: item.steps,
      isMoving: item.isMoving,
      ambientLight: item.ambientLight ?? 0,
      isRealBattery: item.battery != null,
      isRealVolume: item.volume != null,
      isRealSteps: true,
      isRealAmbientLight: item.ambientLight != null,
      timestamp: at,
      timeHint: SensorData.timeHintFor(at),
      dayPhase: SensorData.dayPhaseFor(at),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('移除这条收藏？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('取消', style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(widget.item.time);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -(ProphecyShareCard.cardWidth + 40),
          top: 0,
          child: RepaintBoundary(
            key: _shareImageKey,
            child: ProphecyShareCard(
              prophecy: widget.item.text,
              sensor: _sensorFromRecord(widget.item),
              createdAt: createdAt,
            ),
          ),
        ),
        Dismissible(
          key: ValueKey('${widget.item.time}_${widget.item.text}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(context),
          onDismissed: (_) => widget.onDelete(),
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
                    Text(widget.timeLabel, style: AppTheme.caption(context)),
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
                      label: widget.item.battery != null
                          ? '${widget.item.battery}%'
                          : '--',
                      icon: Icons.battery_full_rounded,
                      active: widget.item.battery != null,
                    ),
                    StatusChip(
                      label: '${widget.item.steps}',
                      icon: Icons.directions_walk_rounded,
                      active: true,
                    ),
                    StatusChip(
                      label: widget.item.volume != null
                          ? '${widget.item.volume}%'
                          : '--',
                      icon: Icons.volume_up_rounded,
                      active: widget.item.volume != null,
                    ),
                    StatusChip(
                      label: widget.item.ambientLight != null
                          ? '${widget.item.ambientLight}lx'
                          : '--',
                      icon: Icons.wb_sunny_outlined,
                      active: widget.item.ambientLight != null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item.text,
                  style: AppTheme.bodyMedium(context).copyWith(height: 1.55),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _MiniAction(
                      icon: Icons.copy_rounded,
                      label: '复制',
                      onTap: () => _copy(context),
                    ),
                    const SizedBox(width: 8),
                    _MiniAction(
                      icon: Icons.image_rounded,
                      label: _sharing ? '生成中' : '分享图',
                      onTap: _sharing ? () {} : () => _share(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTheme.caption(context).copyWith(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
