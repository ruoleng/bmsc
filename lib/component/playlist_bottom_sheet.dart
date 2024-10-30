import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../cache_manager.dart';
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
                  )
                ],
              );
            },
          ),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.playlist_remove, size: 20),
                  tooltip: '清空',
                  onPressed: () {
                    if (globals.api.playlist.length == 0) {
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('清空播放列表'),
                        content: const Text('确定要清空播放列表吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () {
                              globals.api.doAndSave(() async {
                                await globals.api.playlist.clear();
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                StreamBuilder<LoopMode>(
                  stream: globals.api.player.loopModeStream,
                  builder: (context, snapshot) {
                    final loopMode = snapshot.data ?? LoopMode.off;
                    final icons = [Icons.playlist_play, Icons.repeat, Icons.repeat_one];
                    final labels = ["顺序播放", "歌单循环", "单曲循环"];
                    final cycleModes = [LoopMode.off, LoopMode.all, LoopMode.one];
                    final index = cycleModes.indexOf(loopMode);
                    
                    return IconButton(
                      icon: Icon(icons[index], size: 20),
                      tooltip: labels[index],
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        final nextIndex = (index + 1) % cycleModes.length;
                        globals.api.player.setLoopMode(cycleModes[nextIndex]);
                      },
                    );
                  },
                ),
              ],
            ),
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
                  await globals.api.doAndSave(() async {
                    await globals.api.playlist.move(oldIndex, newIndex);
                  });
                },
                itemBuilder: (context, index) {
                 final item = playlist[index].tag;
                        return StreamBuilder<SequenceState?>(
                          // Change the key to include the index to make it unique
                          key: ValueKey('${item.id}_$index'),
                          stream: globals.api.player.sequenceStateStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data?.currentIndex == index;
                            if (isPlaying) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Scrollable.ensureVisible(
                                  context,
                                  alignment: 0.2,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              });
                            }
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -2),
                              contentPadding: const EdgeInsets.only(left: 16, right: 8),
                              minLeadingWidth: 24,
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  isPlaying 
                                    ? Icon(Icons.play_arrow, 
                                        color: Theme.of(context).colorScheme.primary,
                                    size: 20)
                                    : Text('${index + 1}',
                                        style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Flexible( // Added Flexible widget here
                                    child: Text(
                                      item.title,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isPlaying 
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (item.extras['cached'] ?? false)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.check_circle,
                                        size: 16,
                                        color: Color(0xFF66BB6A)),
                                    ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  
                                  if (item.extras['multi'] ?? false) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(Icons.album, size: 12),
                                    ),
                                    Flexible(
                                      child: Text(
                                        item.extras['raw_title'] as String,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ] else
                                    Flexible(
                                      child: Text(
                                        item.artist ?? '',
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.extras['multi'] ?? false)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: InkWell(
                                        onTap: () {
                                          CacheManager.addExcludedPart(item.extras['bvid'] as String, item.extras['cid'] as int);
                                          globals.api.doAndSave(() async {
                                            await globals.api.playlist.removeAt(index);
                                          });
                                        },
                                        child: const Icon(Icons.not_interested, size: 20),
                                      ),
                                    ),
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () {
                                        globals.api.doAndSave(() async {
                                          await globals.api.playlist.removeAt(index);
                                        });
                                      },
                                      child: const Icon(Icons.delete, size: 20),
                                    ),
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
