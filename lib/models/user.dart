import 'package:equatable/equatable.dart';

/// Minimal user model backed by the PocketBase `users` collection.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.username,
  });

  final String id;
  final String email;
  final String username;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'username': username,
      };

  /// Best human readable label: username > email > id > fallback.
  String get displayName {
    if (username.trim().isNotEmpty) return username.trim();
    if (email.trim().isNotEmpty) return email.trim();
    if (id.trim().isNotEmpty) return id.trim();
    return 'пользователь';
  }

  @override
  List<Object?> get props => <Object?>[id, email, username];
}
