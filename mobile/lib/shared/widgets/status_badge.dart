import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/enums.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) => _Badge(label: status.label, color: status.color);
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final TicketPriority priority;

  @override
  Widget build(BuildContext context) => _Badge(label: priority.label, color: priority.color);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
