import 'package:flutter/services.dart';

class FeatureCamGalleryStore {
  const FeatureCamGalleryStore({
    MethodChannel channel = const MethodChannel('feature_cam/media_store'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<bool> requestAccess() async {
    return await _channel.invokeMethod<bool>('requestGalleryAccess') ?? false;
  }

  Future<List<FeatureCamMediaItem>> listMedia() async {
    final rawItems =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'listFeatureCamMedia',
        ) ??
        const <Map<Object?, Object?>>[];
    return rawItems.map(FeatureCamMediaItem.fromMap).toList(growable: false);
  }

  Future<Uint8List> loadMediaBytes(String uri) async {
    final Uint8List? bytes;
    try {
      bytes = await _channel.invokeMethod<Uint8List>('loadMediaBytes', {
        'uri': uri,
      });
    } on MissingPluginException {
      throw StateError(
        'Android 갤러리 모듈이 아직 갱신되지 않았습니다. 앱을 완전히 재설치하거나 flutter run으로 다시 설치해주세요.',
      );
    }
    if (bytes == null) {
      throw StateError('Media bytes are empty.');
    }
    return bytes;
  }

  Future<void> openMedia(FeatureCamMediaItem item) async {
    await _channel.invokeMethod<bool>('openMedia', {
      'uri': item.uri,
      'mimeType': item.mimeType,
    });
  }
}

class FeatureCamMediaItem {
  const FeatureCamMediaItem({
    required this.id,
    required this.uri,
    required this.displayName,
    required this.mimeType,
    required this.isVideo,
    required this.dateAdded,
    required this.thumbnail,
  });

  final int id;
  final String uri;
  final String displayName;
  final String mimeType;
  final bool isVideo;
  final int dateAdded;
  final Uint8List? thumbnail;

  String get code {
    final match = RegExp(r'_([a-z]{2})\.').firstMatch(displayName);
    return match?.group(1)?.toUpperCase() ?? (isVideo ? 'VD' : 'OR');
  }

  factory FeatureCamMediaItem.fromMap(Map<Object?, Object?> map) {
    return FeatureCamMediaItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      uri: map['uri'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'FeatureCam',
      mimeType: map['mimeType'] as String? ?? 'image/jpeg',
      isVideo: map['isVideo'] as bool? ?? false,
      dateAdded: (map['dateAdded'] as num?)?.toInt() ?? 0,
      thumbnail: map['thumbnail'] as Uint8List?,
    );
  }
}
