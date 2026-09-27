import 'package:flutter/material.dart';

class SwipeActionTile extends StatefulWidget {
  const SwipeActionTile({
    required this.child,
    required this.actionLabel,
    required this.onAction,
    this.onTap,
    this.actionColor = const Color(0xFFFA5151),
    this.borderRadius = 14,
    super.key,
  });

  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onTap;
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
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: _actionWidth,
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
          child: AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ),
      ],
    ),
  );
}
