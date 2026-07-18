import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/enums.dart';
import '../../../domain/parking.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import 'parking_providers.dart';

/// Smart Parking (proposal §6.2): live color-coded slot map for everyone,
/// vehicle registration for employees, and unregistered-vehicle alerts for
/// security staff. Data is the mock stand-in for the future MQTT feed.
class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthAuthenticated) return const LoadingView();
    final isSecurity = authState.user.role == UserRole.security;

    // No Scaffold/AppBar here — the surrounding AppShell provides those.
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(parkingSlotsProvider);
        ref.invalidate(parkingOverviewProvider);
        ref.invalidate(myVehiclesProvider);
        ref.invalidate(parkingAlertsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        children: [
          const _OverviewRow(),
          const SizedBox(height: 20),
          if (isSecurity) ...[
            _sectionTitle(context, 'Entry Alerts'),
            const SizedBox(height: 12),
            const _AlertsList(),
            const SizedBox(height: 24),
          ],
          _sectionTitle(context, 'Live Slot Map'),
          const SizedBox(height: 4),
          const Text(
            'Updated by the slot sensors in real time.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          const _SlotMap(),
          const SizedBox(height: 24),
          if (!isSecurity) ...[
            Row(
              children: [
                Expanded(child: _sectionTitle(context, 'My Vehicles')),
                TextButton.icon(
                  onPressed: () => _showRegisterVehicleSheet(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Register'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const _MyVehiclesList(),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      );
}

class _OverviewRow extends ConsumerWidget {
  const _OverviewRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(parkingOverviewProvider);
    return overviewAsync.when(
      data: (o) => Row(
        children: [
          Expanded(child: _statTile('Available', o.free, AppColors.ok)),
          const SizedBox(width: 10),
          Expanded(child: _statTile('Occupied', o.occupied, AppColors.accent)),
          const SizedBox(width: 10),
          Expanded(child: _statTile('Flagged', o.flagged, AppColors.bad)),
        ],
      ),
      loading: () => const SizedBox(height: 88, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _statTile(String label, int value, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: AppColors.tint(color), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _SlotMap extends ConsumerWidget {
  const _SlotMap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(parkingSlotsProvider);
    return slotsAsync.when(
      data: (slots) {
        final zones = <String, List<ParkingSlot>>{};
        for (final s in slots) {
          zones.putIfAbsent(s.zone, () => []).add(s);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in zones.entries) ...[
              Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.35,
                children: [for (final slot in entry.value) _SlotTile(slot: slot)],
              ),
              const SizedBox(height: 16),
            ],
            const _SlotLegend(),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorView(
        message: error is ApiException ? error.message : 'Failed to load parking data.',
        onRetry: () => ref.invalidate(parkingSlotsProvider),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot});

  final ParkingSlot slot;

  @override
  Widget build(BuildContext context) {
    final color = slot.status.color;
    final tooltip = switch (slot.status) {
      ParkingSlotStatus.free => '${slot.label} — available',
      ParkingSlotStatus.occupied => '${slot.label} — ${slot.plate ?? 'occupied'}',
      ParkingSlotStatus.flagged => '${slot.label} — unregistered vehicle ${slot.plate ?? ''}',
    };
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.tint(color, opacity: slot.status == ParkingSlotStatus.free ? 0.10 : 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              slot.status == ParkingSlotStatus.free
                  ? Icons.check
                  : slot.status == ParkingSlotStatus.flagged
                      ? Icons.priority_high
                      : Icons.directions_car_filled,
              size: 16,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              slot.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotLegend extends StatelessWidget {
  const _SlotLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          ],
        );
    return Wrap(
      spacing: 16,
      children: [
        item(AppColors.ok, 'Available'),
        item(AppColors.accent, 'Registered vehicle'),
        item(AppColors.bad, 'Unregistered / flagged'),
      ],
    );
  }
}

class _MyVehiclesList extends ConsumerWidget {
  const _MyVehiclesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);
    return vehiclesAsync.when(
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No vehicles registered yet. Register one so the entrance reader recognises it.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          );
        }
        return Column(
          children: [
            for (final v in vehicles)
              Card(
                margin: const EdgeInsets.only(top: 10),
                child: ListTile(
                  leading: const Icon(Icons.directions_car_outlined, color: AppColors.brand),
                  title: Text(v.plate, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${v.model} • ${v.color}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.tint(v.status.color),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      v.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: v.status.color,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorView(
        message: error is ApiException ? error.message : 'Failed to load vehicles.',
        onRetry: () => ref.invalidate(myVehiclesProvider),
      ),
    );
  }
}

class _AlertsList extends ConsumerWidget {
  const _AlertsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(parkingAlertsProvider);
    return alertsAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return const Text(
            'No entry alerts. Every vehicle so far matched the approved list.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          );
        }
        return Column(
          children: [
            for (final a in alerts)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(
                        a.resolved ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        color: a.resolved ? AppColors.neutral : AppColors.bad,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unregistered vehicle ${a.plate}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            Text(
                              '${a.gate} • ${Formatters.relative(a.occurredAt)}',
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!a.resolved)
                        TextButton(
                          onPressed: () async {
                            await ref.read(parkingRepositoryProvider).resolveAlert(a.id);
                            ref.invalidate(parkingAlertsProvider);
                            ref.invalidate(parkingSlotsProvider);
                            ref.invalidate(parkingOverviewProvider);
                          },
                          child: const Text('Resolve'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorView(
        message: error is ApiException ? error.message : 'Failed to load alerts.',
        onRetry: () => ref.invalidate(parkingAlertsProvider),
      ),
    );
  }
}

// --------------------------------------------------------- Register vehicle

Future<void> _showRegisterVehicleSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _RegisterVehicleForm(),
  );
}

class _RegisterVehicleForm extends ConsumerStatefulWidget {
  const _RegisterVehicleForm();

  @override
  ConsumerState<_RegisterVehicleForm> createState() => _RegisterVehicleFormState();
}

class _RegisterVehicleFormState extends ConsumerState<_RegisterVehicleForm> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(parkingRepositoryProvider).registerVehicle(
            plate: _plateController.text,
            model: _modelController.text,
            color: _colorController.text,
          );
      ref.invalidate(myVehiclesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vehicle submitted — pending admin approval.'),
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Register Vehicle',
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
                const Text(
                  'An admin approves new vehicles before the entrance reader will recognise them.',
                  style: TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Plate number (e.g. ICT-1234)'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Plate number is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Make and model'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Vehicle model is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(labelText: 'Color'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Color is required' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Submit for Approval'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
