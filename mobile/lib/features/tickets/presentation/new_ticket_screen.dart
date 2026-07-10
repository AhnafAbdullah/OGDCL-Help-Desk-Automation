import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/routing/route_paths.dart';
import '../../../domain/category.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import 'tickets_providers.dart';

class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _categoryId;
  PlatformFile? _attachment;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
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
      final repo = ref.read(ticketRepositoryProvider);
      final ticket = await repo.create(
        categoryId: categoryId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      final attachment = _attachment;
      if (attachment != null && attachment.path != null) {
        try {
          await repo.uploadAttachment(
            ticket.id,
            filePath: attachment.path!,
            fileName: attachment.name,
          );
        } on ApiException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ticket created, but the attachment failed: ${e.message}')),
            );
          }
        }
      }

      ref.invalidate(myTicketsProvider);
      if (!mounted) return;
      context.pushReplacement(RoutePaths.ticketDetail(ticket.id));
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

    return Scaffold(
      appBar: AppBar(title: const Text('New Complaint')),
      body: categoriesAsync.when(
        data: _buildForm,
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load categories.',
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      ),
    );
  }

  Widget _buildForm(List<Category> categories) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
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
            minLines: 5,
            maxLines: 10,
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Description is required' : null,
          ),
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
          const SizedBox(height: 28),
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
