import 'package:flutter/material.dart';

class SwipeActionTile extends StatefulWidget {
  const SwipeActionTile({
    required this.child,
    required this.actionLabel,
    required this.onAction,
    this.onTap,
    this.onLongPress,
    this.onSwipeRight,
    this.rightSwipeSelected = false,
    this.swipeEnabled = true,
    this.leftSwipeEnabled = true,
    this.actionColor = const Color(0xFFFA5151),
    this.borderRadius = 14,
    super.key,
  });

  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeRight;
  final bool rightSwipeSelected;
  final bool swipeEnabled;
  final bool leftSwipeEnabled;
  final Color actionColor;
  final double borderRadius;

  @override
  State<SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<SwipeActionTile> {
  static const double _actionWidth = 76;
  double _offset = 0;
  bool _dragging = false;

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.borderRadius),
    child: Stack(
      children: <Widget>[
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: _actionWidth,
          child: ColoredBox(color: widget.actionColor),
        ),
        if (widget.onSwipeRight != null)
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            width: 54,
            child: Center(
              child: Icon(
                widget.rightSwipeSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: widget.rightSwipeSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.swipeEnabled
              ? (_) => _dragging = true
              : null,
          onHorizontalDragUpdate: widget.swipeEnabled
              ? (DragUpdateDetails details) => setState(() {
                  final double max = widget.onSwipeRight == null ? 0 : 54;
                  _offset = (_offset + details.delta.dx).clamp(
                    widget.leftSwipeEnabled ? -_actionWidth : 0,
                    max,
                  );
                })
              : null,
          onHorizontalDragEnd: widget.swipeEnabled
              ? (_) {
                  final bool select = _offset > 27;
                  setState(() {
                    _dragging = false;
                    _offset =
                        widget.leftSwipeEnabled && _offset < -_actionWidth / 2
                        ? -_actionWidth
                        : 0;
                  });
                  if (select) widget.onSwipeRight?.call();
                }
              : null,
          onTap: () {
            if (_dragging) return;
            if (_offset != 0) {
              _close();
            } else {
              widget.onTap?.call();
            }
          },
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: _actionWidth,
          child: IgnorePointer(
            ignoring: !widget.leftSwipeEnabled || _offset > -_actionWidth / 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: widget.leftSwipeEnabled && _offset <= -_actionWidth / 2
                  ? 1
                  : 0,
              child: Material(
                color: widget.actionColor,
                child: InkWell(
                  onTap: () {
                    _close();
                    widget.onAction();
                  },
                  child: Center(
                    child: Text(
                      widget.actionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
