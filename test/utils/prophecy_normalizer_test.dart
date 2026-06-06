import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/config/prophecy_style.dart';
import 'package:nonsense_prophet/models/sensor_data.dart';
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

    test('无传感器锚定也应通过', () {
      const text = '你今天会突然想起一件无关紧要的小事';
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isTrue);
    });

    test('含音量锚定应通过', () {
      const text = '系统音量45%时，你听到的下一句废话会比上一句响0.3分贝';
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isTrue);
    });

    test('含环境光线锚定应通过', () {
      const text = '环境光线320勒克斯时，你眼角余光会多捕捉到2粒灰尘';
      expect(ProphecyNormalizer.isAcceptableProphecy(text), isTrue);
    });
  });

  group('isMlxProphecy', () {
    test('应接受不含传感器数据的废话', () {
      final sensor = SensorData.mock().copyWith(battery: 72, steps: 3500);
      const grounded = '电量七成时，你的拇指滑屏速度会比平时快1.2倍';
      const ungrounded = '你今天会在三分钟后突然想起一件无关紧要的小事';

      expect(ProphecyNormalizer.isMlxProphecy(grounded, sensor), isTrue);
      expect(ProphecyNormalizer.isMlxProphecy(ungrounded, sensor), isTrue);
    });

    test('应去除换行与尾部提示词泄漏', () {
      const raw = '电量72%时，你的拇指会比平时快1.2倍\n请根据以上数据写一条';
      final result = ProphecyNormalizer.normalizeProphecy(raw);
      expect(result, '电量72%时，你的拇指会比平时快1.2倍');
      expect(result.contains('\n'), isFalse);
    });

    test('应识别上一句复述为 prompt 泄漏', () {
      const raw = '上一句是电量50%时你的拇指会快1.2倍，今日你会突然想起一件小事';
      expect(ProphecyNormalizer.isPromptEcho(raw), isTrue);
      expect(ProphecyNormalizer.isAcceptableProphecy(raw), isFalse);
    });
  });
}
