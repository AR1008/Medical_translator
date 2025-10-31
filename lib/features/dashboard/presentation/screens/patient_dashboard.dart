import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../translation/presentation/screens/translation_screen.dart';
import '../../../prescription/presentation/screens/prescription_list_screen.dart';
import '../../../drawing/presentation/screens/patient_drawings_screen.dart';
import '../../../queue/presentation/screens/queue_screen.dart';
import '../../../../core/database/database_helper.dart';

class PatientDashboard extends ConsumerStatefulWidget {
  final User patient;

  const PatientDashboard({super.key, required this.patient});

  @override
  ConsumerState<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends ConsumerState<PatientDashboard> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  int _drawingsCount = 0;
  int _prescriptionsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final drawings = await _db.getPatientDrawings(widget.patient.id);
    final prescriptions = await _db.getPatientPrescriptions(widget.patient.id);
    setState(() {
      _drawingsCount = drawings.length;
      _prescriptionsCount = prescriptions.length;
    });
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      widget.patient.fullName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 28,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          widget.patient.fullName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Quick Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.draw_outlined,
                      title: 'Drawings',
                      count: _drawingsCount.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.medication_outlined,
                      title: 'Prescriptions',
                      count: _prescriptionsCount.toString(),
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Main Features
              Text(
                'Services',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildFeatureCard(
                context: context,
                icon: Icons.translate,
                title: 'Medical Translator',
                subtitle: 'English ↔ Kannada Translation',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TranslationScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              _buildFeatureCard(
                context: context,
                icon: Icons.queue,
                title: 'Join Queue',
                subtitle: 'Check in for consultation',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QueueScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              _buildFeatureCard(
                context: context,
                icon: Icons.image_outlined,
                title: 'My Medical Drawings',
                subtitle: 'View doctor explanations',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientDrawingsScreen(
                        patient: widget.patient,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              _buildFeatureCard(
                context: context,
                icon: Icons.medication,
                title: 'My Prescriptions',
                subtitle: 'View medication details',
                color: Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrescriptionListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String count,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
