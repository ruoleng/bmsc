import 'package:bmsc/model/release.dart';
import 'package:bmsc/screen/dynamic_screen.dart';
import 'package:bmsc/screen/fav_screen.dart';
import 'package:bmsc/screen/history_screen.dart';
import 'package:bmsc/util/update.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bmsc/screen/search_screen.dart';

import 'component/playing_card.dart';
import 'globals.dart' as globals;
import 'package:flutter/foundation.dart';
import 'util/error_handler.dart';
import 'screen/about_screen.dart';
import 'util/logger.dart';
import 'package:bmsc/screen/settings_screen.dart';
import 'package:bmsc/theme.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeProvider.instance.init();
  runApp(const MyApp());
  _setupErrorHandlers();
  _initializeBackgroundServices();
}

void _setupErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorHandler.handleException(details.exception);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorHandler.handleException(error);
    return true;
  };
}

Future<void> _initializeBackgroundServices() async {
  LoggerUtils.init();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.u2x1.bmsc.channel.audio',
    androidNotificationChannelName: 'Audio Playback',
    androidNotificationOngoing: true,
  );
  globals.api.init();
  globals.api.initAudioSession();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: ErrorHandler.navigatorKey,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: ThemeProvider.instance.themeMode,
          home: Builder(builder: (context) {
            return Scaffold(
              body: MyHomePage(title: 'BiliMusic'),
              bottomNavigationBar: StreamBuilder<SequenceState?>(
                stream: globals.api.player.sequenceStateStream,
                builder: (_, snapshot) {
                  final src = snapshot.data?.sequence;
                  return (src == null || src.isEmpty)
                      ? const SizedBox()
                      : const PlayingCard();
                },
              ),
            );
          }),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  List<ReleaseResult>? officialVersions;
  String? curVersion;
  bool hasNewVersion = false;
  FavScreenState? _favScreenState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkNewVersion().then((x) async {
      if (x == null) {
        return;
      }
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        curVersion = "v${packageInfo.version}";
        officialVersions = x;
        hasNewVersion = x.first.tagName != curVersion;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<Widget>(builder: (_) => const AboutScreen()),
          ),
          child: Row(
            children: [
              const Text("BiliMusic"),
              if (hasNewVersion &&
                  officialVersions != null &&
                  curVersion != null)
                Icon(Icons.arrow_circle_up_outlined,
                    color: Theme.of(context).colorScheme.error),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<Widget>(builder: (_) => const SearchScreen()),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<Widget>(builder: (_) => const DynamicScreen()),
            ),
            icon: const Icon(Icons.wind_power_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<Widget>(builder: (_) => const HistoryScreen()),
            ),
            icon: const Icon(Icons.history_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => const SettingsScreen(),
              ),
            ).then((shouldRefresh) {
              if (shouldRefresh == true) {
                if (globals.api.uid == 0) {
                  _favScreenState?.setState(() {
                    _favScreenState?.signedin = false;
                  });
                } else {
                  _favScreenState?.setState(() {
                    _favScreenState?.signedin = true;
                  });
                  _favScreenState?.loadFavorites();
                }
              }
            }),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: FavScreen(
        onInit: (state) => _favScreenState = state,
      ),
    );
  }
}
