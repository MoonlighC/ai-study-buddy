import 'package:flutter/widgets.dart';

import '../features/materials/material_upload_queue.dart';
import '../features/materials/original_material_repository.dart';
import 'app_localizations.dart';
import 'localized_formatters.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  String originalMaterialFailureMessage(OriginalMaterialFailureCode code) =>
      switch (code) {
        OriginalMaterialFailureCode.sessionExpired =>
          l10n.materialPreviewSessionExpired,
        OriginalMaterialFailureCode.previewTooLarge =>
          l10n.materialPreviewTooLarge,
        OriginalMaterialFailureCode.authorizationDenied =>
          l10n.materialPreviewNotAuthorized,
        _ => l10n.materialPreviewUnavailable,
      };

  String materialUploadQueueErrorMessage(MaterialUploadQueueErrorCode? code) =>
      switch (code) {
        MaterialUploadQueueErrorCode.unsupportedFile =>
          l10n.materialUnsupportedFile,
        MaterialUploadQueueErrorCode.invalidFile => l10n.materialInvalidFile,
        MaterialUploadQueueErrorCode.emptyFile => localizedSafeMessage(
          'The selected file is empty.',
        ),
        MaterialUploadQueueErrorCode.fileTooLarge => localizedSafeMessage(
          'The selected file is too large.',
        ),
        MaterialUploadQueueErrorCode.sessionExpired ||
        MaterialUploadQueueErrorCode.sessionChanged =>
          l10n.materialPreviewSessionExpired,
        MaterialUploadQueueErrorCode.processingConsentRequired =>
          l10n.materialProcessingConsentRequired,
        _ => l10n.uploadFailed,
      };

  String localizedSafeMessage(String message) {
    final l = l10n;
    const resetPrefix = 'If an account exists for ';
    const resetSuffix = ', a reset email is on the way.';
    if (message.startsWith(resetPrefix) && message.endsWith(resetSuffix)) {
      final email = message.substring(
        resetPrefix.length,
        message.length - resetSuffix.length,
      );
      return l.authResetNotice(email);
    }
    final uploadLimit = RegExp(
      r'^The selected file exceeds ([0-9]+ (?:KiB|MiB|GiB))\.$',
    ).firstMatch(message);
    if (uploadLimit != null) {
      return l.errorUploadTooLarge(uploadLimit.group(1)!);
    }
    final uploadByteLimit = RegExp(
      r'^The selected file exceeds ([0-9]+) bytes\.$',
    ).firstMatch(message);
    if (uploadByteLimit != null) {
      final bytes = int.parse(uploadByteLimit.group(1)!);
      return l.errorUploadTooLarge(LocalizedFormatters.fileSize(l, bytes));
    }
    return switch (message) {
      'Enter your name.' => l.errorEnterName,
      'Enter a valid email address.' => l.errorEnterValidEmail,
      'Enter your email address.' => l.errorEmailRequired,
      'Password is required.' => l.errorPasswordRequired,
      'Password must be at least 6 characters.' => l.errorPasswordTooShort,
      'Confirm your password.' => l.errorConfirmPassword,
      'Passwords do not match.' => l.errorPasswordsDoNotMatch,
      'Log in to edit your profile.' => l.errorLoginToEditProfile,
      'An account already exists for this email. Try logging in instead.' =>
        l.errorAccountAlreadyExists,
      'Something went wrong. Please try again.' => l.genericLocalizedError,
      'Unable to sign in. Check your email address and password.' =>
        l.authInvalidCredentials,
      'Confirm your email address before signing in.' =>
        l.authEmailNotConfirmed,
      'Too many sign-in attempts. Try again later.' => l.authRateLimited,
      'Check your internet connection and try again.' => l.authNetworkFailure,
      'The authentication service is temporarily unavailable. Try again later.' =>
        l.authServiceUnavailable,
      'Could not update the account profile.' => l.errorCouldNotUpdateProfile,
      'Could not log out.' => l.errorCouldNotLogOut,
      'Could not sync subjects. Try again.' => l.errorCouldNotSyncSubjects,
      'Could not sync subjects.' => l.errorCouldNotSyncSubjects,
      'Enter a subject name.' => l.errorEnterSubjectName,
      'Log in to sync subjects.' => l.errorLoginToSyncSubjects,
      'Could not sync materials. Try again.' => l.errorCouldNotSyncMaterials,
      'Could not sync materials.' => l.errorCouldNotSyncMaterials,
      'Enter a title and pasted text.' => l.errorEnterTitleAndText,
      'Log in to sync materials.' => l.errorLoginToSyncMaterials,
      'Choose a PDF or image to upload.' => l.errorChoosePdfOrImage,
      'Log in to upload materials.' => l.errorLoginToUploadMaterials,
      'Could not upload the selected file.' => l.errorCouldNotUploadFile,
      'Choose a supported PDF, PNG, JPG, JPEG, or WEBP file.' =>
        l.errorUnsupportedFile,
      'The selected file is empty.' => l.errorEmptyFile,
      'The file contents do not match the selected file type.' =>
        l.errorFileTypeMismatch,
      'Could not open the file picker.' => l.errorCouldNotOpenFilePicker,
      'Material unavailable.' => l.errorMaterialUnavailable,
      'Could not update favorite.' => l.errorCouldNotUpdateFavorite,
      'Could not sync favorites. Try again.' => l.errorCouldNotSyncFavorites,
      'Could not delete the material. Try again.' =>
        l.errorCouldNotDeleteMaterial,
      'Log in to delete this material.' => l.errorLoginToDeleteMaterial,
      'Processing could not be reset.' => l.errorCouldNotResetProcessing,
      'This PDF cannot be extracted.' => l.errorPdfCannotBeExtracted,
      'Log in to extract PDF text.' => l.errorLoginToExtractPdf,
      'Could not extract text. Try again.' => l.errorCouldNotExtractText,
      'This image cannot be processed.' => l.errorImageCannotBeProcessed,
      'Log in to extract image text.' => l.errorLoginToExtractImage,
      'Could not extract image text. Try again.' =>
        l.errorCouldNotExtractImageText,
      'This PDF cannot be scanned with OCR.' => l.errorPdfCannotBeScanned,
      'Log in to scan this PDF.' => l.errorLoginToScanPdf,
      'Could not scan this PDF. Try again.' => l.errorCouldNotScanPdf,
      'This version can scan PDFs up to 10 pages. Split the PDF and upload a smaller file.' =>
        l.errorPdfOcrPageLimit,
      'No selectable text was found. Scanned PDFs will be supported in the OCR phase.' =>
        l.errorNoSelectablePdfText,
      'No readable text was found in this image.' => l.errorNoReadableImageText,
      'The uploaded file is not a valid PDF.' => l.errorInvalidPdf,
      'Could not read the uploaded PDF.' => l.errorCouldNotReadPdf,
      'Could not read the uploaded image.' => l.errorCouldNotReadImage,
      'The uploaded file is not a valid supported image.' =>
        l.errorInvalidImage,
      'Could not generate summary. Try again.' =>
        l.errorCouldNotGenerateSummary,
      'Add more lecture text before generating a summary.' =>
        l.errorAddMoreLectureText,
      'Could not generate flashcards. Try again.' =>
        l.errorCouldNotGenerateFlashcards,
      'Could not generate quiz. Try again.' => l.errorCouldNotGenerateQuiz,
      'Could not sync flashcards.' => l.errorCouldNotGenerateFlashcards,
      'Could not save review progress.' => l.errorCouldNotSaveReview,
      'Could not save this quiz attempt.' => l.errorCouldNotSaveQuizAttempt,
      _ => l.genericLocalizedError,
    };
  }
}
