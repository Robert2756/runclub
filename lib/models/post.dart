class Post {
  final String id;
  final String title;
  final String creatorId;
  final String? imgurl;
  final String? description;
  final String? activity;
  final int? distance;
  final int? pace;
  final int? speed;
  final String? date;
  final String? time;
  final double? latitude;
  final double? longitude;
  final String? town;
  final String? createdAt;
  final String? group;
  final String? joinMode;
  final int? userdistance;
  final String? startsAt;
  final String? meetingPoint;

  Post({
    required this.id,
    required this.title,
    required this.creatorId,
    this.imgurl,
    this.description,
    this.activity,
    this.distance,
    this.pace,
    this.speed,
    this.date,
    this.time,
    this.latitude,
    this.longitude,
    this.town,
    this.createdAt,
    this.group,
    this.joinMode,
    this.userdistance,
    this.startsAt,
    this.meetingPoint,
  });
}