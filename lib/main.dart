import 'package:bmsc/model/search.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'api.dart';
import 'util/string.dart';

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.u2x1.bmsc.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
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
  var signedin = false;
  List<Result> vidList = [];
  late API api;
  // Future<void> _incrementCounter() async {}
  bool playing = false;
  Result? curTrack;

  Widget customSearchBar = const Text("BiliMusic");
  Icon customIcon = const Icon(Icons.search);
  late WebViewController controller;

  Future<void> onSuccessLogin() async {
    final cookies =
        (await WebviewCookieManager().getCookies('https://www.bilibili.com'))
            .join(';');
    setState(() {
      signedin = true;
      api = API(cookies);
    });
  }

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: customSearchBar,
        actions: [
          IconButton(onPressed: onSearchButtonPressed, icon: customIcon)
        ],
      ),
      body: !signedin
          ? WebViewWidget(controller: controller)
          : vidList.isEmpty
              ? const Center(child: Text('点击右上角搜索！'))
              : _listView(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: !playing ? null : playCard(),
    );
  }

  Widget _listView() {
    return ListView.builder(
      itemCount: vidList.length,
      // padding: const EdgeInsets.all(5.0),
      itemBuilder: (BuildContext context, int index) {
        return _listItemView(vidList[index]);
      },
    );
  }

  Widget _listItemView(Result vid) {
    final duration =
        vid.duration.split(':').map((x) => x.padLeft(2, '0')).join(':');
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        splashColor: Colors.blue.withAlpha(30),
        onTap: () async {
          setState(() {
            playing = true;
            curTrack = vid;
          });
          api.playSong(vid.bvid);
        },
        child: Stack(alignment: Alignment.bottomRight, children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Image.network(
                        fit: BoxFit.cover,
                        'https:${vid.pic}',
                      )),
                ),
                title: Text(
                  stripHtmlIfNeeded(vid.title),
                  style: const TextStyle(fontSize: 14),
                  softWrap: false,
                ),
                subtitle:
                    Text(vid.author, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                duration,
                style: const TextStyle(fontSize: 8),
              )),
        ]),
      ),
    );
  }

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
      } else {
        customIcon = const Icon(Icons.search);
        customSearchBar = Text(widget.title);
      }
    });
  }

  void onSearching(String value) async {
    final ret = await api.search(value);
    if (ret != null) {
      setState(() {
        vidList = ret;
      });
    }
  }

  Widget _playPauseButton(PlayerState? playerState) {
    final processingState = playerState?.processingState;
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return const CircularProgressIndicator();
    } else if (api.player.playing != true) {
      return IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: api.player.play,
      );
    } else if (processingState != ProcessingState.completed) {
      return IconButton(
        icon: const Icon(Icons.pause),
        onPressed: api.player.pause,
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.replay),
        onPressed: () => api.player
            .seek(Duration.zero, index: api.player.effectiveIndices!.first),
      );
    }
  }

  Widget progressIndicator(Duration? dur) {
    if (dur == null || api.player.duration == null) {
      return const CircularProgressIndicator(
        value: 0,
        color: Colors.white,
      );
    }
    return CircularProgressIndicator(
        value: dur.inSeconds / api.player.duration!.inSeconds);
  }

  Widget playCard() {
    return Card(
      clipBehavior: Clip.none,
      child: RotatedBox(
        quarterTurns: 2,
        child: ExpansionTile(
            controlAffinity: ListTileControlAffinity.leading,
            tilePadding: const EdgeInsets.only(left: 10),
            shape: Border.all(width: 0.1, color: Colors.transparent),
            title: RotatedBox(
                quarterTurns: 2,
                child: InkWell(
                    splashColor: Colors.blue.withAlpha(30),
                    child: FractionallySizedBox(
                      widthFactor: 0.95,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Expanded(
                            flex: 8,
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(5.0),
                                child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Image.network(
                                      fit: BoxFit.cover,
                                      'https:${curTrack!.pic}',
                                    )),
                              ),
                              title: StreamBuilder<SequenceState?>(
                                stream: api.player.sequenceStateStream,
                                builder: (_, snapshot) {
                                  final src = snapshot.data?.currentSource;
                                  return Text(src?.tag.title,
                                      style: const TextStyle(fontSize: 12),
                                      softWrap: false,
                                      maxLines: 1);
                                },
                              ),
                              subtitle: StreamBuilder<SequenceState?>(
                                stream: api.player.sequenceStateStream,
                                builder: (_, snapshot) {
                                  final src = snapshot.data?.currentSource;
                                  return Text(src?.tag.artist,
                                      style: const TextStyle(fontSize: 10),
                                      softWrap: false,
                                      maxLines: 1);
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                StreamBuilder<Duration>(
                                  stream: api.player.positionStream,
                                  builder: (_, snapshot) {
                                    final duration = snapshot.data;
                                    return progressIndicator(duration);
                                  },
                                ),
                                StreamBuilder<PlayerState>(
                                  stream: api.player.playerStateStream,
                                  builder: (_, snapshot) {
                                    final playerState = snapshot.data;
                                    return _playPauseButton(playerState);
                                  },
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ))),
            children: [
              StreamBuilder<List<IndexedAudioSource>?>(
                stream: api.player.sequenceStream,
                builder: (_, snapshot) {
                  final playerState = snapshot.data;
                  return playlistView(playerState);
                },
              ),
            ]),
      ),
    );
  }

  Widget playlistView(List<IndexedAudioSource>? x) {
    final songs = x?.map((item) => item.tag.title as String).toList();
    if (songs == null || songs.isEmpty) {
      return const Text('暂无歌曲');
    }
    return ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 300.0,
        ),
        child: RotatedBox(
            quarterTurns: 2,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: songs.length,
              itemBuilder: (BuildContext context, int index) {
                return Card(
                  child: InkWell(
                    splashColor: Colors.blue.withAlpha(30),
                    onTap: () {
                      api.player.seek(Duration.zero, index: index);
                    },
                    child: Text(songs[index]),
                  ),
                );
              },
            )));
  }
}
