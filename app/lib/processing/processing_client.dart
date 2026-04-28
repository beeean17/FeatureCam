import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';

import '../camera/camera_modes.dart';

class ProcessingClient {
  ProcessingClient({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('feature_cam/processing');

  final MethodChannel _channel;

  Future<void> checkHealth() async {
    try {
      await _channel
          .invokeMethod<String>('health')
          .timeout(const Duration(seconds: 3));
    } on PlatformException catch (error) {
      throw ProcessingException(_platformMessage(error));
    } on TimeoutException {
      throw const ProcessingException('내장 Python 처리 엔진 응답이 없습니다.');
    }
  }

  Future<File> processPhoto({
    required File image,
    required File output,
    required FisheyeLensConfig lens,
  }) async {
    await _invokeProcessor('processPhoto', {
      'inputPath': image.path,
      'outputPath': output.path,
      ..._fisheyeArguments(lens),
    });
    return output;
  }

  Future<File> processVideo({
    required File video,
    required File output,
    required FisheyeLensConfig lens,
  }) async {
    await _invokeProcessor('processVideo', {
      'inputPath': video.path,
      'outputPath': output.path,
      ..._fisheyeArguments(lens),
    });
    return output;
  }

  Future<File> processPanorama({
    required List<File> images,
    required File output,
  }) async {
    if (images.length != 3) {
      throw ArgumentError.value(
        images.length,
        'images.length',
        'Panorama processing requires exactly 3 images.',
      );
    }
    await _invokeProcessor('processPanorama', {
      'inputPaths': images.map((file) => file.path).toList(growable: false),
      'outputPath': output.path,
    });
    return output;
  }

  void close() {}

  Map<String, double> _fisheyeArguments(FisheyeLensConfig lens) {
    return {
      'strength': lens.strength,
      'centerX': lens.center.dx,
      'centerY': lens.center.dy,
      'radius': lens.radius,
    };
  }

  Future<String> _invokeProcessor(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      return await _channel
              .invokeMethod<String>(method, arguments)
              .timeout(const Duration(minutes: 10)) ??
          '';
    } on PlatformException catch (error) {
      throw ProcessingException(_platformMessage(error));
    } on TimeoutException {
      throw const ProcessingException('내장 Python 처리 시간이 초과되었습니다.');
    }
  }

  String _platformMessage(PlatformException error) {
    final details = error.details == null ? '' : '\n${error.details}';
    return '${error.message ?? error.code}$details';
  }
}

class ProcessingException implements Exception {
  const ProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}
