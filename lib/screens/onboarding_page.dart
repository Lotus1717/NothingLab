import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/onboarding_service.dart';
import '../services/sensor_service.dart';
import '../widgets/lazy_cat.dart';
import '../widgets/oracle_background.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  bool _requestingPermission = false;

  static const _pageCount = 3;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingService.markCompleted();
    widget.onComplete();
  }

  void _next() {
    if (_page >= _pageCount - 1) {
      _finish();
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _requestSensorPermission() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);
    try {
      await context.read<SensorService>().init();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已刷新传感器，可在设置页查看真/模状态')),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OracleBackground(
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  '跳过',
                  style: AppTheme.caption(context).copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _IntroPage(),
                  const _PermissionPage(),
                  const _ReadyPage(),
                ],
              ),
            ),
            _PageDots(current: _page, count: _pageCount),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _page == 1
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed: _requestingPermission
                              ? null
                              : _requestSensorPermission,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.secondary,
                            side: const BorderSide(color: AppTheme.secondary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          child: Text(
                            _requestingPermission ? '请求中…' : '开启运动与传感器权限',
                            style: AppTheme.caption(context).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PrimaryButton(
                          label: '下一步',
                          onPressed: _next,
                        ),
                      ],
                    )
                  : _PrimaryButton(
                      label: _page == _pageCount - 1 ? '开始戳猫' : '下一步',
                      onPressed: _next,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '废话预言家',
            style: AppTheme.onboardingHero(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '俏皮神谕 · Playful Oracle',
            style: AppTheme.caption(context).copyWith(
              fontSize: 13,
              color: AppTheme.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 36),
          LazyCat(animating: false, onTap: () {}),
          const SizedBox(height: 20),
          Text(
            '戳戳慵懒小猫',
            style: AppTheme.onboardingTitle(context).copyWith(fontSize: 20),
          ),
          const SizedBox(height: 10),
          Text(
            '手机会读取电量、步数、亮度等传感器，\n编出一句只属于此刻的无厘头预言。',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium(context).copyWith(
              color: AppTheme.textMuted,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '传感器是预言素材',
            style: AppTheme.onboardingTitle(context),
          ),
          const SizedBox(height: 12),
          Text(
            '授权后，预言会引用你真实的步数、电量等数据；\n未授权时使用模拟数据，照样能戳猫听废话。',
            style: AppTheme.bodyMedium(context).copyWith(
              color: AppTheme.textMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          _InfoTile(
            icon: Icons.directions_walk_rounded,
            title: '运动与健身',
            subtitle: '读取今日步数，编进预言里',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.sensors_rounded,
            title: '传感器',
            subtitle: '检测是否在走动，丰富预言细节',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.info_outline_rounded,
            title: '可随时查看',
            subtitle: '设置页会标注每项是「真实数据」还是「模拟数据」',
          ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '准备好了吗？',
            style: AppTheme.onboardingTitle(context),
          ),
          const SizedBox(height: 12),
          Text(
            '戳戳小猫，听一句只属于此刻的废话。\n喜欢的可以收藏，或生成分享图发给朋友。',
            style: AppTheme.bodyMedium(context).copyWith(
              color: AppTheme.textMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          _InfoTile(
            icon: Icons.favorite_border_rounded,
            title: '收藏',
            subtitle: '把喜欢的废话存起来，按日期回顾',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.image_rounded,
            title: '分享图',
            subtitle: '一键生成海报，带二维码发给朋友',
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.oracleGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppTheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.caption(context).copyWith(
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int current;
  final int count;

  const _PageDots({required this.current, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryDark : AppTheme.textLight,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryDark.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTheme.caption(context).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
