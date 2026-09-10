import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 🌟 AETHER LIQUID GLASS DROPDOWN 🌟
/// A fluid, glassmorphic dropdown with liquid ripple effects,
/// smooth spring expansion, backdrop blur, and glowing borders.
class AetherLiquidDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) itemLabel;
  final Widget Function(T)? itemBuilder;
  final String? hint;
  final IconData? icon;
  final Color accentColor;
  final double height;
  final EdgeInsetsGeometry padding;
  final bool isExpanded;
  final String? label;

  const AetherLiquidDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemLabel,
    this.itemBuilder,
    this.hint,
    this.icon,
    this.accentColor = const Color(0xFF38BDF8), // Default Sky
    this.height = 46,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    this.isExpanded = true,
    this.label,
  });

  @override
  State<AetherLiquidDropdown<T>> createState() => _AetherLiquidDropdownState<T>();
}

class _AetherLiquidDropdownState<T> extends State<AetherLiquidDropdown<T>> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  late Animation<double> _glowAnimation;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _glowAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    HapticFeedback.selectionClick();
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    _animController.forward();
  }

  void _closeDropdown() {
    _animController.reverse().then((_) {
      _removeOverlay();
      if (mounted) setState(() => _isOpen = false);
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - offset.dy - size.height;
    final showAbove = spaceBelow < 200 && offset.dy > spaceBelow;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss tap listener
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeDropdown,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: showAbove ? const Offset(0, -10) : Offset(0, size.height + 6),
              followerAnchor: showAbove ? Alignment.bottomLeft : Alignment.topLeft,
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scaleY: _expandAnimation.value.clamp(0.01, 1.0),
                    alignment: showAbove ? Alignment.bottomCenter : Alignment.topCenter,
                    child: Opacity(
                      opacity: _expandAnimation.value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  elevation: 12,
                  shadowColor: widget.accentColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C101E).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accentColor.withValues(alpha: 0.18),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: widget.items.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withValues(alpha: 0.05),
                            height: 1,
                            indent: 12,
                            endIndent: 12,
                          ),
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            final isSelected = widget.value == item;

                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.onChanged(item);
                                _closeDropdown();
                              },
                              splashColor: widget.accentColor.withValues(alpha: 0.2),
                              highlightColor: widget.accentColor.withValues(alpha: 0.1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? widget.accentColor.withValues(alpha: 0.16)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    if (isSelected) ...[
                                      Container(
                                        width: 4,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: widget.accentColor,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: widget.accentColor.withValues(alpha: 0.7),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: widget.itemBuilder != null
                                          ? widget.itemBuilder!(item)
                                          : Text(
                                              widget.itemLabel(item),
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.white70,
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: widget.accentColor,
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
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

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    final currentLabel = hasValue ? widget.itemLabel(widget.value as T) : (widget.hint ?? "Select");

    Widget dropdownWidget = CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: _isOpen
                    ? widget.accentColor.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOpen
                      ? widget.accentColor.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.08),
                  width: _isOpen ? 1.4 : 1.0,
                ),
                boxShadow: _isOpen
                    ? [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.22),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: _isOpen ? widget.accentColor : Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.isExpanded)
                    Expanded(
                      child: Text(
                        currentLabel,
                        style: TextStyle(
                          color: hasValue ? Colors.white : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Text(
                      currentLabel,
                      style: TextStyle(
                        color: hasValue ? Colors.white : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _isOpen ? widget.accentColor : Colors.white54,
                      size: 18,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (widget.label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label!.toUpperCase(),
            style: TextStyle(
              color: widget.accentColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          dropdownWidget,
        ],
      );
    }

    return dropdownWidget;
  }
}
