# TempScan - Advanced Mobile Document Scanner & PDF Editor (.vPDF Pioneer)

![TempScan Logo](assets/icon/icon.png)

**TempScan** is a cutting-edge Flutter app revolutionizing document management. Scan, edit, OCR, and create interactive **.vPDF** files (video-embedded PDFs) - the future of rich document formats.

## 🚀 Main Features (.vPDF Highlight)

### 🎥 **.vPDF - Video Embedded PDFs** ⭐ **KEY FEATURE**
- Embed videos directly in PDFs (.vpdf format)
- Built-in video player with timeline thumbnails
- Seek, play/pause controls within PDF viewer
- Perfect for tutorials, lectures, contracts with video attachments
- `create_video_pdf_screen.dart` + `video_embed_builder.dart`

### 📸 **Pro Scanning**
- Camera with auto-edge detection & multi-page
- Import images/PDFs/videos
- High-res capture + temp storage management

### 🧠 **AI Processing (Full Suite)**
| Feature | Implementation |
|---------|----------------|
| **OCR** | google_mlkit_text_recognition (multi-lang) |
| **Forms** | form_recognition_service.dart |
| **Enhance** | auto_enhance_screen.dart + filters |
| **Translate** | google_mlkit_translation |
| **Eraser** | eraser_service.dart (magic removal) |

### ✂️ **Complete Editing**
- **crop_screen.dart**, rotate_sheet.dart (free rotate)
- filter_sheet.dart (20+ pro filters)
- signature_screen.dart + watermark.dart
- annotation_sheet.dart, edit_image_screen.dart
- password_pdf_screen.dart, merge_pdfs_screen.dart

### 📂 **Organization & Automation**
- document.dart, folder.dart models
- document_storage_service.dart + backup_service.dart
- automation_service.dart + rules screen
- Full-text search & smart tags

### 💰 **Monetization Ready**
- entitlement_manager.dart, token_manager.dart
- Pro features via in-app purchases

## 🛠 Tech Stack

| Layer | Packages |
|-------|----------|
| Flutter | Cross-platform (iOS/Android/Web/Linux/macOS/Windows) |
| **PDF** | pdf, pdfx, syncfusion_flutter_pdf |
| **Video** | video_player, chewie, video_embed_builder |
| **AI/ML** | google_mlkit_* |
| **Media** | camera, image_picker, image |

## 🎯 Quick Start

```bash
cd /home/meet-patel/tempscan
flutter pub get
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
flutter run
```

**Screenshots**: Review [assets/] for icon/splash previews.

## 📱 Core Screens Flow

```
HomeScreen → [Camera/Import/VideoPDF] → ReviewScreen 
           → [OCR/Enhance/Edit/Sign] → Export (.vPDF/PDF/Image)
           ↓
Organized Storage + Automation
```

**All Features Implemented** (from lib/ analysis):
- ✅ 18+ UI screens (home_options, ocr_screen, advanced_editor, etc.)
- ✅ Services: signature_service, translation_service, advanced_ocr_engine
- ✅ Utils: file_size_helper, font_matcher
- ✅ Models: automation_rule.dart
- ✅ Temp management for smooth UX

## 📋 Demo Workflows

### 1. **Video PDF Creation** (Main Feature)
```
Home → Create Video PDF → Select video 
→ Auto-thumbnails → Embed → .vPDF Export
→ View in video_pdf_viewer_screen.dart
```

### 2. **Pro Scan Workflow**
```
CameraScreen → Review → OCR Screen → Auto Enhance 
→ Filter Sheet → Signature → Password Protect → Export
```

### 3. **Merge & Automate**
```
Merge PDFs → Reorder → Watermark → Automation applies tags 
→ Organized in Folders → Backup Service
```

## 🎮 Status (TODO.md Summary)

✅ **Production Ready Core**: .vPDF, scanning, OCR/AI, editing, organization  
✅ **Advanced**: Automation engine, monetization  
🔄 **Polish**: Automation UI, cloud backup  

## 🤝 Contribute

1. `git checkout -b feature/.vpdf-enhancement`
2. Code → `flutter analyze` → PR
3. Follow Dart style + add tests

## 📄 License
Proprietary (entitlements for pro features)

---
**Pioneering .vPDF format!** ⭐ [Demo APK/IPA coming soon]  
**Built with Flutter ❤️** | **TempScan Team**

