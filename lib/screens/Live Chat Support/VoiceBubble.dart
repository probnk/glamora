import 'dart:async';
import 'dart:io';
import 'dart:math' as DurationType;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:glamora/Reuse%20Widgets/loadingShimmer.dart';
import 'package:provider/provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart' as aw;
import '../../constants/colors.dart';
import '../../constants/fonts.dart';
import '../../providers/DarkModeProvider.dart';

class VoiceBubble extends StatefulWidget {
  final String audioPath;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const VoiceBubble({
    super.key,
    required this.audioPath,
    required this.isPlaying,
    required this.onPlayPause,
  });

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble>
    with AutomaticKeepAliveClientMixin {
  final aw.PlayerController _waveController = aw.PlayerController();
  bool _isLoading = true;
  bool _isError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _localPath;
  late StreamSubscription<int> _durationSubscription;
  late StreamSubscription<void> _completionSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _downloadAndPrepare();
    _durationSubscription =
        _waveController.onCurrentDurationChanged.listen((ms) {
      if (mounted) setState(() => _position = Duration(milliseconds: ms));
    });
    _completionSubscription = _waveController.onCompletion.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          widget.onPlayPause();
        });
      }
    });
  }

  Future<void> _downloadAndPrepare() async {
    try {
      if (widget.audioPath.startsWith('http')) {
        final cacheManager = DefaultCacheManager();
        var fileInfo = await cacheManager.getFileFromCache(widget.audioPath);
        if (fileInfo != null && await fileInfo.file.exists()) {
          _localPath = fileInfo.file.path;
        } else {
          final file = await cacheManager.getSingleFile(widget.audioPath);
          _localPath = file.path;
        }
      } else {
        _localPath = widget.audioPath;
      }
      await _waveController.preparePlayer(
          path: _localPath!, shouldExtractWaveform: true);
      final dur = await _waveController.getDuration(DurationType.max as aw.DurationType?);
      if (mounted) {
        setState(() {
          _duration = Duration(milliseconds: dur ?? 0);
          _isLoading = false;
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
    }
  }

  Future<void> _seek(Duration position) async {
    await _waveController.seekTo(position.inMilliseconds);
    if (widget.isPlaying) await _waveController.startPlayer();
  }

  @override
  void didUpdateWidget(covariant VoiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      widget.isPlaying
          ? _waveController.startPlayer()
          : _waveController.pausePlayer();
    }
    if (widget.audioPath != oldWidget.audioPath) _downloadAndPrepare();
  }

  @override
  void dispose() {
    _durationSubscription.cancel();
    _completionSubscription.cancel();
    _waveController.stopPlayer();
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return min > 0 ? '$min:${sec.toString().padLeft(2, '0')}' : '${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    if (_isLoading)
      return reusableShimmerContainer(
          context: context, isDarkMode: isDarkMode, height: 50);
    if (_isError) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: smallFont(
                text: 'Error loading voice message',
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                widget.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: isDarkMode ? lightGreen : lightPurple,
                size: 32,
              ),
              onPressed: widget.onPlayPause,
            ),
            Expanded(
              child: GestureDetector(
                onTapDown: (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null) return;
                  final progress =
                      details.localPosition.dx / renderBox.size.width;
                  final newPosition = _duration * progress.clamp(0.0, 1.0);
                  _seek(newPosition);
                },
                child: aw.AudioFileWaveforms(
                  size: Size(MediaQuery.of(context).size.width * 0.6, 32),
                  playerController: _waveController,
                  enableSeekGesture: true,
                  waveformType: aw.WaveformType.fitWidth,
                  playerWaveStyle: aw.PlayerWaveStyle(
                    fixedWaveColor: Colors.grey,
                    liveWaveColor: isDarkMode ? Colors.blue : lightPurple,
                    seekLineColor: Colors.red,
                    scaleFactor: 100,
                    showSeekLine: true,
                    waveThickness: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            smallFont(
                text: _formatDuration(_position),
                color: isDarkMode ? white : grayBlack),
          ],
        ),
      ],
    );
  }
}
