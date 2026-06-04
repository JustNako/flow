import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit.dart';
import '../../models/habit_template.dart';
import '../../models/ai_habit_dto.dart';
import '../../theme/app_theme.dart';
import '../paywall/paywall_screen.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  Color get _kBgDark => context.colors.background;
  Color get _kCardBg => context.colors.card;
  Color get _kCardBorder => context.colors.border;
  Color get _kSageGreen => context.colors.sage;
  Color get _kSageGreenDark => context.colors.sage.withOpacity(0.85);
  Color get _kLavender => context.colors.lavender;
  Color get _kTerracotta => context.colors.terracotta;
  Color get _kTextPrimary => context.colors.textPrimary;
  Color get _kTextSecondary => context.colors.textSecondary;
  Color get _kTextMuted => context.colors.textSecondary.withOpacity(0.65);
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

        final iconIndex =
            _iconOptions.indexWhere((opt) => opt.icon == args.icon);
        if (iconIndex != -1) {
          _selectedIconIndex = iconIndex;
        }
      } else if (args is AiHabitDto) {
        _titleController.text = args.title;
        _descriptionController.text = args.description;
        _targetController.text = args.targetDays.toString();
        _unitController.text = args.unit ?? '';

        int rTypeIdx = args.repeatType;
        if (rTypeIdx >= 0 && rTypeIdx < HabitRepeatType.values.length) {
          _repeatType = HabitRepeatType.values[rTypeIdx];
        }

        if (args.repeatDaysOfWeek != null) {
          _daysOfWeek.addAll(args.repeatDaysOfWeek!);
        }

        if (args.repeatTimesPerPeriod != null) {
          _timesController.text = args.repeatTimesPerPeriod.toString();
        }

        if (args.timeOfDay != null &&
            args.timeOfDay!.toLowerCase() != 'null' &&
            args.timeOfDay!.isNotEmpty) {
          final timeLower = args.timeOfDay!.toLowerCase();
          if (timeLower.contains('morning')) {
            _selectedTime = const TimeOfDay(hour: 8, minute: 0);
          } else if (timeLower.contains('afternoon')) {
            _selectedTime = const TimeOfDay(hour: 14, minute: 0);
          } else if (timeLower.contains('evening')) {
            _selectedTime = const TimeOfDay(hour: 19, minute: 0);
          } else if (timeLower.contains('night')) {
            _selectedTime = const TimeOfDay(hour: 22, minute: 0);
          }
        }

        IconData findIcon(String name) {
          switch (name) {
            case 'fitness_center': return Icons.fitness_center;
            case 'water_drop': return Icons.water_drop_outlined;
            case 'book': return Icons.book_outlined;
            case 'self_improvement': return Icons.self_improvement;
            case 'code': return Icons.code;
            case 'local_fire_department': return Icons.local_fire_department;
            case 'monitor_heart': return Icons.monitor_heart_outlined;
            case 'spa': return Icons.spa_outlined;
            case 'directions_run': return Icons.directions_run;
            case 'bolt': return Icons.bolt;
            case 'directions_walk': return Icons.directions_walk;
            case 'bedtime': return Icons.bedtime_outlined;
            case 'restaurant': return Icons.restaurant_outlined;
            case 'psychology': return Icons.psychology_outlined;
            case 'savings': return Icons.savings_outlined;
            default: return Icons.task_alt;
          }
        }

        final iconIndex =
            _iconOptions.indexWhere((opt) => opt.icon == findIcon(args.icon));
        if (iconIndex != -1) {
          _selectedIconIndex = iconIndex;
        }
      }
      _isInitialized = true;
    }
  }

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

  final List<String> _weekDayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

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

  // ─── Business Logic (unchanged) ───────────────────────────────────────────

  Future<void> _createHabit() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a habit name.');
      return;
    }
    if (_titleController.text.trim().length > 30) {
      _showError('Habit name must be 30 characters or fewer.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_repeatType == HabitRepeatType.specificDaysOfWeek &&
        _daysOfWeek.isEmpty) {
      _showError('Please select at least one day of the week.');
      return;
    }
    if (_repeatType == HabitRepeatType.specificDaysOfMonth &&
        _daysOfMonth.isEmpty) {
      _showError('Please select at least one day of the month.');
      return;
    }
    if (_repeatType == HabitRepeatType.xTimesPerPeriod &&
        (_timesController.text.isEmpty ||
            int.tryParse(_timesController.text) == null)) {
      _showError('Please enter a valid number of times.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _api.createHabit(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        targetDays: int.tryParse(_targetController.text) ?? 1,
        unit: _unitController.text.trim().isEmpty
            ? null
            : _unitController.text.trim(),
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
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kTerracotta.withOpacity(0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: _kTerracotta.withOpacity(0.2)),
              ),
              child: Icon(Icons.star_rounded,
                  color: _kTerracotta, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Limit Reached',
              style: GoogleFonts.playfairDisplay(
                  color: _kTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: _kTextSecondary, fontSize: 16, height: 1.5),
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
                  gradient: LinearGradient(
                    colors: [_kSageGreen, _kSageGreenDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _kSageGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Upgrade to Pro',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: _kBgDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe later',
                style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Icon Picker Bottom Sheet ─────────────────────────────────────────────

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _kTextMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Choose an Icon',
              style: GoogleFonts.playfairDisplay(
                color: _kTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _iconOptions.length,
              itemBuilder: (_, i) {
                final opt = _iconOptions[i];
                final isSelected = _selectedIconIndex == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIconIndex = i);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kSageGreen.withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? _kSageGreen.withOpacity(0.5)
                            : _kCardBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(opt.icon,
                            color:
                                isSelected ? _kSageGreen : _kTextSecondary,
                            size: 24),
                        const SizedBox(height: 2),
                        Text(
                          opt.label,
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? _kSageGreen
                                : _kTextMuted,
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── BUILD ────────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Custom AppBar ──────────────────────────────────────────
              _buildAppBar(),

              // ── Scrollable form body ──────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    // ── Habit Name + Icon ────────────────────────────────
                    _buildHabitNameCard(),
                    const SizedBox(height: 16),

                    // ── Description ──────────────────────────────────────
                    _buildBentoCard(
                      label: 'DESCRIPTION',
                      child: _buildTextField(
                        controller: _descriptionController,
                        hint: "What's this habit about?",
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Personal Note ────────────────────────────────────
                    _buildBentoCard(
                      label: 'PERSONAL NOTE',
                      badge: 'Optional',
                      child: _buildTextField(
                        controller: _notesController,
                        hint: 'Your why... a reminder to your future self',
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Time of Day ──────────────────────────────────────
                    _buildBentoCard(
                      label: 'TIME OF DAY',
                      badge: 'Optional',
                      child: _buildTimePicker(),
                    ),
                    const SizedBox(height: 16),

                    // ── Frequency ────────────────────────────────────────
                    _buildBentoCard(
                      label: 'FREQUENCY',
                      child: Column(
                        children: [
                          _buildFrequencyPills(),
                          // Dynamic sub-fields
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                  sizeFactor: animation, child: child),
                            ),
                            child: _buildRepeatSubFields(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Daily Target ─────────────────────────────────────
                    _buildBentoCard(
                      label: 'DAILY TARGET',
                      child: _buildDailyTargetRow(),
                    ),
                    const SizedBox(height: 16),

                    // ── Visibility Toggle ────────────────────────────────
                    _buildVisibilityToggle(),
                    const SizedBox(height: 28),

                    // ── Create Button ────────────────────────────────────
                    _buildCreateButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── UI Components ────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Custom AppBar ─────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: context.colors.textPrimary, size: 24),
          ),
          Expanded(
            child: Text(
              'New Habit',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _createHabit,
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: _kSageGreen,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bento Card Wrapper ────────────────────────────────────────────────────
  Widget _buildBentoCard({
    required String label,
    String? badge,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: _kTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              if (badge != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kLavender.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kLavender.withOpacity(0.2)),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      color: _kLavender,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Styled TextField (no border, blends into bento card) ──────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLength,
    TextStyle? textStyle,
  }) {
    return TextFormField(
      controller: controller,
      style: textStyle ??
          GoogleFonts.inter(color: context.colors.textPrimary, fontSize: 15),
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 15),
        filled: false,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        counterText: '',
        isDense: true,
        errorStyle: GoogleFonts.inter(color: context.colors.danger, fontSize: 12),
      ),
    );
  }

  // ── Habit Name + Icon Card ────────────────────────────────────────────────
  Widget _buildHabitNameCard() {
    final selectedIcon = _iconOptions[_selectedIconIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // Icon circle with green badge
          GestureDetector(
            onTap: _showIconPicker,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _kSageGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _kSageGreen.withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(selectedIcon.icon,
                      color: _kSageGreen, size: 26),
                ),
                // Small green badge
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _kSageGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.card, width: 2),
                    ),
                    child: Icon(Icons.check, color: _kBgDark, size: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Name text field
          Expanded(
            child: _buildTextField(
              controller: _titleController,
              hint: 'Habit name...',
              maxLength: 30,
              textStyle: GoogleFonts.inter(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Time Picker ───────────────────────────────────────────────────────────
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
                  colorScheme: ColorScheme.dark(
                    primary: context.colors.primary,
                    onPrimary: context.colors.background,
                    surface: context.colors.card,
                    onSurface: context.colors.textPrimary,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _selectedTime != null 
              ? _kSageGreen.withOpacity(0.15) 
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedTime != null 
                ? _kSageGreen.withOpacity(0.5) 
                : context.colors.border.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, 
                 color: _selectedTime != null ? _kSageGreen : _kTextSecondary, 
                 size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _selectedTime != null 
                  ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                  : 'Select time (24h)',
                style: GoogleFonts.inter(
                  color: _selectedTime != null ? _kTextPrimary : _kTextSecondary,
                  fontSize: 15,
                  fontWeight: _selectedTime != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (_selectedTime != null)
              GestureDetector(
                onTap: () => setState(() => _selectedTime = null),
                child: Icon(Icons.close_rounded, color: _kTextSecondary, size: 20),
              )
            else
              Icon(Icons.chevron_right_rounded, color: _kTextMuted, size: 22),
          ],
        ),
      ),
    );
  }

  // ── Frequency Pills ───────────────────────────────────────────────────────
  Widget _buildFrequencyPills() {
    final options = [
      _FreqOption('Daily', HabitRepeatType.everyDay),
      _FreqOption('Days of week', HabitRepeatType.specificDaysOfWeek),
      _FreqOption('Days of month', HabitRepeatType.specificDaysOfMonth),
      _FreqOption('Flexible', HabitRepeatType.xTimesPerPeriod),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = _repeatType == opt.type;
          return GestureDetector(
            onTap: () => setState(() => _repeatType = opt.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _kLavender.withOpacity(0.15)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? _kLavender.withOpacity(0.5)
                      : _kCardBorder,
                ),
              ),
              child: Text(
                opt.label,
                style: GoogleFonts.inter(
                  color: isSelected ? _kLavender : _kTextSecondary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Repeat Sub-Fields ─────────────────────────────────────────────────────
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
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Days',
              style: GoogleFonts.inter(
                  color: _kTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final dayValue = (i + 1) % 7;
              final isSelected = _daysOfWeek.contains(dayValue);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected)
                    _daysOfWeek.remove(dayValue);
                  else
                    _daysOfWeek.add(dayValue);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kLavender.withOpacity(0.2)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _kLavender.withOpacity(0.5)
                          : _kCardBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _weekDayLabels[i].substring(0, 2),
                      style: GoogleFonts.inter(
                        color:
                            isSelected ? _kLavender : _kTextSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
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
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Days of Month',
              style: GoogleFonts.inter(
                  color: _kTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: 31,
            itemBuilder: (_, i) {
              final day = i + 1;
              final isSelected = _daysOfMonth.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected)
                    _daysOfMonth.remove(day);
                  else
                    _daysOfMonth.add(day);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kSageGreen.withOpacity(0.2)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? _kSageGreen.withOpacity(0.5)
                          : _kCardBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: GoogleFonts.inter(
                        color: isSelected ? _kSageGreen : _kTextSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
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
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set Frequency',
              style: GoogleFonts.inter(
                  color: _kTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              // Times input
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: TextFormField(
                    controller: _timesController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                        color: _kTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '3',
                      hintStyle: GoogleFonts.inter(
                          color: _kTextMuted.withOpacity(0.5), fontSize: 22),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('times per',
                    style: GoogleFonts.inter(
                        color: _kTextMuted, fontSize: 14)),
              ),
              // Period toggle
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: Row(
                    children: [
                      _periodTab('Week', HabitRepeatPeriod.week),
                      _periodTab('Month', HabitRepeatPeriod.month),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kTerracotta.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kTerracotta.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: _kTerracotta.withOpacity(0.7), size: 15),
                const SizedBox(width: 8),
                Text(
                  '${_timesController.text.isEmpty ? "?" : _timesController.text} times per '
                  '${_repeatPeriod == HabitRepeatPeriod.week ? "week" : "month"}',
                  style: GoogleFonts.inter(
                      color: _kTerracotta.withOpacity(0.8), fontSize: 13),
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
            color: isActive ? _kTerracotta : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.inter(
                  color: isActive ? Colors.white : _kTextSecondary,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        ),
      ),
    );
  }

  // ── Daily Target Row ──────────────────────────────────────────────────────
  Widget _buildDailyTargetRow() {
    return Row(
      children: [
        // Number input
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kCardBorder),
            ),
            child: TextFormField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                  color: _kTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '30',
                hintStyle: GoogleFonts.inter(
                    color: _kTextMuted.withOpacity(0.4), fontSize: 24),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Unit input styled as pill
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _kLavender.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kLavender.withOpacity(0.2)),
            ),
            child: TextFormField(
              controller: _unitController,
              style: GoogleFonts.inter(
                  color: _kLavender, fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'minutes',
                hintStyle: GoogleFonts.inter(
                    color: _kLavender.withOpacity(0.4), fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Visibility Toggle ─────────────────────────────────────────────────────
  Widget _buildVisibilityToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isPublic = !_isPublic),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isPublic
                ? _kSageGreen.withOpacity(0.3)
                : context.colors.border.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visible to friends',
                    style: GoogleFonts.inter(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isPublic
                        ? 'Share your progress publicly'
                        : 'Only you can see this habit',
                    style: GoogleFonts.inter(
                        color: _kTextMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              activeColor: _kSageGreen,
              activeTrackColor: _kSageGreen.withOpacity(0.3),
              inactiveThumbColor: _kTextSecondary,
              inactiveTrackColor: _kCardBorder,
            ),
          ],
        ),
      ),
    );
  }

  // ── Create Button ─────────────────────────────────────────────────────────
  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kSageGreen, _kSageGreenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: _kSageGreen.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _createHabit,
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: _kBgDark, strokeWidth: 2))
                : Text(
                    'Create Habit',
                    style: GoogleFonts.inter(
                      color: _kBgDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Data classes ────────────────────────────────────────────────────────────
class _IconOption {
  final IconData icon;
  final String label;
  const _IconOption(this.icon, this.label);
}


class _FreqOption {
  final String label;
  final HabitRepeatType type;
  const _FreqOption(this.label, this.type);
}