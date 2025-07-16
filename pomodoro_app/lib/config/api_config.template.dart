// lib/config/api_config.template.dart
// Template file showing the structure for API credentials
// Copy this file to api_config.dart and replace with your actual credentials

class ApiConfig {
  // TickTick API credentials
  // Get these from your TickTick developer account
  static const String tickTickClientId = "YOUR_TICKTICK_CLIENT_ID";
  static const String tickTickClientSecret = "YOUR_TICKTICK_CLIENT_SECRET";
  static const String tickTickRedirectUri = "YOUR_TICKTICK_REDIRECT_URI";
  
  // Google OAuth credentials
  // Get this from your Google Cloud Console
  static const String googleClientId = "YOUR_GOOGLE_CLIENT_ID";
  
  // Firebase credentials
  // Get this from your Firebase project settings
  static const String firebaseDatabaseUrl = "YOUR_FIREBASE_DATABASE_URL";
}