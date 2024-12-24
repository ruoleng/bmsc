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

  Widget _previousButton(AudioPlayer player) {
    return IconButton(
      icon: const Icon(Icons.skip_previous),
      onPressed: player.hasPrevious ? player.seekToPrevious : null,
    );
  }

  Widget _nextButton(AudioPlayer player) {
    return IconButton(
      icon: const Icon(Icons.skip_next),
      onPressed: player.hasNext ? player.seekToNext : null,
    );
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
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('正在播放'),
        ),
        body: FutureBuilder<AudioService>(
            future: AudioService.instance,
            builder: (context, snapshot) {
              final audioService = snapshot.data;
              if (audioService == null) {
                return const SizedBox.shrink();
              }
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<SequenceState?>(
                      stream: audioService.player.sequenceStateStream,
                      builder: (_, snapshot) {
                        final src = snapshot.data?.currentSource;
                        return src == null
                            ? const Icon(Icons.question_mark)
                            : shadow(ClipRRect(
                                borderRadius: BorderRadius.circular(5.0),
                                child: SizedBox(
                                    height: 200,
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
                                          bottomNavigationBar:
                                              const PlayingCard(),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                              Icons.repeat,
                              Icons.repeat_one,
                              Icons.shuffle,
                            ];
                            final labels = ["顺序播放", "歌单循环", "单曲循环", "随机播放"];
                            final index = shuffleModeEnabled
                                ? 3
                                : LoopMode.values.indexOf(loopMode);

                            return IconButton(
                              icon: Icon(
                                shuffleModeEnabled
                                    ? Icons.shuffle
                                    : icons[index],
                                size: 20,
                              ),
                              tooltip: labels[index],
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
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(labels[idx]),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
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
                            return IconButton(
                              icon: Icon(_isFavorite == true
                                  ? Icons.favorite
                                  : Icons.favorite_border),
                              onPressed: src == null
                                  ? null
                                  : () async {
                                      final bs = await BilibiliService.instance;
                                      final uid = bs.myInfo?.mid ?? 0;
                                      final favs = await bs.getFavs(uid,
                                          rid: src.tag.extras['aid']);
                                      if (favs == null || favs.isEmpty) return;

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
                                                    aid:
                                                        src.tag.extras['aid']));
                                        if (result == null) return;
                                        final toAdd = result['toAdd'];
                                        final toRemove = result['toRemove'];
                                        if (toAdd.isEmpty && toRemove.isEmpty)
                                          return;

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
                        StreamBuilder<SequenceState?>(
                          stream: audioService.player.sequenceStateStream,
                          builder: (_, __) {
                            return _previousButton(audioService.player);
                          },
                        ),
                        StreamBuilder<PlayerState>(
                          stream: audioService.player.playerStateStream,
                          builder: (_, snapshot) {
                            final playerState = snapshot.data;
                            return _playPauseButton(
                                playerState, audioService.player);
                          },
                        ),
                        StreamBuilder<SequenceState?>(
                          stream: audioService.player.sequenceStateStream,
                          builder: (_, __) {
                            return _nextButton(audioService.player);
                          },
                        ),
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
                        StreamBuilder<SequenceState?>(
                          stream: audioService.player.sequenceStateStream,
                          builder: (context, snapshot) {
                            final src = snapshot.data?.currentSource;
                            return IconButton(
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
                                      ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }));
  }
}
