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
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      developer.log('Creating Firebase credential');
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      developer.log('Signing in with Firebase');
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
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

  Future<User?> signUpWithEmail(String email, String password, String username, String userType) async {
    try {
      developer.log('Starting Email Sign Up');
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      await storeUserData(userCredential.user, username, userType);
      developer.log('Email Sign Up successful');
      return userCredential.user;
    } catch (e, stackTrace) {
      developer.log('Email Sign Up failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      developer.log('Starting Email Sign In');
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      developer.log('Email Sign In successful');
      return userCredential.user;
    } catch (e, stackTrace) {
      developer.log('Email Sign In failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> storeUserData(User? user, [String? username, String? userType]) async {
    try {
      if (user != null) {
        developer.log('Storing user data for: ${user.uid}');
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'username': username ?? user.displayName,
          'userType': userType ?? 'regular',
          'photoURL': user.photoURL,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        developer.log('User data stored successfully');
      }
    } catch (e, stackTrace) {
      developer.log('Failed to store user data', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}