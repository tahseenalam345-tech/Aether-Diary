import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum DrawingTool { pen, marker, pencil, eraser }

class DrawingPoint {
  final Offset offset;
  final Paint paint;
  DrawingPoint({required this.offset, required this.paint});
}

class AetherDrawingCanvasDialog extends StatefulWidget {
  const AetherDrawingCanvasDialog({super.key});

  @override
  State<AetherDrawingCanvasDialog> createState() => _AetherDrawingCanvasDialogState();
}

class _AetherDrawingCanvasDialogState extends State<AetherDrawingCanvasDialog> {
  final List<List<DrawingPoint>> _strokes = [];
  List<DrawingPoint> _currentStroke = [];
  final List<List<DrawingPoint>> _redoStrokes = [];

  DrawingTool _selectedTool = DrawingTool.pen;
  Color _selectedColor = Colors.black; // 🌟 Pure Jet Black default
  double _strokeWidth = 3.0;

  final List<Color> _colors = [
    Colors.black, // Default
    const Color(0xFF1E293B), // Dark Slate
    const Color(0xFF1D4ED8), // Royal Blue
    const Color(0xFFDC2626), // Crimson Red
    const Color(0xFF059669), // Emerald Green
    const Color(0xFFD97706), // Amber Orange
    const Color(0xFF7C3AED), // Deep Violet
    const Color(0xFF0284C7), // Sky Blue
    const Color(0xFFDB2777), // Pink
  ];

  Paint _createPaint() {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (_selectedTool) {
      case DrawingTool.pen:
        paint.color = _selectedColor;
        paint.strokeWidth = _strokeWidth;
        break;
      case DrawingTool.marker:
        paint.color = _selectedColor.withValues(alpha: 0.45);
        paint.strokeWidth = _strokeWidth * 3.5;
        break;
      case DrawingTool.pencil:
        paint.color = _selectedColor.withValues(alpha: 0.75);
        paint.strokeWidth = _strokeWidth * 0.7;
        break;
      case DrawingTool.eraser:
        paint.color = Colors.white; // 🌟 Pure Whiteboard Eraser
        paint.strokeWidth = _strokeWidth * 5.0;
        break;
    }
    return paint;
  }

  Future<String?> _saveCanvasAsImage() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(900, 900);

      // 🌟 Draw crisp white background for the whiteboard
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // Draw all strokes
      for (final stroke in _strokes) {
        for (int i = 0; i < stroke.length - 1; i++) {
          canvas.drawLine(stroke[i].offset, stroke[i + 1].offset, stroke[i].paint);
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final buffer = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(buffer);

      return file.path;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C101E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              // 🌟 TOP TOOL HEADER
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131826),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Tool Selectors
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _toolButton(DrawingTool.pen, Icons.edit_rounded, "Pen"),
                            const SizedBox(width: 6),
                            _toolButton(DrawingTool.marker, Icons.brush_rounded, "Marker"),
                            const SizedBox(width: 6),
                            _toolButton(DrawingTool.pencil, Icons.mode_edit_outline_rounded, "Pencil"),
                            const SizedBox(width: 6),
                            _toolButton(DrawingTool.eraser, Icons.auto_fix_normal_outlined, "Eraser"),
                          ],
                        ),
                      ),
                    ),

                    // Undo / Redo / Clear Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.undo_rounded, color: Colors.white70, size: 20),
                          onPressed: _strokes.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _redoStrokes.add(_strokes.removeLast());
                                  });
                                },
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.redo_rounded, color: Colors.white70, size: 20),
                          onPressed: _redoStrokes.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _strokes.add(_redoStrokes.removeLast());
                                  });
                                },
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _strokes.clear();
                              _redoStrokes.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 🌟 INTERACTIVE WHITEBOARD CANVAS (CLEAN PURE WHITE)
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: ClipRect(
                    child: GestureDetector(
                      onPanStart: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final point = box.globalToLocal(details.globalPosition);
                        setState(() {
                          _currentStroke = [DrawingPoint(offset: point, paint: _createPaint())];
                          _strokes.add(_currentStroke);
                          _redoStrokes.clear();
                        });
                      },
                      onPanUpdate: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final point = box.globalToLocal(details.globalPosition);
                        setState(() {
                          _currentStroke.add(DrawingPoint(offset: point, paint: _createPaint()));
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _currentStroke = [];
                        });
                      },
                      child: CustomPaint(
                        painter: _AetherSketchPainter(strokes: _strokes),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),

              // 🌟 BOTTOM COLOR PALETTE & ACTIONS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131826),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(
                  children: [
                    // Palette
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _colors.map((c) {
                            final isSelected = _selectedColor == c && _selectedTool != DrawingTool.eraser;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedColor = c;
                                  if (_selectedTool == DrawingTool.eraser) _selectedTool = DrawingTool.pen;
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF38BDF8) : Colors.white24,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), blurRadius: 8)]
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Cancel
                    TextButton(
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ),

                    const SizedBox(width: 4),

                    // Save / Insert
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF060B14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        final path = await _saveCanvasAsImage();
                        if (context.mounted) {
                          Navigator.pop(context, path);
                        }
                      },
                      child: const Text("Insert Sketch", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton(DrawingTool tool, IconData icon, String label) {
    final isSelected = _selectedTool == tool;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTool = tool);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF38BDF8) : Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isSelected ? const Color(0xFF38BDF8) : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _AetherSketchPainter extends CustomPainter {
  final List<List<DrawingPoint>> strokes;
  _AetherSketchPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i].offset, stroke[i + 1].offset, stroke[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AetherSketchPainter oldDelegate) => true;
}
