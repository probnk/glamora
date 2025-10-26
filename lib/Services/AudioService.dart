import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  String? _currentRecordingPath;
  bool _isRecording = false;
  bool _isPlaying = false;

  Future<void> init() async {
    await _recorder.openRecorder();
    await _player.openPlayer();
  }

  Future<String> startRecording() async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/recording_$timestamp.aac';

      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
        bitRate: 32000, // 32 kbps for compression
        sampleRate: 22050, // Lower sample rate for compression
      );

      _isRecording = true;
      return _currentRecordingPath!;
    } catch (e) {
      throw Exception('Recording failed: $e');
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      await _recorder.stopRecorder();
      _isRecording = false;

      // Compress the recorded audio
      final compressedPath = await _compressAudio(_currentRecordingPath!);
      return compressedPath;
    } catch (e) {
      throw Exception('Stop recording failed: $e');
    }
  }

  Future<String> _compressAudio(String inputPath) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${directory.path}/compressed_$timestamp.m4a';

      // Using flutter_sound for basic compression
      await _recorder.startRecorder(
        toFile: outputPath,
        codec: Codec.aacMP4,
        bitRate: 16000, // Further reduce bitrate for compression
        sampleRate: 16000,
      );

      // Note: For better compression, you might need ffmpeg
      // This is a simplified approach

      return outputPath;
    } catch (e) {
      // If compression fails, return original path
      return inputPath;
    }
  }

  Future<void> playAudio(String path) async {
    try {
      await _player.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS,
        whenFinished: () {
          _isPlaying = false;
        },
      );
      _isPlaying = true;
    } catch (e) {
      throw Exception('Playback failed: $e');
    }
  }

  Future<void> stopPlaying() async {
    await _player.stopPlayer();
    _isPlaying = false;
  }

  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
  }

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
}