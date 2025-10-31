class AppConstants {
  // App Info
  static const String appName = 'Medical Translator';
  static const String appVersion = '1.0.0';
  
  // User Types
  static const String userTypePatient = 'patient';
  static const String userTypeDoctor = 'doctor';
  static const String userTypeAdmin = 'admin';
  
  // Languages
  static const Map<String, String> languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'zh': 'Chinese',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ja': 'Japanese',
  };
  
  // Priority Levels
  static const Map<int, String> priorityLevels = {
    1: 'Critical',
    2: 'Urgent',
    3: 'Moderate',
    4: 'Low',
    5: 'Routine',
  };
  
  // Priority Colors
  static const Map<int, String> priorityColors = {
    1: '0xFFE53935', // Red
    2: '0xFFFF9800', // Orange
    3: '0xFFFFC107', // Amber
    4: '0xFF4CAF50', // Green
    5: '0xFF2196F3', // Blue
  };
  
  // Session Status
  static const String sessionActive = 'active';
  static const String sessionPaused = 'paused';
  static const String sessionCompleted = 'completed';
  static const String sessionCancelled = 'cancelled';
  
  // Queue Status
  static const String queueWaiting = 'waiting';
  static const String queueInProgress = 'in_progress';
  static const String queueCompleted = 'completed';
  static const String queueCancelled = 'cancelled';
  
  // Storage Keys
  static const String keyUser = 'user';
  static const String keyToken = 'token';
  static const String keyLanguage = 'language';
  static const String keyTheme = 'theme';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Limits
  static const int maxRecordingDuration = 60; // seconds
  static const int maxTranslationLength = 5000; // characters
  static const int maxQueueSize = 50;
  static const int maxPrescriptionMedicines = 10;
}
