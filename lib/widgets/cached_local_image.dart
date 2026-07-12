import 'dart:io';
import 'package:flutter/material.dart';

class CachedLocalImage extends StatefulWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Widget fallback;

  const CachedLocalImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.color,
    this.colorBlendMode,
    required this.fallback,
  });

  @override
  State<CachedLocalImage> createState() => _CachedLocalImageState();
}

class _CachedLocalImageState extends State<CachedLocalImage> {
  bool _imageExists = false;

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  @override
  void didUpdateWidget(CachedLocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _checkImage();
    }
  }

  void _checkImage() {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      if (mounted) setState(() => _imageExists = false);
      return;
    }
    File(widget.imagePath!).exists().then((v) {
      if (mounted) {
        setState(() => _imageExists = v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_imageExists && widget.imagePath != null) {
      return Image.file(
        File(widget.imagePath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
      );
    } else {
      return widget.fallback;
    }
  }
}
