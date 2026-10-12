import 'package:flutter/material.dart';

import '../api.dart';
import '../components.dart';
import '../roles.dart';
import '../theme.dart';
import '../ui.dart';

/// Admit a patient to a ward. Whoever admits joins the care team; they can
/// also name the responsible consultant, who becomes the owner.
class AdmitScreen extends StatefulWidget {
  const AdmitScreen({super.key, required this.ward, this.bedId});

  final Map<String, dynamic> ward;
  final String? bedId;

  @override
  State<AdmitScreen> createState() => _AdmitScreenState();
}

class _AdmitScreenState extends State<AdmitScreen> {
  final _mrn = TextEditingController();
  final _name = TextEditingController();
  DateTime? _dateOfBirth;
  String? _sex;
  late String? _bedId = widget.bedId;
  String? _ownerId;
  bool _busy = false;

  late final Future<(List<Map<String, dynamic>>, List<Staff>)> _choices =
      () async {
        final beds = await Api.beds(widget.ward['id']);
        final taken = await Api.occupiedBeds(widget.ward['id']);
        final staff = await Api.colleagues();
        return (
          beds.where((b) => !taken.contains(b['id'])).toList(),
          staff
              .where((s) => s.isActive && s.role == StaffRole.consultant)
              .toList(),
        );
      }();

  Future<void> _admit() async {
    if (_mrn.text.trim().isEmpty || _name.text.trim().isEmpty) {
      showMessage(context, 'MRN and name are required');
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => Api.admitPatient(
        wardId: widget.ward['id'],
        bedId: _bedId,
        mrn: _mrn.text,
        fullName: _name.text,
        dateOfBirth: _dateOfBirth,
        sex: _sex,
        ownerId: _ownerId,
      ),
      'Patient admitted',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1970),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admit to ${widget.ward['name']}')),
      body: FutureBuilder(
        future: _choices,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Loading();
          final (freeBeds, consultants) = snapshot.data!;
          return Readable(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                Space.xl,
              ),
              children: [
                const SectionHeader('Patient'),
                _group([
                  TextField(
                    controller: _mrn,
                    decoration: const InputDecoration(labelText: 'MRN'),
                  ),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  PickerField(
                    label: 'Date of birth',
                    value: _dateOfBirth?.toIso8601String().substring(0, 10),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDateOfBirth,
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _sex,
                    decoration: const InputDecoration(labelText: 'Sex'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Not set')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                    ],
                    onChanged: (v) => setState(() => _sex = v),
                  ),
                ]),
                const SectionHeader('Placement and team'),
                _group([
                  DropdownButtonFormField<String?>(
                    initialValue: freeBeds.any((b) => b['id'] == _bedId)
                        ? _bedId
                        : null,
                    decoration: const InputDecoration(labelText: 'Bed'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No bed yet'),
                      ),
                      for (final b in freeBeds)
                        DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text(bedName(b, freeBeds)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _bedId = v),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _ownerId,
                    decoration: const InputDecoration(
                      labelText: 'Responsible consultant',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Not set'),
                      ),
                      for (final c in consultants)
                        DropdownMenuItem(value: c.id, child: Text(c.fullName)),
                    ],
                    onChanged: (v) => setState(() => _ownerId = v),
                  ),
                ]),
                const SizedBox(height: Space.xl),
                FilledButton.icon(
                  onPressed: _busy ? null : _admit,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(_busy ? 'Admitting…' : 'Admit'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Fields in a card, evenly spaced.
  Widget _group(List<Widget> fields) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(spacing: Space.md, children: fields),
    ),
  );
}
