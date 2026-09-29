import 'package:flutter/material.dart';

class SwipeActionTile extends StatefulWidget {
  const SwipeActionTile({
    required this.child,
    required this.actionLabel,
    required this.onAction,
    this.onTap,
    this.onLongPress,
    this.actionColor = const Color(0xFFFA5151),
    this.borderRadius = 14,
    super.key,
  });

  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
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
        Positioned.fill(child: ColoredBox(color: widget.actionColor)),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _dragging = true,
          onHorizontalDragUpdate: (DragUpdateDetails details) => setState(() {
            _offset = (_offset + details.delta.dx).clamp(-_actionWidth, 0);
          }),
          onHorizontalDragEnd: (_) => setState(() {
            _dragging = false;
            _offset = _offset < -_actionWidth / 2 ? -_actionWidth : 0;
          }),
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
            ignoring: _offset > -_actionWidth / 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _offset <= -_actionWidth / 2 ? 1 : 0,
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
