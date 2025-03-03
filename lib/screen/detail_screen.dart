import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:bmsc/component/playlist_bottom_sheet.dart';
import 'package:bmsc/component/select_favlist_dialog_multi.dart';
import 'package:bmsc/screen/user_detail_screen.dart';
import 'package:bmsc/service/audio_service.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:bmsc/service/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../component/playing_card.dart';
import '../util/widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bmsc/screen/comment_screen.dart';
import 'package:share_plus/share_plus.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key});

  @override
  State<StatefulWidget> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool? _isFavorite;
  int? _currentAid;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _checkFavoriteStatus(int? aid) async {
    if (!mounted) return;
    if (aid == null) {
      setState(() => _isFavorite = null);
      return;
    }
    final isFavorited = await (await BilibiliService.instance).isFavorited(aid);
    if (!mounted) return;
    setState(() => _isFavorite = isFavorited);
  }

  Widget progressIndicator(Duration? dur, AudioPlayer player) {
    return LinearProgressIndicator(
        value: (dur?.inSeconds ?? 0) / (player.duration?.inSeconds ?? 1));
  }

  Widget _playPauseButton(PlayerState? playerState, AudioPlayer player) {
    final processingState = playerState?.processingState;
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.more_horiz_sharp,
            size: 40,
          ));
    } else if (player.playing != true) {
      return IconButton(
        icon: const Icon(
          Icons.play_arrow,
          size: 40,
        ),
        onPressed: player.play,
      );
    } else if (processingState != ProcessingState.completed) {
      return IconButton(
        icon: const Icon(
          Icons.pause,
          size: 40,
        ),
        onPressed: player.pause,
      );
    } else {
      return IconButton(
        icon: const Icon(
          Icons.replay,
          size: 40,
        ),
        onPressed: () =>
            player.seek(Duration.zero, index: player.effectiveIndices!.first),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('正在播放'),
        actions: [
          FutureBuilder<AudioService>(
              future: AudioService.instance,
              builder: (_, snapshot) {
                final audioService = snapshot.data;
                if (audioService == null) {
                  return const SizedBox.shrink();
                }
                return StreamBuilder<SequenceState?>(
                    stream: audioService.player.sequenceStateStream,
                    builder: (context, snapshot) {
                      final src = snapshot.data?.currentSource;
                      return IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: src == null
                            ? null
                            : () {
                                final bvid = src.tag.extras['bvid'];
                                final title = src.tag.title;
                                final url =
                                    'https://www.bilibili.com/video/$bvid';
                                Share.share(
                                  '$title\n$url',
                                  subject: title,
                                );
                              },
                      );
                    });
              }),
        ],
      ),
      body: FutureBuilder<AudioService>(
        future: AudioService.instance,
        builder: (context, snapshot) {
          final audioService = snapshot.data;
          if (audioService == null) {
            return const SizedBox.shrink();
          }

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 800,
                ),
                child: isLandscape
                    ? _buildLandscapeLayout(context, audioService)
                    : _buildPortraitLayout(context, audioService),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, AudioService audioService) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<SequenceState?>(
            stream: audioService.player.sequenceStateStream,
            builder: (_, snapshot) {
              final src = snapshot.data?.currentSource;
              return src == null
                  ? const SizedBox(
                      height: 200,
                      width: 355.5,
                      child: Center(
                        child: Icon(Icons.question_mark, size: 50),
                      ),
                    )
                  : shadow(ClipRRect(
                      borderRadius: BorderRadius.circular(5.0),
                      child: SizedBox(
                          height: 200,
                          width: 355.5,
                          child: CachedNetworkImage(
                            imageUrl: src.tag.artUri.toString(),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const Icon(Icons.music_note),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.music_note),
                          )),
                    ));
            },
          ),
          StreamBuilder<SequenceState?>(
            stream: audioService.player.sequenceStateStream,
            builder: (_, snapshot) {
              final src = snapshot.data?.currentSource;
              return Padding(
                padding: const EdgeInsets.only(
                    top: 16, left: 16, right: 16, bottom: 8),
                child: Text(
                  src?.tag.title ?? "",
                  style: const TextStyle(fontSize: 20),
                  softWrap: true,
                ),
              );
            },
          ),
          StreamBuilder<SequenceState?>(
            stream: audioService.player.sequenceStateStream,
            builder: (_, snapshot) {
              final src = snapshot.data?.currentSource;
              return InkWell(
                onTap: () => src == null
                    ? 0
                    : Navigator.pushReplacement(context,
                        MaterialPageRoute<Widget>(
                            builder: (BuildContext context) {
                        return Overlay(
                          initialEntries: [
                            OverlayEntry(builder: (context3) {
                              return Scaffold(
                                body: UserDetailScreen(
                                  mid: src.tag.extras['mid'] ?? 0,
                                ),
                                bottomNavigationBar: const PlayingCard(),
                              );
                            })
                          ],
                        );
                      })),
                child: Text(src?.tag.artist ?? "",
                    style: const TextStyle(fontSize: 14),
                    softWrap: false,
                    maxLines: 1),
              );
            },
          ),
          const SizedBox(
            height: 30,
          ),
          Padding(
              padding: const EdgeInsets.all(20.0),
              child: StreamBuilder<(Duration, Duration, Duration?)>(
                stream: Rx.combineLatest2(
                    audioService.player.positionStream,
                    audioService.player.playbackEventStream,
                    (position, playbackEvent) => (
                          position, // progress
                          playbackEvent.bufferedPosition, // buffered
                          playbackEvent.duration, // total
                        )),
                builder: (context, snapshot) {
                  final durationState = snapshot.data;
                  final progress = durationState?.$1 ?? Duration.zero;
                  final buffered = durationState?.$2 ?? Duration.zero;
                  final total = durationState?.$3 ?? Duration.zero;
                  return ProgressBar(
                    progress: progress,
                    buffered: buffered,
                    total: total,
                    onSeek: audioService.player.seek,
                    timeLabelTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 10),
                    timeLabelPadding: 5,
                    thumbRadius: 5,
                  );
                },
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder<(LoopMode, bool)>(
                      stream: Rx.combineLatest2(
                        audioService.player.loopModeStream,
                        audioService.player.shuffleModeEnabledStream,
                        (a, b) => (a, b),
                      ),
                      builder: (context, snapshot) {
                        final (loopMode, shuffleModeEnabled) =
                            snapshot.data ?? (LoopMode.off, false);
                        final icons = [
                          Icons.playlist_play,
                          Icons.repeat_one,
                          Icons.repeat,
                          Icons.shuffle,
                        ];
                        final labels = ["顺序播放", "单曲循环", "歌单循环", "随机播放"];
                        final index = shuffleModeEnabled
                            ? 3
                            : LoopMode.values.indexOf(loopMode);

                        return TextButton.icon(
                          icon: Icon(
                            shuffleModeEnabled ? Icons.shuffle : icons[index],
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          label: Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onPressed: () {
                            final idx = (index + 1) % labels.length;

                            if (idx == 3) {
                              audioService.player.setShuffleModeEnabled(true);
                            } else {
                              audioService.player
                                  .setLoopMode(LoopMode.values[idx]);
                              audioService.player.setShuffleModeEnabled(false);
                            }
                          },
                        );
                      },
                    ),
                    StreamBuilder<SequenceState?>(
                      stream: audioService.player.sequenceStateStream,
                      builder: (context, snapshot) {
                        final src = snapshot.data?.currentSource;
                        if (src?.tag.extras['aid'] != _currentAid) {
                          _currentAid = src?.tag.extras['aid'];
                          Future.microtask(
                              () => _checkFavoriteStatus(_currentAid));
                        }
                        return TextButton.icon(
                          icon: Icon(
                            _isFavorite == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 20,
                            color: _isFavorite == true
                                ? Colors.red
                                : Theme.of(context).colorScheme.primary,
                          ),
                          label: Text(
                            _isFavorite == true ? '已收藏' : '收藏',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isFavorite == true
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onPressed: src == null
                              ? null
                              : () async {
                                  final bs = await BilibiliService.instance;
                                  final uid = bs.myInfo?.mid ?? 0;
                                  final favs = await bs.getFavs(uid,
                                      rid: src.tag.extras['aid']);
                                  if (favs == null || favs.isEmpty) {
                                    return;
                                  }

                                  final defaultFolderId =
                                      await SharedPreferencesService
                                          .getDefaultFavFolder();

                                  if (!_isFavorite! &&
                                      defaultFolderId != null) {
                                    final success = await bs.favoriteVideo(
                                          src.tag.extras['aid'],
                                          [defaultFolderId.$1],
                                          [],
                                        ) ??
                                        false;
                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success
                                            ? '已添加到收藏夹 ${defaultFolderId.$2}'
                                            : '收藏失败'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    if (success) {
                                      Future.microtask(() => setState(
                                          () => _isFavorite = success));
                                    }
                                  } else {
                                    if (!context.mounted) return;
                                    final result = await showDialog(
                                        context: context,
                                        builder: (context) =>
                                            SelectMultiFavlistDialog(
                                                aid: src.tag.extras['aid']));
                                    if (result == null) return;
                                    final toAdd = result['toAdd'];
                                    final toRemove = result['toRemove'];
                                    if (toAdd.isEmpty && toRemove.isEmpty) {
                                      return;
                                    }

                                    final success =
                                        await (await BilibiliService.instance)
                                                .favoriteVideo(
                                              src.tag.extras['aid'],
                                              toAdd,
                                              toRemove,
                                            ) ??
                                            false;
                                    if (!mounted) return;

                                    if (success) {
                                      if (toAdd.isNotEmpty) {
                                        Future.microtask(() => setState(() {
                                              _isFavorite = true;
                                            }));
                                      } else {
                                        _checkFavoriteStatus(
                                            src.tag.extras['aid']);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('收藏夹已更新'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } else {
                                      _checkFavoriteStatus(
                                          src.tag.extras['aid']);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('操作失败'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<SequenceState?>(
                      stream: audioService.player.sequenceStateStream,
                      builder: (_, __) {
                        return IconButton(
                          icon: const Icon(Icons.skip_previous, size: 36),
                          onPressed: audioService.player.hasPrevious
                              ? audioService.player.seekToPrevious
                              : null,
                        );
                      },
                    ),
                    StreamBuilder<PlayerState>(
                      stream: audioService.player.playerStateStream,
                      builder: (_, snapshot) {
                        final playerState = snapshot.data;
                        return Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: _playPauseButton(
                                playerState, audioService.player),
                          ),
                        );
                      },
                    ),
                    StreamBuilder<SequenceState?>(
                      stream: audioService.player.sequenceStateStream,
                      builder: (_, __) {
                        return IconButton(
                          icon: const Icon(Icons.skip_next, size: 36),
                          onPressed: audioService.player.hasNext
                              ? audioService.player.seekToNext
                              : null,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<int?>(
                      stream: audioService.sleepTimerStream,
                      builder: (context, snapshot) {
                        final remainingSeconds = snapshot.data;
                        final isActive = remainingSeconds != null;

                        String formatTime(int seconds) {
                          final hours = seconds ~/ 3600;
                          final minutes = (seconds % 3600) ~/ 60;
                          final remainingSecs = seconds % 60;

                          if (hours > 0) {
                            return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
                          } else {
                            return '$minutes:${remainingSecs.toString().padLeft(2, '0')}';
                          }
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isActive ? Icons.timer : Icons.timer_outlined,
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              onPressed: () {
                                if (isActive) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('定时停止播放'),
                                      content: const Text('是否取消定时停止播放？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('返回'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            audioService.setSleepTimer(null);
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('已取消定时停止播放'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: const Text('取消定时'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  // 显示定时选项对话框
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('定时停止播放'),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(bottom: 8.0),
                                              child: Text('倒计时停止',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            SizedBox(
                                              height: 200,
                                              child: ListView(
                                                shrinkWrap: true,
                                                children: [
                                                  ...[
                                                    5,
                                                    10,
                                                    15,
                                                    30,
                                                    45,
                                                    60,
                                                    90
                                                  ].map((minutes) => ListTile(
                                                        dense: true,
                                                        title:
                                                            Text('$minutes 分钟'),
                                                        onTap: () {
                                                          audioService
                                                              .setSleepTimer(
                                                                  minutes);
                                                          Navigator.pop(
                                                              context);
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                  '将在 $minutes 分钟后停止播放'),
                                                              duration:
                                                                  const Duration(
                                                                      seconds:
                                                                          2),
                                                            ),
                                                          );
                                                        },
                                                      )),
                                                  ListTile(
                                                    dense: true,
                                                    title: const Text('自定义时间'),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      // 显示自定义时间输入对话框
                                                      final controller =
                                                          TextEditingController();
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                              '设置定时时间（分钟）'),
                                                          content: TextField(
                                                            controller:
                                                                controller,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            decoration:
                                                                const InputDecoration(
                                                              labelText: '分钟',
                                                              border:
                                                                  OutlineInputBorder(),
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context),
                                                              child: const Text(
                                                                  '取消'),
                                                            ),
                                                            FilledButton(
                                                              onPressed: () {
                                                                final minutes =
                                                                    int.tryParse(
                                                                        controller
                                                                            .text);
                                                                if (minutes !=
                                                                        null &&
                                                                    minutes >
                                                                        0) {
                                                                  audioService
                                                                      .setSleepTimer(
                                                                          minutes);
                                                                  Navigator.pop(
                                                                      context);
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                          '将在 $minutes 分钟后停止播放'),
                                                                      duration: const Duration(
                                                                          seconds:
                                                                              2),
                                                                    ),
                                                                  );
                                                                }
                                                              },
                                                              child: const Text(
                                                                  '确定'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(),
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                  top: 8.0, bottom: 8.0),
                                              child: Text('指定时刻停止',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            ListTile(
                                              dense: true,
                                              title: const Text('选择时间'),
                                              onTap: () async {
                                                Navigator.pop(context);

                                                // 获取当前时间作为初始值
                                                final now = DateTime.now();
                                                final initialTime = TimeOfDay(
                                                    hour: now.hour,
                                                    minute: now.minute);

                                                // 显示时间选择器
                                                final selectedTime =
                                                    await showTimePicker(
                                                  context: context,
                                                  initialTime: initialTime,
                                                  builder: (context, child) {
                                                    return MediaQuery(
                                                      data:
                                                          MediaQuery.of(context)
                                                              .copyWith(
                                                        alwaysUse24HourFormat:
                                                            true,
                                                      ),
                                                      child: child!,
                                                    );
                                                  },
                                                );

                                                if (selectedTime != null &&
                                                    context.mounted) {
                                                  // 创建目标DateTime
                                                  final now = DateTime.now();
                                                  var targetTime = DateTime(
                                                    now.year,
                                                    now.month,
                                                    now.day,
                                                    selectedTime.hour,
                                                    selectedTime.minute,
                                                  );

                                                  // 如果选择的时间已经过去，则设置为明天的这个时间
                                                  if (targetTime
                                                      .isBefore(now)) {
                                                    targetTime = targetTime.add(
                                                        const Duration(
                                                            days: 1));
                                                  }

                                                  // 设置定时器
                                                  audioService.setSleepTimer(
                                                      null,
                                                      specificTime: targetTime);

                                                  // 计算并显示剩余时间
                                                  final difference = targetTime
                                                      .difference(now);
                                                  final hours =
                                                      difference.inHours;
                                                  final minutes =
                                                      difference.inMinutes % 60;

                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            '将在 ${selectedTime.format(context)} (${hours > 0 ? '$hours小时' : ''}${minutes > 0 ? '$minutes分钟' : ''}后) 停止播放'),
                                                        duration:
                                                            const Duration(
                                                                seconds: 2),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            if (isActive)
                              Text(
                                formatTime(remainingSeconds),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            if (!isActive)
                              Text(
                                '定时',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.queue_music),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => const PlaylistBottomSheet(),
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              isScrollControlled: true,
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.7,
                              ),
                            );
                          },
                        ),
                        Text(
                          '播放列表',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    StreamBuilder<SequenceState?>(
                      stream: audioService.player.sequenceStateStream,
                      builder: (context, snapshot) {
                        final src = snapshot.data?.currentSource;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.comment_outlined),
                                onPressed: src == null
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CommentScreen(
                                              aid: src.tag.extras['aid']
                                                  .toString(),
                                            ),
                                          ),
                                        )),
                            Text(
                              '评论',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                            )
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(
      BuildContext context, AudioService audioService) {
    return Row(children: [
      Expanded(
        flex: 1,
        child: StreamBuilder<SequenceState?>(
          stream: audioService.player.sequenceStateStream,
          builder: (_, snapshot) {
            final src = snapshot.data?.currentSource;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cover image
                src == null
                    ? const SizedBox(
                        height: 200,
                        width: 355.5,
                        child: Center(
                          child: Icon(Icons.question_mark, size: 50),
                        ),
                      )
                    : shadow(ClipRRect(
                        borderRadius: BorderRadius.circular(5.0),
                        child: SizedBox(
                          height: 200,
                          width: 355.5,
                          child: CachedNetworkImage(
                            imageUrl: src.tag.artUri.toString(),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const Icon(Icons.music_note),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.music_note),
                          ),
                        ),
                      )),
                // Title and artist
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        src?.tag.title ?? "",
                        style: const TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        src?.tag.artist ?? "",
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      Expanded(
        flex: 1,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: StreamBuilder<(Duration, Duration, Duration?)>(
                      stream: Rx.combineLatest2(
                          audioService.player.positionStream,
                          audioService.player.playbackEventStream,
                          (position, playbackEvent) => (
                                position, // progress
                                playbackEvent.bufferedPosition, // buffered
                                playbackEvent.duration, // total
                              )),
                      builder: (context, snapshot) {
                        final durationState = snapshot.data;
                        final progress = durationState?.$1 ?? Duration.zero;
                        final buffered = durationState?.$2 ?? Duration.zero;
                        final total = durationState?.$3 ?? Duration.zero;
                        return ProgressBar(
                          progress: progress,
                          buffered: buffered,
                          total: total,
                          onSeek: audioService.player.seek,
                          timeLabelTextStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 10),
                          timeLabelPadding: 5,
                          thumbRadius: 5,
                        );
                      },
                    )),
                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StreamBuilder<(LoopMode, bool)>(
                            stream: Rx.combineLatest2(
                              audioService.player.loopModeStream,
                              audioService.player.shuffleModeEnabledStream,
                              (a, b) => (a, b),
                            ),
                            builder: (context, snapshot) {
                              final (loopMode, shuffleModeEnabled) =
                                  snapshot.data ?? (LoopMode.off, false);
                              final icons = [
                                Icons.playlist_play,
                                Icons.repeat_one,
                                Icons.repeat,
                                Icons.shuffle,
                              ];
                              final labels = ["顺序播放", "单曲循环", "歌单循环", "随机播放"];
                              final index = shuffleModeEnabled
                                  ? 3
                                  : LoopMode.values.indexOf(loopMode);

                              return TextButton.icon(
                                icon: Icon(
                                  shuffleModeEnabled
                                      ? Icons.shuffle
                                      : icons[index],
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                label: Text(
                                  labels[index],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                onPressed: () {
                                  final idx = (index + 1) % labels.length;

                                  if (idx == 3) {
                                    audioService.player
                                        .setShuffleModeEnabled(true);
                                  } else {
                                    audioService.player
                                        .setLoopMode(LoopMode.values[idx]);
                                    audioService.player
                                        .setShuffleModeEnabled(false);
                                  }
                                },
                              );
                            },
                          ),
                          StreamBuilder<SequenceState?>(
                            stream: audioService.player.sequenceStateStream,
                            builder: (context, snapshot) {
                              final src = snapshot.data?.currentSource;
                              if (src?.tag.extras['aid'] != _currentAid) {
                                _currentAid = src?.tag.extras['aid'];
                                Future.microtask(
                                    () => _checkFavoriteStatus(_currentAid));
                              }
                              return TextButton.icon(
                                icon: Icon(
                                  _isFavorite == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 20,
                                  color: _isFavorite == true
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                label: Text(
                                  _isFavorite == true ? '已收藏' : '收藏',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isFavorite == true
                                        ? Colors.red
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                onPressed: src == null
                                    ? null
                                    : () async {
                                        final bs =
                                            await BilibiliService.instance;
                                        final uid = bs.myInfo?.mid ?? 0;
                                        final favs = await bs.getFavs(uid,
                                            rid: src.tag.extras['aid']);
                                        if (favs == null || favs.isEmpty) {
                                          return;
                                        }

                                        final defaultFolderId =
                                            await SharedPreferencesService
                                                .getDefaultFavFolder();

                                        if (!_isFavorite! &&
                                            defaultFolderId != null) {
                                          final success =
                                              await bs.favoriteVideo(
                                                    src.tag.extras['aid'],
                                                    [defaultFolderId.$1],
                                                    [],
                                                  ) ??
                                                  false;
                                          if (!context.mounted) return;

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(success
                                                  ? '已添加到收藏夹 ${defaultFolderId.$2}'
                                                  : '收藏失败'),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                          if (success) {
                                            Future.microtask(() => setState(
                                                () => _isFavorite = success));
                                          }
                                        } else {
                                          if (!context.mounted) return;
                                          final result = await showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  SelectMultiFavlistDialog(
                                                      aid: src
                                                          .tag.extras['aid']));
                                          if (result == null) return;
                                          final toAdd = result['toAdd'];
                                          final toRemove = result['toRemove'];
                                          if (toAdd.isEmpty &&
                                              toRemove.isEmpty) {
                                            return;
                                          }

                                          final success =
                                              await (await BilibiliService
                                                          .instance)
                                                      .favoriteVideo(
                                                    src.tag.extras['aid'],
                                                    toAdd,
                                                    toRemove,
                                                  ) ??
                                                  false;
                                          if (!mounted) return;

                                          if (success) {
                                            if (toAdd.isNotEmpty) {
                                              Future.microtask(
                                                  () => setState(() {
                                                        _isFavorite = true;
                                                      }));
                                            } else {
                                              _checkFavoriteStatus(
                                                  src.tag.extras['aid']);
                                            }

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text('收藏夹已更新'),
                                                  duration:
                                                      Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          } else {
                                            _checkFavoriteStatus(
                                                src.tag.extras['aid']);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text('操作失败'),
                                                  duration:
                                                      Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          StreamBuilder<SequenceState?>(
                            stream: audioService.player.sequenceStateStream,
                            builder: (_, __) {
                              return IconButton(
                                icon: const Icon(Icons.skip_previous, size: 36),
                                onPressed: audioService.player.hasPrevious
                                    ? audioService.player.seekToPrevious
                                    : null,
                              );
                            },
                          ),
                          StreamBuilder<PlayerState>(
                            stream: audioService.player.playerStateStream,
                            builder: (_, snapshot) {
                              final playerState = snapshot.data;
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _playPauseButton(
                                      playerState, audioService.player),
                                ),
                              );
                            },
                          ),
                          StreamBuilder<SequenceState?>(
                            stream: audioService.player.sequenceStateStream,
                            builder: (_, __) {
                              return IconButton(
                                icon: const Icon(Icons.skip_next, size: 36),
                                onPressed: audioService.player.hasNext
                                    ? audioService.player.seekToNext
                                    : null,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          StreamBuilder<int?>(
                            stream: audioService.sleepTimerStream,
                            builder: (context, snapshot) {
                              final remainingSeconds = snapshot.data;
                              final isActive = remainingSeconds != null;

                              String formatTime(int seconds) {
                                final hours = seconds ~/ 3600;
                                final minutes = (seconds % 3600) ~/ 60;
                                final remainingSecs = seconds % 60;

                                if (hours > 0) {
                                  return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
                                } else {
                                  return '$minutes:${remainingSecs.toString().padLeft(2, '0')}';
                                }
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isActive
                                          ? Icons.timer
                                          : Icons.timer_outlined,
                                      color: isActive
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                    ),
                                    onPressed: () {
                                      if (isActive) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('定时停止播放'),
                                            content: const Text('是否取消定时停止播放？'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('返回'),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  audioService
                                                      .setSleepTimer(null);
                                                  Navigator.pop(context);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content:
                                                          Text('已取消定时停止播放'),
                                                      duration:
                                                          Duration(seconds: 2),
                                                    ),
                                                  );
                                                },
                                                child: const Text('取消定时'),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        // 显示定时选项对话框
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('定时停止播放'),
                                            content: SizedBox(
                                              width: double.maxFinite,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                        bottom: 8.0),
                                                    child: Text('倒计时停止',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                  SizedBox(
                                                    height: 200,
                                                    child: ListView(
                                                      shrinkWrap: true,
                                                      children: [
                                                        ...[
                                                          5,
                                                          10,
                                                          15,
                                                          30,
                                                          45,
                                                          60,
                                                          90
                                                        ]
                                                            .map(
                                                                (minutes) =>
                                                                    ListTile(
                                                                      dense:
                                                                          true,
                                                                      title: Text(
                                                                          '$minutes 分钟'),
                                                                      onTap:
                                                                          () {
                                                                        audioService
                                                                            .setSleepTimer(minutes);
                                                                        Navigator.pop(
                                                                            context);
                                                                        ScaffoldMessenger.of(context)
                                                                            .showSnackBar(
                                                                          SnackBar(
                                                                            content:
                                                                                Text('将在 $minutes 分钟后停止播放'),
                                                                            duration:
                                                                                const Duration(seconds: 2),
                                                                          ),
                                                                        );
                                                                      },
                                                                    )),
                                                        ListTile(
                                                          dense: true,
                                                          title: const Text(
                                                              '自定义时间'),
                                                          onTap: () {
                                                            Navigator.pop(
                                                                context);
                                                            // 显示自定义时间输入对话框
                                                            final controller =
                                                                TextEditingController();
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (context) =>
                                                                      AlertDialog(
                                                                title: const Text(
                                                                    '设置定时时间（分钟）'),
                                                                content:
                                                                    TextField(
                                                                  controller:
                                                                      controller,
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .number,
                                                                  decoration:
                                                                      const InputDecoration(
                                                                    labelText:
                                                                        '分钟',
                                                                    border:
                                                                        OutlineInputBorder(),
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context),
                                                                    child:
                                                                        const Text(
                                                                            '取消'),
                                                                  ),
                                                                  FilledButton(
                                                                    onPressed:
                                                                        () {
                                                                      final minutes =
                                                                          int.tryParse(
                                                                              controller.text);
                                                                      if (minutes !=
                                                                              null &&
                                                                          minutes >
                                                                              0) {
                                                                        audioService
                                                                            .setSleepTimer(minutes);
                                                                        Navigator.pop(
                                                                            context);
                                                                        ScaffoldMessenger.of(context)
                                                                            .showSnackBar(
                                                                          SnackBar(
                                                                            content:
                                                                                Text('将在 $minutes 分钟后停止播放'),
                                                                            duration:
                                                                                const Duration(seconds: 2),
                                                                          ),
                                                                        );
                                                                      }
                                                                    },
                                                                    child:
                                                                        const Text(
                                                                            '确定'),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Divider(),
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                        top: 8.0, bottom: 8.0),
                                                    child: Text('指定时刻停止',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                  ListTile(
                                                    dense: true,
                                                    title: const Text('选择时间'),
                                                    onTap: () async {
                                                      Navigator.pop(context);

                                                      // 获取当前时间作为初始值
                                                      final now =
                                                          DateTime.now();
                                                      final initialTime =
                                                          TimeOfDay(
                                                              hour: now.hour,
                                                              minute:
                                                                  now.minute);

                                                      // 显示时间选择器
                                                      final selectedTime =
                                                          await showTimePicker(
                                                        context: context,
                                                        initialTime:
                                                            initialTime,
                                                        builder:
                                                            (context, child) {
                                                          return MediaQuery(
                                                            data: MediaQuery.of(
                                                                    context)
                                                                .copyWith(
                                                              alwaysUse24HourFormat:
                                                                  true,
                                                            ),
                                                            child: child!,
                                                          );
                                                        },
                                                      );

                                                      if (selectedTime !=
                                                              null &&
                                                          context.mounted) {
                                                        // 创建目标DateTime
                                                        final now =
                                                            DateTime.now();
                                                        var targetTime =
                                                            DateTime(
                                                          now.year,
                                                          now.month,
                                                          now.day,
                                                          selectedTime.hour,
                                                          selectedTime.minute,
                                                        );

                                                        // 如果选择的时间已经过去，则设置为明天的这个时间
                                                        if (targetTime
                                                            .isBefore(now)) {
                                                          targetTime =
                                                              targetTime.add(
                                                                  const Duration(
                                                                      days: 1));
                                                        }

                                                        // 设置定时器
                                                        audioService
                                                            .setSleepTimer(null,
                                                                specificTime:
                                                                    targetTime);

                                                        // 计算并显示剩余时间
                                                        final difference =
                                                            targetTime
                                                                .difference(
                                                                    now);
                                                        final hours =
                                                            difference.inHours;
                                                        final minutes =
                                                            difference
                                                                    .inMinutes %
                                                                60;

                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                  '将在 ${selectedTime.format(context)} (${hours > 0 ? '$hours小时' : ''}${minutes > 0 ? '$minutes分钟' : ''}后) 停止播放'),
                                                              duration:
                                                                  const Duration(
                                                                      seconds:
                                                                          2),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  if (isActive)
                                    Text(
                                      formatTime(remainingSeconds),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  if (!isActive)
                                    Text(
                                      '定时',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isActive
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.queue_music),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) =>
                                        const PlaylistBottomSheet(),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    isScrollControlled: true,
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                              0.7,
                                    ),
                                  );
                                },
                              ),
                              Text(
                                '播放列表',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          StreamBuilder<SequenceState?>(
                            stream: audioService.player.sequenceStateStream,
                            builder: (context, snapshot) {
                              final src = snapshot.data?.currentSource;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.comment_outlined),
                                      onPressed: src == null
                                          ? null
                                          : () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      CommentScreen(
                                                    aid: src.tag.extras['aid']
                                                        .toString(),
                                                  ),
                                                ),
                                              )),
                                  Text(
                                    '评论',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  )
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}
