import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/services/onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('首次启动 onboarding 未完成', () async {
    expect(await OnboardingService.isCompleted(), isFalse);
  });

  test('markCompleted 后 onboarding 已完成', () async {
    await OnboardingService.markCompleted();
    expect(await OnboardingService.isCompleted(), isTrue);
  });
}
