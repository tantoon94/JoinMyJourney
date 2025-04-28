import 'package:cloud_firestore/cloud_firestore.dart';

class Mission {
  final String id;
  final String title;
  final String description;
  final String researcherId;
  final String researcherName;
  final String subject;
  final String purpose;
  final String? gdprFileUrl;
  final List<String> tags;
  final List<Map<String, dynamic>> locations;
  final DateTime deadline;
  final int entryLimit;
  final int currentEntries;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.researcherId,
    required this.researcherName,
    required this.subject,
    required this.purpose,
    this.gdprFileUrl,
    required this.tags,
    required this.locations,
    required this.deadline,
    required this.entryLimit,
    required this.currentEntries,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Mission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Mission(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      researcherId: data['researcherId'] ?? '',
      researcherName: data['researcherName'] ?? '',
      subject: data['subject'] ?? '',
      purpose: data['purpose'] ?? '',
      gdprFileUrl: data['gdprFileUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      locations: List<Map<String, dynamic>>.from(data['locations'] ?? []),
      deadline: (data['deadline'] as Timestamp).toDate(),
      entryLimit: data['entryLimit'] ?? 0,
      currentEntries: data['currentEntries'] ?? 0,
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'researcherId': researcherId,
      'researcherName': researcherName,
      'subject': subject,
      'purpose': purpose,
      'gdprFileUrl': gdprFileUrl,
      'tags': tags,
      'locations': locations,
      'deadline': Timestamp.fromDate(deadline),
      'entryLimit': entryLimit,
      'currentEntries': currentEntries,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
} 