import 'package:flutter/material.dart';
import '../utils/image_handler.dart';
import '../widgets/profile_preview.dart';

class JourneyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool showEditButton;
  final bool isLiked;
  final VoidCallback? onLike;
  final bool showLikeButton;
  final Widget? trailing;

  const JourneyCard({
    super.key,
    required this.data,
    this.onTap,
    this.onEdit,
    this.showEditButton = false,
    this.isLiked = false,
    this.onLike,
    this.showLikeButton = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Journey Map Thumbnail
            if (data['mapThumbnailUrl'] != null)
              AspectRatio(
                aspectRatio: 2.0,
                child: Image.network(
                  data['mapThumbnailUrl'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else if (data['imageData'] != null)
              AspectRatio(
                aspectRatio: 2.0,
                child: ImageHandler.buildImagePreview(
                  context: context,
                  imageData: data['imageData'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.map, size: 64, color: Colors.white),
                ),
              ),
            // Journey Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Creator Photo
                  if (data['creatorPhotoUrl'] != null)
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: ProfilePreview(userId: data['creatorId']),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(data['creatorPhotoUrl']),
                        child: data['creatorPhotoUrl'] == null
                            ? const Icon(Icons.person, size: 24)
                            : null,
                      ),
                    ),
                  if (data['creatorPhotoUrl'] == null)
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: ProfilePreview(userId: data['creatorId']),
                          ),
                        );
                      },
                      child: const CircleAvatar(
                        radius: 24,
                        child: Icon(Icons.person, size: 24),
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Journey Title & Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? 'Untitled Journey',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (data['description'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            data['description'],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Journey Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Journey Metrics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Likes and Shadowers
                      Row(
                        children: [
                          if (showLikeButton && onLike != null)
                            IconButton(
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.amber,
                                size: 20,
                              ),
                              onPressed: onLike,
                            ),
                          Text(
                            '${data['likes'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.directions_walk,
                              color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${data['shadowers'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (showEditButton && onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.amber),
                          onPressed: onEdit,
                        ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Journey Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Difficulty
                      Row(
                        children: List.generate(
                          (data['difficulty'] ?? 1).clamp(1, 3),
                          (index) => const Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.local_fire_department,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      // Cost Level
                      Row(
                        children: List.generate(
                          (data['cost'] ?? 1).clamp(1, 3),
                          (index) => const Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.attach_money,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      // Duration
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(data['durationInHours'] ?? 0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      // People
                      Row(
                        children: [
                          const Icon(Icons.people,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${data['recommendedPeople'] ?? 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDifficultyIcons(int difficulty) {
    return '💧' * difficulty;
  }

  String _formatDuration(dynamic hours) {
    if (hours is int) hours = hours.toDouble();
    if (hours == null) return '';
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '$minutes min';
    } else if (hours % 1 == 0) {
      return '${hours.toInt()} h';
    } else {
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      return '$h h $m min';
    }
  }
}
