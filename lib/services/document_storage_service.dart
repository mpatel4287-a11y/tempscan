import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';
import '../models/folder.dart';

class DocumentStorageService {
  static const String _documentsKey = 'scanned_documents';
  static const String _foldersKey = 'document_folders';
  static const String _tagsKey = 'custom_tags';
  
  static DocumentStorageService? _instance;
  static DocumentStorageService get instance => _instance ??= DocumentStorageService._();
  
  DocumentStorageService._();
  
  List<ScannedDocument> _documents = [];
  List<DocumentFolder> _folders = [];
  Set<String> _customTags = {};
  
  List<ScannedDocument> get documents => List.unmodifiable(_documents);
  List<DocumentFolder> get folders => List.unmodifiable(_folders);
  Set<String> get customTags => Set.unmodifiable(_customTags);
  
  Future<void> initialize() async {
    await _loadDocuments();
    await _loadFolders();
    await _loadTags();
  }
  
  Future<void> _loadDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final docsJson = prefs.getString(_documentsKey);
      if (docsJson != null) {
        final List<dynamic> decoded = jsonDecode(docsJson);
        _documents = decoded
            .map((doc) => ScannedDocument.fromJson(doc as Map<String, dynamic>))
            .where((doc) => File(doc.filePath).existsSync())
            .toList();
      }
    } catch (e) {
      _documents = [];
    }
  }
  
  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final docsJson = jsonEncode(_documents.map((doc) => doc.toJson()).toList());
    await prefs.setString(_documentsKey, docsJson);
  }
  
  Future<void> addDocument(ScannedDocument document) async {
    _documents.insert(0, document);
    await _saveDocuments();
    await _updateFolderCounts();
  }
  
  Future<void> updateDocument(ScannedDocument document) async {
    final index = _documents.indexWhere((doc) => doc.id == document.id);
    if (index != -1) {
      _documents[index] = document;
      await _saveDocuments();
    }
  }
  
  Future<void> deleteDocument(String id) async {
    _documents.removeWhere((doc) => doc.id == id);
    await _saveDocuments();
    await _updateFolderCounts();
  }
  
  ScannedDocument? getDocument(String id) {
    try {
      return _documents.firstWhere((doc) => doc.id == id);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> _loadFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = prefs.getString(_foldersKey);
      if (foldersJson != null) {
        final List<dynamic> decoded = jsonDecode(foldersJson);
        _folders = decoded
            .map((folder) => DocumentFolder.fromJson(folder as Map<String, dynamic>))
            .toList();
      }
      
      if (_folders.isEmpty) {
        _folders = [
          DocumentFolder(id: 'folder_bills', name: 'Bills', createdAt: DateTime.now(), color: Colors.orange),
          DocumentFolder(id: 'folder_ids', name: 'IDs', createdAt: DateTime.now(), color: Colors.blue),
          DocumentFolder(id: 'folder_notes', name: 'Notes', createdAt: DateTime.now(), color: Colors.green),
          DocumentFolder(id: 'folder_work', name: 'Work', createdAt: DateTime.now(), color: Colors.purple),
        ];
        await _saveFolders();
      }
    } catch (e) {
      _folders = [];
    }
  }
  
  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = jsonEncode(_folders.map((folder) => folder.toJson()).toList());
    await prefs.setString(_foldersKey, foldersJson);
  }
  
  Future<void> _updateFolderCounts() async {
    for (int i = 0; i < _folders.length; i++) {
      final folder = _folders[i];
      final count = _documents.where((doc) => doc.folderId == folder.id).length;
      _folders[i] = folder.copyWith(documentCount: count);
    }
    await _saveFolders();
  }
  
  Future<void> addFolder(DocumentFolder folder) async {
    _folders.add(folder);
    await _saveFolders();
  }
  
  Future<void> updateFolder(DocumentFolder folder) async {
    final index = _folders.indexWhere((f) => f.id == folder.id);
    if (index != -1) {
      _folders[index] = folder;
      await _saveFolders();
    }
  }
  
  Future<void> deleteFolder(String id) async {
    for (int i = 0; i < _documents.length; i++) {
      if (_documents[i].folderId == id) {
        _documents[i] = _documents[i].copyWith(folderId: null);
      }
    }
    await _saveDocuments();
    _folders.removeWhere((folder) => folder.id == id);
    await _saveFolders();
  }
  
  DocumentFolder? getFolder(String id) {
    try {
      return _folders.firstWhere((folder) => folder.id == id);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> _loadTags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tagsJson = prefs.getString(_tagsKey);
      if (tagsJson != null) {
        _customTags = Set<String>.from(jsonDecode(tagsJson));
      }
    } catch (e) {
      _customTags = {};
    }
  }
  
  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    final tagsJson = jsonEncode(_customTags.toList());
    await prefs.setString(_tagsKey, tagsJson);
  }
  
  Future<void> addTag(String tag) async {
    _customTags.add(tag);
    await _saveTags();
  }
  
  Future<void> removeTag(String tag) async {
    _customTags.remove(tag);
    await _saveTags();
  }
  
  List<ScannedDocument> searchDocuments({String? query, String? folderId, List<String>? tags, DateTime? fromDate, DateTime? toDate}) {
    return _documents.where((doc) {
      if (query != null && query.isNotEmpty) {
        final searchLower = query.toLowerCase();
        final nameMatch = doc.name.toLowerCase().contains(searchLower);
        final ocrMatch = doc.ocrText?.toLowerCase().contains(searchLower) ?? false;
        if (!nameMatch && !ocrMatch) return false;
      }
      if (folderId != null && doc.folderId != folderId) return false;
      if (tags != null && tags.isNotEmpty) {
        final hasAnyTag = tags.any((tag) => doc.tags.contains(tag));
        if (!hasAnyTag) return false;
      }
      if (fromDate != null && doc.createdAt.isBefore(fromDate)) return false;
      if (toDate != null && doc.createdAt.isAfter(toDate)) return false;
      return true;
    }).toList();
  }
  
  List<ScannedDocument> getDocumentsInFolder(String? folderId) {
    return _documents.where((doc) => doc.folderId == folderId).toList();
  }
  
  List<ScannedDocument> getDocumentsByTag(String tag) {
    return _documents.where((doc) => doc.tags.contains(tag)).toList();
  }
  
  List<ScannedDocument> getRecentDocuments({int limit = 10}) {
    final sorted = List<ScannedDocument>.from(_documents)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }
  
  Set<String> getUsedTags() {
    final allTags = <String>{};
    for (final doc in _documents) {
      allTags.addAll(doc.tags);
    }
    return allTags;
  }
  
  Future<void> addTagToDocument(String docId, String tag) async {
    final index = _documents.indexWhere((doc) => doc.id == docId);
    if (index != -1) {
      final doc = _documents[index];
      if (!doc.tags.contains(tag)) {
        final newTags = List<String>.from(doc.tags)..add(tag);
        _documents[index] = doc.copyWith(tags: newTags);
        await _saveDocuments();
      }
    }
  }
  
  Future<void> removeTagFromDocument(String docId, String tag) async {
    final index = _documents.indexWhere((doc) => doc.id == docId);
    if (index != -1) {
      final doc = _documents[index];
      final newTags = List<String>.from(doc.tags)..remove(tag);
      _documents[index] = doc.copyWith(tags: newTags);
      await _saveDocuments();
    }
  }
  
  Future<void> moveDocumentToFolder(String docId, String? folderId) async {
    final index = _documents.indexWhere((doc) => doc.id == docId);
    if (index != -1) {
      _documents[index] = _documents[index].copyWith(folderId: folderId, modifiedAt: DateTime.now());
      await _saveDocuments();
      await _updateFolderCounts();
    }
  }
  
  Future<void> renameDocument(String docId, String newName) async {
    final index = _documents.indexWhere((doc) => doc.id == docId);
    if (index != -1) {
      _documents[index] = _documents[index].copyWith(name: newName, modifiedAt: DateTime.now());
      await _saveDocuments();
    }
  }
  
  Map<String, dynamic> getStorageStats() {
    return {
      'totalDocuments': _documents.length,
      'totalFolders': _folders.length,
      'totalSize': _documents.fold<int>(0, (sum, doc) => sum + doc.fileSize),
      'documentsByType': {
        'pdf': _documents.where((d) => d.type == DocumentType.pdf).length,
        'image': _documents.where((d) => d.type == DocumentType.image).length,
      },
    };
  }
  
  Future<void> clearAll() async {
    _documents.clear();
    _folders.clear();
    _customTags.clear();
    await _saveDocuments();
    await _saveFolders();
    await _saveTags();
  }
}
