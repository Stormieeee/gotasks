import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:gotask/edit_event_page.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'auth_service.dart';
import 'create_event_page.dart';
import 'view_event_page.dart';
import 'list_page.dart'; // Import the list view page

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
        title: Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.summary}"?'),
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
        SnackBar(content: Text('Event deleted successfully')),
      );
      
      // Refresh the calendar
      _fetchCalendarEvents();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error deleting event: $e';
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
        title: Text('Calendar View'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchCalendarEvents,
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
                  : Column(
                      children: [
                        TableCalendar(
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
                            _focusedDay = focusedDay;
                          },
                          calendarStyle: CalendarStyle(
                            markersMaxCount: 3,
                            markerDecoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Expanded(
                          child: _getEventsForDay(_selectedDay).isEmpty
                              ? Center(child: Text('No events scheduled for this day'))
                              : ListView.builder(
                                  itemCount: _getEventsForDay(_selectedDay).length,
                                  itemBuilder: (context, index) {
                                    final event = _getEventsForDay(_selectedDay)[index];
                                    final start = event.start?.dateTime ?? DateTime.now();
                                    final end = event.end?.dateTime ?? DateTime.now();
                                    
                                    final formattedStartTime = DateFormat('h:mm a').format(start);
                                    final formattedEndTime = DateFormat('h:mm a').format(end);
                                    
                                    return Card(
                                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      child: InkWell(
                                        onTap: () => _viewEventDetails(event),
                                        child: ListTile(
                                          title: Text(event.summary ?? 'Untitled Event'),
                                          subtitle: Text('$formattedStartTime - $formattedEndTime'),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.edit, color: Colors.blue),
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
                                                icon: Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => _deleteEvent(event),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: "switchToList", // Add a unique hero tag to avoid conflicts
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
      floatingActionButton: FloatingActionButton(
        heroTag: "addEvent",
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
        tooltip: 'Add Event',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}