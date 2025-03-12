import 'package:audio_service/audio_service.dart';
import 'package:bmsc/service/audio_service.dart' as app_audio;
import 'package:just_audio/just_audio.dart';

/// An [AudioHandler] implementation that uses the app's existing AudioService
/// to control playback and expose its state through the audio_service plugin.
class BmscAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final app_audio.AudioService _audioService;

  BmscAudioHandler(this._audioService) {
    // Forward playback events from the app's AudioService to the audio_service plugin
    _listenToPlaybackEvents();

    // Initialize the queue and media item
    _updateQueue();
    _updateMediaItem();
  }

  void _listenToPlaybackEvents() {
    // Listen to player state changes
    _audioService.player.playerStateStream.listen((playerState) {
      _updatePlaybackState(playerState);
    });

    // Listen to current index changes to update the media item
    _audioService.player.currentIndexStream.listen((_) {
      _updateMediaItem();
    });

    // Listen to sequence state changes to update the queue
    _audioService.player.sequenceStateStream.listen((_) {
      _updateQueue();
    });

    _audioService.player.positionStream.listen((duration) {
      playbackState.add(playbackState.value.copyWith(
          updatePosition: duration,
          bufferedPosition: _audioService.player.bufferedPosition));
    });
  }

  void _updatePlaybackState(PlayerState playerState) {
    final playing = playerState.playing;
    final processingState = {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[playerState.processingState] ??
        AudioProcessingState.idle;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _audioService.player.position,
      bufferedPosition: _audioService.player.bufferedPosition,
      speed: _audioService.currentSpeed,
      queueIndex: _audioService.player.currentIndex,
    ));
  }

  void _updateMediaItem() {
    final currentIndex = _audioService.player.currentIndex;
    if (currentIndex == null) return;

    if (currentIndex >= _audioService.playlist.length) return;

    final currentSource = _audioService.playlist.sequence[currentIndex];
    if (currentSource.tag is MediaItem) {
      mediaItem.add(currentSource.tag as MediaItem);
    }
  }

  void _updateQueue() {
    final sequence = _audioService.playlist.sequence;
    if (sequence.isEmpty) return;

    final items = sequence.map((source) => source.tag as MediaItem).toList();

    queue.add(items);
  }

  @override
  Future<void> play() => _audioService.player.play();

  @override
  Future<void> pause() => _audioService.player.pause();

  @override
  Future<void> seek(Duration position) => _audioService.player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) =>
      _audioService.player.seek(Duration.zero, index: index);

  @override
  Future<void> skipToNext() => _audioService.player.seekToNext();

  @override
  Future<void> skipToPrevious() => _audioService.player.seekToPrevious();

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _audioService.player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _audioService.player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        await _audioService.player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _audioService.player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> stop() async {
    await _audioService.player.stop();
    await super.stop();
  }

  @override
  Future<void> setSpeed(double speed) => _audioService.setPlaybackSpeed(speed);
}
