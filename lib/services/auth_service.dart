import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User?> signInWithGoogle() async {
    try {
      developer.log('Starting Google Sign In');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        developer.log('Google Sign In cancelled by user');
        return null;
      }

      developer.log('Getting Google Auth credentials');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      developer.log('Creating Firebase credential');
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      developer.log('Signing in with Firebase');
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        developer.log('Google Sign In successful');
        await storeUserData(userCredential.user);
        return userCredential.user;
      } else {
        developer.log('Google Sign In failed: No user returned');
        return null;
      }
    } catch (e, stackTrace) {
      developer.log('Google Sign In failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<User?> signUpWithEmail(
      String email, String password, String username, String userType) async {
    try {
      developer.log('Starting Email Sign Up for: $email, userType: $userType');
      
      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email, password, and username are required',
        );
      }

      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
          
      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Failed to create user account',
        );
      }

      developer.log('User account created, storing additional data');
      await storeUserData(userCredential.user, username, userType);
      
      developer.log('Email Sign Up successful');
      return userCredential.user;
    } catch (e, stackTrace) {
      developer.log('Email Sign Up failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      developer.log('Starting Email Sign In');
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      developer.log('Email Sign In successful');
      return userCredential.user;
    } catch (e, stackTrace) {
      developer.log('Email Sign In failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e, stackTrace) {
      developer.log('Failed to send password reset email', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> storeUserData(User? user,
      [String? username, String? userType]) async {
    try {
      if (user == null) {
        throw Exception('Cannot store data for null user');
      }

      developer.log('Storing user data for: ${user.uid}');
      developer.log('Username: $username, UserType: $userType');

      // Normalize the userType regardless of input case
      String normalizedUserType = userType?.toLowerCase() == 'researcher' 
          ? 'Researcher' 
          : 'Regular Member';
      
      if (username == null || username.isEmpty) {
        throw Exception('Username is required');
      }

      final userData = {
        // Basic Info
        'uid': user.uid,
        'email': user.email,
        'username': username,
        'displayName': username,
        'userType': normalizedUserType,
        'photoURL': user.photoURL,
        
        // Profile Info
        'bio': '',
        'interests': [],
        'preferences': {
          'notifications': true,
          'emailUpdates': true,
          'privacyLevel': 'public'
        },

        // Stats & Metrics
        'stats': {
          'journeysCreated': 0,
          'journeysShadowed': 0,
          'totalLikes': 0,
          'completedJourneys': 0
        },

        // Timestamps
        'createdAt': user.metadata.creationTime ?? FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),

        // Account Status
        'status': 'active',
        'isVerified': user.emailVerified,
      };

      // Additional fields for researchers
      if (normalizedUserType == 'Researcher') {
        userData['researcherProfile'] = {
          'institution': '',
          'researchAreas': [],
          'publications': [],
          'missionStats': {
            'totalMissions': 0,
            'activeMissions': 0,
            'completedMissions': 0,
            'totalParticipants': 0
          }
        };
      }

      developer.log('Saving user data: $userData');
      
      await _db.collection('users').doc(user.uid).set(
        userData,
        SetOptions(merge: true),
      );
      
      developer.log('User data stored successfully');
    } catch (e, stackTrace) {
      developer.log('Failed to store user data',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
