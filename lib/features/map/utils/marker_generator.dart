import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Helper to generate high-quality custom circular avatar markers for Google Maps.
class MarkerGenerator {
  /// Cache generated markers to avoid redundant repaints
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Generates a sleek, compact circular avatar marker with a romantic border and drop shadow.
  static Future<BitmapDescriptor> createCustomAvatarMarker({
    String? imageUrl,
    required String label,
    required Color borderColor,
    Color backgroundColor = const Color(0xFFF8F6F2),
    Color textColor = const Color(0xFF252525),
    double size = 64.0,
  }) async {
    final cacheKey = '$imageUrl-$label-${borderColor.toARGB32()}-$size';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = size / 2;

    // Pin tip height at the bottom
    const double tipHeight = 9.0;
    final double totalHeight = size + tipHeight;
    final Offset center = Offset(radius, radius);

    // 1. Draw soft drop shadow under marker
    final Path shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius - 2));
    canvas.drawShadow(
      shadowPath,
      Colors.black.withValues(alpha: 0.30),
      5.0,
      true,
    );

    // 2. Draw small bottom triangle pointer pointing to exact coordinate
    final Path pointerPath = Path()
      ..moveTo(radius - 6, size - 4)
      ..lineTo(radius, totalHeight)
      ..lineTo(radius + 6, size - 4)
      ..close();
    final Paint pointerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pointerPath, pointerPaint);

    // 3. Draw outer colored border ring
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // 4. Draw white inner gap ring
    final Paint innerGapPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius - 5, innerGapPaint);

    // 5. Draw inner avatar circle or image
    final double contentRadius = radius - 7.5;
    ui.Image? loadedImage;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        loadedImage = await _fetchAndDecodeImage(imageUrl);
      } catch (_) {
        loadedImage = null;
      }
    }

    if (loadedImage != null) {
      // Clip canvas into a circle and draw the loaded avatar image
      canvas.save();
      final Path clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: contentRadius));
      canvas.clipPath(clipPath);

      final Rect src = Rect.fromLTWH(
        0,
        0,
        loadedImage.width.toDouble(),
        loadedImage.height.toDouble(),
      );
      final Rect dst = Rect.fromCircle(center: center, radius: contentRadius);
      canvas.drawImageRect(loadedImage, src, dst, Paint()..isAntiAlias = true);
      canvas.restore();
    } else {
      // Fallback: Romantic background with user initials
      final Paint bgPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, contentRadius, bgPaint);

      final textSpan = TextSpan(
        text: label.isNotEmpty
            ? label
                  .substring(0, label.length > 2 ? 2 : label.length)
                  .toUpperCase()
            : '♥',
        style: TextStyle(
          color: textColor,
          fontSize: contentRadius * 0.76,
          fontWeight: FontWeight.w700,
          fontFamily: 'Plus Jakarta Sans',
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentRadius * 2);

      textPainter.paint(
        canvas,
        Offset(
          center.dx - (textPainter.width / 2),
          center.dy - (textPainter.height / 2),
        ),
      );
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image markerImage = await picture.toImage(
      size.toInt(),
      totalHeight.toInt(),
    );
    final ByteData? byteData = await markerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }

    final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Network and base64 data URI image loader and decoder
  static Future<ui.Image> _fetchAndDecodeImage(String url) async {
    if (url.startsWith('data:image')) {
      final commaIndex = url.indexOf(',');
      final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
      final bytes = base64Decode(base64Str);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    }

    final Completer<ui.Image> completer = Completer();
    final ImageStream stream = NetworkImage(
      url,
    ).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        completer.completeError(exception, stackTrace);
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }
}
