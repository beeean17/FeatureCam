import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gallery/feature_cam_gallery_store.dart';
import 'camera_theme.dart';

class FeatureCamGalleryScreen extends StatefulWidget {
  const FeatureCamGalleryScreen({super.key});

  @override
  State<FeatureCamGalleryScreen> createState() =>
      _FeatureCamGalleryScreenState();
}

class _FeatureCamGalleryScreenState extends State<FeatureCamGalleryScreen> {
  final FeatureCamGalleryStore _store = const FeatureCamGalleryStore();
  late Future<_GalleryLoadResult> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadGallery();
  }

  Future<_GalleryLoadResult> _loadGallery() async {
    final hasAccess = await _store.requestAccess();
    if (!hasAccess) {
      return const _GalleryLoadResult.denied();
    }
    final items = await _store.listMedia();
    return _GalleryLoadResult(items: items);
  }

  void _reload() {
    setState(() {
      _loadFuture = _loadGallery();
    });
  }

  void _openItem(FeatureCamMediaItem item, List<FeatureCamMediaItem> items) {
    if (item.isVideo) {
      unawaited(_store.openMedia(item));
      return;
    }
    final imageItems = items.where((candidate) => !candidate.isVideo).toList();
    final initialIndex = imageItems.indexWhere(
      (candidate) => candidate.uri == item.uri,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FeatureCamImageViewerScreen(
          items: imageItems,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          store: _store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeatureCamColors.background,
      appBar: AppBar(
        backgroundColor: FeatureCamColors.background,
        foregroundColor: FeatureCamColors.white,
        elevation: 0,
        title: const Text(
          'FeatureCam',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_GalleryLoadResult>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: FeatureCamColors.amber),
            );
          }
          if (snapshot.hasError) {
            return _GalleryMessage(
              icon: Icons.error_outline_rounded,
              title: '갤러리를 불러올 수 없습니다',
              message: '${snapshot.error}',
              actionLabel: '다시 시도',
              onAction: _reload,
            );
          }

          final result = snapshot.data ?? const _GalleryLoadResult.denied();
          if (!result.hasAccess) {
            return _GalleryMessage(
              icon: Icons.photo_library_outlined,
              title: '접근 권한이 필요합니다',
              message: 'DCIM/FeatureCam에 저장된 사진과 영상을 보려면 미디어 접근을 허용해주세요.',
              actionLabel: '권한 요청',
              onAction: _reload,
            );
          }
          if (result.items.isEmpty) {
            return const _GalleryMessage(
              icon: Icons.grid_view_rounded,
              title: '저장된 파일이 없습니다',
              message: '촬영하면 DCIM/FeatureCam에 저장된 항목이 여기에 표시됩니다.',
            );
          }
          return RefreshIndicator(
            color: FeatureCamColors.amber,
            backgroundColor: FeatureCamColors.surface,
            onRefresh: () async => _reload(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: result.items.length,
              itemBuilder: (context, index) {
                final item = result.items[index];
                return _GalleryTile(
                  item: item,
                  onTap: () => _openItem(item, result.items),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.item, required this.onTap});

  final FeatureCamMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: FeatureCamColors.surfaceSoft,
                child: item.thumbnail == null
                    ? const Icon(
                        Icons.broken_image_outlined,
                        color: FeatureCamColors.textSecondary,
                      )
                    : Image.memory(item.thumbnail!, fit: BoxFit.cover),
              ),
              Positioned(left: 6, top: 6, child: _CodeBadge(label: item.code)),
              if (item.isVideo)
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: FeatureCamColors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureCamImageViewerScreen extends StatefulWidget {
  const FeatureCamImageViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.store,
  });

  final List<FeatureCamMediaItem> items;
  final int initialIndex;
  final FeatureCamGalleryStore store;

  @override
  State<FeatureCamImageViewerScreen> createState() =>
      _FeatureCamImageViewerScreenState();
}

class _FeatureCamImageViewerScreenState
    extends State<FeatureCamImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<String, Future<_LoadedGalleryImage>> _imageFutures = {};
  final Map<String, Size> _imageSizes = {};

  FeatureCamMediaItem get _currentItem => widget.items[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    unawaited(_loadImage(_currentItem));
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(_lockPortrait());
    super.dispose();
  }

  Future<_LoadedGalleryImage> _loadImage(FeatureCamMediaItem item) {
    return _imageFutures.putIfAbsent(item.uri, () async {
      final bytes = await widget.store.loadMediaBytes(item.uri);
      final size = await _decodeImageSize(bytes);
      _imageSizes[item.uri] = size;
      if (mounted && item.uri == _currentItem.uri) {
        setState(() {});
        await _applyOrientationPolicy(size);
      }
      return _LoadedGalleryImage(bytes: bytes, size: size);
    });
  }

  Future<Size> _decodeImageSize(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    final image = await completer.future;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    return size;
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    final currentSize = _imageSizes[_currentItem.uri];
    if (currentSize != null) {
      unawaited(_applyOrientationPolicy(currentSize));
      return;
    }
    unawaited(_loadImage(_currentItem));
  }

  Future<void> _applyOrientationPolicy(Size imageSize) {
    if (imageSize.width > imageSize.height) {
      return SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    return _lockPortrait();
  }

  Future<void> _lockPortrait() {
    return SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscapeScreen =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final title = _currentItem.displayName;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscapeScreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: FeatureCamColors.white,
              elevation: 0,
              title: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: _handlePageChanged,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _GalleryImagePage(imageFuture: _loadImage(item));
            },
          ),
          if (isLandscapeScreen &&
              (_imageSizes[_currentItem.uri]?.width ?? 0) >
                  (_imageSizes[_currentItem.uri]?.height ?? 1))
            _LandscapeViewerBar(title: title),
        ],
      ),
    );
  }
}

class _GalleryImagePage extends StatelessWidget {
  const _GalleryImagePage({required this.imageFuture});

  final Future<_LoadedGalleryImage> imageFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadedGalleryImage>(
      future: imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: FeatureCamColors.amber),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _GalleryMessage(
            icon: Icons.broken_image_outlined,
            title: '이미지를 열 수 없습니다',
            message: '${snapshot.error ?? '이미지 데이터가 없습니다.'}',
          );
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          panEnabled: false,
          child: Center(
            child: Image.memory(
              snapshot.data!.bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }
}

class _LandscapeViewerBar extends StatelessWidget {
  const _LandscapeViewerBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: FeatureCamColors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FeatureCamColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedGalleryImage {
  const _LoadedGalleryImage({required this.bytes, required this.size});

  final Uint8List bytes;
  final Size size;

  bool get isLandscape => size.width > size.height;
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FeatureCamColors.background.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: FeatureCamColors.strokeSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: FeatureCamColors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FeatureCamColors.textSecondary, size: 38),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FeatureCamColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FeatureCamColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: FeatureCamColors.amber,
                  foregroundColor: FeatureCamColors.background,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GalleryLoadResult {
  const _GalleryLoadResult({required this.items}) : hasAccess = true;

  const _GalleryLoadResult.denied() : hasAccess = false, items = const [];

  final bool hasAccess;
  final List<FeatureCamMediaItem> items;
}
