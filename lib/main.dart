import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Join My Journey',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Maps'),
      ),
      body: ListView(
        children: const [
          JourneyMapThumbnail(
            profilePicture: 'assets/profile1.png',
            duration: '2 hours',
            participants: '2-4 people',
            rating: 4.5,
          ),
          // Add more JourneyMapThumbnail widgets here
        ],
      ),
    );
  }
}

class JourneyMapThumbnail extends StatelessWidget {
  final String profilePicture;
  final String duration;
  final String participants;
  final double rating;

  const JourneyMapThumbnail({super.key, 
    required this.profilePicture,
    required this.duration,
    required this.participants,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: AssetImage(profilePicture),
        ),
        title: Text('Duration: $duration'),
        subtitle: Text('Participants: $participants'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.yellow),
            Text(rating.toString()),
          ],
        ),
      ),
    );
  }
}