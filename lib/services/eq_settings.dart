import 'axion_eq_service.dart';
import 'settings_manager.dart';
import 'silence_filter.dart';

/// Single source of truth for the desktop EQ filter chain.
///
/// The AXION page, the Skip-silence toggle and app startup all have to apply
/// the *same* saved preset; previously each call passed only `enabled`, which
/// silently wiped the equalizer from mpv's filter chain.
class EqSettings {
  EqSettings._();

  static List<double>? savedGains(SettingsManager settings) {
    // The 10-band page is authoritative: moving a slider writes here.
    final bands = settings.equalizerBandsGain;
    if (bands.length >= 10) return List<double>.from(bands);
    // Older installs (and the AXION-only path) may only have the encoded
    // preset, so keep it as a fallback.
    final encoded = settings.extra<String>('axionEQGains', '');
    if (encoded.isNotEmpty) {
      try {
        final preset = AxionEqService.decodePreset(encoded);
        if (preset.gains.length == 10) return List<double>.from(preset.gains);
      } catch (_) {}
    }
    return null;
  }

  static void apply(SettingsManager settings) {
    SilenceFilter.apply(
      enabled: settings.skipSilence,
      eqGains: savedGains(settings),
      eqEnabled: settings.equalizerEnabled,
    );
  }
}
