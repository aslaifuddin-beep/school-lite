import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// دائرة حساب بحرفين من الاسم + لون مميز لكل طالب.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    required this.colorIndex,
    this.size = 44,
    this.isActive = false,
    this.imageUrl,
  });

  final String initials;
  final int colorIndex;
  final double size;
  final bool isActive;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.colorForIndex(colorIndex);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? color.withValues(alpha: 0.18) : color,
        border: Border.all(
          color: isActive ? color : Colors.transparent,
          width: 3,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsText(color),
            )
          : Center(child: _initialsText(color)),
    );
  }

  Widget _initialsText(Color color) => Text(
        initials,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
}
