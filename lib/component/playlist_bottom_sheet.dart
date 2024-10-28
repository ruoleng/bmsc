import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../globals.dart' as globals;

class PlaylistBottomSheet extends StatelessWidget {
  const PlaylistBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with loop mode control
        ListTile(
          title: StreamBuilder<List<IndexedAudioSource>?>(
            stream: globals.api.player.sequenceStream,
            builder: (_, snapshot) {
              return Row(
                children: [
                  SizedBox(width: 10),
                  Text(
                    "播放列表 (${snapshot.data?.length ?? 0})",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              );
            },
          ),
          trailing: StreamBuilder<LoopMode>(
            stream: globals.api.player.loopModeStream,
            builder: (context, snapshot) {
              final loopMode = snapshot.data ?? LoopMode.off;
              final icons = [Icons.playlist_play, Icons.repeat, Icons.repeat_one, Icons.radio];
              final labels = ["顺序播放", "歌单循环", "单曲循环", "漫步模式"];
              final cycleModes = [LoopMode.off, LoopMode.all, LoopMode.one, LoopMode.off];
              final index = globals.api.recommendationMode ? 3 : cycleModes.indexOf(loopMode);
              
              return IconButton(
                icon: Icon(icons[index], size: 20),
                tooltip: labels[index],
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  final nextIndex = (index + 1) % cycleModes.length;
                  if (nextIndex == 3) {
                    globals.api.player.setLoopMode(LoopMode.off);
                    globals.api.enableRecommendationMode();
                  } else {
                    globals.api.player.setLoopMode(cycleModes[nextIndex]);
                    globals.api.disableRecommendationMode();
                  }
                  
                },
              );
            },
          ),
        ),

        // Playlist
        Flexible(
          child: StreamBuilder<List<IndexedAudioSource>?>(
            stream: globals.api.player.sequenceStream,
            builder: (_, snapshot) {
              final playlist = snapshot.data;
              if (playlist == null || playlist.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无歌曲'),
                );
              }

              return ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: playlist.length,
                onReorder: (oldIndex, newIndex) async {
                  if (oldIndex < newIndex) newIndex--;
                  await globals.api.playlist.move(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                 final item = playlist[index].tag;
                        return StreamBuilder<SequenceState?>(
                          key: Key(item.id),
                          stream: globals.api.player.sequenceStateStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data?.currentIndex == index;
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -2),
                              contentPadding: const EdgeInsets.only(left: 16, right: 8),
                              minLeadingWidth: 24,
                              leading: isPlaying 
                                ? Icon(Icons.play_arrow, 
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20)
                                : Text('${index + 1}',
                                    style: Theme.of(context).textTheme.bodySmall),
                              title: Text(
                                item.title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isPlaying 
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                item.artist,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.extras['isRecommendation'] ?? false)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Chip(
                                        label: const Text('推'),
                                        labelStyle: Theme.of(context).textTheme.labelSmall,
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  if (item.extras['cached'] ?? false)
                                    Icon(Icons.check_circle,
                                      size: 16,
                                      color: Colors.green),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () => globals.api.playlist.removeAt(index),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle, size: 24),
                                  ),
                                ],
                              ),
                              onTap: () {
                                globals.api.player.seek(Duration.zero, index: index);
                              },
                            );
                          }
                        );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
