import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../dashboard/presentation/screens/patient_dashboard.dart';
import '../../../dashboard/presentation/screens/doctor_dashboard.dart';
import '../../../dashboard/presentation/screens/admin_dashboard.dart';
import '../../../../core/constants/app_constants.dart';

class HomeScreen extends ConsumerWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Route to appropriate dashboard based on user type
    switch (user.userType) {
      case AppConstants.userTypePatient:
        return PatientDashboard(patient: user);
      case AppConstants.userTypeDoctor:
        return DoctorDashboard(doctor: user);
      case AppConstants.userTypeAdmin:
        return AdminDashboard(admin: user);
      default:
        return const Scaffold(
          body: Center(child: Text('Invalid user type')),
        );
    }
  }
}
