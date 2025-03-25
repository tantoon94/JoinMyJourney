import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(),
    );
  }
}
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Journey Maps'),
      ),
      body: ListView(
        children: [
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

  JourneyMapThumbnail({
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
            Icon(Icons.star, color: Colors.yellow),
            Text(rating.toString()),
          ],
        ),
      ),
    );
  }
}