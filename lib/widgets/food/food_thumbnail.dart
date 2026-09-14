import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_semantic_colors.dart';
import 'food_category_visuals.dart';

/// Food photo thumbnail with a graceful fallback: category-accented tile with
/// the category emoji whenever [imageUrl] is null/empty or the network image
/// fails. Never renders a broken-image widget.
class FoodThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String? category;
  final double size;

  const FoodThumbnail({
    super.key,
    required this.imageUrl,
    required this.category,
    this.size = 48,
  });

  Widget _fallback() {
    final color = AppSemanticColors.forFoodCategory(category ?? '');
    final emoji = FoodCategoryVisuals.forDb(category).emoji;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.46)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        errorWidget: (_, __, ___) => _fallback(),
      ),
    );
  }
}
