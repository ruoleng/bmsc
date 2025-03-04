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

  // 判断是否为小屏幕设备的辅助方法
  bool _isSmallScreen(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    
    // 打印设备信息，帮助调试
    print('Screen size: $screenWidth x $screenHeight, Pixel ratio: $devicePixelRatio');
    
    // 使用更宽松的条件来判断小屏幕
    // 对于720x1280的xhdpi设备，逻辑分辨率约为360x640，像素比约为2.0
    // 我们将条件放宽，确保这类设备被识别为小屏幕
    return screenWidth <= 400 || screenHeight <= 720;
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
          _buildShareButton(),
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
                constraints: const BoxConstraints(
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

  Widget _buildShareButton() {
    return FutureBuilder<AudioService>(
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
                      final url = 'https://www.bilibili.com/video/$bvid';
                      Share.share(
                        '$title\n$url',
                        subject: title,
                      );
                    },
            );
          },
        );
      },
    );
  }

  Widget _buildPortraitLayout(BuildContext context, AudioService audioService) {
    // 使用辅助方法判断小屏幕
    final isSmallScreen = _isSmallScreen(context);
    
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCoverImage(audioService),
          _buildTitleAndArtist(audioService, context),
          // 根据屏幕大小调整间距
          SizedBox(height: isSmallScreen ? 10 : 30),
          _buildProgressBar(audioService, context),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8.0 : 16.0),
            child: Column(
              children: [
                _buildPlaybackControls(audioService, context),
                SizedBox(height: isSmallScreen ? 8 : 16),
                _buildTransportControls(audioService),
                SizedBox(height: isSmallScreen ? 8 : 16),
                _buildAdditionalControls(audioService, context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, AudioService audioService) {
    // 使用辅助方法判断小屏幕
    final isSmallScreen = _isSmallScreen(context);
    
    return Row(children: [
      Expanded(
        flex: 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCoverImage(audioService),
            _buildTitleAndArtist(audioService, context),
          ],
        ),
      ),
      Expanded(
        flex: 1,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressBar(audioService, context),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8.0 : 16.0),
                  child: Column(
                    children: [
                      _buildPlaybackControls(audioService, context),
                      SizedBox(height: isSmallScreen ? 8 : 16),
                      _buildTransportControls(audioService),
                      SizedBox(height: isSmallScreen ? 8 : 16),
                      _buildAdditionalControls(audioService, context),
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

  Widget _buildCoverImage(AudioService audioService) {
    return StreamBuilder<SequenceState?>(
      stream: audioService.player.sequenceStateStream,
      builder: (context, snapshot) {
        final src = snapshot.data?.currentSource;
        // 获取屏幕宽度
        final screenWidth = MediaQuery.of(context).size.width;
        // 使用辅助方法判断小屏幕
        final isSmallScreen = _isSmallScreen(context);
        // 根据屏幕宽度计算图片尺寸，小屏幕上显示更小的图片
        final imageSize = isSmallScreen ? 
            Size(screenWidth * 0.7, screenWidth * 0.4) : 
            Size(355.5, 200);
            
        return src == null
            ? SizedBox(
                height: imageSize.height,
                width: imageSize.width,
                child: const Center(
                  child: Icon(Icons.question_mark, size: 50),
                ),
              )
            : shadow(ClipRRect(
                borderRadius: BorderRadius.circular(5.0),
                child: SizedBox(
                    height: imageSize.height,
                    width: imageSize.width,
                    child: CachedNetworkImage(
                      imageUrl: src.tag.artUri.toString(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Icon(Icons.music_note),
                      errorWidget: (context, url, error) => const Icon(Icons.music_note),
                    )),
              ));
      },
    );
  }

  Widget _buildTitleAndArtist(AudioService audioService, BuildContext context) {
    // 使用辅助方法判断小屏幕
    final isSmallScreen = _isSmallScreen(context);
    
    return Column(
      children: [
        StreamBuilder<SequenceState?>(
          stream: audioService.player.sequenceStateStream,
          builder: (_, snapshot) {
            final src = snapshot.data?.currentSource;
            return Padding(
              padding: EdgeInsets.only(
                top: isSmallScreen ? 8 : 16, 
                left: isSmallScreen ? 8 : 16, 
                right: isSmallScreen ? 8 : 16, 
                bottom: isSmallScreen ? 4 : 8
              ),
              child: Text(
                src?.tag.title ?? "",
                style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
                softWrap: true,
                textAlign: TextAlign.center,
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
                  ? null
                  : Navigator.pushReplacement(context, MaterialPageRoute<Widget>(
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
                      },
                    )),
              child: Text(
                src?.tag.artist ?? "",
                style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                softWrap: false,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressBar(AudioService audioService, BuildContext context) {
    // 使用辅助方法判断小屏幕
    final isSmallScreen = _isSmallScreen(context);
    
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : 20.0),
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
                color: Theme.of(context).colorScheme.primary, fontSize: 10),
            timeLabelPadding: 5,
            thumbRadius: 5,
          );
        },
      ),
    );
  }

  Widget _buildPlaybackControls(AudioService audioService, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPlaybackModeButton(audioService, context),
        _buildFavoriteButton(audioService, context),
      ],
    );
  }

  Widget _buildPlaybackModeButton(AudioService audioService, BuildContext context) {
    return StreamBuilder<(LoopMode, bool)>(
      stream: Rx.combineLatest2(
        audioService.player.loopModeStream,
        audioService.player.shuffleModeEnabledStream,
        (a, b) => (a, b),
      ),
      builder: (context, snapshot) {
        final (loopMode, shuffleModeEnabled) = snapshot.data ?? (LoopMode.off, false);
        final icons = [
          Icons.playlist_play,
          Icons.repeat_one,
          Icons.repeat,
          Icons.shuffle,
        ];
        final labels = ["顺序播放", "单曲循环", "歌单循环", "随机播放"];
        final index = shuffleModeEnabled ? 3 : LoopMode.values.indexOf(loopMode);

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
              audioService.player.setLoopMode(LoopMode.values[idx]);
              audioService.player.setShuffleModeEnabled(false);
            }
          },
        );
      },
    );
  }

  Widget _buildFavoriteButton(AudioService audioService, BuildContext context) {
    return StreamBuilder<SequenceState?>(
      stream: audioService.player.sequenceStateStream,
      builder: (context, snapshot) {
        final src = snapshot.data?.currentSource;
        if (src?.tag.extras['aid'] != _currentAid) {
          _currentAid = src?.tag.extras['aid'];
          Future.microtask(() => _checkFavoriteStatus(_currentAid));
        }
        return TextButton.icon(
          icon: Icon(
            _isFavorite == true ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: _isFavorite == true ? Colors.red : Theme.of(context).colorScheme.primary,
          ),
          label: Text(
            _isFavorite == true ? '已收藏' : '收藏',
            style: TextStyle(
              fontSize: 12,
              color: _isFavorite == true ? Colors.red : Theme.of(context).colorScheme.primary,
            ),
          ),
          onPressed: src == null ? null : () => _handleFavoriteAction(src, context),
        );
      },
    );
  }

  Future<void> _handleFavoriteAction(IndexedAudioSource src, BuildContext context) async {
    final bs = await BilibiliService.instance;
    final uid = bs.myInfo?.mid ?? 0;
    final favs = await bs.getFavs(uid, rid: src.tag.extras['aid']);
    if (favs == null || favs.isEmpty) {
      return;
    }

    final defaultFolderId = await SharedPreferencesService.getDefaultFavFolder();

    if (!_isFavorite! && defaultFolderId != null) {
      final success = await bs.favoriteVideo(
            src.tag.extras['aid'],
            [defaultFolderId.$1],
            [],
          ) ??
          false;
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已添加到收藏夹 ${defaultFolderId.$2}' : '收藏失败'),
          duration: const Duration(seconds: 2),
        ),
      );
      if (success) {
        Future.microtask(() => setState(() => _isFavorite = success));
      }
    } else {
      if (!context.mounted) return;
      final result = await showDialog(
          context: context,
          builder: (context) => SelectMultiFavlistDialog(aid: src.tag.extras['aid']));
      if (result == null) return;
      final toAdd = result['toAdd'];
      final toRemove = result['toRemove'];
      if (toAdd.isEmpty && toRemove.isEmpty) {
        return;
      }

      final success = await (await BilibiliService.instance).favoriteVideo(
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
          _checkFavoriteStatus(src.tag.extras['aid']);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('收藏夹已更新'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _checkFavoriteStatus(src.tag.extras['aid']);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('操作失败'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Widget _buildTransportControls(AudioService audioService) {
    // 使用辅助方法判断小屏幕
    final isSmallScreen = _isSmallScreen(context);
    final iconSize = isSmallScreen ? 30.0 : 36.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StreamBuilder<SequenceState?>(
          stream: audioService.player.sequenceStateStream,
          builder: (_, __) {
            return IconButton(
              icon: Icon(Icons.skip_previous, size: iconSize),
              onPressed: audioService.player.hasPrevious ? audioService.player.seekToPrevious : null,
            );
          },
        ),
        StreamBuilder<PlayerState>(
          stream: audioService.player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                child: _playPauseButton(playerState, audioService.player, context, isSmallScreen),
              ),
            );
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: audioService.player.sequenceStateStream,
          builder: (_, __) {
            return IconButton(
              icon: Icon(Icons.skip_next, size: iconSize),
              onPressed: audioService.player.hasNext ? audioService.player.seekToNext : null,
            );
          },
        ),
      ],
    );
  }

  Widget _playPauseButton(PlayerState? playerState, AudioPlayer player, BuildContext context, bool isSmallScreen) {
    final processingState = playerState?.processingState;
    final iconSize = isSmallScreen ? 34.0 : 40.0;
    
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.more_horiz_sharp,
            size: iconSize,
          ));
    } else if (player.playing != true) {
      return IconButton(
        icon: Icon(
          Icons.play_arrow,
          size: iconSize,
        ),
        onPressed: player.play,
      );
    } else if (processingState != ProcessingState.completed) {
      return IconButton(
        icon: Icon(
          Icons.pause,
          size: iconSize,
        ),
        onPressed: player.pause,
      );
    } else {
      return IconButton(
        icon: Icon(
          Icons.replay,
          size: iconSize,
        ),
        onPressed: () => player.seek(Duration.zero, index: player.effectiveIndices!.first),
      );
    }
  }

  Widget _buildAdditionalControls(AudioService audioService, BuildContext context) {
    // 使用辅助方法判断小屏幕
    final isSmallScreen = _isSmallScreen(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSleepTimerButton(audioService, context, isSmallScreen),
        _buildPlaylistButton(context, isSmallScreen),
        _buildCommentButton(audioService, context, isSmallScreen),
      ],
    );
  }

  Widget _buildSleepTimerButton(AudioService audioService, BuildContext context, bool isSmallScreen) {
    return StreamBuilder<int?>(
      stream: audioService.sleepTimerStream,
      builder: (context, snapshot) {
        final remainingSeconds = snapshot.data;
        final isActive = remainingSeconds != null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isActive ? Icons.timer : Icons.timer_outlined,
                color: isActive ? Theme.of(context).colorScheme.primary : null,
                size: isSmallScreen ? 22 : 24,
              ),
              onPressed: () => _handleSleepTimerPress(isActive, audioService, context),
            ),
            if (isActive)
              Text(
                _formatTime(remainingSeconds),
                style: TextStyle(
                  fontSize: isSmallScreen ? 8 : 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (!isActive)
              Text(
                '定时',
                style: TextStyle(
                  fontSize: isSmallScreen ? 8 : 10,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSecs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSecs.toString().padLeft(2, '0')}';
    }
  }

  void _handleSleepTimerPress(bool isActive, AudioService audioService, BuildContext context) {
    if (isActive) {
      _showCancelSleepTimerDialog(audioService, context);
    } else {
      _showSleepTimerOptionsDialog(audioService, context);
    }
  }

  void _showCancelSleepTimerDialog(AudioService audioService, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('定时停止播放'),
        content: const Text('是否取消定时停止播放？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () {
              audioService.setSleepTimer(null);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
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
  }

  void _showSleepTimerOptionsDialog(AudioService audioService, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('定时停止播放'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text('倒计时停止', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 200,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...[5, 10, 15, 30, 45, 60, 90].map((minutes) => ListTile(
                          dense: true,
                          title: Text('$minutes 分钟'),
                          onTap: () {
                            audioService.setSleepTimer(minutes);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('将在 $minutes 分钟后停止播放'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        )),
                    ListTile(
                      dense: true,
                      title: const Text('自定义时间'),
                      onTap: () => _showCustomTimerDialog(audioService, context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text('指定时刻停止', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                dense: true,
                title: const Text('选择时间'),
                onTap: () => _showTimePickerDialog(audioService, context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomTimerDialog(AudioService audioService, BuildContext context) {
    Navigator.pop(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置定时时间（分钟）'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '分钟',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                audioService.setSleepTimer(minutes);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('将在 $minutes 分钟后停止播放'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimePickerDialog(AudioService audioService, BuildContext context) async {
    Navigator.pop(context);

    // 获取当前时间作为初始值
    final now = DateTime.now();
    final initialTime = TimeOfDay(hour: now.hour, minute: now.minute);

    // 显示时间选择器
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null && context.mounted) {
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
      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }

      // 设置定时器
      audioService.setSleepTimer(null, specificTime: targetTime);

      // 计算并显示剩余时间
      final difference = targetTime.difference(now);
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '将在 ${selectedTime.format(context)} (${hours > 0 ? '$hours小时' : ''}${minutes > 0 ? '$minutes分钟' : ''}后) 停止播放'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildPlaylistButton(BuildContext context, bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.queue_music,
            size: isSmallScreen ? 22 : 24,
          ),
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
        Text(
          '播放列表',
          style: TextStyle(
            fontSize: isSmallScreen ? 8 : 10,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentButton(AudioService audioService, BuildContext context, bool isSmallScreen) {
    return StreamBuilder<SequenceState?>(
      stream: audioService.player.sequenceStateStream,
      builder: (context, snapshot) {
        final src = snapshot.data?.currentSource;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: Icon(
                  Icons.comment_outlined,
                  size: isSmallScreen ? 22 : 24,
                ),
                onPressed: src == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentScreen(
                              aid: src.tag.extras['aid'].toString(),
                            ),
                          ),
                        )),
            Text(
              '评论',
              style: TextStyle(
                fontSize: isSmallScreen ? 8 : 10,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            )
          ],
        );
      },
    );
  }
}
