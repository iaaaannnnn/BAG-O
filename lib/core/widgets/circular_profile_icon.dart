part of '../../app/app.dart';

class CircularProfileIcon extends StatefulWidget {
  const CircularProfileIcon({
    this.userName,
    this.photoUrl,
    this.radius = 20,
    this.borderColor,
    this.backgroundColor,
    this.textColor,
    this.badgeCount,
    this.showBadge = false,
    this.padding,
    this.tooltip,
    this.onTap,
    this.enableMenu = false,
    this.onMenuAction,
    Key? key,
  }) : super(key: key);

  final String? userName;
  final String? photoUrl;
  final double radius;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? textColor;
  final int? badgeCount;
  final bool showBadge;
  final EdgeInsets? padding;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool enableMenu;
  final ValueChanged<ProfileAction>? onMenuAction;

  @override
  State<CircularProfileIcon> createState() => _CircularProfileIconState();
}

class _CircularProfileIconState extends State<CircularProfileIcon> {
  final GlobalKey _anchorKey = GlobalKey();

  String get _initialLetter {
    final name = widget.userName?.trim();
    if (name != null && name.isNotEmpty) {
      return name.characters.first.toUpperCase();
    }
    return '?';
  }

  Future<void> _handleTap() async {
    if (widget.enableMenu) {
      final action = await _showPopupMenu();
      if (action != null) {
        widget.onMenuAction?.call(action);
      }
    } else {
      widget.onTap?.call();
    }
  }

  Future<ProfileAction?> _showPopupMenu() async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = _anchorKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(offset.dx, offset.dy + box.size.height, box.size.width, box.size.height),
      Offset.zero & overlay.size,
    );

    return showMenu<ProfileAction>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(value: ProfileAction.viewProfile, child: Text('View Profile')),
        PopupMenuItem(value: ProfileAction.settings, child: Text('Settings')),
        PopupMenuItem(value: ProfileAction.logout, child: Text('Logout')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = widget.borderColor ?? theme.colorScheme.outlineVariant;
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surfaceContainerHigh;
    final textColor = widget.textColor ?? theme.colorScheme.onSurfaceVariant;

    final double size = widget.radius * 2;

    final avatarFallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Text(
        _initialLetter,
        style: theme.textTheme.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600),
      ),
    );

    Widget avatarContent;
    final url = widget.photoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final base64String = url.split(',').last;
          final bytes = base64Decode(base64String);
          avatarContent = ClipOval(
            child: Image.memory(
              bytes,
              key: ValueKey(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => avatarFallback,
            ),
          );
        } catch (_) {
          avatarContent = avatarFallback;
        }
      } else {
        avatarContent = ClipOval(
          child: Image.network(
            url,
            key: ValueKey(url),
            width: size,
            height: size,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) => avatarFallback,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return avatarFallback;
            },
          ),
        );
      }
    } else {
      avatarContent = avatarFallback;
    }

    final badgeVisible = (widget.badgeCount != null && widget.badgeCount! > 0) || widget.showBadge;
    final badge = badgeVisible
        ? Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: widget.badgeCount != null && widget.badgeCount! > 0 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: widget.badgeCount != null && widget.badgeCount! > 0 ? BorderRadius.circular(10) : null,
                border: Border.all(color: theme.colorScheme.surface, width: 1),
              ),
              constraints: BoxConstraints(
                minWidth: widget.badgeCount != null && widget.badgeCount! > 0 ? 18 : 10,
                minHeight: widget.badgeCount != null && widget.badgeCount! > 0 ? 16 : 10,
              ),
              child: Center(
                child: widget.badgeCount != null && widget.badgeCount! > 0
                    ? Text(
                        widget.badgeCount! > 99 ? '99+' : widget.badgeCount!.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onError, height: 1),
                      )
                    : SizedBox(width: 6, height: 6, child: DecoratedBox(decoration: BoxDecoration(color: theme.colorScheme.onError, shape: BoxShape.circle))),
              ),
            ),
          )
        : const SizedBox.shrink();

    final core = Container(
      key: _anchorKey,
      padding: widget.padding,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: avatarContent),
      ),
    );

    final child = Stack(children: [core, badge]);

    final tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _handleTap,
        child: Tooltip(message: widget.tooltip ?? 'Profile', preferBelow: false, child: child),
      ),
    );

    return tappable;
  }
}

// Real data mode: always use live Firestore data
const bool kUseMockData = false;

// Empty mock placeholders (kept to avoid analyzer errors from leftover references)
const List<Map<String, dynamic>> kMockPendingRequests = <Map<String, dynamic>>[];
const List<Map<String, dynamic>> kMockResidents = <Map<String, dynamic>>[];
const List<Map<String, dynamic>> kMockComplaints = <Map<String, dynamic>>[];
const List<Map<String, dynamic>> kMockTransparencyDocs = <Map<String, dynamic>>[];

// Limits and quotas
// ignore: constant_identifier_names
const int MAX_TRANSPARENCY_UPLOAD_BYTES = 10 * 1024 * 1024; // 10 MB
// ignore: constant_identifier_names
const int MAX_REQUESTS_PER_DOC_PER_DAY = 2; // per-document-type per user per day
// ignore: constant_identifier_names
const int MAX_COMPLAINTS_PER_DAY = 2; // complaints per user per day


