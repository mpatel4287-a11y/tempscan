
# Implementation TODO - Phase 4

## Task: Implement Advanced Workflows & Enterprise-Style Features

### Phase 4: Advanced Workflows & Enterprise-Style Features

#### 1. Multi-Source PDF Creation ✅ COMPLETE
- [x] Camera scans - Already implemented in camera_screen.dart
- [x] Import Images - Implemented with file_picker in home_options_screen.dart
- [x] Import PDFs - Implemented with file_picker in home_options_screen.dart
- [ ] Mix sources in one document - Need to implement unified workflow

#### 2. Advanced Export Options ✅ MOSTLY COMPLETE
- [x] PDF export - review_screen.dart
- [x] JPG export - review_screen.dart
- [x] PNG export - review_screen.dart  
- [ ] Text (from OCR) - Need to add OCR export option
- [ ] Custom quality and resolution settings - Need to add quality dialog

#### 3. Document Organization System ✅ COMPLETE
- [x] Create document model (lib/models/document.dart)
- [x] Create document storage service (lib/services/document_storage_service.dart)
- [x] Create folder/collection system (model exists)
- [x] Implement tags (Bills, IDs, Notes, Work)
- [x] Implement search by name, date, tag (service has methods)
- [x] Implement OCR-based text search (service has methods)
- [x] Make My Documents screen functional (connected to DocumentStorageService)

#### 4. Automation Rules ✅ COMPLETE
- [x] Create automation service (lib/services/automation_service.dart) - NOW EXISTS
- [x] Auto-name documents with customizable patterns
- [x] Auto-export after scan
- [x] Auto-apply enhancement presets
- [x] Auto-apply password protection
- [x] One-tap workflow presets
- [ ] Automation settings screen - Need to create UI

#### 5. Cloud Integration (OPTIONAL - FUTURE)
- [ ] Export to cloud services placeholder
- [ ] Sync across devices placeholder
- [ ] Backup & restore placeholder

---

## Recently Completed:
1. ✅ Created lib/services/automation_service.dart
2. ✅ Implemented _importImages() with FilePicker
3. ✅ Implemented _importPdfs() with FilePicker  
4. ✅ Connected My Documents to DocumentStorageService
5. ✅ Added search and tag filtering to My Documents
6. ✅ Added isPdf parameter to _buildDocumentItem for proper icon display

---

## Implementation Details:

### Document Model:
```
dart
class ScannedDocument {
  String id;
  String name;
  DateTime createdAt;
  DateTime modifiedAt;
  String? folderId;
  List<String> tags;
  String filePath;
  String? thumbnailPath;
  String? ocrText;
  int fileSize;
  DocumentType type; // pdf, image
}
```

### Folder Model:
```
dart
class DocumentFolder {
  String id;
  String name;
  String? parentId;
  DateTime createdAt;
  Color color;
}
```

### Automation Rules:
```
dart
class AutomationRule {
  String id;
  String name;
  RuleTrigger trigger;
  List<RuleAction> actions;
  bool isEnabled;
}

enum RuleTrigger {
  afterScan,
  afterOcr,
  manual,
}

enum RuleAction {
  autoRename,
  autoExport,
  autoEnhance,
  autoPassword,
  autoTag,
}
```

---

## Summary of Changes to Make:

### New Files to Create:
1. lib/models/document.dart - Document model
2. lib/models/folder.dart - Folder model
3. lib/models/automation_rule.dart - Automation rule model
4. lib/services/document_storage_service.dart - Document persistence
5. lib/services/automation_service.dart - Automation rules engine
6. lib/ui/document_organization_screen.dart - Functional My Documents
7. lib/ui/automation_settings_screen.dart - Automation rules UI
8. lib/ui/export_quality_screen.dart - Quality settings dialog
9. lib/ui/ocr_export_screen.dart - OCR text export

### Files to Modify:
1. lib/ui/home_options_screen.dart - Complete import functionality
2. lib/ui/review_screen.dart - Add quality settings, OCR export
3. lib/core/app.dart - Add navigation for new screens

---

## Priority Order:
1. First: Document Organization System (core storage)
2. Second: Complete Multi-Source PDF Creation
3. Third: Automation Rules
4. Fourth: Advanced Export Improvements
5. Fifth: Cloud Integration (placeholder only)
