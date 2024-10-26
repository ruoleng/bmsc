import 'package:bmsc/screen/detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../globals.dart' as globals;
import '../util/audio.dart';
import 'package:cached_network_image/cached_network_image.dart';

Widget udn(Widget child) {
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
      child: udn(ReorderableListView.builder(
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
                    DecoratedBox(
                        decoration: BoxDecoration(
                            color: songs[index].extras['cached'] ? Colors.green : Colors.red,
                            borderRadius: const BorderRadius.all(Radius.circular(2))),
                        child: Padding(
                          padding: const EdgeInsets.all(1.0),
                          child: Text(
                            songs[index].extras['cached'] ? '已缓存' : '未缓存',
                            style: const TextStyle(
                                fontSize: 7, color: Colors.white),
                          ),
                        )),
                    const SizedBox(
                      width: 5,
                    ),
                    DecoratedBox(
                        decoration: const BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.all(Radius.circular(2))),
                        child: Padding(
                          padding: const EdgeInsets.all(1.0),
                          child: Text(
                            audioQuality(songs[index].extras['quality']),
                            style: const TextStyle(
                                fontSize: 7, color: Colors.white),
                          ),
                        )),
                    const SizedBox(
                      width: 5,
                    ),
                    const Icon(Icons.person_outline, size: 12),
                    Text(
                      songs[index].artist,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 1,
                    ),
                    const Spacer(),
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

Widget playCard(BuildContext context) {
  return udn(
    ExpansionTile(
        controlAffinity: ListTileControlAffinity.leading,
        tilePadding: const EdgeInsets.only(left: 10),
        shape: const Border(bottom: BorderSide(width: 2, color: Colors.black)),
        leading: const Icon(Icons.expand_more),
        title: udn(InkWell(
            onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<Widget>(builder: (BuildContext context) {
                    return const DetailScreen();
                  }),
                ),
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
                              stream: globals.api.player.sequenceStateStream,
                              builder: (_, snapshot) {
                                final src = snapshot.data?.currentSource;
                                return CachedNetworkImage(
                                  imageUrl: src?.tag.artUri.toString() ?? "",
                                  placeholder: (context, url) => const Icon(Icons.music_note),
                                  errorWidget: (context, url, error) => const Icon(Icons.music_note),
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
          udn(Row(
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
