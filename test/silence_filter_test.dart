import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/silence_filter.dart';

void main() {
  group('SilenceFilter (desktop skip-silence)', () {
    test('builds an mpv silenceremove lavfi chain when enabled', () {
      final f = SilenceFilter.buildFilter(enabled: true);
      expect(f, contains('lavfi='));
      expect(f, contains('silenceremove'));
      expect(f, contains('start_threshold'));
      expect(f, contains('stop_periods=-1'));
    });

    test('returns an empty filter when disabled', () {
      expect(SilenceFilter.buildFilter(enabled: false), '');
    });

    test('buildChain combines silence removal and 10-band equalizer', () {
      final gains = List<double>.filled(10, 1.5);
      final chain = SilenceFilter.buildChain(
        skipSilence: true,
        eqGains: gains,
        eqEnabled: true,
      );
      expect(chain, startsWith('lavfi=['));
      expect(chain, contains('silenceremove'));
      expect(chain, contains('equalizer='));
      expect(chain, contains('f=31'));
      expect(chain, contains('g=1.5'));

      final eqOnly = SilenceFilter.buildChain(
        skipSilence: false,
        eqGains: gains,
        eqEnabled: true,
      );
      expect(eqOnly, isNot(contains('silenceremove')));
      expect(eqOnly, contains('equalizer='));
      expect(SilenceFilter.buildChain(skipSilence: false), '');
    });

    test('filter string is a valid mpv af assignment', () {
      final f = SilenceFilter.buildFilter(enabled: true);
      expect(f.startsWith('lavfi=['), isTrue);
      expect(f.endsWith(']'), isTrue);
      // balanced brackets
      expect(f.split('[').length, f.split(']').length);
    });
  });
}
