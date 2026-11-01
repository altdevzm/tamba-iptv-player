import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../models/media_item.dart';

class PosterCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool showProgress;

  const PosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 170,
    this.height = 255,
    this.showProgress = false,
  });

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: widget.width,
            height: widget.height,
            transform: Matrix4.diagonal3Values(
              _isFocused ? 1.08 : (_isHovered ? 1.05 : 1.0),
              _isFocused ? 1.08 : (_isHovered ? 1.05 : 1.0),
              1.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isFocused
                    ? Colors.white
                    : (_isHovered
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.08)),
                width: _isFocused ? 2.5 : (_isHovered ? 2 : 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: _isFocused
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : (_isHovered
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.3)),
                  blurRadius: _isFocused ? 24 : (_isHovered ? 20 : 10),
                  offset: Offset(0, _isActive ? 8 : 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // --- Poster Image ---
                  if (widget.item.posterUrl != null &&
                      widget.item.posterUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.item.posterUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppColors.surfaceElevated),
                      errorWidget: (context, url, err) =>
                          _buildFallbackPoster(),
                    )
                  else
                    _buildFallbackPoster(),

                  // --- Bottom Gradient Overlay ---
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0.45, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Center Play Icon on D-Pad focus or hover
                  if (_isActive)
                    Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isFocused
                              ? AppColors.primary
                              : Colors.black.withValues(alpha: 0.55),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),

                  // --- Content Info at Bottom ---
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: widget.showProgress ? 16 : 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Series / Film Tag
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Text(
                                'N',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.item.type == MediaType.series
                                  ? 'SERIES'
                                  : 'FILM',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Title
                        Text(
                          widget.item.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),

                        const SizedBox(height: 3),

                        // Match Percentage
                        if (widget.item.matchPercentage != null)
                          Text(
                            '${widget.item.matchPercentage}% Match',
                            style: const TextStyle(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),

                        // Genres
                        if (widget.item.genres.isNotEmpty)
                          Text(
                            widget.item.genres.join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // --- Red Watch Progress Bar (if continuing) ---
                  if (widget.showProgress && widget.item.watchProgress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 3.5,
                        color: Colors.white.withValues(alpha: 0.2),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: widget.item.watchProgress,
                          child: Container(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackPoster() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E28), Color(0xFF121218)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.item.type == MediaType.live
                  ? Icons.live_tv_rounded
                  : Icons.movie_outlined,
              color: Colors.white24,
              size: 38,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                widget.item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
