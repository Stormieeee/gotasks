import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:gotask/Pages/edit_event_page.dart';
import 'package:gotask/Pages/list_page.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:gotask/services/auth_service.dart';
import 'package:gotask/services/cloud_logger.dart';
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
    CloudLogger().pageView('CalendarPage', {
      'initialDate': _selectedDay.toIso8601String(),
      'calendarFormat': _calendarFormat.toString()
    });
    _fetchCalendarEvents();
  }

  Future<void> _fetchCalendarEvents() async {
    final stopwatch = Stopwatch()..start();
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    CloudLogger().info('Fetching calendar events', {
      'eventType': 'DATA_FETCH',
      'component': 'CalendarPage',
      'action': 'FETCH_EVENTS_STARTED',
      'focusedMonth': DateFormat('yyyy-MM').format(_focusedDay)
    });

    try {
      final calendarApi = await _authService.getCalendarApi();
      
      if (calendarApi == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get Calendar API client';
        });
        
        CloudLogger().error('Failed to get Calendar API client', {
          'eventType': 'API_ERROR',
          'component': 'CalendarPage',
          'action': 'FETCH_EVENTS_FAILED',
          'reason': 'NULL_API_CLIENT'
        });
        return;
      }

      // Get events for the current month plus padding
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month + 2, 0);
      
      final fetchStopwatch = Stopwatch()..start();
      final events = await calendarApi.events.list(
        'primary',
        // Use toUtc() for consistent API calls
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      fetchStopwatch.stop();

      // Group events by date
      final Map<DateTime, List<calendar.Event>> eventMap = {};
      
      for (var event in events.items ?? []) {
        if (event.start?.dateTime != null) {
          // Convert to local time and then create a normalized date
          final localEventDate = event.start!.dateTime!.toLocal();
          final eventDate = DateTime(
            localEventDate.year,
            localEventDate.month,
            localEventDate.day,
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
      
      stopwatch.stop();
      CloudLogger().info('Calendar events fetched successfully', {
        'eventType': 'DATA_FETCH',
        'component': 'CalendarPage',
        'action': 'FETCH_EVENTS_COMPLETED',
        'eventCount': events.items?.length ?? 0,
        'daysWithEvents': eventMap.length,
        'apiFetchDurationMs': fetchStopwatch.elapsedMilliseconds,
        'totalDurationMs': stopwatch.elapsedMilliseconds
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching calendar events: $e';
      });
      
      stopwatch.stop();
      CloudLogger().error('Error fetching calendar events', {
        'eventType': 'API_ERROR',
        'component': 'CalendarPage',
        'action': 'FETCH_EVENTS_ERROR',
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds
      });
    }
  }

  List<calendar.Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  Future<void> _deleteEvent(calendar.Event event) async {
    CloudLogger().userAction('delete_event_dialog_shown', {
      'eventId': event.id,
      'eventTitle': event.summary,
      'screen': 'CalendarPage'
    });

    // Show confirmation dialog before deleting
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Task'),
        content: Text('Are you sure you want to clear this task "${event.summary}"?'),
        actions: [
          TextButton(
            onPressed: () {
              CloudLogger().userAction('delete_event_canceled', {
                'eventId': event.id,
                'eventTitle': event.summary
              });
              Navigator.of(context).pop(false);
            },
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              CloudLogger().userAction('delete_event_confirmed', {
                'eventId': event.id,
                'eventTitle': event.summary
              });
              Navigator.of(context).pop(true);
            },
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

    final stopwatch = Stopwatch()..start();
    CloudLogger().info('Deleting calendar event', {
      'eventType': 'DATA_MUTATION',
      'component': 'CalendarPage',
      'action': 'DELETE_EVENT_STARTED',
      'eventId': event.id,
      'eventTitle': event.summary
    });

    try {
      final calendarApi = await _authService.getCalendarApi();
      
      if (calendarApi == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get Calendar API client';
        });
        
        CloudLogger().error('Failed to get Calendar API client for delete', {
          'eventType': 'API_ERROR',
          'component': 'CalendarPage',
          'action': 'DELETE_EVENT_FAILED',
          'reason': 'NULL_API_CLIENT',
          'eventId': event.id
        });
        return;
      }

      // Delete the event
      await calendarApi.events.delete('primary', event.id!);
      
      stopwatch.stop();
      CloudLogger().info('Calendar event deleted successfully', {
        'eventType': 'DATA_MUTATION',
        'component': 'CalendarPage',
        'action': 'DELETE_EVENT_COMPLETED',
        'eventId': event.id,
        'durationMs': stopwatch.elapsedMilliseconds
      });
      
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
      
      stopwatch.stop();
      CloudLogger().error('Error deleting calendar event', {
        'eventType': 'API_ERROR',
        'component': 'CalendarPage',
        'action': 'DELETE_EVENT_ERROR',
        'eventId': event.id,
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event')),
      );
    }
  }

  Future<void> _viewEventDetails(calendar.Event event) async {
    CloudLogger().userAction('view_event_details', {
      'eventId': event.id,
      'eventTitle': event.summary,
      'eventDate': event.start?.dateTime?.toIso8601String()
    });
    
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
    
    CloudLogger().pageView('CalendarPage', {
      'returnedFrom': 'EventDetailsPage',
      'selectedDate': _selectedDay.toIso8601String()
    });
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
            onPressed: () {
              CloudLogger().userAction('refresh_calendar', {
                'focusedMonth': DateFormat('yyyy-MM').format(_focusedDay)
              });
              _fetchCalendarEvents();
            },
            tooltip: 'Refresh Tasks/Events',
          ),
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              CloudLogger().userAction('navigate_to_profile', {
                'from': 'CalendarPage'
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(user: _authService.currentUser!),
                ),
              ).then((_) {
                CloudLogger().pageView('CalendarPage', {
                  'returnedFrom': 'ProfilePage'
                });
              });
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
                              onPressed: () {
                                CloudLogger().userAction('retry_calendar_fetch', {
                                  'previousError': _errorMessage
                                });
                                _fetchCalendarEvents();
                              },
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
                                  firstDay: DateTime(2020, 1, 1),
                                  lastDay: DateTime(2030, 12, 31),
                                  focusedDay: _focusedDay,
                                  calendarFormat: _calendarFormat,
                                  eventLoader: _getEventsForDay,
                                  selectedDayPredicate: (day) {
                                    return isSameDay(_selectedDay, day);
                                  },
                                  onDaySelected: (selectedDay, focusedDay) {
                                    CloudLogger().userAction('calendar_day_selected', {
                                      'selectedDate': DateFormat('yyyy-MM-dd').format(selectedDay),
                                      'previousDate': DateFormat('yyyy-MM-dd').format(_selectedDay),
                                      'eventCount': _getEventsForDay(selectedDay).length
                                    });
                                    
                                    setState(() {
                                      _selectedDay = selectedDay;
                                      _focusedDay = focusedDay;
                                    });
                                  },onFormatChanged: (format) {
                                    CloudLogger().userAction('calendar_format_changed', {
                                      'previousFormat': _calendarFormat.toString(),
                                      'newFormat': format.toString()
                                    });
                                    
                                    setState(() {
                                      _calendarFormat = format;
                                    });
                                  },
                                  onPageChanged: (focusedDay) {
                                    CloudLogger().userAction('calendar_page_changed', {
                                      'previousMonth': DateFormat('yyyy-MM').format(_focusedDay),
                                      'newMonth': DateFormat('yyyy-MM').format(focusedDay)
                                    });
                                    
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
                                          
                                          // Convert times to local time
                                          final start = event.start?.dateTime?.toLocal() ?? DateTime.now();
                                          final end = event.end?.dateTime?.toLocal() ?? DateTime.now();
                                          
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
                                                          CloudLogger().userAction('edit_event_button_tapped', {
                                                            'eventId': event.id,
                                                            'eventTitle': event.summary
                                                          });
                                                          
                                                          final result = await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => EditEventPage(event: event),
                                                            ),
                                                          );
                                                          
                                                          CloudLogger().pageView('CalendarPage', {
                                                            'returnedFrom': 'EditEventPage',
                                                            'editResult': result.toString()
                                                          });
                                                          
                                                          if (result == true) {
                                                            _fetchCalendarEvents();
                                                          }
                                                        },
                                                      ),
                                                      IconButton(
                                                        icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                                                        onPressed: () {
                                                          CloudLogger().userAction('delete_event_button_tapped', {
                                                            'eventId': event.id,
                                                            'eventTitle': event.summary
                                                          });
                                                          _deleteEvent(event);
                                                        },
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
                  CloudLogger().userAction('switch_to_list_view', {
                    'from': 'CalendarPage',
                    'currentMonth': DateFormat('yyyy-MM').format(_focusedDay)
                  });
                  
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
          CloudLogger().userAction('add_task_button_tapped', {
            'selectedDate': DateFormat('yyyy-MM-dd').format(_selectedDay)
          });
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventPage(),
            ),
          );
          
          CloudLogger().pageView('CalendarPage', {
            'returnedFrom': 'CreateEventPage',
            'createResult': result.toString()
          });
          
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