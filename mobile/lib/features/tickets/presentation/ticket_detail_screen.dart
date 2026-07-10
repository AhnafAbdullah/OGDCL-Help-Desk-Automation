import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/enums.dart';
import '../../../domain/ticket.dart';
import '../../../domain/user.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../data/handler_option.dart';
import '../domain/ticket_actions.dart';
import 'tickets_providers.dart';
import 'widgets/status_timeline.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  bool _busy = false;

  void _refreshAfterMutation() {
    ref.invalidate(ticketDetailProvider(widget.ticketId));
    ref.invalidate(myTicketsProvider);
    ref.invalidate(assignedTicketsProvider);
    ref.invalidate(adminTicketsProvider);
    ref.invalidate(adminTicketCountsProvider);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateStatus(TicketStatus status, {String? note}) async {
    setState(() => _busy = true);
    try {
      await ref.read(ticketRepositoryProvider).updateStatus(widget.ticketId, status: status, note: note);
      _refreshAfterMutation();
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmStatusChange(TicketAction action, TicketStatus newStatus) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action.label),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final note = noteController.text.trim();
      await _updateStatus(newStatus, note: note.isEmpty ? null : note);
    }
  }

  Future<void> _openReassignDialog() async {
    setState(() => _busy = true);
    List<HandlerOption> handlers;
    try {
      handlers = await ref.read(ticketRepositoryProvider).activeHandlers();
    } on ApiException catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e.message);
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    if (handlers.isEmpty) {
      _showError('No active handlers are available to reassign to.');
      return;
    }

    var selected = handlers.first.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Reassign Ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final h in handlers)
                  RadioListTile<int>(
                    value: h.id,
                    groupValue: selected,
                    title: Text(h.displayName),
                    subtitle: h.department != null ? Text(h.department!) : null,
                    onChanged: (value) => setDialogState(() => selected = value!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reassign'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _busy = true);
      try {
        await ref.read(ticketRepositoryProvider).assign(widget.ticketId, handlerId: selected);
        _refreshAfterMutation();
      } on ApiException catch (e) {
        _showError(e.message);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _openFeedbackDialog() async {
    var rating = 5;
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Rate the Resolution'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        i <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () => setDialogState(() => rating = i),
                    ),
                ],
              ),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Comment (optional)'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _busy = true);
      try {
        final comment = commentController.text.trim();
        await ref.read(ticketRepositoryProvider).submitFeedback(
              widget.ticketId,
              rating: rating,
              comment: comment.isEmpty ? null : comment,
            );
        _refreshAfterMutation();
      } on ApiException catch (e) {
        _showError(e.message);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _attachFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'docx', 'xlsx', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(ticketRepositoryProvider)
          .uploadAttachment(widget.ticketId, filePath: file.path!, fileName: file.name);
      ref.invalidate(ticketDetailProvider(widget.ticketId));
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAndOpen(Attachment attachment) async {
    setState(() => _busy = true);
    try {
      final bytes =
          await ref.read(ticketRepositoryProvider).downloadAttachment(widget.ticketId, attachment.id);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${attachment.fileName}');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(ticketDetailProvider(widget.ticketId));
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Details')),
      body: ticketAsync.when(
        data: (ticket) {
          if (authState is! AuthAuthenticated) return const LoadingView();
          return _buildBody(ticket, authState.user);
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load ticket.',
          onRetry: () => ref.invalidate(ticketDetailProvider(widget.ticketId)),
        ),
      ),
    );
  }

  Widget _buildBody(Ticket ticket, User currentUser) {
    final actions = availableActions(ticket, currentUser);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.refresh(ticketDetailProvider(widget.ticketId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _headerCard(ticket),
              const SizedBox(height: 16),
              _descriptionCard(ticket),
              if (ticket.attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                _attachmentsCard(ticket),
              ],
              if (ticket.feedback != null) ...[
                const SizedBox(height: 16),
                _feedbackCard(ticket.feedback!),
              ],
              const SizedBox(height: 16),
              _historyCard(ticket),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (final action in actions) _buildActionButton(action)],
                ),
              ],
            ],
          ),
        ),
        if (_busy) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
      ],
    );
  }

  Widget _buildActionButton(TicketAction action) => switch (action) {
        TicketAction.startProgress =>
          _actionButton(action, () => _confirmStatusChange(action, TicketStatus.inProgress)),
        TicketAction.markResolved =>
          _actionButton(action, () => _confirmStatusChange(action, TicketStatus.resolved)),
        TicketAction.closeTicket =>
          _actionButton(action, () => _confirmStatusChange(action, TicketStatus.closed)),
        TicketAction.reopenTicket => _actionButton(
            action,
            () => _confirmStatusChange(action, TicketStatus.inProgress),
            filled: false,
          ),
        TicketAction.reassign => _actionButton(action, _openReassignDialog, filled: false),
        TicketAction.leaveFeedback => _actionButton(action, _openFeedbackDialog, filled: false),
        TicketAction.attachFile => _actionButton(action, _attachFile, filled: false),
      };

  Widget _actionButton(TicketAction action, VoidCallback onTap, {bool filled = true}) {
    final icon = switch (action) {
      TicketAction.startProgress => Icons.play_arrow,
      TicketAction.markResolved => Icons.check,
      TicketAction.closeTicket => Icons.lock_outline,
      TicketAction.reopenTicket => Icons.replay,
      TicketAction.reassign => Icons.swap_horiz,
      TicketAction.leaveFeedback => Icons.star_border,
      TicketAction.attachFile => Icons.attach_file,
    };
    return filled
        ? ElevatedButton.icon(
            onPressed: _busy ? null : onTap,
            icon: Icon(icon, size: 18),
            label: Text(action.label),
          )
        : OutlinedButton.icon(
            onPressed: _busy ? null : onTap,
            icon: Icon(icon, size: 18),
            label: Text(action.label),
          );
  }

  Widget _headerCard(Ticket ticket) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.ticketNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
                  ),
                ),
                PriorityBadge(priority: ticket.priority),
                const SizedBox(width: 8),
                StatusBadge(status: ticket.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(ticket.category, style: const TextStyle(color: Colors.black54)),
            const Divider(height: 28),
            _infoRow('Submitted by', ticket.createdBy),
            if (ticket.assignedTo != null) _infoRow('Assigned to', ticket.assignedTo!),
            if (ticket.department != null) _infoRow('Department', ticket.department!),
            _infoRow('Created', Formatters.dateTime(ticket.createdAt)),
            _infoRow('Last updated', Formatters.dateTime(ticket.updatedAt)),
            if (ticket.resolvedAt != null) _infoRow('Resolved', Formatters.dateTime(ticket.resolvedAt!)),
            if (ticket.closedAt != null) _infoRow('Closed', Formatters.dateTime(ticket.closedAt!)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _descriptionCard(Ticket ticket) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(ticket.description),
          ],
        ),
      ),
    );
  }

  Widget _attachmentsCard(Ticket ticket) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            for (final a in ticket.attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(a.fileName, overflow: TextOverflow.ellipsis),
                subtitle: Text(_fileSize(a.sizeBytes)),
                trailing: const Icon(Icons.download_outlined),
                onTap: _busy ? null : () => _downloadAndOpen(a),
              ),
          ],
        ),
      ),
    );
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _feedbackCard(TicketFeedback feedback) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feedback',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= feedback.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  ),
              ],
            ),
            if (feedback.comment != null && feedback.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(feedback.comment!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyCard(Ticket ticket) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'History',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            StatusTimeline(entries: ticket.statusHistory),
          ],
        ),
      ),
    );
  }
}
