import 'package:bmsc/model/release.dart';
import 'package:bmsc/model/search.dart';
import 'package:bmsc/screen/fav_screen.dart';
import 'package:bmsc/screen/history_screen.dart';
import 'package:bmsc/util/update.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'component/playing_card.dart';
import 'component/track_tile.dart';
import 'util/string.dart';
import 'globals.dart' as globals;

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.u2x1.bmsc.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  globals.api.initAudioSession();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiliMusic',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'BiliMusic'),
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(builder: (context) {
              return Scaffold(
                  body: child,
                  bottomNavigationBar: StreamBuilder<SequenceState?>(
                    stream: globals.api.player.sequenceStateStream,
                    builder: (_, snapshot) {
                      final src = snapshot.data?.sequence;
                      return (src == null || src.isEmpty)
                          ? const SizedBox()
                          : playCard();
                    },
                  ));
            })
          ],
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

class _MyHomePageState extends State<MyHomePage> {
  var signedin = true;
  List<Result> vidList = [];
  ReleaseResult? officialVersion;
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
    checkNewVersion().then((x) async {
      if (x == null) {
        return;
      }
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        curVersion = "v${packageInfo.version}";
        officialVersion = x;
        hasNewVersion = x.tagName != curVersion;
      });
    });
    (WebviewCookieManager().getCookies('https://www.bilibili.com'))
        .then((x) async {
      final cookies = x.join(';');
      globals.api.setCookies(cookies);
      if ((await globals.api.getUID()) == null) {
        setState(() {
          signedin = false;
        });
        controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) async {
                if (!request.url.startsWith('https://passport.bilibili.com/')) {
                  onSuccessLogin();
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

  Widget customSearchBar = const Text("BiliMusic");
  Icon customIcon = const Icon(Icons.search);

  PreferredSizeWidget rawAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: customSearchBar,
      actions: [
        (hasNewVersion && officialVersion != null && curVersion != null)
            ? IconButton(
                onPressed: () {
                  showUpdateDialog(context, officialVersion!, curVersion!);
                },
                icon: const Icon(
                  Icons.arrow_circle_up_outlined,
                  color: Colors.red,
                ))
            : const SizedBox(),
        IconButton(
            onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<Widget>(builder: (BuildContext context) {
                    return const HistoryScreen();
                  }),
                ),
            icon: const Icon(Icons.history_outlined)),
        IconButton(
            onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<Widget>(builder: (BuildContext context) {
                    return const FavScreen();
                  }),
                ),
            icon: const Icon(Icons.star_outline)),
        IconButton(onPressed: onSearchButtonPressed, icon: customIcon)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: rawAppBar(context),
      body: !signedin
          ? WebViewWidget(controller: controller)
          : vidList.isEmpty
              ? const Center(child: Text('点击右上角搜索！'))
              : _listView(),
    );
  }

  Widget _listView() {
    return NotificationListener<ScrollEndNotification>(
        onNotification: (scrollEnd) {
          final metrics = scrollEnd.metrics;
          if (metrics.atEdge) {
            bool isTop = metrics.pixels == 0;
            if (!isTop) {
              loadMore();
            }
          }
          return true;
        },
        child: ListView.builder(
          physics: const ClampingScrollPhysics(),
          itemCount: vidList.length,
          itemBuilder: (BuildContext context, int index) {
            return _listItemView(vidList[index]);
          },
        ));
  }

  Widget _listItemView(Result vid) {
    final duration =
        vid.duration.split(':').map((x) => x.padLeft(2, '0')).join(':');
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        splashColor: Colors.blue.withAlpha(30),
        child: trackTile(
          pic: 'https:${vid.pic}',
          title: stripHtmlIfNeeded(vid.title),
          author: vid.author,
          len: duration,
          view: unit(vid.play),
          onTap: () => globals.api.playSong(vid.bvid),
        ),
      ),
    );
  }

  final fieldTextController = TextEditingController();
  void onSearchButtonPressed() {
    setState(() {
      if (customIcon.icon == Icons.search) {
        customIcon = const Icon(Icons.cancel);
        customSearchBar = ListTile(
          leading: const Icon(
            Icons.search,
            color: Colors.white,
            size: 28,
          ),
          title: TextField(
            controller: fieldTextController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '歌曲名称',
              hintStyle: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
            ),
            style: const TextStyle(
              color: Colors.white,
            ),
            onSubmitted: onSearching,
          ),
        );
      } else if (fieldTextController.text.isNotEmpty) {
        fieldTextController.clear();
      } else {
        customIcon = const Icon(Icons.search);
        customSearchBar = Text(widget.title);
      }
    });
  }

  bool _hasMore = false;
  int _curPage = 1;
  String _curSearch = "";
  void onSearching(String value) async {
    _curSearch = value;
    _hasMore = true;
    _curPage = 1;
    vidList.clear();
    loadMore();
  }

  void loadMore() async {
    if (!_hasMore) {
      return;
    }
    final ret = await globals.api.search(_curSearch, _curPage);
    if (ret != null) {
      setState(() {
        _hasMore = ret.page < ret.numPages;
        _curPage++;
        vidList.addAll(ret.result);
      });
    }
  }
}
