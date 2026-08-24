import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/voice_food_log_result.dart';
import 'supabase_client.dart';

class VoiceFoodLogService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  bool get isRecording => _currentPath != null;

  /// Requests mic permission and starts recording to a temp m4a file.
  Future<void> startRecording() async {
    if (_currentPath != null) return;

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (!status.isGranted) {
      throw VoiceLogException.fromType(VoiceLogErrorType.microphone);
    }

    try {
      final dir = await getTemporaryDirectory();
      _currentPath =
          '${dir.path}/voice_food_log_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (!await _recorder.hasPermission()) {
        _currentPath = null;
        throw VoiceLogException.fromType(VoiceLogErrorType.microphone);
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 96000,
        ),
        path: _currentPath!,
      );
    } on VoiceLogException {
      rethrow;
    } catch (e) {
      debugPrint('❌ VoiceFoodLogService.startRecording: $e');
      _currentPath = null;
      throw VoiceLogException.fromType(VoiceLogErrorType.unknown);
    }
  }

  /// Stops the active recording and returns the recorded file,
  /// or null if nothing was recording / the file is empty.
  Future<File?> stopRecording() async {
    final path = _currentPath;
    if (path == null) return null;
    _currentPath = null;

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('❌ VoiceFoodLogService.stopRecording: $e');
    }

    final file = File(path);
    if (!await file.exists() || await file.length() == 0) return null;
    return file;
  }

  /// Discards the current recording without sending anything.
  Future<void> cancelRecording() async {
    await stopRecording();
    final path = _currentPath;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  /// Sends the audio to the `log-food-voice` Edge Function.
  ///
  /// The function runs the Gemini transcription + analysis, uploads the audio
  /// to the private `voice-food-logs` bucket and persists `voice_food_logs` +
  /// `voice_food_log_items` rows, returning real DB ids parsed into
  /// [VoiceFoodLogResult].
  Future<VoiceFoodLogResult> logFromAudio(File audioFile) async {
    if (currentUserId == null) {
      throw VoiceLogException.fromType(VoiceLogErrorType.unauthorized);
    }

    final Uint8List bytes;
    try {
      bytes = await audioFile.readAsBytes();
    } catch (_) {
      throw VoiceLogException.fromType(VoiceLogErrorType.unknown);
    }

    final Map<String, dynamic> data;
    try {
      final response = await supabase.functions.invoke(
        'log-food-voice',
        body: {
          'audioBase64': base64Encode(bytes),
          'mimeType': 'audio/mp4',
        },
      );
      data = Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } on SocketException catch (_) {
      throw VoiceLogException.fromType(VoiceLogErrorType.network);
    } catch (e) {
      debugPrint('❌ VoiceFoodLogService.logFromAudio: $e');
      throw VoiceLogException.fromType(VoiceLogErrorType.unknown);
    }

    final result = VoiceFoodLogResult.fromJson(data);

    // The Edge Function returns 200 with rows persisted; a missing log id
    // means an unexpected response shape.
    if (result.logId.isEmpty) {
      throw VoiceLogException.fromType(VoiceLogErrorType.analysisFailed);
    }
    if (!result.isFood) {
      throw VoiceLogException.fromType(VoiceLogErrorType.notFood);
    }
    return result;
  }

  VoiceLogException _mapFunctionException(FunctionException e) {
    debugPrint('❌ log-food-voice failed [${e.status}]: ${e.reasonPhrase}');

    // The error payload rides in `details` for non-2xx responses.
    String? code;
    final details = e.details;
    if (details is Map) {
      code = details['error']?.toString();
    } else if (details is String && details.isNotEmpty) {
      try {
        code = (jsonDecode(details) as Map)['error']?.toString();
      } catch (_) {}
    }

    switch (code) {
      case 'persist_failed':
        // Gemini analysis succeeded but storage/DB write failed.
        return VoiceLogException.fromType(VoiceLogErrorType.serverError);
      case 'analysis_failed':
        return VoiceLogException.fromType(VoiceLogErrorType.analysisFailed);
      case 'unauthorized':
        return VoiceLogException.fromType(VoiceLogErrorType.unauthorized);
      case 'bad_request':
        return VoiceLogException.fromType(VoiceLogErrorType.unknown);
    }

    if (e.status == 401) {
      return VoiceLogException.fromType(VoiceLogErrorType.unauthorized);
    }
    if (e.status == 0) {
      return VoiceLogException.fromType(VoiceLogErrorType.network);
    }
    return VoiceLogException.fromType(VoiceLogErrorType.analysisFailed);
  }
}
