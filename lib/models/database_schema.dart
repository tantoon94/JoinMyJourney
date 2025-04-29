class DatabaseSchema {
  // Collections
  static const String users = 'users';
  static const String journeys = 'journeys';
  static const String stops = 'stops';
  static const String images = 'images';

  // User fields
  static const String userPhotoUrl = 'photoURL';
  static const String userDisplayName = 'displayName';
  static const String userBio = 'bio';
  static const String userCreatedAt = 'createdAt';
  static const String userUpdatedAt = 'updatedAt';

  // Journey fields
  static const String journeyTitle = 'title';
  static const String journeyDescription = 'description';
  static const String journeyImageUrl = 'imageUrl';
  static const String journeyCreatorId = 'creatorId';
  static const String journeyCreatedAt = 'createdAt';
  static const String journeyUpdatedAt = 'updatedAt';
  static const String journeyStops = 'stops';
  static const String journeyRoute = 'route';

  // Stop fields
  static const String stopName = 'name';
  static const String stopDescription = 'description';
  static const String stopImageMetadata = 'imageMetadata';
  static const String stopLocation = 'location';
  static const String stopOrder = 'order';
  static const String stopCreatedAt = 'createdAt';
  static const String stopUpdatedAt = 'updatedAt';

  // Image metadata fields
  static const String imageData = 'data';
  static const String imageType = 'type';
  static const String imageSize = 'size';
  static const String imageTimestamp = 'timestamp';
  static const String imageName = 'name';
  static const String imageUrl = 'url';
}
