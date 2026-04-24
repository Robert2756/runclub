class Post {
  final String id;
  final String title;
  final String creatorId;
  final String? imgurl;
  final String? description;
  final String? activity;
  final int? distance;
  final int? pace;
  final String? date;
  final String? time;
  final double? latitude;
  final double? longitude;
  final String? town;
  final String? createdAt;
  final String? group;
  final String? frequency;
  final int? userdistance;

  Post({
    required this.id,
    required this.title,
    required this.creatorId,
    this.imgurl,
    this.description,
    this.activity,
    this.distance,
    this.pace,
    this.date,
    this.time,
    this.latitude,
    this.longitude,
    this.town,
    this.createdAt,
    this.group,
    this.frequency,
    this.userdistance,
  });
}