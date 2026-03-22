
enum RuleTrigger { afterScan, afterOcr, manual }

enum RuleAction {
  autoRename,
  autoExport,
  autoEnhance,
  autoPassword,
  autoTag,
  autoMoveToFolder,
}

enum ExportFormat { pdf, jpg, png }

class AutomationRule {
  final String id;
  String name;
  RuleTrigger trigger;
  List<RuleAction> actions;
  bool isEnabled;

  // Action-specific settings
  String? renamePattern;
  ExportFormat? exportFormat;
  String? exportPath;
  bool? enhanceEnabled;
  String? password;
  List<String>? tags;
  String? folderId;

  // Quality settings
  int? jpgQuality;
  int? pngCompression;
  bool? highResolution;

  AutomationRule({
    required this.id,
    required this.name,
    required this.trigger,
    this.actions = const [],
    this.isEnabled = true,
    this.renamePattern,
    this.exportFormat,
    this.exportPath,
    this.enhanceEnabled,
    this.password,
    this.tags,
    this.folderId,
    this.jpgQuality,
    this.pngCompression,
    this.highResolution,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trigger': trigger.name,
      'actions': actions.map((a) => a.name).toList(),
      'isEnabled': isEnabled,
      'renamePattern': renamePattern,
      'exportFormat': exportFormat?.name,
      'exportPath': exportPath,
      'enhanceEnabled': enhanceEnabled,
      'password': password,
      'tags': tags,
      'folderId': folderId,
      'jpgQuality': jpgQuality,
      'pngCompression': pngCompression,
      'highResolution': highResolution,
    };
  }

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'] as String,
      name: json['name'] as String,
      trigger: RuleTrigger.values.firstWhere(
        (e) => e.name == json['trigger'],
        orElse: () => RuleTrigger.afterScan,
      ),
      actions:
          (json['actions'] as List<dynamic>?)
              ?.map(
                (a) => RuleAction.values.firstWhere(
                  (e) => e.name == a,
                  orElse: () => RuleAction.autoRename,
                ),
              )
              .toList() ??
          [],
      isEnabled: json['isEnabled'] as bool? ?? true,
      renamePattern: json['renamePattern'] as String?,
      exportFormat: json['exportFormat'] != null
          ? ExportFormat.values.firstWhere(
              (e) => e.name == json['exportFormat'],
              orElse: () => ExportFormat.pdf,
            )
          : null,
      exportPath: json['exportPath'] as String?,
      enhanceEnabled: json['enhanceEnabled'] as bool?,
      password: json['password'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      folderId: json['folderId'] as String?,
      jpgQuality: json['jpgQuality'] as int?,
      pngCompression: json['pngCompression'] as int?,
      highResolution: json['highResolution'] as bool?,
    );
  }

  AutomationRule copyWith({
    String? id,
    String? name,
    RuleTrigger? trigger,
    List<RuleAction>? actions,
    bool? isEnabled,
    String? renamePattern,
    ExportFormat? exportFormat,
    String? exportPath,
    bool? enhanceEnabled,
    String? password,
    List<String>? tags,
    String? folderId,
    int? jpgQuality,
    int? pngCompression,
    bool? highResolution,
  }) {
    return AutomationRule(
      id: id ?? this.id,
      name: name ?? this.name,
      trigger: trigger ?? this.trigger,
      actions: actions ?? this.actions,
      isEnabled: isEnabled ?? this.isEnabled,
      renamePattern: renamePattern ?? this.renamePattern,
      exportFormat: exportFormat ?? this.exportFormat,
      exportPath: exportPath ?? this.exportPath,
      enhanceEnabled: enhanceEnabled ?? this.enhanceEnabled,
      password: password ?? this.password,
      tags: tags ?? this.tags,
      folderId: folderId ?? this.folderId,
      jpgQuality: jpgQuality ?? this.jpgQuality,
      pngCompression: pngCompression ?? this.pngCompression,
      highResolution: highResolution ?? this.highResolution,
    );
  }

  String get triggerDisplayName {
    switch (trigger) {
      case RuleTrigger.afterScan:
        return 'After Scan';
      case RuleTrigger.afterOcr:
        return 'After OCR';
      case RuleTrigger.manual:
        return 'Manual';
    }
  }

  String get actionsDisplayName {
    if (actions.isEmpty) return 'No actions';
    return actions
        .map((a) {
          switch (a) {
            case RuleAction.autoRename:
              return 'Rename';
            case RuleAction.autoExport:
              return 'Export';
            case RuleAction.autoEnhance:
              return 'Enhance';
            case RuleAction.autoPassword:
              return 'Password';
            case RuleAction.autoTag:
              return 'Tag';
            case RuleAction.autoMoveToFolder:
              return 'Move';
          }
        })
        .join(', ');
  }

  // Default automation rules
  static List<AutomationRule> get defaults => [
    AutomationRule(
      id: 'default_rename',
      name: 'Auto-rename Documents',
      trigger: RuleTrigger.afterScan,
      actions: [RuleAction.autoRename],
      renamePattern: 'Scan_{date}_{time}',
    ),
    AutomationRule(
      id: 'default_export',
      name: 'Quick Export to PDF',
      trigger: RuleTrigger.afterScan,
      actions: [RuleAction.autoExport],
      exportFormat: ExportFormat.pdf,
    ),
  ];
}
