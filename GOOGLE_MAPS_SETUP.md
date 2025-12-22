# Google Maps Setup Guide

## Why the map might not be showing

The map requires a **Google Maps API key** to work. If you see an error or a blank map, it's because the API key hasn't been configured yet.

## Step-by-Step Setup

### 1. Get a Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - **Maps SDK for Android** (for Android apps)
   - **Maps SDK for iOS** (for iOS apps)
4. Go to "Credentials" → "Create Credentials" → "API Key"
5. Copy your API key

### 2. Configure for Android

1. Open `android/app/src/main/AndroidManifest.xml`
2. Find this line:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
   ```
3. Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key

### 3. Configure for iOS

1. Open `ios/Runner/Info.plist`
2. Find this line:
   ```xml
   <key>GMSApiKey</key>
   <string>YOUR_GOOGLE_MAPS_API_KEY</string>
   ```
3. Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key

### 4. Restart the App

After adding the API key:
```bash
flutter clean
flutter pub get
flutter run
```

## Common Errors

- **"Map not showing"**: API key not set or invalid
- **"API key not valid"**: Check that you've enabled the correct APIs in Google Cloud Console
- **"Permission denied"**: Make sure you've enabled Maps SDK for your platform (Android/iOS)

## Testing Without API Key

The app will show an error message with instructions if the API key is missing. You can still test other features of the app, but the map won't display until the API key is configured.

