import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../globals.dart' as globals;
import '../model/search.dart';
import '../util/string.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PlaylistSearchScreen extends StatefulWidget {
  const PlaylistSearchScreen({super.key});

  @override
  State<StatefulWidget> createState() => _PlaylistSearchScreenState();
}

class _PlaylistSearchScreenState extends State<PlaylistSearchScreen> {
  final textController = TextEditingController();
  final scrollController = ScrollController();
  List<Map<String, dynamic>> results = [];
  bool isSearching = false;
  bool isSaving = false;
  bool autoscroll = true;
  bool isReverse = true;
  bool isSearchPaused = false;
  bool isSavingPaused = false;

  late BuildContext _context;

  Completer<void>? _pauseSearchCompleter;

  Completer<void>? _pauseSavingCompleter;

  int totalTracks = 0;
  int processedTracks = 0;
  int totalFavorites = 0;
  int processedFavorites = 0;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _notificationsInitialized = true;
  }

  void _toggleSearchPause() {
    setState(() {
      isSearchPaused = !isSearchPaused;
      if (!isSearchPaused && _pauseSearchCompleter != null) {
        _pauseSearchCompleter?.complete();
        _pauseSearchCompleter = null;
      }
    });
  }

  void _toggleSavingPause() {
    setState(() {
      isSavingPaused = !isSavingPaused;
      if (!isSavingPaused && _pauseSavingCompleter != null) {
        _pauseSavingCompleter?.complete();
        _pauseSavingCompleter = null;
      }
    });
  }

  Future<void> _waitForSearchPause() async {
    if (isSearchPaused) {
      _pauseSearchCompleter = Completer<void>();
      await _pauseSearchCompleter!.future;
    }
  }

  Future<void> _waitForSavingPause() async {
    if (isSavingPaused) {
      _pauseSavingCompleter = Completer<void>();
      await _pauseSavingCompleter!.future;
    }
  }

  // Add GlobalKey to the ListTile you want to scroll to
  final itemKeys = <int, GlobalKey>{}; // Add this with other state variables

  void scrollTo(int index) {
    final context = itemKeys[index]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    return Scaffold(
      appBar: AppBar(
        title: const Text('歌单导入'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: textController,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText:
                    '[示例1] 歌名 \$ 作者 \$ 时长(秒)\nTRUE \$ Yoari \$ 192\n夏日已所剩无几 \$ 泠鸢yousa \$ 271\n[示例2] 平台:歌单ID\nnetease:1234567890\ntencent:1207922987\nkugou:collection_3_1323003327_2_0',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.all(8),
              ),
              style: TextStyle(fontSize: 12),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: isSearching ? _toggleSearchPause : null,
                child: Text(isSearchPaused ? '继续' : '暂停'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (isSearching && !isSearchPaused) ||
                        (isSaving && !isSavingPaused)
                    ? null
                    : _processPlaylist,
                child: Text('搜索'),
              ),
              Row(
                children: [
                  Checkbox(
                    value: isReverse,
                    onChanged: (bool? value) {
                      setState(() {
                        isReverse = value ?? false;
                      });
                    },
                  ),
                  const Text('倒序'),
                ],
              ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                if (results.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: isSaving ? _toggleSavingPause : null,
                        child: Text(isSavingPaused ? '继续' : '暂停'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSaving || (isSearching && !isSearchPaused)
                            ? null
                            : () async {
                                final uid = await globals.api.getStoredUID();
                                if (uid == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('请先登录')),
                                    );
                                  }
                                  return;
                                }

                                final favs = await globals.api.getFavs(uid);
                                if (favs == null || favs.list.isEmpty) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('未找到收藏夹')),
                                    );
                                  }
                                  return;
                                }

                                if (!context.mounted) return;

                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('选择收藏夹'),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        height: 300,
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: favs.list.length,
                                          itemBuilder: (context, index) {
                                            final folder = favs.list[index];
                                            return ListTile(
                                              title: Text(folder.title),
                                              subtitle: Text(
                                                  '${folder.mediaCount} 首曲目'),
                                              onTap: () async {
                                                Navigator.pop(context);

                                                var foundTracks = [];

                                                for (var i = 0;
                                                    i < results.length;
                                                    i++) {
                                                  final result = results[i];
                                                  if (result['aid'] != null) {
                                                    foundTracks.add({
                                                      ...result,
                                                      'index': i
                                                    });
                                                  }
                                                }

                                                final confirmed =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog(
                                                      title: const Text('确认'),
                                                      content: Text(
                                                          '确定要添加 ${foundTracks.length} 首曲目到 ${folder.title} 吗？'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                          child:
                                                              const Text('取消'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  true),
                                                          child:
                                                              const Text('确定'),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );

                                                if (confirmed != true) return;

                                                var successCount = 0;

                                                setState(() {
                                                  isSaving = true;
                                                  isSavingPaused = false;
                                                  processedFavorites = 0;
                                                  totalFavorites =
                                                      foundTracks.length;
                                                });

                                                // Show initial favorite notification
                                                await flutterLocalNotificationsPlugin
                                                    .show(
                                                  1, // Use a different notification ID for favorites
                                                  '添加收藏',
                                                  '准备添加到收藏夹...',
                                                  const NotificationDetails(
                                                    android:
                                                        AndroidNotificationDetails(
                                                      'favorite_progress',
                                                      'Favorite Progress',
                                                      channelDescription:
                                                          'Notifications for favorite progress',
                                                      importance:
                                                          Importance.high,
                                                      priority: Priority.high,
                                                      ongoing: true,
                                                      showProgress: true,
                                                      onlyAlertOnce: true,
                                                      playSound: false,
                                                    ),
                                                  ),
                                                );

                                                for (var i = 0;
                                                    i < foundTracks.length;
                                                    i++) {
                                                  await _waitForSavingPause();
                                                  final track = foundTracks[i];
                                                  final success = await globals
                                                      .api
                                                      .favoriteVideo(
                                                    track['aid'],
                                                    [folder.id],
                                                    [],
                                                  );
                                                  if (success == null) {
                                                    showErrorSnackBar(
                                                        "收藏失败，已暂停");
                                                    --i;
                                                    _toggleSavingPause();
                                                    continue;
                                                  }

                                                  setState(() {
                                                    results[track['index']]
                                                            ['favAddStatus'] =
                                                        success;
                                                    processedFavorites = i + 1;
                                                  });

                                                  // Update favorite progress notification
                                                  await flutterLocalNotificationsPlugin
                                                      .show(
                                                    1,
                                                    '添加收藏',
                                                    '处理中: ${i + 1}/${foundTracks.length}',
                                                    NotificationDetails(
                                                      android:
                                                          AndroidNotificationDetails(
                                                        'favorite_progress',
                                                        'Favorite Progress',
                                                        channelDescription:
                                                            'Notifications for favorite progress',
                                                        importance:
                                                            Importance.high,
                                                        priority: Priority.high,
                                                        ongoing: true,
                                                        showProgress: true,
                                                        maxProgress:
                                                            foundTracks.length,
                                                        progress: i + 1,
                                                        onlyAlertOnce: true,
                                                        playSound: false,
                                                      ),
                                                    ),
                                                  );

                                                  if (autoscroll) {
                                                    scrollTo(track['index']);
                                                  }
                                                  if (success) successCount++;

                                                  await Future.delayed(
                                                      const Duration(
                                                          milliseconds: 1200));
                                                }

                                                // Show completion notification
                                                await flutterLocalNotificationsPlugin
                                                    .show(
                                                  1,
                                                  '添加收藏',
                                                  '完成: 已添加 $successCount/${foundTracks.length} 首曲目到 ${folder.title}',
                                                  const NotificationDetails(
                                                    android:
                                                        AndroidNotificationDetails(
                                                      'favorite_progress',
                                                      'Favorite Progress',
                                                      channelDescription:
                                                          'Notifications for favorite progress',
                                                      importance:
                                                          Importance.high,
                                                      priority: Priority.high,
                                                      onlyAlertOnce: true,
                                                      playSound: false,
                                                    ),
                                                  ),
                                                );

                                                setState(() {
                                                  isSaving = false;
                                                });
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          '已添加 $successCount/${foundTracks.length} 首曲目到 ${folder.title}'),
                                                    ),
                                                  );
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                        child: const Text('收藏'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final text = results
                              .where((r) => r['bvid'] != null)
                              .map((r) => "${r['track']}\$${r['bvid']}")
                              .join('\n');
                          await Clipboard.setData(ClipboardData(text: text));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制到剪贴板')),
                            );
                          }
                        },
                        child: const Text('复制'),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: autoscroll,
                            onChanged: (bool? value) {
                              setState(() {
                                autoscroll = value ?? true;
                              });
                            },
                          ),
                          const Text('自动滚动'),
                        ],
                      ),
                    ],
                  ),
                if (isSearching || isSavingPaused)
                  LinearProgressIndicator(
                    value: totalTracks > 0 ? processedTracks / totalTracks : 0,
                  ),
                if (totalFavorites > 0)
                  LinearProgressIndicator(
                    value: processedFavorites / totalFavorites,
                    color: Colors.green,
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      // Create a key if it doesn't exist
                      itemKeys[index] ??= GlobalKey();

                      final result = results[index];
                      return ListTile(
                        key: itemKeys[index],
                        title: Text("${result['artist']} - ${result['track']}",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('result: ${result['title'] ?? '未找到'}',
                                style: TextStyle(fontSize: 12)),
                            if (result['bvid'] != null)
                              Text(
                                  '(∑: ${result['score']}) (|Δ|: ${result['durationDiff']}s) (ε: ${result['play']}) (§: ${result['typename']})',
                                  style: TextStyle(fontSize: 12)),
                            if (result['favAddStatus'] != null)
                              Text(
                                result['favAddStatus']! ? '已添加到收藏夹' : '添加失败',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: result['favAddStatus']!
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: isSearching && !isSearchPaused
                                      ? null
                                      : () async {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          setState(() => isSearching = true);
                                          final track = result['track'];
                                          final artist = result['artist'];
                                          final duration = result['duration'];
                                          final trackResults =
                                              await _searchTracks(
                                                  track, artist, duration);
                                          if (trackResults.isEmpty) {
                                            showErrorSnackBar("搜索失败");
                                          }
                                          setState(() {
                                            isSearching = false;
                                          });

                                          if (!context.mounted) return;

                                          final selectedVideo =
                                              await showDialog<int?>(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: Text('选择视频'),
                                                content: SizedBox(
                                                  width: double.maxFinite,
                                                  height: 400,
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        trackResults.length,
                                                    itemBuilder: (context, i) {
                                                      final video =
                                                          trackResults[i];

                                                      return ListTile(
                                                        title: Text(
                                                            stripHtmlIfNeeded(
                                                                video['title']),
                                                            style: TextStyle(
                                                                fontSize: 12)),
                                                        subtitle: Text(
                                                            '(∑: ${video['score']}) (|Δ|: ${video['durationDiff']}s) (ε: ${video['play']}) (§: ${video['typename']})',
                                                            style: TextStyle(
                                                                fontSize: 12)),
                                                        onTap: () {
                                                          Navigator.pop(
                                                              context, i);
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                    child: Text('取消'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (selectedVideo == null) return;
                                          setState(() {
                                            results[index] =
                                                trackResults[selectedVideo];
                                          });
                                        },
                                ),
                                if (result['bvid'] != null)
                                  const Icon(Icons.check, color: Colors.green)
                                else
                                  const Icon(Icons.close, color: Colors.red),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showErrorSnackBar(String message) {
    if (_context.mounted) {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '关闭',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(_context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  Future<void> _processPlaylist() async {
    await _initializeNotifications();

    // Show initial notification
    const androidDetails = AndroidNotificationDetails(
      'playlist_search',
      'Playlist Search',
      channelDescription: 'Notifications for playlist search progress',
      importance: Importance.high,
      priority: Priority.high,
      showProgress: true,
      onlyAlertOnce: true,
      playSound: false,
      ongoing: true,
      autoCancel: false,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      '歌单搜索',
      '准备处理...',
      notificationDetails,
    );

    setState(() {
      isSearching = true;
      isSaving = false;
      isSearchPaused = false;
      results = [];
      processedFavorites = 0;
      processedTracks = 0;
      totalFavorites = 0;
      totalTracks = 0;
    });

    List<Map<String, dynamic>> tracks = [];

    final lines = textController.text.split('\n');

    for (final line in lines) {
      List<Map<String, dynamic>> appendTracks = [];
      if (line.startsWith('netease:')) {
        final playlistId = line.split(':')[1].trim();
        final tracks = await globals.api.fetchNeteasePlaylistTracks(playlistId);
        if (tracks == null) {
          showErrorSnackBar("获取歌单 netease:$playlistId 失败");
          continue;
        } else if (tracks.isEmpty) {
          showErrorSnackBar("查无歌单 netease:$playlistId");
          continue;
        }
        appendTracks.addAll(tracks);
      } else if (line.startsWith('tencent:')) {
        final playlistId = line.split(':')[1].trim();
        final tracks = await globals.api.fetchTencentPlaylistTracks(playlistId);
        if (tracks == null) {
          showErrorSnackBar("获取歌单 tencent:$playlistId 失败");
          continue;
        } else if (tracks.isEmpty) {
          showErrorSnackBar("查无歌单 tencent:$playlistId");
          continue;
        }
        appendTracks.addAll(tracks);
      } else if (line.startsWith('kugou:')) {
        final playlistId = line.split(':')[1].trim();
        final tracks = await globals.api.fetchKuGouPlaylistTracks(playlistId);
        if (tracks == null) {
          showErrorSnackBar("获取歌单 kugou:$playlistId 失败");
          continue;
        } else if (tracks.isEmpty) {
          showErrorSnackBar("查无歌单 kugou:$playlistId");
          continue;
        }
        appendTracks.addAll(tracks);
      } else {
        final parts = line.split('\$').map((e) => e.trim()).toList();
        if (parts.length != 3) continue;
        appendTracks.add({
          'name': parts[0],
          'artist': parts[1],
          'duration': int.parse(parts[2]),
        });
      }
      tracks.addAll(appendTracks);
    }

    if (isReverse) {
      tracks = tracks.reversed.toList();
    }

    // Show all tracks first
    setState(() {
      results = tracks
          .map((track) => {
                'track': track['name'],
                'artist': track['artist'],
                'duration': track['duration'],
                'title': '等待搜索...', // "Waiting for search..."
              })
          .toList();
      totalTracks = tracks.length;
    });

    // Update the notification with total tracks
    await flutterLocalNotificationsPlugin.show(
      0,
      '歌单搜索',
      '处理中: 0/$totalTracks',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'playlist_search',
          'Playlist Search',
          channelDescription: 'Notifications for playlist search progress',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          showProgress: true,
          maxProgress: totalTracks,
          progress: 0,
          onlyAlertOnce: true,
          playSound: false,
        ),
      ),
    );

    // Then process each track
    for (var i = 0; i < tracks.length; i++) {
      await _waitForSearchPause();
      await Future.delayed(const Duration(milliseconds: 1200));
      final track = tracks[i];
      final result =
          await _searchTrack(track['name'], track['artist'], track['duration']);
      if (result == null) {
        showErrorSnackBar("搜索失败，已暂停");
        --i;
        _toggleSearchPause();
        continue;
      }
      setState(() {
        results[i] = result;
        processedTracks = i + 1;
      });

      // Update notification progress
      await flutterLocalNotificationsPlugin.show(
        0,
        '歌单搜索',
        '处理中: ${i + 1}/$totalTracks',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'playlist_search',
            'Playlist Search',
            channelDescription: 'Notifications for playlist search progress',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: true,
            showProgress: true,
            maxProgress: totalTracks,
            progress: i + 1,
            onlyAlertOnce: true,
            playSound: false,
          ),
        ),
      );

      if (autoscroll) {
        scrollTo(i);
      }
    }

    // Show completion notification
    await flutterLocalNotificationsPlugin.show(
      0,
      '歌单搜索',
      '处理完成: $totalTracks 首歌曲',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'playlist_search',
          'Playlist Search',
          channelDescription: 'Notifications for playlist search progress',
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          playSound: false,
        ),
      ),
    );

    setState(() {
      isSearching = false;
    });
  }

  int _parseDuration(String duration) {
    final parts = duration.split(':');
    if (parts.length != 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static const _minCommonSubstringLength = 4;

  Set<String> allTypeNames = {};
  static const int INF = 999;

  final RegExp wordRegex = RegExp(r'([^a-zA-Z0-9_\u4e00-\u9fa5]+)');

  Future<List<Map<String, dynamic>>> _searchTracks(
      String track, String artist, int duration) async {
    final searchString = '$track - $artist';
    final searchResult = await globals.api.search(searchString, 1);
    if (searchResult == null) return [];

    List<Map<String, dynamic>> ret = [];

    final trackWords = track
        .toLowerCase()
        .split(wordRegex)
        .where((e) => e.isNotEmpty)
        .toList();
    final artistWords = artist
        .toLowerCase()
        .split(wordRegex)
        .where((e) => e.isNotEmpty)
        .toList();

    final searchWords = searchString
        .toLowerCase()
        .split(wordRegex)
        .where((e) => e.isNotEmpty)
        .toList();
    final searchWordsSet = searchWords.toSet();
    final searchChinese = RegExp(r'[\u4e00-\u9fa5]+')
        .allMatches(searchString)
        .map((m) => m.group(0)!)
        .join();

    int _rankScore(Result video) {
      // 音Mad, 音乐现场, 翻唱, 科学科普, 运动综合
      const list = [26, 29, 31, 201, 238];
      if (list.contains(int.parse(video.typeid))) return -INF;

      final durationDiff = (_parseDuration(video.duration) - duration).abs();
      if (durationDiff > 3 * 60) return -INF;

      final result = stripHtmlIfNeeded(video.title);
      final resultWords = result
          .toLowerCase()
          .split(wordRegex)
          .where((e) => e.isNotEmpty)
          .toList();

      bool hasTrack = containsSubarrayKMP(resultWords, trackWords);
      bool hasArtist = containsSubarrayKMP(resultWords, artistWords);
      if (hasTrack && hasArtist) return INF;

      if (durationDiff > 20) return -INF;

      if (hasTrack || hasArtist) return 10;

      bool hasWordMatch =
          searchWordsSet.intersection(resultWords.toSet()).isNotEmpty;
      if (hasWordMatch) return 5;

      bool hasLongChineseCommonSubstring = false;
      final resultChinese = RegExp(r'[\u4e00-\u9fa5]+')
          .allMatches(result)
          .map((m) => m.group(0)!)
          .join();

      int maxLen = 0;

      final List<List<int>> dp = List.generate(
        searchChinese.length + 1,
        (_) => List.filled(resultChinese.length + 1, 0),
      );

      for (int i = 1; i <= searchChinese.length; i++) {
        for (int j = 1; j <= resultChinese.length; j++) {
          if (searchChinese[i - 1] == resultChinese[j - 1]) {
            dp[i][j] = dp[i - 1][j - 1] + 1;
            if (dp[i][j] > maxLen) {
              maxLen = dp[i][j];
              if (maxLen >= _minCommonSubstringLength) {
                hasLongChineseCommonSubstring = true;
                break;
              }
            }
          }
        }
        if (hasLongChineseCommonSubstring) break;
      }

      return 0;
    }

    for (final video in searchResult.result) {
      if (video.typeid == '') continue;

      int priority = switch (video.typeid) {
        '193' => 1, // MV
        '130' => 1, // 音乐综合
        '267' => 1, // 电台
        _ => 0,
      };

      int score = _rankScore(video);
      // if (score == -INF) continue;
      int durationDiff = (_parseDuration(video.duration) - duration).abs();
      final videoPlayCountLog =
          video.play > 0 ? (log(video.play) / log(10)) : 0;
      score += priority * 1000 - durationDiff + (videoPlayCountLog * 5).round();
      ret.add({
        'track': track,
        'artist': artist,
        'duration': duration,
        'bvid': video.bvid,
        'aid': video.aid,
        'typename': video.typename,
        'typeid': video.typeid,
        'title': stripHtmlIfNeeded(video.title),
        'durationDiff': durationDiff,
        'play': videoPlayCountLog.round(),
        'score': score,
      });
    }
    return ret;
  }

  Future<Map<String, dynamic>?> _searchTrack(
      String track, String artist, int duration) async {
    final tracks = await _searchTracks(track, artist, duration);
    if (tracks.isEmpty) return null;
    return tracks.reduce((a, b) => a['score'] > b['score'] ? a : b);
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }
}
