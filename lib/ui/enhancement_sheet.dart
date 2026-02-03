import 'package:flutter/material.dart';

class EnhancementSheet extends StatefulWidget {
  final double clarity;
  final double noiseReduction;
  final Function(double clarity, double noiseReduction) onChanged;
  final VoidCallback onCancel;

  const EnhancementSheet({
    super.key,
    required this.clarity,
    required this.noiseReduction,
    required this.onChanged,
    required this.onCancel,
  });

  @override
  State<EnhancementSheet> createState() => _EnhancementSheetState();
}

class _EnhancementSheetState extends State<EnhancementSheet> {
  late double _clarity;
  late double _noiseReduction;

  @override
  void initState() {
    super.initState();
    _clarity = widget.clarity;
    _noiseReduction = widget.noiseReduction;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Fine-Tune Quality',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),

          // Clarity Slider
          _buildSlider(
            label: 'Clarity (Sharpness)',
            icon: Icons.details,
            value: _clarity,
            onChanged: (val) {
              setState(() => _clarity = val);
              widget.onChanged(_clarity, _noiseReduction);
            },
          ),

          // Noise Reduction Slider
          _buildSlider(
            label: 'Noise Reduction',
            icon: Icons.waves,
            value: _noiseReduction,
            onChanged: (val) {
              setState(() => _noiseReduction = val);
              widget.onChanged(_clarity, _noiseReduction);
            },
          ),

          const SizedBox(height: 16),
          // Info Message
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Effects will be applied during final document generation. Preview may show limited detail.',
              style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 24),
          // Apply Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${(value * 100).toInt()}%', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
            ],
          ),
          Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            activeColor: Colors.blueAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
