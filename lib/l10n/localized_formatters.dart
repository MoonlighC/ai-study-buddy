import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/models/material.dart';
import '../core/models/flashcard.dart';
import '../core/models/study_session.dart';
import 'app_localizations.dart';

class LocalizedFormatters {
  const LocalizedFormatters._();

  static String materialDate(
    AppLocalizations l10n,
    StudyMaterial material, {
    DateTime? now,
  }) {
    final instant = material.createdAt ?? DateTime.tryParse(material.createdLabel);
    if (instant != null) {
      return dateOrRelative(l10n, instant, now: now);
    }
    return switch (material.createdLabel.trim()) {
      'Just now' => l10n.relativeJustNow,
      'Today' => l10n.relativeToday,
      'Yesterday' => l10n.relativeYesterday,
      'Synced' || 'Not synced' => l10n.relativeSynced,
      _ => l10n.relativeRecent,
    };
  }

  static String dateOrRelative(
    AppLocalizations l10n,
    DateTime value, {
    DateTime? now,
  }) {
    final localValue = value.toLocal();
    final localNow = (now ?? DateTime.now()).toLocal();
    final valueDay = DateTime(localValue.year, localValue.month, localValue.day);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final days = today.difference(valueDay).inDays;
    if (days == 0) {
      if (localNow.difference(localValue).abs() < const Duration(minutes: 5)) {
        return l10n.relativeJustNow;
      }
      return l10n.relativeToday;
    }
    if (days == 1) return l10n.relativeYesterday;
    initializeDateFormatting(l10n.localeName);
    return DateFormat.yMMMd(l10n.localeName).format(localValue);
  }

  static String dateTime(AppLocalizations l10n, DateTime value) {
    initializeDateFormatting(l10n.localeName);
    return DateFormat.yMMMd(
      l10n.localeName,
    ).add_jm().format(value.toLocal());
  }

  static String percentage(AppLocalizations l10n, num percent) {
    final formatter = NumberFormat.percentPattern(l10n.localeName)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = percent == percent.roundToDouble() ? 0 : 2;
    return formatter.format(percent / 100);
  }

  static String decimal(AppLocalizations l10n, num value) =>
      NumberFormat.decimalPatternDigits(
        locale: l10n.localeName,
        decimalDigits: value == value.roundToDouble() ? 0 : 2,
      ).format(value);

  static String fileSize(AppLocalizations l10n, int bytes) {
    if (bytes < 1024) return l10n.fileSizeBytes(bytes);
    final kib = bytes / 1024;
    if (kib < 1024) return l10n.fileSizeKibibytes(_compact(l10n, kib));
    return l10n.fileSizeMebibytes(_compact(l10n, kib / 1024));
  }

  static String _compact(AppLocalizations l10n, double value) {
    return NumberFormat.decimalPatternDigits(
      locale: l10n.localeName,
      decimalDigits: value == value.roundToDouble() ? 0 : 1,
    ).format(value);
  }

  static String difficulty(
    AppLocalizations l10n,
    FlashcardDifficulty value,
  ) => switch (value) {
    FlashcardDifficulty.easy => l10n.settingsDifficultyEasy,
    FlashcardDifficulty.medium => l10n.settingsDifficultyMedium,
    FlashcardDifficulty.exam => l10n.settingsDifficultyExam,
  };

  static String confidence(
    AppLocalizations l10n,
    LectureConfidence value,
  ) => switch (value) {
    LectureConfidence.understoodEverything => l10n.confidenceUnderstoodEverything,
    LectureConfidence.mostly => l10n.confidenceMostly,
    LectureConfidence.aboutHalf => l10n.confidenceAboutHalf,
    LectureConfidence.completelyLost => l10n.confidenceCompletelyLost,
  };

  static String studyBlock(AppLocalizations l10n, String legacyLabel) =>
      switch (legacyLabel) {
        'Summary' => l10n.blockSummary,
        'Flashcards' => l10n.blockFlashcards,
        'Quiz' => l10n.blockQuiz,
        'Review mistakes' => l10n.blockReviewMistakes,
        'Simple explanation' => l10n.blockSimpleExplanation,
        'Guided flashcards' => l10n.blockGuidedFlashcards,
        'Quick quiz' => l10n.blockQuickQuiz,
        _ => l10n.relativeRecent,
      };
}
