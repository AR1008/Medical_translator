import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String username;
  final String fullName;
  final String userType;
  final String email;
  final String? department;
  final String? specialization;
  final String? phone;

  const User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.userType,
    required this.email,
    this.department,
    this.specialization,
    this.phone,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: map['fullName'] as String,
      userType: map['userType'] as String,
      email: map['email'] as String,
      department: map['department'] as String?,
      specialization: map['specialization'] as String?,
      phone: map['phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'userType': userType,
      'email': email,
      'department': department,
      'specialization': specialization,
      'phone': phone,
    };
  }

  @override
  List<Object?> get props => [
        id,
        username,
        fullName,
        userType,
        email,
        department,
        specialization,
        phone,
      ];
}
