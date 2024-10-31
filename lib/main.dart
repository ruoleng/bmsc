import 'package:bmsc/model/release.dart';
import 'package:bmsc/screen/dynamic_screen.dart';
import 'package:bmsc/screen/fav_screen.dart';
import 'package:bmsc/screen/history_screen.dart';
import 'package:bmsc/screen/cache_screen.dart';
import 'package:bmsc/util/update.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:bmsc/screen/search_screen.dart';
import 'package:bmsc/screen/playlist_search_screen.dart';

import 'component/playing_card.dart';
import 'globals.dart' as globals;
import 'package:flutter/foundation.dart';
import 'util/error_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'screen/about_screen.dart';
import 'util/logger.dart';

final logger = LoggerUtils.getLogger('Main');

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.u2x1.bmsc.channel.audio',
    androidNotificationChannelName: 'Audio Playback',
    androidNotificationOngoing: true,
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorHandler.handleException(details.exception);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorHandler.handleException(error);
    return true;
  };

  globals.api.initAudioSession();
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permission
  if (Platform.isAndroid) {
    await Permission.notification.request();
  }

  await LoggerUtils.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      useMaterial3: true,
    );

    return MaterialApp(
      navigatorKey: ErrorHandler.navigatorKey,
      theme: theme,
      home: Builder(builder: (context) {
        return Scaffold(
          body: MyHomePage(title: 'BiliMusic'),
          bottomNavigationBar: StreamBuilder<SequenceState?>(
            stream: globals.api.player.sequenceStateStream,
            builder: (_, snapshot) {
              final src = snapshot.data?.sequence;
              return (src == null || src.isEmpty)
                  ? const SizedBox()
                  : PlayingCard();
            },
          ),
        );
      }),
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
  var signedin = true;
  List<ReleaseResult>? officialVersions;
  String? curVersion;
  bool hasNewVersion = false;
  late WebViewController controller;

  Future<void> onSuccessLogin() async {
    final cookies =
        (await WebviewCookieManager().getCookies('https://www.bilibili.com'))
            .join(';');

    setState(() {
      signedin = true;
      globals.api.setCookies(cookies);
    });
  }

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
    (WebviewCookieManager().getCookies('https://www.bilibili.com'))
        .then((x) async {
      final cookies = x.join(';');
      globals.api.setCookies(cookies);
      if ((await globals.api.getUID()) == 0) {
        setState(() {
          signedin = false;
        });
        logger.info('User not logged in');
        controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) async {
                if (!request.url.startsWith('https://passport.bilibili.com/')) {
                  onSuccessLogin();
                  logger.info('User logged in');
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(
              Uri.parse('https://passport.bilibili.com/h5-app/passport/login'));
      }
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                Icon(Icons.arrow_circle_up_outlined, color: Colors.red),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<Widget>(
                  builder: (_) => const PlaylistSearchScreen()),
            ),
            icon: const Icon(Icons.input),
          ),
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
              MaterialPageRoute<Widget>(builder: (_) => const CacheScreen()),
            ),
            icon: const Icon(Icons.storage),
          ),
        ],
      ),
      body:
          !signedin ? WebViewWidget(controller: controller) : const FavScreen(),
    );
  }
}
