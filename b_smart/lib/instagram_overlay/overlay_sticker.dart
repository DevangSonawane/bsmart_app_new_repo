import 'dart:io';
import 'package:flutter/material.dart';
import 'overlay_shape.dart';

class OverlaySticker {
  final String id;
  final File imageFile;
  final OverlayShape shape;
  final Offset position;
  final double scale;
  final double rotation;

  const OverlaySticker({
    required this.id,
    required this.imageFile,
    required this.shape,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  OverlaySticker copyWith({
    String? id,
    File? imageFile,
    OverlayShape? shape,
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    return OverlaySticker(
      id: id ?? this.id,
      imageFile: imageFile ?? this.imageFile,
      shape: shape ?? this.shape,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}
