import 'package:equatable/equatable.dart';

class QueueItem extends Equatable {
  final String id;
  final String patientName;
  final int priority;
  final String department;
  final String status;
  final DateTime checkinTime;
  final String? assignedDoctor;
  final String? notes;

  const QueueItem({
    required this.id,
    required this.patientName,
    required this.priority,
    required this.department,
    required this.status,
    required this.checkinTime,
    this.assignedDoctor,
    this.notes,
  });

  QueueItem copyWith({
    String? id,
    String? patientName,
    int? priority,
    String? department,
    String? status,
    DateTime? checkinTime,
    String? assignedDoctor,
    String? notes,
  }) {
    return QueueItem(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      priority: priority ?? this.priority,
      department: department ?? this.department,
      status: status ?? this.status,
      checkinTime: checkinTime ?? this.checkinTime,
      assignedDoctor: assignedDoctor ?? this.assignedDoctor,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientName': patientName,
      'priority': priority,
      'department': department,
      'status': status,
      'checkinTime': checkinTime.toIso8601String(),
      'assignedDoctor': assignedDoctor,
      'notes': notes,
    };
  }

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'],
      patientName: json['patientName'],
      priority: json['priority'],
      department: json['department'],
      status: json['status'],
      checkinTime: DateTime.parse(json['checkinTime']),
      assignedDoctor: json['assignedDoctor'],
      notes: json['notes'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        patientName,
        priority,
        department,
        status,
        checkinTime,
        assignedDoctor,
        notes,
      ];
}
