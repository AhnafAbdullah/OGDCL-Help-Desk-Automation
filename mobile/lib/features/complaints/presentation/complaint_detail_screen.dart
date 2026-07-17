import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/complaint.dart';
import '../../../domain/enums.dart';
import '../../../domain/user.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/complaint_actions.dart';
import 'complaints_providers.dart';
import 'widgets/status_timeline.dart';

class ComplaintDetailScreen extends ConsumerStatefulWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final int complaintId;

  @override
  ConsumerState<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  bool _busy = false;

  void _refreshAfterMutation() {
    ref.invalidate(complaintDetailProvider(widget.complaintId));
    ref.invalidate(myComplaintsProvider);
    ref.invalidate(assignedComplaintsProvider);
    ref.invalidate(availableComplaintsProvider);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateStatus(ComplaintStatus status, {String? note}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(complaintRepositoryProvider)
          .updateStatus(widget.complaintId, status: status, note: note);
      _refreshAfterMutation();
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmStatusChange(ComplaintAction action, ComplaintStatus newStatus) async {
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

  Future<void> _confirmSelfAssign(User actor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pick Up Complaint'),
        content: const Text(
          'Pick up this complaint? You\'ll be responsible for working and resolving it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pick Up'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(complaintRepositoryProvider)
          .selfAssign(widget.complaintId, handlerId: actor.id);
      _refreshAfterMutation();
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
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
        await ref.read(complaintRepositoryProvider).submitFeedback(
              widget.complaintId,
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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'docx', 'xlsx', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(complaintRepositoryProvider)
          .uploadAttachment(widget.complaintId, filePath: file.path!, fileName: file.name);
      ref.invalidate(complaintDetailProvider(widget.complaintId));
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAndOpen(Attachment attachment) async {
    setState(() => _busy = true);
    try {
      final bytes = await ref
          .read(complaintRepositoryProvider)
          .downloadAttachment(widget.complaintId, attachment.id);
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
    final complaintAsync = ref.watch(complaintDetailProvider(widget.complaintId));
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Details')),
      body: complaintAsync.when(
        data: (complaint) {
          if (authState is! AuthAuthenticated) return const LoadingView();
          return _buildBody(complaint, authState.user);
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load complaint.',
          onRetry: () => ref.invalidate(complaintDetailProvider(widget.complaintId)),
        ),
      ),
    );
  }

  Widget _buildBody(Complaint complaint, User currentUser) {
    final actions = availableActions(complaint, currentUser);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.refresh(complaintDetailProvider(widget.complaintId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _headerCard(complaint),
              if (complaint.status == ComplaintStatus.pendingApproval) ...[
                const SizedBox(height: 16),
                _infoBanner(
                  icon: Icons.hourglass_top,
                  color: AppColors.warn,
                  message:
                      'This Critical complaint is awaiting admin approval on the web dashboard '
                      'before it\'s routed to a department.',
                ),
              ],
              if (complaint.status == ComplaintStatus.rejected) ...[
                const SizedBox(height: 16),
                _infoBanner(
                  icon: Icons.cancel_outlined,
                  color: AppColors.bad,
                  message: complaint.rejectionReason ?? 'This complaint was rejected by the admin.',
                ),
              ],
              const SizedBox(height: 16),
              _descriptionCard(complaint),
              if (complaint.attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                _attachmentsCard(complaint),
              ],
              if (complaint.feedback != null) ...[
                const SizedBox(height: 16),
                _feedbackCard(complaint.feedback!),
              ],
              const SizedBox(height: 16),
              _historyCard(complaint),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (final action in actions) _buildActionButton(action, currentUser)],
                ),
              ],
            ],
          ),
        ),
        if (_busy) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
      ],
    );
  }

  Widget _infoBanner({required IconData icon, required Color color, required String message}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.tint(color), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildActionButton(ComplaintAction action, User actor) => switch (action) {
        ComplaintAction.selfAssign => _actionButton(action, () => _confirmSelfAssign(actor)),
        ComplaintAction.startProgress =>
          _actionButton(action, () => _confirmStatusChange(action, ComplaintStatus.inProgress)),
        ComplaintAction.markResolved =>
          _actionButton(action, () => _confirmStatusChange(action, ComplaintStatus.resolved)),
        ComplaintAction.closeComplaint =>
          _actionButton(action, () => _confirmStatusChange(action, ComplaintStatus.closed)),
        ComplaintAction.reopenComplaint => _actionButton(
            action,
            () => _confirmStatusChange(action, ComplaintStatus.inProgress),
            filled: false,
          ),
        ComplaintAction.leaveFeedback => _actionButton(action, _openFeedbackDialog, filled: false),
        ComplaintAction.attachFile => _actionButton(action, _attachFile, filled: false),
      };

  Widget _actionButton(ComplaintAction action, VoidCallback onTap, {bool filled = true}) {
    final icon = switch (action) {
      ComplaintAction.selfAssign => Icons.pan_tool_alt_outlined,
      ComplaintAction.startProgress => Icons.play_arrow,
      ComplaintAction.markResolved => Icons.check,
      ComplaintAction.closeComplaint => Icons.lock_outline,
      ComplaintAction.reopenComplaint => Icons.replay,
      ComplaintAction.leaveFeedback => Icons.star_border,
      ComplaintAction.attachFile => Icons.attach_file,
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

  Widget _headerCard(Complaint complaint) {
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
                    complaint.complaintNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
                  ),
                ),
                SeverityBadge(severity: complaint.severity),
                const SizedBox(width: 8),
                StatusBadge(status: complaint.status),
              ],
            ),
            if (complaint.isOverdue) ...[
              const SizedBox(height: 8),
              const Align(alignment: Alignment.centerLeft, child: OverdueBadge()),
            ],
            const SizedBox(height: 8),
            Text(
              complaint.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(complaint.category, style: const TextStyle(color: Colors.black54)),
            const Divider(height: 28),
            _infoRow('Submitted by', complaint.createdBy),
            if (complaint.assignedTo != null) _infoRow('Assigned to', complaint.assignedTo!),
            if (complaint.department != null) _infoRow('Department', complaint.department!),
            _infoRow('Created', Formatters.dateTime(complaint.createdAt)),
            if (complaint.assignedAt != null)
              _infoRow('Assigned', Formatters.dateTime(complaint.assignedAt!)),
            _infoRow('Last updated', Formatters.dateTime(complaint.updatedAt)),
            if (complaint.resolvedAt != null)
              _infoRow('Resolved', Formatters.dateTime(complaint.resolvedAt!)),
            if (complaint.closedAt != null) _infoRow('Closed', Formatters.dateTime(complaint.closedAt!)),
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

  Widget _descriptionCard(Complaint complaint) {
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
            Text(complaint.description),
          ],
        ),
      ),
    );
  }

  Widget _attachmentsCard(Complaint complaint) {
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
            for (final a in complaint.attachments)
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

  Widget _feedbackCard(ComplaintFeedback feedback) {
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

  Widget _historyCard(Complaint complaint) {
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
            StatusTimeline(entries: complaint.statusHistory),
          ],
        ),
      ),
    );
  }
}
