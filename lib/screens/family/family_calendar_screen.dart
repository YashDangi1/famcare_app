import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../providers/family/family_events_provider.dart';
import '../../models/family/family_event.dart';
import '../../models/family/family_event.dart';
import 'family_event_edit_screen.dart';
import 'family_tasks_screen.dart';
import '../../widgets/error_retry_view.dart';
import 'package:table_calendar/table_calendar.dart';

class FamilyCalendarScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String patientUserId;

  const FamilyCalendarScreen({super.key, required this.groupId, required this.patientUserId});

  @override
  ConsumerState<FamilyCalendarScreen> createState() => _FamilyCalendarScreenState();
}

class _FamilyCalendarScreenState extends ConsumerState<FamilyCalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Fetch events for a month around the selected date
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    final eventsAsync = ref.watch(familyEventsProvider(
      (groupId: widget.groupId, patientUserId: widget.patientUserId, from: startOfMonth, to: endOfMonth)
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Calendar'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.calendarPlus, color: Colors.blue),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyEventEditScreen(
                groupId: widget.groupId,
                patientUserId: widget.patientUserId,
                initialDate: _selectedDate,
              ))).then((_) => ref.refresh(familyEventsProvider((groupId: widget.groupId, patientUserId: widget.patientUserId, from: startOfMonth, to: endOfMonth))));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                return Column(
                  children: [
                    _buildCalendar(events),
                    Expanded(
                      child: _buildEventList(events),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetryView(
                errorMessage: 'Failed to load calendar events.',
                onRetry: () => ref.refresh(familyEventsProvider((groupId: widget.groupId, patientUserId: widget.patientUserId, from: startOfMonth, to: endOfMonth))),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEventList(List<FamilyEvent> events) {
    final dayEvents = events.where((e) => isSameDay(e.startAt, _selectedDate)).toList();
    if (dayEvents.isEmpty) {
      return const Center(child: Text('No events for this day.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayEvents.length,
      itemBuilder: (context, index) {
        return _buildEventCard(dayEvents[index]);
      },
    );
  }

  Widget _buildCalendar(List<FamilyEvent> events) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _selectedDate,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDate = selectedDay;
          });
        },
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        eventLoader: (day) {
          return events.where((e) => isSameDay(e.startAt, day)).toList();
        },
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(FamilyEvent event) {
    final color = _getEventColor(event.eventType);
    final icon = _getEventIcon(event.eventType);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(event.description!, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.clock, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(event.isAllDay ? 'All Day' : DateFormat('jm').format(event.startAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            )
          ],
        ),
        onTap: () {
          if (event.eventType == 'task_due') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyTasksScreen(groupId: event.groupId)));
          }
        },
      ),
    );
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'appointment': return Colors.blue;
      case 'task_due': return Colors.orange;
      case 'care_visit': return Colors.purple;
      case 'med_support_window': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'appointment': return LucideIcons.stethoscope;
      case 'task_due': return LucideIcons.checkSquare;
      case 'care_visit': return LucideIcons.home;
      case 'med_support_window': return LucideIcons.pill;
      default: return LucideIcons.calendar;
    }
  }
}
