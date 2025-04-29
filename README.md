<img src="https://github.com/tantoon94/JoinMyJourney/blob/main/assets/logo.png" width="100"/> 

# Join My Journey App

**Join My Journey APP** is your ultimate companion for exploring the city in a fun and engaging way! Whether you're a local looking for new adventures, a traveler seeking unconventional experiences, or a family wanting to explore together, this app has something for everyone.

Discover personalised routes users create based on their own experiences, complete with exciting stops and activities. It's like Instagram, but with maps! Follow others' journeys, create your own, and share the fun with friends or go solo. Perfect for dates, busy workers, and anyone looking to make the most of their time in the city.



## Who is the app for?
<img src="https://github.com/tantoon94/JoinMyJourney/blob/main/Img/JoinMYJourney%20-%20Persona%20Empathy%20Map.jpg" width="600"/>
- **Explorers**: Anyone who wants to discover new places and experiences in their city.
- **Travelers**: Visitors seeking unconventional, local experiences.
- **Families & Friends**: Groups looking for fun, curated walking adventures.
- **Busy Workers**: People who want ready-made plans for their free time.
- **Couples**: Dates looking for creative ideas.

## What does the app do?

- Suggests curated walking routes ("journeys") with mapped stops and activities.
- Lets users create, save, and share their own journeys with the community.
- Provides details, photos, and tips for each stop along a route.
- Allows users to search, filter, and follow journeys by category, location, or creator.
- Supports social sign-in (Google, Apple) and user profiles.

## App wireframe layout

<!-- Replace these links with your actual screenshots -->
<img src="https://github.com/tantoon94/JoinMyJourney/blob/main/Img/Screenshot%202025-04-28%20184323.png" width="600"/>

<img src="https://github.com/tantoon94/JoinMyJourney/blob/main/assets/logo.png" width="400" centre/>

## App Workflow

1. **Sign Up / Login**: Users can register or sign in using email, Google, or Apple. User type (Regular Member or Researcher) is selected at sign up.
2. **Browse & Search**: Users can browse featured journeys or search for routes by keywords, category, or location.
3. **View Journey Details**: Each journey shows a mapped route, stops, descriptions, and photos.
4. **Create a Journey**: Users can create a new journey by mapping a route, adding stops, descriptions, and images.
5. **Track & Save**: While walking, users can track their journey, add stops, and save the route for others.
6. **Profile & Social**: Users can view their journeys, edit their profile, and interact with the community.

## How to Download the App

- **Android (APK):**
  1. Go to the [Releases](https://github.com/<your-repo>/releases) section of this repository.
  2. Download the latest `.apk` file to your Android device.
  3. Open the file to install (you may need to allow installation from unknown sources).

- **iOS (TestFlight):**
  1. Request access to the TestFlight beta by contacting the developer at Tinasamie@outlook.com.
  2. You will receive an invitation link to download the app via TestFlight.

## Developer Setup & Installation

1. **Clone the repository**:
   ```bash
   git clone <repo-url>
   cd JoinMyJourney
   ```
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Configure Firebase**:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
   - Ensure Firebase Auth, Firestore, and Storage are enabled in your Firebase project.
4. **Run the app**:
   ```bash
   flutter run
   ```

## API Keys & Configuration

### Web Services Used

1. **Firebase Services**:
   - Firebase Authentication (with Google Sign-In)
   - Cloud Firestore (database)
   - Firebase Storage (file storage)
   - Firebase Realtime Database (optional)

2. **Google Maps Platform**:
   - Maps SDK for Flutter
   - Location services

3. **Google Sign-In**:
   - OAuth 2.0 authentication
   - Web and Android client support

### Setup Instructions

- **Google Maps:**  
  Obtain an API key from the [Google Cloud Console](https://console.cloud.google.com/) and enable the Maps SDK for both Android and iOS.
  - Add your key to `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift` as per [Flutter Google Maps setup](https://pub.dev/packages/google_maps_flutter).

- **Firebase:**  
  Follow the [Firebase setup guide for Flutter](https://firebase.flutter.dev/docs/overview/).
  Required services to enable in Firebase Console:
  - Authentication (with Google Sign-In)
  - Cloud Firestore
  - Storage
  - Realtime Database (if needed)

- **Google Sign-In:**
  Configure OAuth 2.0 client IDs in the Google Cloud Console for:
  - Android applications
  - Web applications

**Tested with Flutter 3.x and the latest stable versions of Firebase plugins.**

## License

This project is for educational and non-commercial use. See LICENSE file for details.

## Contact

For questions or feedback, contact: Tinasamie@outlook.com

