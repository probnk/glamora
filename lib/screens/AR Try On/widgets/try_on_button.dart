import 'package:flutter/material.dart';
import 'package:glamora/models/productModel.dart';
import 'package:provider/provider.dart';

import '../ar_try_on_screen.dart';

class ARTryOnButton extends StatefulWidget {
  final ClothingProductModel product;
  final bool isAvailable;
  final VoidCallback? onPressed;
  final bool showLoading;
  final bool isPreloading;

  const ARTryOnButton({
    Key? key,
    required this.product,
    this.isAvailable = true,
    this.onPressed,
    this.showLoading = false,
    this.isPreloading = false,
  }) : super(key: key);

  @override
  _ARTryOnButtonState createState() => _ARTryOnButtonState();
}

class _ARTryOnButtonState extends State<ARTryOnButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.showLoading) {
      _startLoading();
    }
  }

  void _startLoading() {
    setState(() {
      _isLoading = true;
    });
    _animationController.repeat(reverse: true);
  }

  void _stopLoading() {
    setState(() {
      _isLoading = false;
    });
    _animationController.stop();
  }

  @override
  void didUpdateWidget(ARTryOnButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showLoading != oldWidget.showLoading) {
      if (widget.showLoading) {
        _startLoading();
      } else {
        _stopLoading();
      }
    }
  }

  void _handleTap() async {
    if (!widget.isAvailable || _isLoading) return;

    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Add a slight delay for better UX
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      // Navigate to AR screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ARTryOnScreen(
            product: widget.product,
          ),
        ),
      );

    } catch (e) {
      print('Error navigating to AR screen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start AR: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onHover(bool isHovering) {
    setState(() {
      _isHovering = isHovering;
    });

    if (isHovering) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: _handleTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isAvailable
                    ? [
                  Colors.blueAccent,
                  Colors.purpleAccent,
                ]
                    : [
                  Colors.grey[400]!,
                  Colors.grey[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(_isHovering ? 0.4 : 0.2),
                  blurRadius: _isHovering ? 20 : 10,
                  spreadRadius: _isHovering ? 2 : 1,
                  offset: Offset(0, _isHovering ? 4 : 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Button content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading || widget.isPreloading)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      else
                        Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 24,
                        ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Virtual Try-On',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.isPreloading)
                              Text(
                                'Preparing AR...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              )
                            else
                              Text(
                                widget.isAvailable
                                    ? 'See how it looks on you'
                                    : 'AR not available for this product',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                          ],
                        ),
                      ),

                      if (!_isLoading && !widget.isPreloading)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),

                // Loading overlay
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ),

                // Disabled overlay
                if (!widget.isAvailable)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.block,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// Simple Icon Button for AR
class ARTryOnIconButton extends StatelessWidget {
  final ClothingProductModel product;
  final VoidCallback? onTap;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  const ARTryOnIconButton({
    Key? key,
    required this.product,
    this.onTap,
    this.size = 56,
    this.backgroundColor = Colors.blueAccent,
    this.iconColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(Icons.camera_alt_rounded,
          color: iconColor,
          size: size * 0.5,
        ),
        onPressed:() {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ARTryOnScreen(
                  product: product,
                ),
              ),
            );
        },
        splashRadius: size * 0.6,
      ),
    );
  }
}