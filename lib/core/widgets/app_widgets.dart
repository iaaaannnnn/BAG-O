part of '../../app/app.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionPanel extends StatelessWidget {
  const SectionPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({this.message = 'Loading', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          Text(message, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('BAG-O')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class DashboardActionTile extends StatefulWidget {
  const DashboardActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<DashboardActionTile> createState() => _DashboardActionTileState();
}

class _DashboardActionTileState extends State<DashboardActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Card(
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          onHighlightChanged: (isHighlighted) {
            if (_pressed != isHighlighted) {
              setState(() => _pressed = isHighlighted);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(widget.icon, size: 22, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.title.replaceAll('\n', ' '),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
