import 'package:audio_session/audio_session.dart';
import 'package:bmsc/database_manager.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:bmsc/service/shared_preferences_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:bmsc/util/logger.dart';
import 'package:rxdart/rxdart.dart';

final _logger = LoggerUtils.getLogger('AudioService');

class AudioService {
  static final instance = _init();

  final playlist = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: [],
  );
  final player = AudioPlayer();
  late AudioSession session;

  static Future<AudioService> _init() async {
    final x = AudioService();
    try {
      final restored = await SharedPreferencesService.getPlaylist();
      if (restored != null) {
        await x.playlist.addAll(restored.$1);
      }
      await x.player.setAudioSource(x.playlist);
      if (restored != null && restored.$2 < x.playlist.length) {
        await x.player.seek(null, index: restored.$2);
      }
      await x.restorePlayMode();
    } catch (e) {
      _logger.severe('Failed to restore playlist', e);
    }
    x.session = await AudioSession.instance;
    await x.session.configure(const AudioSessionConfiguration.music());
    await x.hookEvents();
    return x;
  }

  Future<void> restorePlayMode() async {
    final mode = await SharedPreferencesService.getPlayMode();
    if (mode == 3) {
      await player.setLoopMode(LoopMode.all);
      await player.setShuffleModeEnabled(true);
    } else {
      await player.setLoopMode(LoopMode.values[mode]);
      await player.setShuffleModeEnabled(false);
    }
  }

  Future<void> hookEvents() async {
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        player.pause();
      }
    });
    session.becomingNoisyEventStream.listen((_) {
      player.pause();
    });

    Rx.combineLatest2(player.loopModeStream, player.shuffleModeEnabledStream,
        (a, b) => (a, b)).listen((data) async {
      final (loopMode, shuffleModeEnabled) = data;

      if (shuffleModeEnabled) {
        await SharedPreferencesService.setPlayMode(3);
      } else {
        await SharedPreferencesService.setPlayMode(
            LoopMode.values.indexOf(loopMode));
      }
    });

    player.currentIndexStream.listen((index) async {
      if (index != null) {
        final prefs = await SharedPreferencesService.instance;
        await prefs.setInt('currentIndex', index);
        if (player.playing) {
          _logger
              .info('currentIndexStream hijack dummy source for index: $index');
          await _hijackDummySource(index: index);
          _logger.info('currentIndexStream hijack done');
        }
      }
    });

    player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.ready) {
        final index = player.currentIndex;
        if (index == null) {
          return;
        }
        if (state.playing == false) {
          return;
        }
        _logger.info('processing state hijack dummy source for index: $index');
        await _hijackDummySource(index: index);
        _logger.info('processing state hijack done');
      }
    });
  }

  Future<void> _hijackDummySource({int? index}) async {
    index ??= player.currentIndex;
    if (index == null) {
      _logger.warning('No current index available for hijacking');
      return;
    }

    final currentSource = playlist.sequence[index];

    final extras = currentSource.tag.extras;
    if (extras == null) {
      return;
    }
    if (extras['dummy'] != true) {
      if (extras['bvid'] != null && extras['cid'] != null) {
        await DatabaseManager.updatePlayStats(extras['bvid'], extras['cid']);
        _logger.info(
            'update play stats for bvid: ${extras['bvid']} cid: ${extras['cid']}');
      }
      return;
    }
    _logger.info('Hijacking dummy source for index: $index');

    await player.pause();
    List<IndexedAudioSource>? srcs;
    try {
      srcs = await (await BilibiliService.instance)
          .getAudios(currentSource.tag.id);
    } catch (e) {
      _logger.warning('Failed to get audio sources: $e');
      srcs = await DatabaseManager.getLocalAudioList(currentSource.tag.id);
    }
    final excludedCids =
        await DatabaseManager.getExcludedParts(currentSource.tag.id);
    for (var cid in excludedCids) {
      srcs?.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }
    if (srcs == null) {
      _logger
          .warning('No audio sources found for BVID: ${currentSource.tag.id}');
      if (player.loopMode != LoopMode.one &&
          player.currentIndex != null &&
          player.currentIndex! < playlist.length - 1) {
        await player.seekToNext();
        await player.play();
      }
      return;
    }
    await doAndSavePlaylist(() async {
      await playlist.insertAll(index! + 1, srcs!);
      await playlist.removeAt(index);
    });
    await player.play();
  }

  Future<void> playByBvid(String bvid) async {
    _logger.info('Playing by BVID: $bvid');
    await player.pause();
    final srcs = await (await BilibiliService.instance).getAudios(bvid);
    if (srcs == null) {
      _logger.warning('No audio sources found for BVID: $bvid');
      return;
    }
    final excludedCids = await DatabaseManager.getExcludedParts(bvid);
    for (var cid in excludedCids) {
      srcs.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }

    final idx = await _addUniqueSourcesToPlaylist(srcs,
        insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);
    if (idx != null) {
      await player.seek(Duration.zero, index: idx);
    }
    await player.play();
  }

  Future<void> playByBvids(List<String> bvids, {int index = 0}) async {
    if (bvids.isEmpty) {
      return;
    }
    final metas = await DatabaseManager.getMetas(bvids);
    final silenceUri = Uri(scheme: 'asset', path: '/assets/silent.m4a');
    final srcs = await Future.wait(metas.map((x) async {
      _logger.info('uri: ${x.artUri}');
      return AudioSource.uri(silenceUri,
          tag: MediaItem(
              id: x.bvid,
              title: x.title,
              // http://i0.hdslb.com/bfs/archive/32ddc1acc1cba622cbcd789ff7e0b91bcf0097fe.jpg
              artUri: Uri.http(x.artUri.substring(7, 19), x.artUri.substring(19)),
              artist: x.artist,
              extras: {'dummy': true}));
    }).toList());
    await player.stop();
    await doAndSavePlaylist(() async {
      await playlist.clear();
      await playlist.addAll(srcs);
    });
    await player.seek(Duration.zero, index: index);
    await player.play();
    _logger.info('playByBvids done');
  }

  Future<void> playLocalAudio(String bvid, int cid) async {
    await player.pause();
    final cachedSource = await DatabaseManager.getLocalAudio(bvid, cid);
    if (cachedSource == null) {
      return;
    }
    final idx = await _addUniqueSourcesToPlaylist([cachedSource],
        insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);

    if (idx != null) {
      await player.seek(Duration.zero, index: idx);
    }
    await player.play();
  }

  Future<void> addToPlaylistCachedAudio(String bvid, int cid) async {
    final cachedSource = await DatabaseManager.getLocalAudio(bvid, cid);
    if (cachedSource == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist([cachedSource],
        insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);
  }

  Future<void> appendPlaylist(String bvid,
      {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    final srcs = await (await BilibiliService.instance).getAudios(bvid);
    final excludedCids = await DatabaseManager.getExcludedParts(bvid);
    for (var cid in excludedCids) {
      srcs?.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }
    if (srcs == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist(srcs,
        insertIndex: insertIndex, extraExtras: extraExtras);
  }

  Future<void> appendCachedPlaylist(String bvid,
      {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    final srcs = await DatabaseManager.getLocalAudioList(bvid);
    final excludedCids = await DatabaseManager.getExcludedParts(bvid);
    for (var cid in excludedCids) {
      srcs?.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }
    if (srcs == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist(srcs,
        insertIndex: insertIndex, extraExtras: extraExtras);
  }

  Future<void> doAndSavePlaylist(Future<void> Function() func) async {
    await func();
    SharedPreferencesService.savePlaylist(playlist, player);
  }

  Future<int?> _addUniqueSourcesToPlaylist(List<IndexedAudioSource> sources,
      {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    int? ret;
    for (var source in sources) {
      if (source.tag is MediaItem) {
        var mediaItem = source.tag as MediaItem;
        var duplicatePos = playlist.children.indexWhere((child) {
          if (child is IndexedAudioSource && child.tag is MediaItem) {
            return (child.tag as MediaItem).id == mediaItem.id;
          }
          return false;
        });

        if (duplicatePos == -1) {
          if (extraExtras != null) {
            mediaItem.extras?.addAll(extraExtras);
          }
          if (insertIndex != null) {
            await doAndSavePlaylist(() async {
              await playlist.insert(insertIndex!, source);
            });
            ret ??= insertIndex;
            insertIndex++;
          } else {
            await doAndSavePlaylist(() async {
              await playlist.add(source);
            });
            ret ??= playlist.length - 1;
          }
        } else {
          ret = duplicatePos;
        }
      }
    }
    return ret;
  }
}
