import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/category.dart';
import '../../../domain/enums.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import 'complaints_providers.dart';

/// The "New Complaint" form, shown as a modal popup (see [showNewComplaintSheet])
/// rather than a separate page.
class NewComplaintForm extends ConsumerStatefulWidget {
  const NewComplaintForm({super.key});

  @override
  ConsumerState<NewComplaintForm> createState() => _NewComplaintFormState();
}

/// Opens the New Complaint form as a draggable modal popup.
Future<void> showNewComplaintSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const NewComplaintForm(),
  );
}

class _NewComplaintFormState extends ConsumerState<NewComplaintForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _categoryId;
  ComplaintSeverity _severity = ComplaintSeverity.medium;
  PlatformFile? _attachment;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'docx', 'xlsx', 'txt'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _attachment = result.files.first);
    }
  }

  Future<void> _submit() async {
    final categoryId = _categoryId;
    if (!_formKey.currentState!.validate() || categoryId == null) {
      if (categoryId == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please choose a category.')));
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(complaintRepositoryProvider);
      final complaint = await repo.create(
        categoryId: categoryId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        severity: _severity,
      );

      final attachment = _attachment;
      if (attachment != null && attachment.path != null) {
        try {
          await repo.uploadAttachment(
            complaint.id,
            filePath: attachment.path!,
            fileName: attachment.name,
          );
        } on ApiException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Complaint submitted, but the attachment failed: ${e.message}')),
            );
          }
        }
      }

      ref.invalidate(myComplaintsProvider);
      if (!mounted) return;
      final goRouter = GoRouter.of(context);
      Navigator.of(context).pop();
      goRouter.push(RoutePaths.complaintDetail(complaint.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: viewInsets),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'New Complaint',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: categoriesAsync.when(
                data: _buildForm,
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(
                  message: error is ApiException ? error.message : 'Failed to load categories.',
                  onRetry: () => ref.invalidate(categoriesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(List<Category> categories) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
            validator: (value) => value == null ? 'Please choose a category' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
            minLines: 4,
            maxLines: 8,
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Description is required' : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Severity',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final severity in ComplaintSeverity.values)
                ChoiceChip(
                  label: Text(severity.label),
                  avatar: CircleAvatar(backgroundColor: severity.color),
                  selected: _severity == severity,
                  onSelected: (_) => setState(() => _severity = severity),
                ),
            ],
          ),
          if (_severity == ComplaintSeverity.critical) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.bad),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.bad, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Critical complaints are routed to the admin for approval before '
                      'being assigned to a department.',
                      style: TextStyle(color: AppColors.bad, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(_attachment == null ? 'Attach a file (optional)' : _attachment!.name),
          ),
          if (_attachment != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _attachment = null),
                child: const Text('Remove attachment'),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Allowed: jpg, jpeg, png, gif, pdf, docx, xlsx, txt — up to 10 MB.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Submit Complaint'),
          ),
        ],
      ),
    );
  }
}
