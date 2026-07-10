import 'package:flutter/material.dart';

import 'app_config.dart';
import 'app_state.dart';
import 'routes.dart';
import 'theme.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_repository.dart';
import '../features/favorites/favorite_repository.dart';
import '../features/flashcards/flashcard_repository.dart';
import '../features/generation/summary_repository.dart';
import '../features/materials/material_repository.dart';
import '../features/materials/material_file_picker.dart';
import '../features/materials/material_upload_repository.dart';
import '../features/materials/pdf_text_extraction_repository.dart';
import '../features/materials/image_text_extraction_repository.dart';
import '../features/materials/scanned_pdf_ocr_repository.dart';
import '../features/quizzes/quiz_repository.dart';
import '../features/progress/weak_topic_repository.dart';
import '../features/subjects/subject_repository.dart';

class StudyBuddyApp extends StatefulWidget {
  const StudyBuddyApp({
    this.config,
    this.authRepository,
    this.profileRepository,
    this.subjectRepository,
    this.materialRepository,
    this.materialUploadRepository,
    this.pdfTextExtractionRepository,
    this.imageTextExtractionRepository,
    this.scannedPdfOcrRepository,
    this.materialFilePicker,
    this.materialIdGenerator,
    this.favoriteRepository,
    this.flashcardRepository,
    this.summaryRepository,
    this.quizRepository,
    this.weakTopicRepository,
    super.key,
  });

  final AppConfig? config;
  final AuthRepository? authRepository;
  final ProfileRepository? profileRepository;
  final SubjectRepository? subjectRepository;
  final MaterialRepository? materialRepository;
  final MaterialUploadRepository? materialUploadRepository;
  final PdfTextExtractionRepository? pdfTextExtractionRepository;
  final ImageTextExtractionRepository? imageTextExtractionRepository;
  final ScannedPdfOcrRepository? scannedPdfOcrRepository;
  final MaterialFilePicker? materialFilePicker;
  final String Function()? materialIdGenerator;
  final FavoriteRepository? favoriteRepository;
  final FlashcardRepository? flashcardRepository;
  final SummaryRepository? summaryRepository;
  final QuizRepository? quizRepository;
  final WeakTopicRepository? weakTopicRepository;

  @override
  State<StudyBuddyApp> createState() => _StudyBuddyAppState();
}

class _StudyBuddyAppState extends State<StudyBuddyApp> {
  late final AppConfig config = widget.config ?? AppConfig.fromValues();
  late final AppState state = AppState(
    config: config,
    subjectRepository: widget.subjectRepository,
    materialRepository: widget.materialRepository,
    materialUploadRepository: widget.materialUploadRepository,
    pdfTextExtractionRepository: widget.pdfTextExtractionRepository,
    imageTextExtractionRepository: widget.imageTextExtractionRepository,
    scannedPdfOcrRepository: widget.scannedPdfOcrRepository,
    materialFilePicker: widget.materialFilePicker,
    materialIdGenerator: widget.materialIdGenerator,
    favoriteRepository: widget.favoriteRepository,
    flashcardRepository: widget.flashcardRepository,
    summaryRepository: widget.summaryRepository,
    quizRepository: widget.quizRepository,
    weakTopicRepository: widget.weakTopicRepository,
  );
  late final AuthController authController = AuthController(
    authRepository: widget.authRepository ?? MockAuthRepository(),
    profileRepository: widget.profileRepository ?? NoopProfileRepository(),
  );

  @override
  void dispose() {
    authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: AuthScope(
        controller: authController,
        child: MaterialApp(
          title: 'AI Study Buddy',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          initialRoute: AppRoutes.authGate,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}
