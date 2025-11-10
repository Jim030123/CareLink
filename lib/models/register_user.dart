class RegisterUser {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String? confirmPassword;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? role;
  final bool termsAccepted;

  const RegisterUser({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.confirmPassword,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.role,
    this.termsAccepted = false,
  });

  RegisterUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    String? confirmPassword,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? role,
    bool? termsAccepted,
  }) {
    return RegisterUser(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      termsAccepted: termsAccepted ?? this.termsAccepted,
    );
  }

  factory RegisterUser.fromJson(Map<String, dynamic> json) {
    DateTime? dob;
    if (json['dateOfBirth'] != null) {
      final v = json['dateOfBirth'];
      if (v is String) {
        dob = DateTime.tryParse(v);
      } else if (v is int) {
        dob = DateTime.fromMillisecondsSinceEpoch(v);
      }
    }

    return RegisterUser(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      confirmPassword: json['confirmPassword'],
      phone: json['phone'],
      dateOfBirth: dob,
      gender: json['gender'],
      role: json['role'],
      termsAccepted: json['termsAccepted'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
      'phone': phone,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'role': role,
      'termsAccepted': termsAccepted,
    };
  }

  /// Returns the payload typically sent to backend for registration.
  /// Excludes confirmPassword by default.
  Map<String, dynamic> toRegisterPayload() {
    final map = toJson();
    map.remove('confirmPassword');
    return map;
  }

  // Basic validators

  bool get isEmailValid {
    final pattern =
        r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$';
    return RegExp(pattern).hasMatch(email);
  }

  bool get isPasswordValid {
    // Minimum 8 chars, at least one letter and one number
    final pattern = r'^(?=.*[A-Za-z])(?=.*\d).{8,}$';
    return RegExp(pattern).hasMatch(password);
  }

  bool get passwordsMatch => confirmPassword == null ? true : password == confirmPassword;

  bool get isPhoneValid {
    if (phone == null || phone!.isEmpty) return true; // optional phone
    // Allow + and digits, 7..15 digits
    final pattern = r'^\+?\d{7,15}$';
    return RegExp(pattern).hasMatch(phone!);
  }

  bool get isValid {
    return firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty &&
        isEmailValid &&
        isPasswordValid &&
        passwordsMatch &&
        isPhoneValid &&
        termsAccepted;
  }

  @override
  String toString() {
    return 'RegisterUser(firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, dateOfBirth: $dateOfBirth, gender: $gender, role: $role, termsAccepted: $termsAccepted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RegisterUser &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.email == email &&
        other.password == password &&
        other.confirmPassword == confirmPassword &&
        other.phone == phone &&
        other.dateOfBirth == dateOfBirth &&
        other.gender == gender &&
        other.role == role &&
        other.termsAccepted == termsAccepted;
  }

  @override
  int get hashCode {
    return Object.hash(
      firstName,
      lastName,
      email,
      password,
      confirmPassword,
      phone,
      dateOfBirth,
      gender,
      role,
      termsAccepted,
    );
  }
}