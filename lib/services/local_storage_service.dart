import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences — kept as a plain class (not
/// a GetxController) since it holds no reactive state, just persisted
/// key/value reads and writes. Registered once in main() as permanent.
class LocalStorageService {
  static const _onboardingKey = 'has_seen_onboarding';

  final SharedPreferences _prefs;
  LocalStorageService._(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService._(prefs);
  }

  bool get hasSeenOnboarding => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingSeen() => _prefs.setBool(_onboardingKey, true);
}