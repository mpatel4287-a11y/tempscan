import 'package:flutter/material.dart';
import '../temp_storage/temp_image_manager.dart';

class AnnotationSheet extends StatefulWidget {
  final AnnotationType currentType;
  final Color currentColor;
  final double currentWidth;
  final Function(AnnotationType type, Color color, double width) onSettingsChanged;
  final VoidCallback onCancel;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const AnnotationSheet({
    super.key,
    required this.currentType,
    required this.currentColor,
    required this.currentWidth,
    required this.onSettingsChanged,
    required this.onCancel,
    required this.onUndo,
    required this.onClear,
  });

  @override
  State<AnnotationSheet> createState() => _AnnotationSheetState();
}

class _AnnotationSheetState extends State<AnnotationSheet> {
  late AnnotationType _selectedType;
  late Color _selectedColor;
  late double _selectedWidth;

  final List<Color> _colors = [
    Colors.yellowAccent,
    Colors.lightBlueAccent,
    Colors.lightGreenAccent,
    Colors.pinkAccent,
    Colors.orangeAccent,
    Colors.white,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentType;
    _selectedColor = widget.currentColor;
    _selectedWidth = widget.currentWidth;
  }

  void _notifyChange() {
    widget.onSettingsChanged(_selectedType, _selectedColor, _selectedWidth);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          
          // Tools & Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AnnotationType.values.map((type) => _buildToolIcon(type)).toList(),
                    ),
                  ),
                ),
                const VerticalDivider(color: Colors.white10),
                IconButton(icon: const Icon(Icons.undo, color: Colors.white, size: 20), onPressed: widget.onUndo),
                IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: widget.onCancel),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 24),

          // Color & Width Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Minimal horizontal color list
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      itemBuilder: (context, index) {
                        final color = _colors[index];
                        final isSelected = _selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedColor = color);
                            _notifyChange();
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Compact Slider
                Expanded(
                  flex: 2,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: _selectedWidth,
                      min: 2.0,
                      max: 20.0,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setState(() => _selectedWidth = val);
                        _notifyChange();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildToolIcon(AnnotationType type) {
    IconData icon;
    String label;
    switch (type) {
      case AnnotationType.highlight:
        icon = Icons.brush;
        label = 'Highlight';
        break;
      case AnnotationType.underline:
        icon = Icons.format_underlined;
        label = 'Underline';
        break;
      case AnnotationType.pen:
        icon = Icons.create;
        label = 'Pen';
        break;
      case AnnotationType.square:
        icon = Icons.crop_square;
        label = 'Square';
        break;
      case AnnotationType.circle:
        icon = Icons.circle_outlined;
        label = 'Circle';
        break;
      case AnnotationType.arrow:
        icon = Icons.trending_flat;
        label = 'Arrow';
        break;
      case AnnotationType.text:
        icon = Icons.text_fields;
        label = 'Text';
        break;
    }

    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedType = type);
        _notifyChange();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white70, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
