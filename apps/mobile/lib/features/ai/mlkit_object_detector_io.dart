import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path_provider/path_provider.dart';

import 'ai_vision_models.dart';

class MlkitObjectDetector {
  MlkitObjectDetector({ObjectDetector? detector})
      : _detector = detector ??
            ObjectDetector(
              options: ObjectDetectorOptions(
                mode: DetectionMode.single,
                classifyObjects: true,
                multipleObjects: true,
              ),
            );

  final ObjectDetector _detector;
  int _frameSequence = 0;

  Future<List<AiDetectedObject>> detect(Uint8List pngBytes) async {
    if (pngBytes.isEmpty) {
      return const [];
    }

    final imageSize = await _decodeImageSize(pngBytes);
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return const [];
    }

    File? frameFile;
    try {
      frameFile = await _writeFrameToTempFile(pngBytes);
      final inputImage = InputImage.fromFile(frameFile);
      final detectedObjects = await _detector.processImage(inputImage);
      return [
        for (final object in detectedObjects)
          _toDetectedObject(object, imageSize),
      ];
    } finally {
      final file = frameFile;
      if (file != null) {
        try {
          await file.delete();
        } catch (_) {
          // Best-effort cleanup only. The next frame overwrites old temp data.
        }
      }
    }
  }

  Future<void> dispose() {
    return _detector.close();
  }

  Future<File> _writeFrameToTempFile(Uint8List pngBytes) async {
    final tempDirectory = await getTemporaryDirectory();
    final frameName = 'connect_ai_frame_${_frameSequence++ % 4}.png';
    final file =
        File('${tempDirectory.path}${Platform.pathSeparator}$frameName');
    await file.writeAsBytes(pngBytes, flush: false);
    return file;
  }

  Future<_ImageSize> _decodeImageSize(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      return _ImageSize(
        width: image.width.toDouble(),
        height: image.height.toDouble(),
      );
    } finally {
      image.dispose();
    }
  }

  AiDetectedObject _toDetectedObject(
    DetectedObject object,
    _ImageSize imageSize,
  ) {
    final label = _bestLabel(object);
    final rect = object.boundingBox;
    final objectWidth = rect.width.abs().clamp(0.0, imageSize.width).toDouble();
    final objectHeight =
        rect.height.abs().clamp(0.0, imageSize.height).toDouble();
    final areaRatio = (objectWidth * objectHeight) /
        (imageSize.width * imageSize.height).clamp(1.0, double.infinity);

    return AiDetectedObject(
      label: label.text,
      confidence: label.confidence,
      areaRatio: areaRatio.clamp(0.0, 1.0).toDouble(),
      centerXRatio:
          (rect.center.dx / imageSize.width).clamp(0.0, 1.0).toDouble(),
      centerYRatio:
          (rect.center.dy / imageSize.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  _ObjectLabel _bestLabel(DetectedObject object) {
    if (object.labels.isEmpty) {
      return const _ObjectLabel(text: 'object', confidence: 0.65);
    }

    final labels = [...object.labels]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final best = labels.first;
    final text = best.text.trim().isEmpty ? 'object' : best.text.trim();
    return _ObjectLabel(text: text, confidence: best.confidence);
  }
}

class _ImageSize {
  const _ImageSize({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;
}

class _ObjectLabel {
  const _ObjectLabel({
    required this.text,
    required this.confidence,
  });

  final String text;
  final double confidence;
}
