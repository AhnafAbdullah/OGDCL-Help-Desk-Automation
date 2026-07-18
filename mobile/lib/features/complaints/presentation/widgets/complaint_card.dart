import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/complaint.dart';
import '../../../../shared/widgets/status_badge.dart';

class ComplaintCard extends StatelessWidget {
  const ComplaintCard({super.key, required this.complaint});

  final ComplaintSummary complaint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(RoutePaths.complaintDetail(complaint.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      complaint.complaintNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SeverityBadge(severity: complaint.severity),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                complaint.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(complaint.category, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  StatusBadge(status: complaint.status),
                  if (complaint.isOverdue) ...[
                    const SizedBox(width: 8),
                    const OverdueBadge(),
                  ],
                  const Spacer(),
                  if (complaint.assignedTo != null) ...[
                    const Icon(Icons.person_outline, size: 14, color: Colors.black45),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        complaint.assignedTo!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    Formatters.relative(complaint.updatedAt),
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
