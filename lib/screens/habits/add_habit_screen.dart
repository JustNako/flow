import 'package:flutter/material.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit.dart';
import '../../models/habit_template.dart';
import '../../theme/app_theme.dart';
import '../paywall/paywall_screen.dart';
class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = HabitApiService.instance;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  final _timesController = TextEditingController();
  final _notesController = TextEditingController();
  final _unitController = TextEditingController();

  HabitRepeatType _repeatType = HabitRepeatType.everyDay;
  final Set<int> _daysOfWeek = {};
  final Set<int> _daysOfMonth = {};
  HabitRepeatPeriod _repeatPeriod = HabitRepeatPeriod.week;
  int _selectedIconIndex = 0;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _isPublic = true;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is HabitTemplate) {
        _titleController.text = args.title;
        _descriptionController.text = args.description;
        _targetController.text = args.targetDays.toString();
        _repeatType = args.repeatType;
        
        // Find icon index
        final iconIndex = _iconOptions.indexWhere((opt) => opt.icon == args.icon);
        if (iconIndex != -1) {
          _selectedIconIndex = iconIndex;
        }
      }
      _isInitialized = true;
    }
  }

  final List<_RepeatOption> _repeatOptions = [
    _RepeatOption(
      type: HabitRepeatType.everyDay,
      icon: Icons.all_inclusive,
      label: 'Daily',
      subtitle: 'Every single day',
      color: const Color(0xFF00B4DB),
    ),
    _RepeatOption(
      type: HabitRepeatType.specificDaysOfWeek,
      icon: Icons.calendar_view_week,
      label: 'Days of Week',
      subtitle: 'Mon, Wed, Fri...',
      color: const Color(0xFFDA22FF),
    ),
    _RepeatOption(
      type: HabitRepeatType.specificDaysOfMonth,
      icon: Icons.calendar_month,
      label: 'Days of Month',
      subtitle: '1st, 15th, 30th...',
      color: const Color(0xFF11998E),
    ),
    _RepeatOption(
      type: HabitRepeatType.xTimesPerPeriod,
      icon: Icons.repeat,
      label: 'X Times',
      subtitle: '3x per week / month',
      color: const Color(0xFFFF512F),
    ),
  ];

  final List<_IconOption> _iconOptions = [
    _IconOption(Icons.water_drop_outlined, 'Water'),
    _IconOption(Icons.fitness_center, 'Workout'),
    _IconOption(Icons.book_outlined, 'Read'),
    _IconOption(Icons.nights_stay_outlined, 'Sleep'),
    _IconOption(Icons.favorite_border, 'Health'),
    _IconOption(Icons.local_cafe_outlined, 'Coffee'),
    _IconOption(Icons.restaurant_outlined, 'Diet'),
    _IconOption(Icons.psychology_outlined, 'Mind'),
    _IconOption(Icons.code, 'Code'),
    _IconOption(Icons.directions_run, 'Run'),
    _IconOption(Icons.self_improvement, 'Meditate'),
    _IconOption(Icons.music_note_outlined, 'Music'),
    _IconOption(Icons.bed_outlined, 'Bed'),
    _IconOption(Icons.accessibility_new, 'Stretch'),
    _IconOption(Icons.directions_walk, 'Walk'),
    _IconOption(Icons.menu_book, 'Book'),
    _IconOption(Icons.computer, 'Work'),
    _IconOption(Icons.edit_note, 'Plan'),
  ];

  final List<String> _weekDayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _timesController.dispose();
    _notesController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _createHabit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_repeatType == HabitRepeatType.specificDaysOfWeek && _daysOfWeek.isEmpty) {
      _showError('Please select at least one day of the week.');
      return;
    }
    if (_repeatType == HabitRepeatType.specificDaysOfMonth && _daysOfMonth.isEmpty) {
      _showError('Please select at least one day of the month.');
      return;
    }
    if (_repeatType == HabitRepeatType.xTimesPerPeriod &&
        (_timesController.text.isEmpty || int.tryParse(_timesController.text) == null)) {
      _showError('Please enter a valid number of times.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _api.createHabit(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        targetDays: int.tryParse(_targetController.text) ?? 1,
        unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
        repeatType: _repeatType,
        repeatDaysOfWeek: _repeatType == HabitRepeatType.specificDaysOfWeek
            ? (_daysOfWeek.toList()..sort())
            : null,
        repeatDaysOfMonth: _repeatType == HabitRepeatType.specificDaysOfMonth
            ? (_daysOfMonth.toList()..sort())
            : null,
        repeatTimesPerPeriod: _repeatType == HabitRepeatType.xTimesPerPeriod
            ? int.tryParse(_timesController.text)
            : null,
        repeatPeriod: _repeatType == HabitRepeatType.xTimesPerPeriod
            ? (_repeatPeriod == HabitRepeatPeriod.week ? 1 : 2)
            : null,
        isPublic: _isPublic,
        timeOfDay: _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
            : null,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('ProRequired')) {
        if (mounted) _showLimitSheet(msg.replaceFirst('ProRequired: ', ''));
      } else {
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLimitSheet(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Color(0xFF161A22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: context.colors.primary?.withOpacity(0.1) ?? const Color(0xFFDA22FF).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.primary?.withOpacity(0.2) ?? const Color(0xFFDA22FF).withOpacity(0.2)),
              ),
              child: Icon(Icons.star_rounded, color: context.colors.primary ?? const Color(0xFFDA22FF), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Limit Reached',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: context.colors.primary ?? const Color(0xFFDA22FF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (context.colors.primary ?? const Color(0xFFDA22FF)).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Upgrade to Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Maybe later',
                style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: [
            // ── Header ────────────────────────────────────────────────────
            Text('Create New Habit',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Start building a new positive habit',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
            const SizedBox(height: 32),

            // ── Habit Name ────────────────────────────────────────────────
            _sectionLabel('Habit Name'),
            _styledField(
              controller: _titleController,
              hint: 'e.g., Morning Meditation',
              maxLength: 30,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (v.trim().length > 30) return 'Name must be 30 characters or fewer';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Icon Picker ───────────────────────────────────────────────
            _sectionLabel('Choose an Icon'),
            _buildIconGrid(),
            const SizedBox(height: 24),

            // ── Description ───────────────────────────────────────────────
            _styledField(
              controller: _descriptionController,
              hint: 'Why is this habit important to you?',
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // ── Notes ─────────────────────────────────────────────────────
            _sectionLabel('Personal Notes (Optional)'),
            _styledField(
              controller: _notesController,
              hint: 'Any specific instructions or notes for yourself...',
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // ── Time of Day ───────────────────────────────────────────────
            _sectionLabel('Time of Day (Optional)'),
            _buildTimePicker(),
            const SizedBox(height: 24),

            // ── Repeat Type ───────────────────────────────────────────────
            _sectionLabel('Frequency'),
            _buildRepeatTypeSelector(),
            const SizedBox(height: 20),

            // ── Dynamic sub-fields based on repeat type ───────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation,
                    child: SizeTransition(sizeFactor: animation, child: child)),
              child: _buildRepeatSubFields(),
            ),

            // ── Daily Target & Unit ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Daily Target'),
                      _styledField(
                        controller: _targetController,
                        hint: 'e.g., 30',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Unit (Optional)'),
                      _styledField(
                        controller: _unitController,
                        hint: 'e.g., min, ml, pages',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Amount and unit per day',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 48),

            // ── Visibility Toggle ─────────────────────────────────────────
            _buildVisibilityToggle(),
            const SizedBox(height: 24),

            // ── Create Button ─────────────────────────────────────────────
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  // ─── Section Label ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  // ─── Styled Text Field ──────────────────────────────────────────────────────
  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 15),
        filled: true,
        fillColor: context.colors.cardSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.primary ?? const Color(0xFFDA22FF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.danger, width: 1.5),
        ),
        errorStyle: TextStyle(color: context.colors.danger),
      ),
    );
  }

  // ─── Icon Grid ──────────────────────────────────────────────────────────────
  Widget _buildIconGrid() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _iconOptions.length,
        padding: const EdgeInsets.symmetric(vertical: 4),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final opt = _iconOptions[i];
          return _IconItem(
            icon: opt.icon,
            label: opt.label,
            isSelected: _selectedIconIndex == i,
            onTap: () => setState(() => _selectedIconIndex = i),
          );
        },
      ),
    );
  }

  // ─── Repeat Type Cards ──────────────────────────────────────────────────────
  Widget _buildRepeatTypeSelector() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _repeatOptions.map((opt) {
        return _RepeatTypeCard(
          option: opt,
          isSelected: _repeatType == opt.type,
          onTap: () => setState(() => _repeatType = opt.type),
        );
      }).toList(),
    );
  }

  // ─── Dynamic Sub-Fields ─────────────────────────────────────────────────────
  Widget _buildRepeatSubFields() {
    switch (_repeatType) {
      case HabitRepeatType.specificDaysOfWeek:
        return _buildDaysOfWeekPicker();
      case HabitRepeatType.specificDaysOfMonth:
        return _buildDaysOfMonthPicker();
      case HabitRepeatType.xTimesPerPeriod:
        return _buildXTimesPicker();
      default:
        return const SizedBox(key: ValueKey('none'));
    }
  }

  Widget _buildDaysOfWeekPicker() {
    return Padding(
      key: const ValueKey('daysOfWeek'),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Days',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Habit will repeat on selected days every week',
            style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              // Map: 0(Mon)->1, 1(Tue)->2 ... 5(Sat)->6, 6(Sun)->0
              final dayValue = (i + 1) % 7;
              final isSelected = _daysOfWeek.contains(dayValue);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) _daysOfWeek.remove(dayValue); else _daysOfWeek.add(dayValue);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42, height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFDA22FF) : const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFDA22FF) : Colors.white.withOpacity(0.05)),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFFDA22FF).withOpacity(0.35),
                            blurRadius: 10, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_weekDayLabels[i].substring(0, 1),
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF8A8F9E),
                          fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(_weekDayLabels[i].substring(1),
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : const Color(0xFF4A4E5A),
                          fontSize: 10)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfMonthPicker() {
    return Padding(
      key: const ValueKey('daysOfMonth'),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Days of Month',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Habit repeats on chosen dates each month',
            style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
            itemCount: 31,
            itemBuilder: (_, i) {
              final day = i + 1;
              final isSelected = _daysOfMonth.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) _daysOfMonth.remove(day); else _daysOfMonth.add(day);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF11998E) : const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF38EF7D) : Colors.white.withOpacity(0.05)),
                  ),
                  child: Center(
                    child: Text('$day',
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF8A8F9E),
                        fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildXTimesPicker() {
    return Padding(
      key: const ValueKey('xTimes'),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set Frequency',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('How many times do you want to repeat this habit?',
            style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            children: [
              // Times input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Times', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _timesController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 24,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '3',
                        hintStyle: const TextStyle(color: Color(0xFF4A4E5A), fontSize: 24),
                        filled: true,
                        fillColor: const Color(0xFF161A22),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFFF512F), width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: const Text('times per',
                  style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 14)),
              ),
              const SizedBox(width: 8),
              // Period toggle (week / month)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Period', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161A22),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _periodTab('Week', HabitRepeatPeriod.week),
                          _periodTab('Month', HabitRepeatPeriod.month),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Preview text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF512F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF512F).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFF7A55), size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_timesController.text.isEmpty ? "?" : _timesController.text} times per '
                  '${_repeatPeriod == HabitRepeatPeriod.week ? "week" : "month"}',
                  style: const TextStyle(color: Color(0xFFFF7A55), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodTab(String label, HabitRepeatPeriod period) {
    final isActive = _repeatPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _repeatPeriod = period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFF512F) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF8A8F9E),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              )),
          ),
        ),
      ),
    );
  }

  // ─── Time Picker ────────────────────────────────────────────────────────────
  Widget _buildTimePicker() {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFFDA22FF),
                    onPrimary: Colors.white,
                    surface: Color(0xFF161A22),
                    onSurface: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
          },
        );
        if (time != null) {
          setState(() => _selectedTime = time);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, 
                 color: _selectedTime != null ? const Color(0xFFDA22FF) : const Color(0xFF8A8F9E), 
                 size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _selectedTime != null 
                  ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                  : 'Select time (24h format)',
                style: TextStyle(
                  color: _selectedTime != null ? Colors.white : const Color(0xFF8A8F9E),
                  fontSize: 15,
                  fontWeight: _selectedTime != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (_selectedTime != null)
              GestureDetector(
                onTap: () => setState(() => _selectedTime = null),
                child: const Icon(Icons.close, color: Color(0xFF8A8F9E), size: 20),
              )
            else
              const Icon(Icons.chevron_right, color: Color(0xFF4A4E5A), size: 22),
          ],
        ),
      ),
    );
  }

  // ─── Visibility Toggle ──────────────────────────────────────────────────────
  Widget _buildVisibilityToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isPublic = !_isPublic),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.cardSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isPublic
                ? context.colors.success.withOpacity(0.4)
                : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isPublic
                    ? context.colors.success.withOpacity(0.15)
                    : context.colors.textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPublic ? Icons.people_outline : Icons.lock_outline,
                color: _isPublic ? context.colors.success : context.colors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isPublic ? 'Visible to Friends' : 'Private',
                    style: TextStyle(
                      color: _isPublic ? context.colors.textPrimary : context.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isPublic
                        ? 'Friends can see this habit and your progress'
                        : 'Only you can see this habit',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              activeColor: context.colors.success,
              inactiveThumbColor: context.colors.textSecondary,
              inactiveTrackColor: context.colors.cardSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Create Button ──────────────────────────────────────────────────────────
  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _createHabit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: context.colors.primary,
          boxShadow: _isLoading ? [] : [
            BoxShadow(
              color: (context.colors.primary ?? const Color(0xFFFF524A)).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            )
          ],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Create Habit',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Data classes ────────────────────────────────────────────────────────────
class _RepeatOption {
  final HabitRepeatType type;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  const _RepeatOption({
    required this.type, required this.icon,
    required this.label, required this.subtitle, required this.color,
  });
}

class _IconOption {
  final IconData icon;
  final String label;
  const _IconOption(this.icon, this.label);
}

// ─── Optimized Sub-Widgets ──────────────────────────────────────────────────

class _IconItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: isSelected ? context.colors.primary : context.colors.cardSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : context.colors.border,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (context.colors.primary ?? const Color(0xFFDA22FF)).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : context.colors.textPrimary, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.colors.textSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepeatTypeCard extends StatelessWidget {
  final _RepeatOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _RepeatTypeCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? option.color.withOpacity(0.12) : const Color(0xFF161A22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? option.color.withOpacity(0.5) : Colors.white.withOpacity(0.05),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? option.color : option.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  option.icon,
                  color: isSelected ? Colors.white : option.color.withOpacity(0.7),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFB0B5C0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      option.subtitle,
                      style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}