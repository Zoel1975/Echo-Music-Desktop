import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/screens/home/cubit/home_cubit.dart';
import 'package:Echo/services/home_sections.dart';
import 'package:Echo/ytmusic/modals/yt_config.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

class _FakeYt extends YTMusic {
  _FakeYt()
      : super(config: YTConfig(visitorData: '', language: 'en', location: 'IT'));

  int libraryCalls = 0;

  @override
  Future<Map<String, dynamic>> browse({
    Map<String, dynamic>? body,
    int limit = 2,
    String additionalParams = '',
  }) async => {
        'chips': [
          {'title': 'Rock'}
        ],
        'sections': [
          {'title': 'Feed', 'contents': []}
        ],
        'continuation': 'CONT',
      };

  @override
  Future<Map> getLibrarySongs({String? continuationParams}) async {
    libraryCalls++;
    return {
      'contents': [
        {'videoId': 'v1', 'title': 'Liked song'}
      ]
    };
  }

  @override
  Future<Map> getLibraryPlaylists({int limit = 25, String? continuationParams}) async {
    libraryCalls++;
    return {
      'contents': [
        {'playlistId': 'PL1', 'title': 'My playlist'}
      ]
    };
  }
}

void main() {
  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_home_sections_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
    if (!Hive.isBoxOpen('COOKIES')) await Hive.openBox('COOKIES');
  });

  test('config encodes the chosen order and survives round-trip', () {
    final config = HomeSectionsConfig([
      HomeSectionKind.likedSongs,
      HomeSectionKind.feed,
    ]);
    expect(config.encode(), ['likedSongs', 'feed']);
    final decoded = HomeSectionsConfig.decode(['likedSongs', 'feed', 'bogus']);
    expect(decoded.order, [
      HomeSectionKind.likedSongs,
      HomeSectionKind.feed
    ]);
    expect(HomeSectionsConfig.decode(null).order,
        HomeSectionsConfig.defaults.order);
    expect(config.toggle(HomeSectionKind.feed).order, [HomeSectionKind.likedSongs]);
    expect(config.move(HomeSectionKind.feed, -1).order.first,
        HomeSectionKind.feed);
    // Never leave the home completely empty.
    expect(HomeSectionsConfig([
      HomeSectionKind.feed
    ]).toggle(HomeSectionKind.feed).order, [HomeSectionKind.feed]);
  });

  test('home renders only the enabled sections, in the saved order', () async {
    final config = HomeSectionsConfig([
      HomeSectionKind.likedSongs,
      HomeSectionKind.playlists,
      HomeSectionKind.feed,
    ]);
    await config.save();
    await Hive.box('COOKIES').put('SID', 'signed-in');

    final yt = _FakeYt();
    final cubit = HomeCubit(yt);
    await cubit.fetch();

    final state = cubit.state as HomeSuccess;
    expect(
      state.sections.map((s) => s['title']).toList(),
      ['Brani preferiti', 'Le tue playlist', 'Feed'],
    );
    expect(state.continuation, 'CONT');
    expect(yt.libraryCalls, 2);
    expect(state.sections.first['contents'].first['videoId'], 'v1');
    await cubit.close();
  });

  test('charts can be removed from home entirely', () async {
    await HomeSectionsConfig([
      HomeSectionKind.feed,
      HomeSectionKind.likedSongs,
    ]).save();
    final cubit = HomeCubit(_FakeYt());
    await cubit.fetch();
    final state = cubit.state as HomeSuccess;
    expect(state.sections.any((s) => s['title'] == 'Browse Charts'), isFalse);
    await cubit.close();
  });
}
