import 'package:flutter/material.dart';

class SlideButton extends StatefulWidget {
  final String text;
  final VoidCallback onConfirm;
  final Color backgroundColor;
  final Color sliderColor;
  final IconData icon;
  final double height;

  const SlideButton({
    super.key,
    required this.text,
    required this.onConfirm,
    this.backgroundColor = Colors.blue,
    this.sliderColor = Colors.white,
    this.icon = Icons.arrow_forward,
    this.height = 60,
  });

  @override
  State<SlideButton> createState() => _SlideButtonState();
}

class _SlideButtonState extends State<SlideButton> {
  double _dragPosition = 0;
  bool _confirmed = false;

  @override
  void didUpdateWidget(SlideButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset when button properties change (e.g., text/color changes)
    if (oldWidget.text != widget.text || 
        oldWidget.backgroundColor != widget.backgroundColor) {
      setState(() {
        _dragPosition = 0;
        _confirmed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sliderSize = widget.height - 8;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = (trackWidth - sliderSize - 8).clamp(0.0, double.infinity);
        if (_dragPosition > maxDrag) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _dragPosition = maxDrag;
            });
          });
        }

        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                left: _dragPosition + 4,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_confirmed) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      _dragPosition = _dragPosition.clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_confirmed) return;
                    if (_dragPosition >= maxDrag * 0.9) {
                      setState(() {
                        _confirmed = true;
                        _dragPosition = maxDrag;
                      });
                      widget.onConfirm();
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _dragPosition = 0;
                            _confirmed = false;
                          });
                        }
                      });
                    } else {
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  child: Container(
                    width: sliderSize,
                    height: sliderSize,
                    decoration: BoxDecoration(
                      color: widget.sliderColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.backgroundColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
