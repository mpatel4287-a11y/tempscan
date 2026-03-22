import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._internal();
  TranslationService._internal();

  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();

  /// Supported Indian languages + English
  static const Map<String, TranslateLanguage> supportedLanguages = {
    'English': TranslateLanguage.english,
    'Hindi': TranslateLanguage.hindi,
    'Gujarati': TranslateLanguage.gujarati,
    'Marathi': TranslateLanguage.marathi,
    'Bengali': TranslateLanguage.bengali,
    'Tamil': TranslateLanguage.tamil,
    'Telugu': TranslateLanguage.telugu,
    'Kannada': TranslateLanguage.kannada,
    'Urdu': TranslateLanguage.urdu,
  };

  /// Checks if a language model is downloaded
  Future<bool> isModelDownloaded(TranslateLanguage language) async {
    return await _modelManager.isModelDownloaded(language.bcpCode);
  }

  /// Downloads a language model
  Future<void> downloadModel(TranslateLanguage language) async {
    await _modelManager.downloadModel(language.bcpCode);
  }

  /// Deletes a language model
  Future<void> deleteModel(TranslateLanguage language) async {
    await _modelManager.deleteModel(language.bcpCode);
  }

  /// Translates text from source to target language
  Future<String> translate({
    required String text,
    required TranslateLanguage source,
    required TranslateLanguage target,
  }) async {
    if (source == target) return text;
    if (text.trim().isEmpty) return text;

    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );

    try {
      final translatedText = await translator.translateText(text);
      return translatedText;
    } finally {
      translator.close();
    }
  }

  /// Batch translates a list of strings
  Future<List<String>> translateBatch({
    required List<String> texts,
    required TranslateLanguage source,
    required TranslateLanguage target,
  }) async {
    if (source == target) return texts;

    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );

    try {
      final List<String> results = [];
      for (final text in texts) {
        if (text.trim().isEmpty) {
          results.add(text);
          continue;
        }
        results.add(await translator.translateText(text));
      }
      return results;
    } finally {
      translator.close();
    }
  }
}
