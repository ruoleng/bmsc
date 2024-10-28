import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:bmsc/api.dart';
import 'package:bmsc/screen/user_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../component/playing_card.dart';
import '../globals.dart' as globals;
import '../util/widget.dart';
import 'package:cached_network_image/cached_network_image.dart';


class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key});

  @override
  State<StatefulWidget> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool? _isFavorite;
  int? _currentAid;
  Map<int, bool> _pendingFavStates = {};

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
    final isFavorited = await globals.api.isFavorited(aid);
    if (!mounted) return;
    setState(() => _isFavorite = isFavorited);
  }

  Widget progressIndicator(Duration? dur) {
    return LinearProgressIndicator(
        value: (dur?.inSeconds ?? 0) /
            (globals.api.player.duration?.inSeconds ?? 1));
  }

  Widget _previousButton() {
    return IconButton(
      icon: const Icon(Icons.skip_previous),
      onPressed: globals.api.player.hasPrevious
          ? globals.api.player.seekToPrevious
          : null,
    );
  }

  Widget _nextButton() {
    return IconButton(
      icon: const Icon(Icons.skip_next),
      onPressed:
          globals.api.player.hasNext ? globals.api.player.seekToNext : null,
    );
  }

  Widget _playPauseButton(PlayerState? playerState) {
    final processingState = playerState?.processingState;
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.more_horiz_sharp,
            size: 40,
          ));
    } else if (globals.api.player.playing != true) {
      return IconButton(
        icon: const Icon(
          Icons.play_arrow,
          size: 40,
        ),
        onPressed: globals.api.player.play,
      );
    } else if (processingState != ProcessingState.completed) {
      return IconButton(
        icon: const Icon(
          Icons.pause,
          size: 40,
        ),
        onPressed: globals.api.player.pause,
      );
    } else {
      return IconButton(
        icon: const Icon(
          Icons.replay,
          size: 40,
        ),
        onPressed: () => globals.api.player.seek(Duration.zero,
            index: globals.api.player.effectiveIndices!.first),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('正在播放'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<SequenceState?>(
                stream: globals.api.player.sequenceStateStream,
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
                                placeholder: (context, url) => const Icon(Icons.music_note),
                                errorWidget: (context, url, error) => const Icon(Icons.music_note),
                              )),
                        ));
                },
              ),
              StreamBuilder<SequenceState?>(
                stream: globals.api.player.sequenceStateStream,
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
                stream: globals.api.player.sequenceStateStream,
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
                                        mid: src.tag.extras['mid'],
                                      ),
                                      bottomNavigationBar:
                                          StreamBuilder<SequenceState?>(
                                        stream: globals
                                            .api.player.sequenceStateStream,
                                        builder: (_, snapshot) {
                                          final src = snapshot.data?.sequence;
                                          return (src == null || src.isEmpty)
                                              ? const SizedBox()
                                              : PlayingCard();
                                        },
                                      ));
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
                  child: StreamBuilder<DurationState>(
                    stream: globals.api.durationState,
                    builder: (context, snapshot) {
                      final durationState = snapshot.data;
                      final progress = durationState?.progress ?? Duration.zero;
                      final buffered = durationState?.buffered ?? Duration.zero;
                      final total = durationState?.total ?? Duration.zero;
                      return ProgressBar(
                        progress: progress,
                        buffered: buffered,
                        total: total,
                        onSeek: globals.api.player.seek,
                        timeLabelTextStyle:
                            const TextStyle(color: Colors.black, fontSize: 10),
                        timeLabelPadding: 5,
                        thumbRadius: 5,
                      );
                    },
                  )),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StreamBuilder<SequenceState?>(
                    stream: globals.api.player.sequenceStateStream,
                    builder: (_, __) {
                      return _previousButton();
                    },
                  ),
                  StreamBuilder<PlayerState>(
                    stream: globals.api.player.playerStateStream,
                    builder: (_, snapshot) {
                      final playerState = snapshot.data;
                      return _playPauseButton(playerState);
                    },
                  ),
                  StreamBuilder<SequenceState?>(
                    stream: globals.api.player.sequenceStateStream,
                    builder: (_, __) {
                      return _nextButton();
                    },
                  ),
                  StreamBuilder<SequenceState?>(
                    stream: globals.api.player.sequenceStateStream,
                    builder: (context, snapshot) {
                      final src = snapshot.data?.currentSource;
                      if (src?.tag.extras['aid'] != _currentAid) {
                        _currentAid = src?.tag.extras['aid'];
                        Future.microtask(() => _checkFavoriteStatus(_currentAid));
                      }
                      return IconButton(
                        icon: Icon(
                          _isFavorite == true ? Icons.favorite : Icons.favorite_border
                        ),
                        onPressed: src == null ? null : () async {
                          final uid = await globals.api.getStoredUID() ?? 0;
                          final favs = await globals.api.getFavs(uid, rid: src.tag.extras['aid']);
                          if (favs == null || favs.list.isEmpty) return;

                          final defaultFolderId = await globals.api.getDefaultFavFolder();
                          
                          if (!_isFavorite! && defaultFolderId != null) {
                            final success = await globals.api.favoriteVideo(
                              src.tag.extras['aid'],
                              [defaultFolderId['id']],
                              [],
                            );
                            if (!context.mounted) return;
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? '已添加到收藏夹 ${defaultFolderId['name']}' : '收藏失败'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            if (success) {
                              Future.microtask(() =>
                                setState(() => _isFavorite = success));
                            }
                          } else {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('选择收藏夹'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: StatefulBuilder(  // Add StatefulBuilder to manage checkbox states
                                      builder: (context, setDialogState) {
                                        return ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: favs.list.length,
                                          itemBuilder: (context, index) {
                                            final folder = favs.list[index];
                                            // Use pending state if exists, otherwise use original state
                                            final isSelected = _pendingFavStates.containsKey(folder.id) 
                                                ? _pendingFavStates[folder.id]! 
                                                : folder.favState == 1;
                                            return FutureBuilder<Map<String, dynamic>?>(
                                              future: globals.api.getDefaultFavFolder(),
                                              builder: (context, snapshot) {
                                                final isDefault = snapshot.data != null && 
                                                    snapshot.data!['id'] == folder.id;
                                                return CheckboxListTile(
                                                  title: Row(
                                                    children: [
                                                      Text(folder.title),
                                                      if (isDefault) 
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 8.0),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.primaryContainer,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              '默认',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  value: isSelected,
                                                  onChanged: (value) {
                                                    setDialogState(() {
                                                      _pendingFavStates[folder.id] = value!;
                                                    });
                                                  },
                                                );
                                              }
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _pendingFavStates.clear();  // Clear pending changes on cancel
                                      },
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        // Store the scaffold context before closing dialog
                                        final scaffoldContext = context;
                                        Navigator.of(context).pop();
                                        
                                        final toAdd = <int>[];
                                        final toRemove = <int>[];
                                        
                                        _pendingFavStates.forEach((folderId, newState) {
                                          final originalState = favs.list
                                              .firstWhere((f) => f.id == folderId)
                                              .favState == 1;
                                          
                                          if (newState != originalState) {
                                            if (newState) {
                                              toAdd.add(folderId);
                                            } else {
                                              toRemove.add(folderId);
                                            }
                                          }
                                        });
                                        
                                        if (toAdd.isEmpty && toRemove.isEmpty) return;
                                        
                                        final success = await globals.api.favoriteVideo(
                                          src.tag.extras['aid'],
                                          toAdd,
                                          toRemove,
                                        );
                                        
                                        if (!mounted) return;
                                        
                                        if (success) {
                                          if (toAdd.isNotEmpty) {
                                            await globals.api.setDefaultFavFolder(toAdd.first, favs.list.firstWhere((f) => f.id == toAdd.first).title);
                                            Future.microtask(() => setState(() { 
                                              _isFavorite = true;
                                            }));
                                          } else {
                                            _checkFavoriteStatus(src.tag.extras['aid']);
                                          }
                                          
                                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                            const SnackBar(
                                              content: Text('收藏夹已更新'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        } else {
                                          _checkFavoriteStatus(src.tag.extras['aid']);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('操作失败'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                        
                                        _pendingFavStates.clear();  // Clear pending changes after applying
                                      },
                                      child: const Text('确定'),
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ));
  }
}
