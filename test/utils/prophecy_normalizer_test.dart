import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/config/prophecy_style.dart';
import 'package:nonsense_prophet/utils/prophecy_normalizer.dart';

void main() {
  group('normalizeProphecy', () {
    test('应去除 ChatML token 和前缀', () {
      const raw = '<|im_start|>assistant\n预言：电量50%时，你的拇指会比平时快1.2倍';
      final result = ProphecyNormalizer.normalizeProphecy(raw);
      expect(result, '电量50%时，你的拇指会比平时快1.2倍');
    });

    test('应去除引号包裹', () {
      const raw = '「电量72%时，你的拇指滑屏速度会比平时快1.2倍」';
      final result = ProphecyNormalizer.normalizeProphecy(raw);
      expect(result, '电量72%时，你的拇指滑屏速度会比平时快1.2倍');
    });

    test('应去除「好的，」前缀', () {
      const raw = '好的，电量60%时，你的下一口呼吸会比上一口重0.002克';
      final result = ProphecyNormalizer.normalizeProphecy(raw);
      expect(result, '电量60%时，你的下一口呼吸会比上一口重0.002克');
    });

    test('超长文本应按标点优先截断', () {
      final raw = '电量${'很' * 20}%时，你的拇指滑屏速度会比平时快1.2倍，'
          '而且你还会在下一秒想起一件无关紧要的小事';
      final result = ProphecyNormalizer.normalizeProphecy(raw);
      expect(result.length, lessThanOrEqualTo(ProphecyStyle.maxChars));
      expect(
        result.endsWith('。') || result.endsWith('，') || result.endsWith('倍'),
        isTrue,
      );
    });

    test('空输入应返回空字符串', () {
      expect(ProphecyNormalizer.normalizeProphecy(''), isEmpty);
      expect(ProphecyNormalizer.normalizeProphecy('   '), isEmpty);
    });
  });

  group('isAcceptableProphecy', () {
    test('合格预言应通过质量门', () {
      const text = '电量72%时，你的拇指滑屏速度会比平时快1.2倍';
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isTrue);
    });

    test('过短文本应被拒绝', () {
      expect(ProphecyNormalizer.isAcceptableProphecy('电量50%'), isFalse);
    });

    test('超长文本应被拒绝', () {
      final text = '电' * 50;
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isFalse);
    });

    test('含英文应被拒绝', () {
      const text = '电量72%时，你的thumb会比平时快1.2倍滑屏';
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isFalse);
    });

    test('含 emoji 应被拒绝', () {
      const text = '电量72%时，你的拇指🐱会比平时快1.2倍滑屏';
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isFalse);
    });

    test('无传感器锚定且无数字应被拒绝', () {
      const text = '你今天会突然想起一件无关紧要的小事';
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isFalse);
    });

    test('含数字但无传感器锚定应通过', () {
      const text = '你今天会在3分钟后突然想起一件无关紧要的小事';
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isTrue);
    });
  });
}
