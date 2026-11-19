import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '一笔：带有多枚书签的共同账本',
    image: true,
    child: Image.asset(
      'assets/branding/oneentry_mark_foreground.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
    ),
  );
}
