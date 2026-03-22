// ignore_for_file: prefer_collection_literals

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/automation_rule.dart';
import '../models/document.dart';

class AutomationService {
  static const String _rulesKey = 'automation_rules';

  static AutomationService? _instance;
  static AutomationService get instance => _instance ??= AutomationService._();

  AutomationService._();

  List<AutomationRule> _rules = [];

  List<AutomationRule> get rules => List.unmodifiable(_rules);
  List<AutomationRule> get enabledRules =>
      _rules.where((r) => r.isEnabled).toList();

  Future<void> initialize() async {
    await _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rulesJson = prefs.getString(_rulesKey);
      if (rulesJson != null) {
        final List<dynamic> decoded = _parseJsonList(rulesJson);
        _rules = decoded
            .map((r) => AutomationRule.fromJson(r as Map<String, dynamic>))
            .toList();
      }

      if (_rules.isEmpty) {
        _rules = AutomationRule.defaults;
        await _saveRules();
      }
    } catch (e) {
      _rules = AutomationRule.defaults;
    }
  }

  List<dynamic> _parseJsonList(String json) {
    // Simple JSON array parsing
    if (json.isEmpty || json == 'null') return [];
    final List<dynamic> result = [];
    // Use basic parsing - in production, use dart:convert
    int depth = 0;
    int start = -1;
    for (int i = 0; i < json.length; i++) {
      if (json[i] == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (json[i] == '}') {
        depth--;
        if (depth == 0 && start != -1) {
          result.add(_parseJsonObject(json.substring(start, i + 1)));
          start = -1;
        }
      }
    }
    return result;
  }

  Map<String, dynamic> _parseJsonObject(String json) {
    final Map<String, dynamic> result = {};
    // Remove outer braces
    String inner = json.trim();
    if (inner.startsWith('{') && inner.endsWith('}')) {
      inner = inner.substring(1, inner.length - 1);
    }
    // Parse key-value pairs
    String key = '';
    String value = '';
    bool inKey = true;
    bool inString = false;
    bool escapeNext = false;

    for (int i = 0; i < inner.length; i++) {
      final char = inner[i];

      if (escapeNext) {
        if (inKey) {
          key += char;
        } else {
          value += char;
        }
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        escapeNext = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        continue;
      }

      if (!inString) {
        if (char == ':') {
          inKey = false;
          value = '';
        } else if (char == ',') {
          if (key.isNotEmpty) {
            result[_parseValue(key)] = _parseValue(value);
          }
          key = '';
          value = '';
          inKey = true;
        } else if (char != ' ' && char != '\n' && char != '\t') {
          if (inKey) {
            key += char;
          } else {
            value += char;
          }
        }
      } else {
        if (inKey) {
          key += char;
        } else {
          value += char;
        }
      }
    }

    if (key.isNotEmpty) {
      result[_parseValue(key)] = _parseValue(value);
    }

    return result;
  }

  String _parseValue(String val) {
    val = val.trim();
    if (val.startsWith('"') && val.endsWith('"')) {
      return val.substring(1, val.length - 1);
    }
    if (val == 'true') return 'true';
    if (val == 'false') return 'false';
    if (val == 'null') return 'null';
    return val;
  }

  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = '[${_rules.map((r) => r.toJson().toString()).join(',')}]';
    await prefs.setString(_rulesKey, rulesJson);
  }

  Future<void> addRule(AutomationRule rule) async {
    _rules.add(rule);
    await _saveRules();
  }

  Future<void> updateRule(AutomationRule rule) async {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _rules[index] = rule;
      await _saveRules();
    }
  }

  Future<void> deleteRule(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _saveRules();
  }

  Future<void> toggleRule(String id) async {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index != -1) {
      _rules[index] = _rules[index].copyWith(
        isEnabled: !_rules[index].isEnabled,
      );
      await _saveRules();
    }
  }

  // Execute automation rules for a document
  Future<ScannedDocument?> executeRules({
    required ScannedDocument document,
    required RuleTrigger trigger,
  }) async {
    final applicableRules = enabledRules
        .where((r) => r.trigger == trigger)
        .toList();

    if (applicableRules.isEmpty) return document;

    ScannedDocument currentDoc = document;

    for (final rule in applicableRules) {
      currentDoc = await _executeRule(rule, currentDoc);
    }

    return currentDoc;
  }

  Future<ScannedDocument> _executeRule(
    AutomationRule rule,
    ScannedDocument doc,
  ) async {
    for (final action in rule.actions) {
      switch (action) {
        case RuleAction.autoRename:
          if (rule.renamePattern != null) {
            final newName = _generateName(rule.renamePattern!, doc);
            doc = doc.copyWith(name: newName, modifiedAt: DateTime.now());
          }
          break;
        case RuleAction.autoTag:
          if (rule.tags != null && rule.tags!.isNotEmpty) {
            final newTags = [...doc.tags, ...rule.tags!].toSet().toList();
            doc = doc.copyWith(tags: newTags, modifiedAt: DateTime.now());
          }
          break;
        case RuleAction.autoMoveToFolder:
          if (rule.folderId != null) {
            doc = doc.copyWith(
              folderId: rule.folderId,
              modifiedAt: DateTime.now(),
            );
          }
          break;
        case RuleAction.autoEnhance:
        case RuleAction.autoExport:
        case RuleAction.autoPassword:
          // These actions require additional processing
          // and are handled in the export/enhance flow
          break;
      }
    }
    return doc;
  }

  String _generateName(String pattern, ScannedDocument doc) {
    final now = doc.createdAt;
    String name = pattern;

    name = name.replaceAll(
      '{date}',
      '${now.year}-${_pad(now.month)}-${_pad(now.day)}',
    );
    name = name.replaceAll('{time}', '${_pad(now.hour)}-${_pad(now.minute)}');
    name = name.replaceAll(
      '{timestamp}',
      now.millisecondsSinceEpoch.toString(),
    );
    name = name.replaceAll('{original}', doc.name);

    // Add file extension if not present
    if (!name.contains('.')) {
      final ext = doc.type == DocumentType.pdf ? '.pdf' : '.jpg';
      name += ext;
    }

    return name;
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  // Get rules by trigger
  List<AutomationRule> getRulesByTrigger(RuleTrigger trigger) {
    return _rules.where((r) => r.trigger == trigger).toList();
  }

  // Reset to default rules
  Future<void> resetToDefaults() async {
    _rules = AutomationRule.defaults;
    await _saveRules();
  }

  // Export rules to file
  Future<String> exportRules() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/automation_rules.json');
    final content = '[${_rules.map((r) => _encodeRule(r)).join(',')}]';
    await file.writeAsString(content);
    return file.path;
  }

  String _encodeRule(AutomationRule r) {
    return '{"id":"${r.id}","name":"${r.name}","trigger":"${r.trigger.name}","actions":[${r.actions.map((a) => '"${a.name}"').join(',')}],"isEnabled":${r.isEnabled},"renamePattern":"${r.renamePattern ?? ''}"}';
  }

  // Get statistics
  Map<String, dynamic> getStats() {
    return {
      'totalRules': _rules.length,
      'enabledRules': _rules.where((r) => r.isEnabled).length,
      'rulesByTrigger': {
        'afterScan': _rules
            .where((r) => r.trigger == RuleTrigger.afterScan)
            .length,
        'afterOcr': _rules
            .where((r) => r.trigger == RuleTrigger.afterOcr)
            .length,
        'manual': _rules.where((r) => r.trigger == RuleTrigger.manual).length,
      },
    };
  }
}
