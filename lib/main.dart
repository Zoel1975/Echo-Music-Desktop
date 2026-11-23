import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:Echo/themes/app_fonts.dart';
import 'package:Echo/themes/theme.dart';
import 'package:Echo/ytmusic/modals/yt_config.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'generated/l10n.dart';
import 'services/audio_fallback.dart';
import 'services/error_log.dart';
import 'services/cast/cast_service.dart';
import 'services/download_manager.dart';
import 'services/file_storage.dart';
import 'services/storage_service.dart';
import 'services/content_filter_service.dart';
import 'services/eq_settings.dart';
import 'services/silence_filter.dart';
import 'services/export_task_queue.dart';
import 'services/scrobble_service.dart';
import 'services/song_dna_service.dart';
import 'services/cloud_service.dart';
import 'services/discord_rpc_service.dart';
import 'services/listen_together_service.dart';
import 'services/remote_control_service.dart';
import 'services/runtime_probe_service.dart';
import 'services/audio_device_service.dart';
import 'services/library.dart';
import 'services/lyrics.dart';
import 'services/cookie_store.dart';
import 'services/stream_resolver.dart';
import 'services/media_player.dart';
import 'services/settings_manager.dart';
import 'utils/router.dart';
import 'ytmusic/ytmusic.dart';
import 'services/yt_audio_stream.dart';

/// Held for the whole process so no other instance can open the Hive boxes.
RandomAccessFile? _instanceLock;

/// Keep the app usable when a single widget/network callback throws: log the
/// error and show a recoverable card instead of Flutter's red error screen.
void _writeErrorLog(String text) => ErrorLog.write(text);

void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[echo] Flutter error: ${details.exceptionAsString()}');
    _writeErrorLog(
      'Flutter error: ${details.exceptionAsString()}\n${details.stack ?? StackTrace.empty}',
    );
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[echo] Uncaught error: $error\n$stack');
    _writeErrorLog('Uncaught error: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    const Text('Qualcosa non ha funzionato in questa schermata.'),
                    const SizedBox(height: 4),
                    Text(details.exceptionAsString(),
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => router.go('/'),
                      child: const Text('Torna alla home'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  try {
    await _startApp();
  } catch (e, stack) {
    // Never leave a live process with no window: startup I/O (Hive lock,
    // application support dir, audio endpoint) can fail on locked-down PCs.
    _writeErrorLog('Startup failed: $e\n$stack');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Avvio non riuscito: $e\n\nRiavvia Echo Music.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          backgroundColor: const Color(0xFF121212),
        ),
      ),
    );
  }
}

Future<void> _startApp() async {

  // Single-instance guard: Hive locks its files, so launching the app twice
  // used to produce a PathAccessException and a blank window.
  _instanceLock = await _acquireInstanceLock();
  if (_instanceLock == null) {
    runApp(const _AlreadyRunningApp());
    return;
  }

  await initialiseHive();

  // Initialize JustAudioBackground for notifications and background playback.
  // It only ships Android/iOS implementations: on desktop the platform channel
  // is missing and desktop playback is handled by media_kit below.
  if (Platform.isAndroid || Platform.isIOS) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.echo.music.audio',
      androidNotificationChannelName: 'Echo Music',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    );
  }

  // If the previous launch died while libmpv was opening the audio endpoint
  // (AUDCLNT_E_DEVICE_IN_USE is a hard native crash), retry without an audio
  // output so the UI - including login and sign out - remains usable.
  await prepareAudioFallback();

  // Initialize JustAudioMediaKit for Windows, Linux, and macOS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    JustAudioMediaKit.ensureInitialized();
    JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
    JustAudioMediaKit.title = 'Echo Music';
    JustAudioMediaKit.prefetchPlaylist = true;
    JustAudioMediaKit.pitch = true;
  }

  // InnerTube stream resolution must use the Google login cookies (bot check)
  // when the user is signed in.
  StreamResolver.instance.cookieHeaderProvider = () => CookieStore.instance.cookieHeader;

  String? visitorId = await Hive.box('SETTINGS').get('VISITOR_ID');

  YTMusic ytMusic = YTMusic(
    config:
        YTConfig(visitorData: visitorId ?? '', language: 'en', location: 'IN'),
    onIdUpdate: (visitorId) async {
      await Hive.box('SETTINGS').put('VISITOR_ID', visitorId);
    },
  );

  final GlobalKey<NavigatorState> panelKey = GlobalKey<NavigatorState>();
  // Restore per-video PoTokens captured from the signed-in browser.
  StreamResolver.instance.loadPoTokens();

  await FileStorage.initialise();
  FileStorage fileStorage = FileStorage();
  SettingsManager settingsManager = SettingsManager();
  AppFonts.initialize(settingsManager.extra<String>('appFont', 'Google Sans Flex'));

  final themeVariant =
      settingsManager.extra<String>('themeVariant', 'System');
  if (themeVariant == 'Monochrome' || themeVariant == 'Monochrome OLED') {
    // Mirrors Android's monochrome theme variant: seed the scheme with grey.
    themeSeedOverride = Colors.grey;
  }

  GetIt.I.registerSingleton<SettingsManager>(settingsManager);
  // Genuine desktop skip-silence: apply mpv's silenceremove filter before any
  // AudioPlayer is created (players snapshot the filter at construction).
  // Restore the saved AXION/EQ preset as well as skip-silence: applying only
  // `enabled` used to wipe the equalizer from the filter chain on restart.
  EqSettings.apply(settingsManager);
  GetIt.I.registerSingleton<StorageService>(StorageService());
  GetIt.I.registerSingleton<ContentFilterService>(ContentFilterService());
  GetIt.I.registerSingleton<ExportTaskQueue>(ExportTaskQueue());
  final audioDevices = AudioDeviceService();
  GetIt.I.registerSingleton<AudioDeviceService>(audioDevices);
  // Restore the output device the user picked in a previous session.
  if (settingsManager.audioDeviceId.isNotEmpty) {
    unawaited(audioDevices.selectDevice(settingsManager.audioDeviceId));
  }
  // Google Cast device picker (Android: CastButton + CastConnectionHandler).
  GetIt.I.registerSingleton<CastService>(CastService());
  GetIt.I.registerSingleton<ScrobbleService>(ScrobbleService());
  GetIt.I.registerSingleton<SongDnaService>(SongDnaService());
  GetIt.I.registerSingleton<CloudService>(CloudService());
  GetIt.I.registerSingleton<DiscordRpcService>(DiscordRpcService());
  GetIt.I.registerSingleton<ListenTogetherService>(ListenTogetherService());
  final remoteControl = RemoteControlService();
  GetIt.I.registerSingleton<RemoteControlService>(remoteControl);
  // Cast and LAN-remote both expose the real playback endpoint; restore either
  // persisted toggle at startup so the feature survives a restart.
  if (settingsManager.castEnabled || settingsManager.remoteControlEnabled) {
    unawaited(remoteControl.start());
  }

  // Start Local Audio Server
  final String audioStreamUrl = await createAudioStreamServer();
  GetIt.I.registerSingleton<String>(audioStreamUrl,
      instanceName: 'audioStreamUrl');

  MediaPlayer mediaPlayer = MediaPlayer();
  GetIt.I.registerSingleton<MediaPlayer>(mediaPlayer);
  LibraryService libraryService = LibraryService();
  GetIt.I.registerSingleton<DownloadManager>(DownloadManager());
  GetIt.I.registerSingleton(panelKey);
  GetIt.I.registerSingleton<YTMusic>(ytMusic);

  GetIt.I.registerSingleton<FileStorage>(fileStorage);

  GetIt.I.registerSingleton<LibraryService>(libraryService);
  GetIt.I.registerSingleton<LyricsService>(LyricsService());

  // Opt-in loopback diagnostics for verifying session behaviour at runtime.
  if (Platform.environment['ECHO_DIAG'] == '1') {
    await RuntimeProbeService.start();
  }

  // Resume playback in the background: awaiting it before runApp() could
  // block the first Flutter frame (e.g. a slow/failed stream resolve), which
  // left the process alive with an invisible window.
  if (!audioFallback.value && settingsManager.persistentQueue) {
    unawaited(GetIt.I<MediaPlayer>().restoreLastPlayed());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsManager),
        ChangeNotifierProvider(create: (_) => mediaPlayer),
        ChangeNotifierProvider(create: (_) => libraryService),
        // The export screen reads this with context.watch; registering only in
        // GetIt made navigating to /export_queue throw ProviderNotFound.
        ChangeNotifierProvider.value(
            value: GetIt.I<ExportTaskQueue>()),
      ],
      child: const Echo(),
    ),
  );
}

class Echo extends StatelessWidget {
  const Echo({super.key});
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
      },
      child: MaterialApp.router(
        title: 'Echo Music',
        routerConfig: router,
        locale: Locale(context.watch<SettingsManager>().language['value']!),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        debugShowCheckedModeBanner: false,
        themeMode: context.watch<SettingsManager>().themeMode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
      ),
    );
  }
}

Future<RandomAccessFile?> _acquireInstanceLock() async {
  try {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/database');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = await File('${dir.path}/echo-single-instance.lock')
        .open(mode: FileMode.write);
    await file.lock();
    return file;
  } catch (_) {
    return null;
  }
}

class _AlreadyRunningApp extends StatelessWidget {
  const _AlreadyRunningApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'Echo Music is already running.\nClose the other window first.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

Future<void> initialiseHive() async {
  String? applicationDataDirectoryPath;
  if (Platform.isWindows || Platform.isLinux) {
    applicationDataDirectoryPath =
        "${(await getApplicationSupportDirectory()).path}/database";
  }
  await Hive.initFlutter(applicationDataDirectoryPath);
  await Hive.openBox('SETTINGS');
  await Hive.openBox('LIBRARY');
  await Hive.openBox('SEARCH_HISTORY');
  await Hive.openBox('SONG_HISTORY');
  await Hive.openBox('FAVOURITES');
  await Hive.openBox('DOWNLOADS');
  await Hive.openBox('QUEUE');
  await Hive.openBox('COOKIES');
  await Hive.openBox('ACCOUNT');
  await Hive.openBox('BLOCKED_ARTISTS');
  await Hive.openBox('DISLIKED_SONGS');
  await Hive.openBox('BEAT_ANALYSIS');
  await Hive.openBox('POTOKENS');
}
