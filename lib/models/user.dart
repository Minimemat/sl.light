class User {
  final int id;
  final String email;
  final String jwtToken;
  final String displayName;

  const User({
    required this.id,
    required this.email,
    required this.jwtToken,
    required this.displayName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'] ?? 0,
      email: json['user_email'] ?? '',
      jwtToken: json['token'] ?? '',
      displayName: json['user_display_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'user_email': email,
      'token': jwtToken,
      'user_display_name': displayName,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.jwtToken == jwtToken &&
        other.displayName == displayName;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        jwtToken.hashCode ^
        displayName.hashCode;
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName)';
  }
}
