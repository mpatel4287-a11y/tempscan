// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Modern rotate sheet with dark theme
class RotateSheet extends StatefulWidget {
  final int currentRotation;
  final ValueChanged<int> onRotate;
  final String? imagePath;

  const RotateSheet({
    super.key,
    required this.currentRotation,
    required this.onRotate,
    this.imagePath,
  });

  @override
  State<RotateSheet> createState() => _RotateSheetState();
}

class _RotateSheetState extends State<RotateSheet> {
  late int _tempRotation;
  bool _showCustomAngle = false;

  @override
  void initState() {
    super.initState();
    _tempRotation = widget.currentRotation;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rotate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showCustomAngle = !_showCustomAngle;
                  });
                },
                icon: Icon(
                  _showCustomAngle ? Icons.rotate_right : Icons.tune,
                  size: 18,
                  color: Colors.blue,
                ),
                label: Text(
                  _showCustomAngle ? 'Quick' : 'Custom',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_showCustomAngle)
            _buildCustomAngleSection()
          else
            _buildQuickRotateSection(),

          const SizedBox(height: 24),

          // Apply and Reset buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onRotate(-widget.currentRotation);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onRotate(_tempRotation - widget.currentRotation);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRotateSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RotateOptionButton(
          icon: Icons.rotate_90_degrees_ccw,
          label: 'Left',
          onTap: () {
            setState(() {
              _tempRotation = (_tempRotation - 90) % 360;
            });
          },
        ),
        _RotateOptionButton(
          icon: Icons.rotate_90_degrees_cw,
          label: 'Right',
          onTap: () {
            setState(() {
              _tempRotation = (_tempRotation + 90) % 360;
            });
          },
        ),
        _RotateOptionButton(
          icon: Icons.flip,
          label: 'Flip',
          onTap: () {
            setState(() {
              _tempRotation = (_tempRotation + 180) % 360;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCustomAngleSection() {
    return Column(
      children: [
        // Rotation preview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Show image preview if available
              if (widget.imagePath != null)
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Transform.rotate(
                    angle: _tempRotation * math.pi / 180,
                    child: Image.file(
                      File(widget.imagePath!),
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.image,
                    size: 40,
                    color: Colors.white38,
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$_tempRotation°',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Custom angle slider
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  const Text(
                    'Custom Angle',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_tempRotation°',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: _tempRotation.toDouble(),
                min: -180,
                max: 180,
                divisions: 72,
                activeColor: Colors.blue,
                inactiveColor: Colors.white24,
                onChanged: (value) {
                  setState(() {
                    _tempRotation = value.round();
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '-180°',
                    style: TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                  Text(
                    '0°',
                    style: TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                  Text(
                    '+180°',
                    style: TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Preset buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PresetChip(45, '45° Left'),
            _PresetChip(-45, '45° Right'),
            _PresetChip(90, '90° Left'),
            _PresetChip(-90, '90° Right'),
          ],
        ),
      ],
    );
  }

  Widget _PresetChip(int angle, String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setState(() {
          _tempRotation = angle;
        });
      },
      backgroundColor: _tempRotation == angle
          ? Colors.blue
          : const Color(0xFF3A3A3A),
      labelStyle: TextStyle(
        color: _tempRotation == angle ? Colors.white : Colors.white70,
      ),
      side: BorderSide(
        color: _tempRotation == angle ? Colors.blue : Colors.white24,
      ),
    );
  }
}

/// Modern rotate option button
class _RotateOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RotateOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.15),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, size: 28, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
