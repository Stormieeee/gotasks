import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:gotask/Pages/edit_event_page.dart';
import 'package:gotask/Pages/list_page.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:gotask/services/auth_service.dart';
import 'create_event_page.dart';
import 'view_event_page.dart';
import 'profile_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final AuthService _authService = AuthService();
  Map<DateTime, List<calendar.Event>> _events = {};
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCalendarEvents();
  }

  Future<void> _fetchCalendarEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final calendarApi = await _authService.getCalendarApi();
      
      if (calendarApi == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get Calendar API client';
        });
        return;
      }

      // Get events for the current month plus padding
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month + 2, 0);
      
      final events = await calendarApi.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      // Group events by date
      final Map<DateTime, List<calendar.Event>> eventMap = {};
      
      for (var event in events.items ?? []) {
        if (event.start?.dateTime != null) {
          final eventDate = DateTime(
            event.start!.dateTime!.year,
            event.start!.dateTime!.month,
            event.start!.dateTime!.day,
          );
          
          if (eventMap[eventDate] == null) {
            eventMap[eventDate] = [];
          }
          
          eventMap[eventDate]!.add(event);
        }
      }

      setState(() {
        _events = eventMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching calendar events: $e';
      });
    }
  }

  List<calendar.Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  Future<void> _deleteEvent(calendar.Event event) async {
    // Show confirmation dialog before deleting
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Task'),
        content: Text('Are you sure you want to clear this task "${event.summary}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('DELETE'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldDelete) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final calendarApi = await _authService.getCalendarApi();
      
      if (calendarApi == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get Calendar API client';
        });
        return;
      }

      // Delete the event
      await calendarApi.events.delete('primary', event.id!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task successfully cleared')),
      );
      
      // Refresh the calendar
      _fetchCalendarEvents();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error clearing task: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event')),
      );
    }
  }

  Future<void> _viewEventDetails(calendar.Event event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(
          event: event,
          onEventDeleted: () => _deleteEvent(event),
          onEventUpdated: _fetchCalendarEvents,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        title: Text(
          'GoTask',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchCalendarEvents,
            tooltip: 'Refresh Tasks/Events',
          ),
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(user: _authService.currentUser!),
                ),
              );
            },
            tooltip: 'User Profile',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Header section
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Tasks/Events',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_focusedDay),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.only(top: 80),
              child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red.shade300,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red.shade300),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _fetchCalendarEvents,
                              child: Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              // Calendar widget with styling
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: TableCalendar(
                                  firstDay: DateTime.utc(2020, 1, 1),
                                  lastDay: DateTime.utc(2030, 12, 31),
                                  focusedDay: _focusedDay,
                                  calendarFormat: _calendarFormat,
                                  eventLoader: _getEventsForDay,
                                  selectedDayPredicate: (day) {
                                    return isSameDay(_selectedDay, day);
                                  },
                                  onDaySelected: (selectedDay, focusedDay) {
                                    setState(() {
                                      _selectedDay = selectedDay;
                                      _focusedDay = focusedDay;
                                    });
                                  },
                                  onFormatChanged: (format) {
                                    setState(() {
                                      _calendarFormat = format;
                                    });
                                  },
                                  onPageChanged: (focusedDay) {
                                    setState(() {
                                      _focusedDay = focusedDay;
                                    });
                                  },
                                  calendarStyle: CalendarStyle(
                                    todayDecoration: BoxDecoration(
                                      color: Colors.blue.shade300,
                                      shape: BoxShape.circle,
                                    ),
                                    selectedDecoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      shape: BoxShape.circle,
                                    ),
                                    markersMaxCount: 3,
                                    markerDecoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      shape: BoxShape.circle,
                                    ),
                                    markerSize: 6,
                                    weekendTextStyle: TextStyle(color: Colors.red.shade300),
                                  ),
                                  headerStyle: HeaderStyle(
                                    formatButtonTextStyle: TextStyle(color: Colors.blue.shade700),
                                    formatButtonDecoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Events section header
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tasks/Events for ${DateFormat('MMM d, yyyy').format(_selectedDay)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Event list for selected day
                              Expanded(
                                child: _getEventsForDay(_selectedDay).isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.event_available,
                                              size: 60,
                                              color: Colors.blue.shade200,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'No Tasks/Events for this day',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Tap the + button to add an Task/Event',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.only(bottom: 80),
                                        itemCount: _getEventsForDay(_selectedDay).length,
                                        itemBuilder: (context, index) {
                                          final event = _getEventsForDay(_selectedDay)[index];
                                          final start = event.start?.dateTime ?? DateTime.now();
                                          final end = event.end?.dateTime ?? DateTime.now();
                                          
                                          final formattedStartTime = DateFormat('h:mm a').format(start);
                                          final formattedEndTime = DateFormat('h:mm a').format(end);
                                          
                                          return Card(
                                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: InkWell(
                                              onTap: () => _viewEventDetails(event),
                                              borderRadius: BorderRadius.circular(12),
                                              child: Padding(
                                                padding: EdgeInsets.all(4),
                                                child: ListTile(
                                                  leading: Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        formattedStartTime.split(':')[0],
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.blue.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  title: Text(
                                                    event.summary ?? 'Untitled Task/Event',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    '$formattedStartTime - $formattedEndTime',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
                                                        onPressed: () async {
                                                          final result = await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => EditEventPage(event: event),
                                                            ),
                                                          );
                                                          
                                                          if (result == true) {
                                                            _fetchCalendarEvents();
                                                          }
                                                        },
                                                      ),
                                                      IconButton(
                                                        icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                                                        onPressed: () => _deleteEvent(event),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
            ),
            
            // List view button
            Positioned(
              left: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: "switchToList", 
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                elevation: 4,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ListPage(),
                    ),
                  );
                },
                child: Icon(Icons.list),
                tooltip: 'Switch to List View',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "addTask",
        backgroundColor: Colors.blue.shade700,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventPage(),
            ),
          );
          
          if (result == true) {
            _fetchCalendarEvents();
          }
        },
        child: Icon(Icons.add),
        tooltip: 'Add Task',
      ),
    );
  }
}