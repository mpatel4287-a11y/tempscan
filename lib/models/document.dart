// ignore_for_file: unused_import

import 'dart:convert';
import 'package:flutter/material.dart';

enum DocumentType { pdf, image }

class ScannedDocument {
  final String id;
  String name;
  DateTime createdAt;
  DateTime modifiedAt;
  String? folderId;
  List<String> tags;
  String filePath;
  String? thumbnailPath;
  String? ocrText;
  int fileSize;
  DocumentType type;

  ScannedDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    this.folderId,
    this.tags = const [],
    required this.filePath,
    this.thumbnailPath,
    this.ocrText,
    required this.fileSize,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'folderId': folderId,
      'tags': tags,
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
      'ocrText': ocrText,
      'fileSize': fileSize,
      'type': type.name,
    };
  }

  factory ScannedDocument.fromJson(Map<String, dynamic> json) {
    return ScannedDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      folderId: json['folderId'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      filePath: json['filePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      ocrText: json['ocrText'] as String?,
      fileSize: json['fileSize'] as int,
      type: DocumentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DocumentType.pdf,
      ),
    );
  }

  ScannedDocument copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? folderId,
    List<String>? tags,
    String? filePath,
    String? thumbnailPath,
    String? ocrText,
    int? fileSize,
    DocumentType? type,
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      ocrText: ocrText ?? this.ocrText,
      fileSize: fileSize ?? this.fileSize,
      type: type ?? this.type,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} year(s) ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} month(s) ago';
    if (diff.inDays > 0) return '${diff.inDays} day(s) ago';
    if (diff.inHours > 0) return '${diff.inHours} hour(s) ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minute(s) ago';
    return 'Just now';
  }

  IconData get icon {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.image:
        return Icons.image;
    }
  }

  Color get iconColor {
    switch (type) {
      case DocumentType.pdf:
        return Colors.red;
      case DocumentType.image:
        return Colors.blue;
    }
  }
}
