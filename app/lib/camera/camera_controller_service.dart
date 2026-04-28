import 'dart:ui';

import 'package:camera/camera.dart';

class CameraControllerService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;

  CameraController? get controller => _controller;
  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get canSwitchCamera => _cameras.length > 1;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraException('no-cameras', 'No cameras are available.');
    }
    await _selectCamera(0);
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) {
      return;
    }
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _selectCamera(nextIndex);
  }

  Future<XFile> takePhoto() async {
    final activeController = _requireController();
    if (activeController.value.isTakingPicture) {
      throw CameraException('busy', 'Camera is already taking a picture.');
    }
    return activeController.takePicture();
  }

  Future<void> startVideoRecording() async {
    final activeController = _requireController();
    if (activeController.value.isRecordingVideo) {
      return;
    }
    await activeController.prepareForVideoRecording();
    await activeController.startVideoRecording();
  }

  Future<XFile> stopVideoRecording() {
    final activeController = _requireController();
    return activeController.stopVideoRecording();
  }

  Future<void> focusAt(Offset normalizedPoint) async {
    final activeController = _requireController();
    final point = Offset(
      normalizedPoint.dx.clamp(0.0, 1.0),
      normalizedPoint.dy.clamp(0.0, 1.0),
    );

    try {
      await activeController.setFocusMode(FocusMode.auto);
    } on CameraException {
      // Some devices keep focus mode fixed but still accept focus points.
    }
    try {
      await activeController.setFocusPoint(point);
    } on CameraException {
      // Tap focus is best-effort because support varies by camera.
    }
    try {
      await activeController.setExposureMode(ExposureMode.auto);
    } on CameraException {
      // Some cameras do not expose exposure mode controls.
    }
    try {
      await activeController.setExposurePoint(point);
    } on CameraException {
      // Exposure point is also device-dependent.
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> _selectCamera(int index) async {
    final previousController = _controller;
    _controller = null;
    await previousController?.dispose();

    final nextController = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );

    await nextController.initialize();
    try {
      await nextController.setFlashMode(FlashMode.off);
    } on CameraException {
      // Some cameras do not expose flash controls.
    }
    _selectedCameraIndex = index;
    _controller = nextController;
  }

  CameraController _requireController() {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      throw CameraException('not-ready', 'Camera is not initialized.');
    }
    return activeController;
  }
}
