import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../domain/ticket.dart';

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.entries});

  final List<StatusHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) _entry(entries[i], isLast: i == entries.length - 1),
      ],
    );
  }

  Widget _entry(StatusHistoryEntry entry, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: entry.toStatus.color, shape: BoxShape.circle),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: Colors.black12)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fromStatus == null
                        ? entry.toStatus.label
                        : '${entry.fromStatus!.label} → ${entry.toStatus.label}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.changedBy} • ${Formatters.dateTime(entry.changedAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (entry.note != null && entry.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(entry.note!, style: const TextStyle(fontSize: 12.5)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
