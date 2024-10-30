import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../globals.dart' as globals;
import '../screen/detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'playlist_bottom_sheet.dart';
class PlayingCard extends StatelessWidget {
  const PlayingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      elevation: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini Player
          StreamBuilder<SequenceState?>(
            stream: globals.api.player.sequenceStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              if (state?.sequence.isEmpty ?? true) return const SizedBox.shrink();
              final artUri = state?.currentSource?.tag.artUri.toString() ?? "";
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  StreamBuilder<Duration>(
                    stream: globals.api.player.positionStream,
                    builder: (context, snapshot) {
                      return ProgressBar(
                        progress: snapshot.data ?? Duration.zero,
                        total: globals.api.player.duration ?? Duration.zero,
                        onSeek: globals.api.player.seek,
                        barHeight: 2,
                        baseBarColor: Colors.grey[300],
                        progressBarColor: Theme.of(context).colorScheme.primary,
                        thumbRadius: 0,
                        timeLabelLocation: TimeLabelLocation.none,
                      );
                    },
                  ),

                  // Main content
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DetailScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          // Album art
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: artUri == "" ? Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.music_note,
                                    color: Theme.of(context).colorScheme.primary),
                              ) :  CachedNetworkImage(
                                imageUrl: artUri,
                                placeholder: (context, url) => Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.music_note,
                                      color: Theme.of(context).colorScheme.primary),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.music_note,
                                      color: Theme.of(context).colorScheme.primary),
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Title and artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  state?.currentSource?.tag.title ?? "",
                                  style: Theme.of(context).textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  state?.currentSource?.tag.artist ?? "",
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          
                          // Controls
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous),
                                onPressed: globals.api.player.hasPrevious ? globals.api.player.seekToPrevious : null,
                              ),
                              StreamBuilder<PlayerState>(
                                stream: globals.api.player.playerStateStream,
                                builder: (context, snapshot) {
                                  final playing = globals.api.player.playing;
                                  final processingState = snapshot.data?.processingState;
                                  
                                  if (processingState == ProcessingState.loading ||
                                      processingState == ProcessingState.buffering) {
                                    return const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    );
                                  }
                                  
                                  return IconButton(
                                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                                    onPressed: playing ? globals.api.player.pause : globals.api.player.play,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next),
                                onPressed: globals.api.player.hasNext ? globals.api.player.seekToNext : null,
                              ),
                              // Add playlist button
                              IconButton(
                                icon: const Icon(Icons.queue_music),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => const PlaylistBottomSheet(),
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                    isScrollControlled: true,
                                    constraints: BoxConstraints(
                                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
