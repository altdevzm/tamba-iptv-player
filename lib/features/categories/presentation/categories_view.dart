import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../content_details/presentation/adaptive_details_coordinator.dart';

enum CategoryContentType {
  live,
  movies,
  series,
}

extension CategoryContentTypeLabel on CategoryContentType {
  String get label {
    switch (this) {
      case CategoryContentType.live:
        return 'Live TV';
      case CategoryContentType.movies:
        return 'Movies';
      case CategoryContentType.series:
        return 'TV Shows';
    }
  }

  IconData get icon {
    switch (this) {
      case CategoryContentType.live:
        return Icons.live_tv_rounded;
      case CategoryContentType.movies:
        return Icons.movie_rounded;
      case CategoryContentType.series:
        return Icons.tv_rounded;
    }
  }

  String get categoryTableType {
    switch (this) {
      case CategoryContentType.live:
        return 'live';
      case CategoryContentType.movies:
        return 'movies';
      case CategoryContentType.series:
        return 'series';
    }
  }

  String get contentItemType {
    switch (this) {
      case CategoryContentType.live:
        return 'live';
      case CategoryContentType.movies:
        return 'movie';
      case CategoryContentType.series:
        return 'series';
    }
  }
}

class CategoriesView extends ConsumerStatefulWidget {
  const CategoriesView({super.key});

  @override
  ConsumerState<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends ConsumerState<CategoriesView> {
  CategoryContentType _selectedContentType = CategoryContentType.movies;
  int? _selectedCategoryId;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onContentTypeChanged(CategoryContentType type) {
    setState(() {
      _selectedContentType = type;
      _selectedCategoryId = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePlaylistId = ref.watch(activePlaylistIdProvider);
    final db = ref.watch(databaseProvider);

    if (activePlaylistId == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            'No playlist selected. Please add or select a playlist in Settings.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final categoriesStream = db.watchCategories(
      activePlaylistId,
      _selectedContentType.categoryTableType,
    );

    final contentStream = db.watchContentItems(
      activePlaylistId,
      _selectedContentType.contentItemType,
      categoryId: _selectedCategoryId,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header with Content Type Dropdown Selector ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Browse by Category',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explore ${_selectedContentType.label} collections across your playlist',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),

                // Content Type Selector Dropdown / Segmented Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: CategoryContentType.values.map((type) {
                      final isSelected = _selectedContentType == type;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: () => _onContentTypeChanged(type),
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  type.icon,
                                  size: 15,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  type.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Category Horizontal Strip ──
            StreamBuilder<List<CategoriesTableData>>(
              stream: categoriesStream,
              builder: (context, snap) {
                final categories = snap.data ?? [];
                if (categories.isEmpty) return const SizedBox.shrink();

                return SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      if (idx == 0) {
                        final isSelected = _selectedCategoryId == null;
                        return ChoiceChip(
                          label: Text('All ${_selectedContentType.label}'),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = null),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        );
                      }

                      final cat = categories[idx - 1];
                      final isSelected = _selectedCategoryId == cat.id;

                      return ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = cat.id),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            // ── Category Content Grid ──
            Expanded(
              child: StreamBuilder<List<ContentItemsTableData>>(
                stream: contentStream,
                builder: (context, snap) {
                  final items = snap.data ?? [];

                  if (snap.connectionState == ConnectionState.waiting &&
                      items.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectedContentType.icon,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No ${_selectedContentType.label} found in this category',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select another category or sync your playlist.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12.5),
                          ),
                        ],
                      ),
                    );
                  }

                  final isLive =
                      _selectedContentType == CategoryContentType.live;

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isLive ? 320 : 190,
                      childAspectRatio: isLive ? 2.4 : 0.65,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final item = items[idx];
                      if (isLive) {
                        return _LiveCategoryCard(
                          channel: item,
                          onTap: () => AdaptiveDetailsCoordinator.show(context,
                              content: item),
                        );
                      }
                      return _MediaCategoryCard(
                        content: item,
                        onTap: () => AdaptiveDetailsCoordinator.show(context,
                            content: item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaCategoryCard extends StatefulWidget {
  final ContentItemsTableData content;
  final VoidCallback onTap;

  const _MediaCategoryCard({required this.content, required this.onTap});

  @override
  State<_MediaCategoryCard> createState() => _MediaCategoryCardState();
}

class _MediaCategoryCardState extends State<_MediaCategoryCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final isActive = _isHovered || _isFocused;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onShowHoverHighlight: (h) => setState(() => _isHovered = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.diagonal3Values(
            _isFocused ? 1.04 : 1.0,
            _isFocused ? 1.04 : 1.0,
            1.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (_isHovered
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08)),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (c.posterUrl != null && c.posterUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: c.posterUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildFallback(c.title),
                )
              else
                _buildFallback(c.title),

              // Title Scrim
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    c.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              if (c.rating != null && c.rating! > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          c.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(String title) {
    return Container(
      color: const Color(0xFF1B1B22),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ),
    );
  }
}

class _LiveCategoryCard extends StatefulWidget {
  final ContentItemsTableData channel;
  final VoidCallback onTap;

  const _LiveCategoryCard({required this.channel, required this.onTap});

  @override
  State<_LiveCategoryCard> createState() => _LiveCategoryCardState();
}

class _LiveCategoryCardState extends State<_LiveCategoryCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final isActive = _isHovered || _isFocused;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onShowHoverHighlight: (h) => setState(() => _isHovered = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF22222C) : const Color(0xFF16161D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (_isHovered
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08)),
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (ch.posterUrl != null && ch.posterUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ch.posterUrl!,
                    width: 42,
                    height: 42,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => _buildLogoFallback(ch.title),
                  ),
                )
              else
                _buildLogoFallback(ch.title),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ch.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: Colors.redAccent),
                        SizedBox(width: 4),
                        Text(
                          'LIVE CHANNEL',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoFallback(String name) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'TV',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
