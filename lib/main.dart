import 'package:bmsc/model/search.dart';
import 'package:bmsc/page/fav_screen.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'util/string.dart';
import 'globals.dart' as globals;

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

  Widget upsidedn(Widget child) {
    return RotatedBox(quarterTurns: 2, child: child);
  }

  Widget _repeatButton(BuildContext context, LoopMode loopMode) {
    final icons = [
      const Icon(Icons.playlist_play),
      const Icon(Icons.repeat),
      const Icon(Icons.repeat_one),
    ];
    final labels = [
      const Text("顺序播放"),
      const Text("歌单循环"),
      const Text("单曲循环"),
    ];
    const cycleModes = [
      LoopMode.off,
      LoopMode.all,
      LoopMode.one,
    ];
    final index = cycleModes.indexOf(loopMode);
    return ElevatedButton.icon(
      icon: icons[index],
      style: ElevatedButton.styleFrom(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
      ),
      label: labels[index],
      onPressed: () {
        globals.api.player.setLoopMode(
            cycleModes[(cycleModes.indexOf(loopMode) + 1) % cycleModes.length]);
      },
    );
  }

  Widget _playPauseButton(PlayerState? playerState) {
    final processingState = playerState?.processingState;
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return const CircularProgressIndicator();
    } else if (globals.api.player.playing != true) {
      return IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: globals.api.player.play,
      );
    } else if (processingState != ProcessingState.completed) {
      return IconButton(
        icon: const Icon(Icons.pause),
        onPressed: globals.api.player.pause,
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.replay),
        onPressed: () => globals.api.player.seek(Duration.zero,
            index: globals.api.player.effectiveIndices!.first),
      );
    }
  }

  Widget progressIndicator(Duration? dur) {
    if (dur == null || globals.api.player.duration == null) {
      return const CircularProgressIndicator(
        value: 0,
        color: Colors.white,
      );
    }
    return CircularProgressIndicator(
        value: dur.inSeconds / globals.api.player.duration!.inSeconds);
  }

  Widget playlistView(List<IndexedAudioSource>? x) {
    final songs = x?.map((item) => item.tag).toList();
    if (songs == null || songs.isEmpty) {
      return const Text('暂无歌曲');
    }
    return ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 300.0,
        ),
        child: RotatedBox(
            quarterTurns: 2,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: songs.length,
              onReorder: (oldIndex, newIndex) async {
                if (oldIndex < newIndex) {
                  --newIndex;
                }
                await globals.api.playlist.move(oldIndex, newIndex);
              },
              itemBuilder: (BuildContext context, int index) {
                return Column(
                  key: Key(songs[index].id),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      onTap: () {
                        globals.api.player.seek(Duration.zero, index: index);
                      },
                      title: Text(
                        songs[index].title,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                      ),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 12),
                          Text(
                            songs[index].artist,
                            style: const TextStyle(fontSize: 10),
                            maxLines: 1,
                          )
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          globals.api.playlist.removeAt(index);
                        },
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                    )
                  ],
                );
              },
            )));
  }

  Widget playCard() {
    return RotatedBox(
      quarterTurns: 2,
      child: ExpansionTile(
          controlAffinity: ListTileControlAffinity.leading,
          tilePadding: const EdgeInsets.only(left: 10),
          shape:
              const Border(bottom: BorderSide(width: 2, color: Colors.black)),
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
                                  child: StreamBuilder<SequenceState?>(
                                    stream:
                                        globals.api.player.sequenceStateStream,
                                    builder: (_, snapshot) {
                                      final src = snapshot.data?.currentSource;
                                      return src == null
                                          ? const Icon(Icons.question_mark)
                                          : Image.network(
                                              src.tag.artUri.toString(),
                                              fit: BoxFit.cover,
                                            );
                                    },
                                  )),
                            ),
                            title: StreamBuilder<SequenceState?>(
                              stream: globals.api.player.sequenceStateStream,
                              builder: (_, snapshot) {
                                final src = snapshot.data?.currentSource;
                                return Text(src?.tag.title ?? "",
                                    style: const TextStyle(fontSize: 12),
                                    softWrap: false,
                                    maxLines: 1);
                              },
                            ),
                            subtitle: StreamBuilder<SequenceState?>(
                              stream: globals.api.player.sequenceStateStream,
                              builder: (_, snapshot) {
                                final src = snapshot.data?.currentSource;
                                return Text(src?.tag.artist ?? "",
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
                                stream: globals.api.player.positionStream,
                                builder: (_, snapshot) {
                                  final duration = snapshot.data;
                                  return progressIndicator(duration);
                                },
                              ),
                              StreamBuilder<PlayerState>(
                                stream: globals.api.player.playerStateStream,
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
              stream: globals.api.player.sequenceStream,
              builder: (_, snapshot) {
                final playerState = snapshot.data;
                return playlistView(playerState);
              },
            ),
            upsidedn(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: StreamBuilder<List<IndexedAudioSource>?>(
                    stream: globals.api.player.sequenceStream,
                    builder: (_, snapshot) {
                      return Text("播放列表 (${snapshot.data?.length ?? 0})");
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: StreamBuilder<LoopMode>(
                    stream: globals.api.player.loopModeStream,
                    builder: (context, snapshot) {
                      return _repeatButton(
                          context, snapshot.data ?? LoopMode.off);
                    },
                  ),
                ),
              ],
            ))
          ]),
    );
  }

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
          globals.api.playSong(vid.bvid);
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
                  subtitle: Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                      ),
                      Text(vid.author, style: const TextStyle(fontSize: 12)),
                    ],
                  )),
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

  void onSearching(String value) async {
    final ret = await globals.api.search(value);
    if (ret != null) {
      setState(() {
        vidList = ret;
      });
    }
  }
}
