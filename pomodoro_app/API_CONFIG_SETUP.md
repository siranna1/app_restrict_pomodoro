# API Configuration Setup

This application requires API credentials to function properly. Follow these steps to set up the configuration:

## Setup Instructions

1. **Copy the template file:**
   ```bash
   cp lib/config/api_config.template.dart lib/config/api_config.dart
   ```

2. **Replace the placeholder values in `lib/config/api_config.dart` with your actual credentials:**

   - **TickTick API credentials:**
     - Get your Client ID and Client Secret from the [TickTick Developer Portal](https://developer.ticktick.com/)
     - Set up your redirect URI according to your application needs

   - **Google OAuth credentials:**
     - Get your Client ID from [Google Cloud Console](https://console.cloud.google.com/)
     - Enable Google Sign-In API for your project

   - **Firebase credentials:**
     - Get your Database URL from [Firebase Console](https://console.firebase.google.com/)
     - Make sure Firebase Realtime Database is enabled

3. **Important:** The `lib/config/api_config.dart` file is added to `.gitignore` to prevent accidental commits of sensitive credentials.

## Security Notes

- Never commit the `api_config.dart` file to version control
- Keep your API credentials secure and don't share them publicly
- Use environment variables or secure configuration management in production environments