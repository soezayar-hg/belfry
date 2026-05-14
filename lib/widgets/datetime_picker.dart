import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bangkok_time.dart';
import '../theme/belfry_theme.dart';

/// A collapsible date-time picker: a trigger row that expands into a month
/// calendar plus hour / minute stepper fields and an AM/PM toggle. The value
/// is a UTC instant; everything is shown and edited in Bangkok time.
class BelfryDateTimePicker extends StatefulWidget {
  const BelfryDateTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  State<BelfryDateTimePicker> createState() => _BelfryDateTimePickerState();
}

class _BelfryDateTimePickerState extends State<BelfryDateTimePicker>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late int _viewYear;
  late int _viewMonth;
  late final AnimationController _expand;
  late final Animation<double> _curve;

  static const _weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final b = BangkokTime.toBangkok(widget.value);
    _viewYear = b.year;
    _viewMonth = b.month;
    _expand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _curve = CurvedAnimation(
      parent: _expand,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _expand.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _expand.forward();
    } else {
      _expand.reverse();
    }
  }

  @override
  void didUpdateWidget(BelfryDateTimePicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final b = BangkokTime.toBangkok(widget.value);
      _viewYear = b.year;
      _viewMonth = b.month;
    }
  }

  void _emit({int? year, int? month, int? day, int? hour, int? minute}) {
    final b = BangkokTime.toBangkok(widget.value);
    widget.onChanged(
      BangkokTime.fromParts(
        year ?? b.year,
        month ?? b.month,
        day ?? b.day,
        hour ?? b.hour,
        minute ?? b.minute,
      ),
    );
  }

  void _stepMonth(int delta) {
    setState(() {
      var m = _viewMonth + delta;
      var y = _viewYear;
      if (m < 1) {
        m = 12;
        y -= 1;
      } else if (m > 12) {
        m = 1;
        y += 1;
      }
      _viewMonth = m;
      _viewYear = y;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _trigger(),
        // Expand/collapse from the top edge with a synced fade.
        ClipRect(
          child: SizeTransition(
            sizeFactor: _curve,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: _curve,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _panel(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _trigger() {
    final value = widget.value;
    final rel = BangkokTime.formatRelative(value, DateTime.now().toUtc());

    return Material(
      color: BelfryColors.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _open ? BelfryColors.primary : BelfryColors.line2,
              width: _open ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BangkokTime.formatDate(value),
                        style: BelfryText.sans(
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            BangkokTime.formatTime(value),
                            style: BelfryText.mono(
                              size: 13,
                              color: BelfryColors.ink2,
                            ),
                          ),
                          Text(
                            '  ·  ',
                            style: BelfryText.sans(
                              size: 13,
                              color: BelfryColors.ink3,
                            ),
                          ),
                          Text(
                            rel.toUpperCase(),
                            style: BelfryText.sans(
                              size: 11,
                              color: BelfryColors.ink3,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: BelfryColors.ink3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    return Container(
      decoration: BoxDecoration(
        color: BelfryColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BelfryColors.line2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _calendarHeader(),
          _calendarGrid(),
          const Divider(height: 1, color: BelfryColors.line),
          _timeRow(),
        ],
      ),
    );
  }

  Widget _calendarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _stepMonth(-1),
            icon: const Icon(Icons.chevron_left, size: 18),
            color: BelfryColors.ink2,
            visualDensity: VisualDensity.compact,
          ),
          Row(
            children: [
              Text(
                _monthNames[_viewMonth - 1],
                style: BelfryText.sans(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Text(
                '$_viewYear',
                style: BelfryText.sans(size: 14, color: BelfryColors.ink3),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _stepMonth(1),
            icon: const Icon(Icons.chevron_right, size: 18),
            color: BelfryColors.ink2,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _calendarGrid() {
    final selected = BangkokTime.toBangkok(widget.value);
    final today = BangkokTime.now();

    // Sunday-first grid. DateTime.weekday: Mon=1..Sun=7.
    final firstWeekday = DateTime.utc(_viewYear, _viewMonth, 1).weekday % 7;
    final daysInMonth = DateTime.utc(_viewYear, _viewMonth + 1, 0).day;

    final cells = <Widget>[
      for (final letter in _weekdayLetters)
        Center(
          child: Text(
            letter,
            style: BelfryText.sans(
              size: 10,
              weight: FontWeight.w500,
              color: BelfryColors.ink3,
              letterSpacing: 0.6,
            ),
          ),
        ),
    ];

    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final isSelected = day == selected.day &&
          _viewMonth == selected.month &&
          _viewYear == selected.year;
      final isToday = day == today.day &&
          _viewMonth == today.month &&
          _viewYear == today.year;
      cells.add(
        _DayCell(
          day: day,
          selected: isSelected,
          today: isToday,
          onTap: () => _emit(year: _viewYear, month: _viewMonth, day: day),
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.25,
        children: cells,
      ),
    );
  }

  Widget _timeRow() {
    final b = BangkokTime.toBangkok(widget.value);
    final isPm = b.hour >= 12;
    final hour12 = b.hour % 12 == 0 ? 12 : b.hour % 12;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimeStepper(
            label: 'Hour',
            value: hour12,
            min: 1,
            max: 12,
            onChanged: (h12) => _emit(hour: (h12 % 12) + (isPm ? 12 : 0)),
          ),
          SizedBox(
            width: 22,
            height: _TimeStepper.controlHeight,
            child: Center(
              child: Text(
                ':',
                style: BelfryText.mono(size: 24, color: BelfryColors.ink3),
              ),
            ),
          ),
          _TimeStepper(
            label: 'Minute',
            value: b.minute,
            min: 0,
            max: 59,
            onChanged: (m) => _emit(minute: m),
          ),
          const SizedBox(width: 14),
          SizedBox(
            height: _TimeStepper.controlHeight,
            child: Center(
              child: _AmPmToggle(
                isPm: isPm,
                onChanged: (pm) {
                  if (pm == isPm) return;
                  final shifted = pm ? b.hour + 12 : b.hour - 12;
                  _emit(hour: (shifted % 24 + 24) % 24);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    // Selected days darken on hover; unselected days get the soft beige wash.
    final Color background;
    if (selected) {
      background = _hovering
          ? Color.alphaBlend(
              Colors.black.withValues(alpha: 0.12),
              BelfryColors.primary,
            )
          : BelfryColors.primary;
    } else {
      background = _hovering ? BelfryColors.dayHover : Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.all(1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${widget.day}',
                  style: BelfryText.mono(
                    size: 13,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? BelfryColors.onPrimary
                        : BelfryColors.ink,
                  ),
                ),
                if (widget.today)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? BelfryColors.onPrimary
                            : BelfryColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single hour/minute field: an up arrow, a value box (tap to type), and a
/// down arrow, with a caption below. Arrows step the value and wrap around the
/// [min]–[max] range; holding an arrow repeats. [value] is in display units
/// (1–12 for the hour, 0–59 for the minute).
class _TimeStepper extends StatefulWidget {
  const _TimeStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  /// Height of the arrow/box/arrow control region — used by the time row to
  /// vertically centre the colon and the AM/PM toggle next to it.
  static const double controlHeight = 28 + 3 + 46 + 3 + 28;

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_TimeStepper> createState() => _TimeStepperState();
}

class _TimeStepperState extends State<_TimeStepper> {
  static const double _boxWidth = 64;
  static const double _arrowHeight = 28;
  static const double _boxHeight = 46;

  bool _editing = false;
  Timer? _repeat;
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Commit when focus leaves the field (tapped elsewhere).
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commitEdit();
    });
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Wrap [raw] into the inclusive [min]–[max] range.
  int _wrap(int raw) {
    final span = widget.max - widget.min + 1;
    return widget.min + ((raw - widget.min) % span + span) % span;
  }

  void _step(int delta) => widget.onChanged(_wrap(widget.value + delta));

  void _pressArrow(int delta) {
    if (_editing) _commitEdit();
    _step(delta);
    _repeat?.cancel();
    // Hold to repeat: a short delay, then steady ticks.
    _repeat = Timer(const Duration(milliseconds: 350), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 70),
        (_) => _step(delta),
      );
    });
  }

  void _releaseArrow() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _beginEdit() {
    _text.text = '${widget.value}'.padLeft(2, '0');
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
    setState(() => _editing = true);
  }

  void _commitEdit() {
    final parsed = int.tryParse(_text.text.trim());
    if (parsed != null) widget.onChanged(_wrap(parsed));
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(Icons.keyboard_arrow_up_rounded, 1),
        const SizedBox(height: 3),
        _valueBox(),
        const SizedBox(height: 3),
        _arrow(Icons.keyboard_arrow_down_rounded, -1),
        const SizedBox(height: 6),
        Text(
          widget.label.toUpperCase(),
          style: BelfryText.sans(
            size: 10,
            weight: FontWeight.w600,
            color: BelfryColors.ink3,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, int delta) {
    return GestureDetector(
      onTapDown: (_) => _pressArrow(delta),
      onTapUp: (_) => _releaseArrow(),
      onTapCancel: _releaseArrow,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: _boxWidth,
          height: _arrowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BelfryColors.railBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: BelfryColors.ink2),
        ),
      ),
    );
  }

  Widget _valueBox() {
    if (_editing) {
      return SizedBox(
        width: _boxWidth,
        height: _boxHeight,
        child: TextField(
          controller: _text,
          focusNode: _focus,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          style: BelfryText.mono(size: 22, weight: FontWeight.w600),
          cursorColor: BelfryColors.primary,
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: true,
            fillColor: BelfryColors.panel,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: BelfryColors.primary,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: BelfryColors.primary,
                width: 1.5,
              ),
            ),
          ),
          onSubmitted: (_) => _commitEdit(),
        ),
      );
    }
    return GestureDetector(
      onTap: _beginEdit,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: Container(
          width: _boxWidth,
          height: _boxHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BelfryColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BelfryColors.line2),
          ),
          child: Text(
            '${widget.value}'.padLeft(2, '0'),
            style: BelfryText.mono(size: 22, weight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _AmPmToggle extends StatelessWidget {
  const _AmPmToggle({required this.isPm, required this.onChanged});

  final bool isPm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BelfryColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BelfryColors.line2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('AM', !isPm, () => onChanged(false)),
          const Divider(height: 1, color: BelfryColors.line),
          _segment('PM', isPm, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool on, VoidCallback onTap) {
    return Material(
      color: on ? BelfryColors.primary : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: BelfryText.mono(
              size: 13,
              weight: FontWeight.w600,
              color: on ? BelfryColors.onPrimary : BelfryColors.ink3,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}
