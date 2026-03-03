import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/announcement_provider.dart';

// ── Loading Widget ────────────────────────────────────────────────────────────
class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingWidget({
    super.key,
    this.message,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty State Widget ────────────────────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: cs.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error Widget ──────────────────────────────────────────────────────────────
class AppErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 40, color: cs.error.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Custom App Bar ────────────────────────────────────────────────────────────
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.onBackPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: backgroundColor,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed ?? () => Navigator.pop(context),
            )
          : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ── Rating Bar ────────────────────────────────────────────────────────────────
class RatingBar extends StatelessWidget {
  final double rating;
  final int maxRating;
  final Color color;
  final double size;
  final bool isReadOnly;
  final Function(double)? onRatingChanged;

  const RatingBar({
    super.key,
    this.rating = 0.0,
    this.maxRating = 5,
    this.color = const Color(0xFFFFC107),
    this.size = 24,
    this.isReadOnly = true,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        maxRating,
        (index) => GestureDetector(
          onTap: isReadOnly ? null : () => onRatingChanged?.call(index + 1.0),
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: color,
            size: size,
          ),
        ),
      ),
    );
  }
}

// ── Custom Card ───────────────────────────────────────────────────────────────
class CustomCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final double borderRadius;
  final double elevation;

  const CustomCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderRadius = 16,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// ── Fade + Slide Entrance Animation ──────────────────────────────────────────
/// Wraps [child] in a fade-and-slide-up entrance animation.
/// [delay] staggers the animation when building lists.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 350),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Shimmer Placeholder ───────────────────────────────────────────────────────
/// A simple animated shimmer placeholder for loading states.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: Color.lerp(
            isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEF0F3),
            isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF8F9FA),
            _anim.value,
          ),
        ),
      ),
    );
  }
}

// ── Modern Notifications Bottom Sheet ────────────────────────────────────────
/// Shows a modern, dynamically-sized notifications panel as a bottom sheet.
/// [role] is one of 'admin', 'driver', 'student'.
void showAppNotificationsSheet(BuildContext context, String role) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NotificationsSheet(role: role),
  );
}

class _NotificationsSheet extends StatelessWidget {
  final String role;
  const _NotificationsSheet({required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surface = cs.surface;

    return Consumer<AnnouncementProvider>(
      builder: (context, announcementProvider, _) {
        final items = announcementProvider.visibleAnnouncementsFor(role);
        final hasItems = items.isNotEmpty;

        return Container(
          // Cap height at 70% of screen; shrink naturally when few items
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_outlined,
                          size: 20, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifications',
                              style: Theme.of(context).textTheme.titleLarge),
                          if (hasItems)
                            Text(
                              '${items.length} unread',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (hasItems)
                      TextButton.icon(
                        onPressed: () async {
                          await announcementProvider.clearAnnouncementsFor(role);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Clear all'),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.error,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: cs.outlineVariant),

              // ── Content: loading / empty / list
              if (announcementProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!hasItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Row(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 32, color: cs.onSurface.withValues(alpha: 0.25)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'No new notifications',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final ann = items[i];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: i * 50),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ann.title,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ann.description,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 8),
              // Bottom safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}
