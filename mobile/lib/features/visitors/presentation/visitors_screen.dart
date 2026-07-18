import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/enums.dart';
import '../../../domain/visitor.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import 'visitors_providers.dart';

/// Visitor Entry Management (proposal §6.3). Employees pre-register their
/// guests; the generated gate code goes to the guards, who verify it on
/// arrival, issue an RFID card, and close the visit on departure.
class VisitorsScreen extends ConsumerWidget {
  const VisitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthAuthenticated) return const LoadingView();

    // No Scaffold/AppBar here — the surrounding AppShell provides those.
    return authState.user.role == UserRole.security
        ? const _GateDeskView()
        : const _HostView();
  }
}

// ------------------------------------------------------------- Host view

class _HostView extends ConsumerWidget {
  const _HostView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(myVisitorsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myVisitorsProvider.future),
      child: visitsAsync.when(
        data: (visits) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My Visitors',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showRegisterVisitorSheet(context),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Register'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Register guests before they arrive — the gate code goes straight to security.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (visits.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyView(
                  message: 'No visitors registered yet.',
                  icon: Icons.badge_outlined,
                ),
              )
            else
              for (final v in visits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _VisitCard(visit: v, gateActions: false),
                ),
          ],
        ),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load visitors.',
          onRetry: () => ref.invalidate(myVisitorsProvider),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Gate desk view

class _GateDeskView extends ConsumerWidget {
  const _GateDeskView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(gateVisitsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(gateVisitsProvider.future),
      child: visitsAsync.when(
        data: (visits) {
          final pending = visits.where((v) => v.status == VisitStatus.preRegistered).toList();
          final onSite = visits.where((v) => v.status == VisitStatus.checkedIn).toList();
          final departed = visits.where((v) => v.status == VisitStatus.checkedOut).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
            children: [
              ElevatedButton.icon(
                onPressed: () => _showVerifyDialog(context, ref),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Verify Visitor Code'),
              ),
              const SizedBox(height: 20),
              _sectionTitle(context, 'Expected Arrivals (${pending.length})'),
              const SizedBox(height: 10),
              if (pending.isEmpty)
                const Text('No pending arrivals.',
                    style: TextStyle(color: Colors.black54, fontSize: 13))
              else
                for (final v in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VisitCard(visit: v, gateActions: true),
                  ),
              const SizedBox(height: 18),
              _sectionTitle(context, 'Currently On Site (${onSite.length})'),
              const SizedBox(height: 10),
              if (onSite.isEmpty)
                const Text('No visitors inside right now.',
                    style: TextStyle(color: Colors.black54, fontSize: 13))
              else
                for (final v in onSite)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VisitCard(visit: v, gateActions: true),
                  ),
              if (departed.isNotEmpty) ...[
                const SizedBox(height: 18),
                _sectionTitle(context, 'Recent Departures'),
                const SizedBox(height: 10),
                for (final v in departed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VisitCard(visit: v, gateActions: false),
                  ),
              ],
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load gate desk.',
          onRetry: () => ref.invalidate(gateVisitsProvider),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      );
}

// -------------------------------------------------------------- Visit card

class _VisitCard extends ConsumerWidget {
  const _VisitCard({required this.visit, required this.gateActions});

  final VisitorVisit visit;

  /// Whether to show the guard's check-out action on an on-site visit.
  final bool gateActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.visitorName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.tint(visit.status.color),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    visit.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: visit.status.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(visit.purpose, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 8),
            _detailLine(Icons.schedule, switch (visit.status) {
              VisitStatus.preRegistered =>
                'Expected ${Formatters.dateTime(visit.expectedArrival)}',
              VisitStatus.checkedIn =>
                'Arrived ${Formatters.relative(visit.checkInAt ?? visit.expectedArrival)}',
              VisitStatus.checkedOut =>
                'Departed ${Formatters.relative(visit.checkOutAt ?? visit.expectedArrival)}',
            }),
            _detailLine(Icons.person_outline, 'Host: ${visit.hostName}'),
            if (visit.rfidCard != null) _detailLine(Icons.credit_card, 'Card ${visit.rfidCard}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final zone in visit.allowedZones)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
                    ),
                    child: Text(zone,
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ),
              ],
            ),
            if (visit.zoneEvents.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (final e in visit.zoneEvents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        e.allowed ? Icons.check_circle_outline : Icons.block,
                        size: 15,
                        color: e.allowed ? AppColors.ok : AppColors.bad,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          e.allowed
                              ? 'Entered ${e.zone}'
                              : 'Blocked at ${e.zone} — not permitted',
                          style: TextStyle(
                            fontSize: 12,
                            color: e.allowed ? Colors.black54 : AppColors.bad,
                            fontWeight: e.allowed ? FontWeight.w400 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        Formatters.relative(e.occurredAt),
                        style: const TextStyle(fontSize: 11, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
            ],
            if (gateActions && visit.status == VisitStatus.checkedIn) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _checkOut(context, ref),
                  icon: const Icon(Icons.logout, size: 17),
                  label: const Text('Check Out & Collect Card'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailLine(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.black45),
            const SizedBox(width: 7),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            ),
          ],
        ),
      );

  Future<void> _checkOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(visitorRepositoryProvider).checkOut(visit.id);
      ref.invalidate(gateVisitsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('${visit.visitorName} checked out — card deactivated.'),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

// -------------------------------------------------- Guard: verify + check-in

Future<void> _showVerifyDialog(BuildContext context, WidgetRef ref) async {
  final otpController = TextEditingController();
  final cardController = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Verify Visitor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Visitor code (OTP)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cardController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'RFID card to issue (e.g. RFID-1031)'),
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
          child: const Text('Check In'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  try {
    final visit = await ref.read(visitorRepositoryProvider).verifyAndCheckIn(
          otp: otpController.text,
          rfidCard: cardController.text,
        );
    ref.invalidate(gateVisitsProvider);
    messenger.showSnackBar(SnackBar(
      content: Text('${visit.visitorName} checked in — host notified.'),
    ));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

// ------------------------------------------------------ Register visitor

/// Opens the visitor pre-registration form as a modal popup, matching the
/// New Complaint pattern.
Future<void> showRegisterVisitorSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _RegisterVisitorForm(),
  );
}

class _RegisterVisitorForm extends ConsumerStatefulWidget {
  const _RegisterVisitorForm();

  @override
  ConsumerState<_RegisterVisitorForm> createState() => _RegisterVisitorFormState();
}

class _RegisterVisitorFormState extends ConsumerState<_RegisterVisitorForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _contactController = TextEditingController();
  final _purposeController = TextEditingController();
  DateTime _expectedArrival = DateTime.now().add(const Duration(hours: 1));
  final Set<String> _zones = {'Reception'};
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cnicController.dispose();
    _contactController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _pickArrival() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedArrival,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedArrival),
    );
    if (time == null) return;
    setState(() {
      _expectedArrival = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one permitted zone.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(visitorRepositoryProvider).register(
            visitorName: _nameController.text,
            cnic: _cnicController.text,
            contact: _contactController.text,
            purpose: _purposeController.text,
            expectedArrival: _expectedArrival,
            allowedZones: _zones.toList(),
          );
      ref.invalidate(myVisitorsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Visitor registered — gate code sent to security.'),
      ));
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
                      'Register Visitor',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
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
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Visitor name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Visitor name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cnicController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'CNIC (e.g. 61101-1234567-1)'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'CNIC is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Contact number'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Contact number is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _purposeController,
                      decoration: const InputDecoration(labelText: 'Purpose of visit'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Purpose is required' : null,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickArrival,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Expected arrival',
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(Formatters.dateTime(_expectedArrival)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Permitted zones',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The RFID card issued at the gate is limited to these areas.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    for (final zone in kVisitorZones)
                      CheckboxListTile(
                        value: _zones.contains(zone),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _zones.add(zone);
                          } else {
                            _zones.remove(zone);
                          }
                        }),
                        title: Text(zone, style: const TextStyle(fontSize: 14)),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text('Register Visitor'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
