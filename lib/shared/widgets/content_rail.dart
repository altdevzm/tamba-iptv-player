import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ContentRail extends StatelessWidget {
  final String title;
  final VoidCallback? onHeaderTap;
  final List<Widget> children;
  final double height;

  const ContentRail({
    super.key,
    required this.title,
    this.onHeaderTap,
    required this.children,
    this.height = 270,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Rail Header ---
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: InkWell(
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary,
                  size: 14,
                ),
              ],
            ),
          ),
        ),

        // --- Horizontal Scrolling Items ---
        SizedBox(
          height: height + 16,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            itemCount: children.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) => children[index],
          ),
        ),
      ],
    );
  }
}

