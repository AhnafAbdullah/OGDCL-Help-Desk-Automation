import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/ticket.dart';
import '../../../../shared/widgets/status_badge.dart';

class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket});

  final TicketSummary ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(RoutePaths.ticketDetail(ticket.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.ticketNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  PriorityBadge(priority: ticket.priority),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ticket.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(ticket.category, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  StatusBadge(status: ticket.status),
                  const Spacer(),
                  if (ticket.assignedTo != null) ...[
                    const Icon(Icons.person_outline, size: 14, color: Colors.black45),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        ticket.assignedTo!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    Formatters.relative(ticket.updatedAt),
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
