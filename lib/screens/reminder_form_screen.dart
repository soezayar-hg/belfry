import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/lead_time.dart';
import '../models/recurrence.dart';
import '../models/reminder.dart';
import '../theme/belfry_theme.dart';
import '../widgets/belfry_button.dart';
import '../widgets/datetime_picker.dart';
import '../widgets/segmented_control.dart';

/// Create / edit form for a reminder. Pops a [Reminder] draft on save (with no
/// server id assigned for new reminders) or null on cancel. Styled after the
/// prototype's modal.
class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.existing});

  final Reminder? existing;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _remindAt;
  late Recurrence _recurrence;
  late Set<LeadTime> _leadTimes;
  bool _titleError = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _remindAt =
        existing?.remindAt ??
        DateTime.now().toUtc().add(const Duration(hours: 1));
    _recurrence = existing?.recurrence ?? Recurrence.none;
    _leadTimes = {...?existing?.leadTimes};
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    Navigator.of(context).pop(
      Reminder(
        id: widget.existing?.id ?? '',
        title: title,
        note: _note.text.trim(),
        remindAt: _remindAt,
        recurrence: _recurrence,
        leadTimes: _leadTimes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Esc closes the modal — same as Cancel. Works while typing too,
        // since the key event bubbles up from the focused field.
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Scaffold(
        backgroundColor: BelfryColors.scrim,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  decoration: BoxDecoration(
                    color: BelfryColors.panel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _modalHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field(
                              'What to remember',
                              _textField(
                                _title,
                                'e.g. Pay electricity bill',
                                autofocus: !_isEditing,
                                error: _titleError,
                                onChanged: (_) {
                                  if (_titleError) {
                                    setState(() => _titleError = false);
                                  }
                                },
                              ),
                            ),
                            _field(
                              'When · Asia/Bangkok',
                              BelfryDateTimePicker(
                                value: _remindAt,
                                onChanged: (value) =>
                                    setState(() => _remindAt = value),
                              ),
                            ),
                            _field('Repeat', _repeatControl()),
                            _field('Notify me', _leadTimeList()),
                            _field(
                              'Notes (optional)',
                              _textField(_note, 'Anything else?', maxLines: 3),
                            ),
                          ],
                        ),
                      ),
                      _modalFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modalHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing ? 'Edit reminder' : 'New reminder',
              style: BelfryText.sans(size: 18, weight: FontWeight.w600),
            ),
          ),
          BelfryIconButton(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _modalFooter() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BelfryColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          BelfryButton(
            label: 'Cancel',
            variant: BelfryButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          BelfryButton(
            label: _isEditing ? 'Save' : 'Create reminder',
            variant: BelfryButtonVariant.primary,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _field(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: BelfryText.label()),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint, {
    bool autofocus = false,
    bool error = false,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      onChanged: onChanged,
      style: BelfryText.sans(size: 15),
      cursorColor: BelfryColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: BelfryText.sans(size: 15, color: BelfryColors.ink3),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        filled: true,
        fillColor: BelfryColors.panel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: error ? BelfryColors.danger : BelfryColors.line2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: error ? BelfryColors.danger : BelfryColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _repeatControl() {
    return SegmentedControl<Recurrence>(
      value: _recurrence,
      onChanged: (value) => setState(() => _recurrence = value),
      options: const [
        SegmentOption(Recurrence.none, 'Once'),
        SegmentOption(Recurrence.weekly, 'Weekly'),
        SegmentOption(Recurrence.monthly, 'Monthly'),
        SegmentOption(Recurrence.yearly, 'Yearly'),
      ],
    );
  }

  Widget _leadTimeList() {
    return Column(
      children: [
        // The exact-time alarm is always on and rings.
        Container(
          decoration: BoxDecoration(
            color: BelfryColors.offHover,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.check_box, size: 18, color: BelfryColors.ink),
              const SizedBox(width: 10),
              Text('At exact time', style: BelfryText.sans(size: 14)),
              const Spacer(),
              Text(
                'Always on · rings',
                style: BelfryText.sans(size: 11, color: BelfryColors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final lead in LeadTime.values) ...[
          _leadTimeRow(lead),
          if (lead != LeadTime.values.last) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _leadTimeRow(LeadTime lead) {
    final on = _leadTimes.contains(lead);
    return Material(
      color: on ? BelfryColors.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => setState(() {
          if (on) {
            _leadTimes.remove(lead);
          } else {
            _leadTimes.add(lead);
          }
        }),
        borderRadius: BorderRadius.circular(6),
        hoverColor: BelfryColors.offHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                on ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: on ? BelfryColors.accentInk : BelfryColors.ink3,
              ),
              const SizedBox(width: 10),
              Text(lead.label, style: BelfryText.sans(size: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
