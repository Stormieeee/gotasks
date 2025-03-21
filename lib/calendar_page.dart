import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'create_event_page.dart';
import 'edit_event_page.dart';
import 'view_event_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final AuthService _authService = AuthService();
  List<calendar.Event> _events = [];
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

      // Get events from primary calendar for next 7 days
      final now = DateTime.now();
      final oneWeekFromNow = now.add(Duration(days: 7));
      
      final events = await calendarApi.events.list(
        'primary',
        timeMin: now.toUtc(),
        timeMax: oneWeekFromNow.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      setState(() {
        _events = events.items ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching calendar events: $e';
      });
    }
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
        title: Text('Google Calendar'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchCalendarEvents,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
              : _events.isEmpty
                  ? Center(child: Text('No events scheduled for the next 7 days'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final start = event.start?.dateTime ?? DateTime.now();
                        final end = event.end?.dateTime ?? DateTime.now();
                        
                        final formattedDate = DateFormat('EEE, MMM d, yyyy').format(start);
                        final formattedStartTime = DateFormat('h:mm a').format(start);
                        final formattedEndTime = DateFormat('h:mm a').format(end);
                        
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: InkWell(
                            onTap: () => _viewEventDetails(event),
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(event.summary ?? 'Untitled Event'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(formattedDate),
                                      Text('$formattedStartTime - $formattedEndTime'),
                                      if (event.location != null && event.location!.isNotEmpty)
                                        Text('📍 ${event.location}', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: Icon(Icons.chevron_right),
                                ),
                                ButtonBar(
                                  alignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, color: Colors.blue),
                                      tooltip: 'Edit Event',
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
                                      icon: Icon(Icons.clear, color: Colors.red),
                                      tooltip: 'Delete Event',
                                      onPressed: () => _deleteEvent(event),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventPage(),
            ),
          );
          
          // If an event was created, refresh the calendar
          if (result == true) {
            _fetchCalendarEvents();
          }
        },
        child: Icon(Icons.add),
        tooltip: 'Add Event',
      ),
    );
  }
}