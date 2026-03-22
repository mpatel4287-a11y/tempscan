// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class DocumentFolder {
  final String id;
  String name;
  String? parentId;
  DateTime createdAt;
  Color color;
  int documentCount;

  DocumentFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    this.color = Colors.blue,
    this.documentCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'color': color.toHex(),
      'documentCount': documentCount,
    };
  }

  factory DocumentFolder.fromJson(Map<String, dynamic> json) {
    return DocumentFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      color: ColorExtension.fromHex(json['color'] as String? ?? '#2196F3'),
      documentCount: json['documentCount'] as int? ?? 0,
    );
  }

  DocumentFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    DateTime? createdAt,
    Color? color,
    int? documentCount,
  }) {
    return DocumentFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      documentCount: documentCount ?? this.documentCount,
    );
  }
}

// Color extension for hex conversion
extension ColorExtension on Color {
  String toHex() {
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

// Predefined folder colors
class FolderColors {
  static const List<Color> available = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];
}

// Predefined tags
class PredefinedTags {
  static const List<String> all = [
    'Bills',
    'IDs',
    'Notes',
    'Work',
    'Personal',
    'Medical',
    'Financial',
    'Travel',
    'Education',
    'Receipts',
  ];
}
