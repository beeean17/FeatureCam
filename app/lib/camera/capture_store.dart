import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_modes.dart';

class CaptureStore {
  static const MethodChannel _mediaStoreChannel = MethodChannel(
    'feature_cam/media_store',
  );

  Future<File> copyOriginal(
    XFile source, {
    required CameraMode mode,
    required String kind,
    bool exportToDcim = true,
    bool cropToCaptureFrame = false,
    double cropAspectRatio = 3 / 4,
  }) async {
    final extension = _extensionFor(
      source.path,
      fallback: kind == 'video' ? 'mp4' : 'jpg',
    );
    final output = await createCaptureFile(
      mode: mode,
      kind: kind,
      extension: extension,
      processed: false,
    );
    final isPhoto = kind != 'video';
    final copiedFile = isPhoto && cropToCaptureFrame
        ? await _cropImageToCaptureFrame(
            source.path,
            output.path,
            aspectRatio: cropAspectRatio,
          )
        : await File(source.path).copy(output.path);
    if (exportToDcim) {
      await saveToDcim(copiedFile);
    }
    return copiedFile;
  }

  Future<File> writeProcessedBytes(
    Uint8List bytes, {
    required CameraMode mode,
    required String kind,
    required String extension,
    bool exportToDcim = true,
  }) async {
    final output = await createCaptureFile(
      mode: mode,
      kind: kind,
      extension: extension,
      processed: true,
    );
    await output.writeAsBytes(bytes, flush: true);
    if (exportToDcim) {
      await saveToDcim(output);
    }
    return output;
  }

  Future<String> saveToDcim(File file) async {
    final fileName = file.uri.pathSegments.last;
    final uri = await _mediaStoreChannel.invokeMethod<String>('saveToDcim', {
      'inputPath': file.path,
      'displayName': fileName,
      'mimeType': _mimeTypeFor(fileName),
    });
    if (uri == null || uri.isEmpty) {
      throw const FileSystemException(
        'Could not save capture to DCIM/FeatureCam',
      );
    }
    return uri;
  }

  Future<File> createCaptureFile({
    required CameraMode mode,
    required String kind,
    required String extension,
    required bool processed,
  }) async {
    final directory = await _captureDirectory(processed: processed);
    final normalizedExtension = extension.replaceFirst('.', '').toLowerCase();
    final modeCode = _modeCode(mode: mode, kind: kind);

    while (true) {
      final file = File(
        '${directory.path}${Platform.pathSeparator}${_timestamp()}_$modeCode.$normalizedExtension',
      );
      try {
        return await file.create(exclusive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
  }

  Future<Directory> _captureDirectory({required bool processed}) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}FeatureCam${Platform.pathSeparator}${processed ? 'processed' : 'original'}',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _extensionFor(String path, {required String fallback}) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return fallback;
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }

  String _modeCode({required CameraMode mode, required String kind}) {
    if (kind == 'video') {
      return 'vd';
    }
    return switch (mode) {
      CameraMode.photo => 'or',
      CameraMode.fisheye => 'fs',
      CameraMode.panorama => 'pn',
      CameraMode.video => 'vd',
    };
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${_twoDigits(now.year % 100)}'
        '${_twoDigits(now.month)}'
        '${_twoDigits(now.day)}_'
        '${_twoDigits(now.hour)}'
        '${_twoDigits(now.minute)}'
        '${_twoDigits(now.second)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  Future<File> _cropImageToCaptureFrame(
    String inputPath,
    String outputPath, {
    required double aspectRatio,
  }) async {
    await _mediaStoreChannel.invokeMethod<String>('cropImageToAspect', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'aspectRatio': aspectRatio,
    });
    return File(outputPath);
  }

  String _mimeTypeFor(String path) {
    return switch (_extensionFor(path, fallback: 'jpg')) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }
}
