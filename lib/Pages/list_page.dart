import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:gotask/Pages/calendar_page.dart';
import 'package:gotask/Pages/create_event_page.dart';
import 'package:gotask/Pages/edit_event_page.dart';
import 'package:gotask/services/auth_service.dart';
import 'package:gotask/services/cloud_logger.dart';
import 'package:intl/intl.dart';
import 'package:gotask/Pages/view_event_page.dart';
import 'package:gotask/Pages/profile_page.dart';

class ListPage extends StatefulWidget {
  const ListPage({Key? key}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<ListPage> {
  final AuthService _authService = AuthService();
  List<calendar.Event> _events = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    CloudLogger().pageView('ListPage', {
      'source': 'initState',
      'userId': _authService.currentUser?.uid
    });
    
    _fetchCalendarEvents();
  }

  @override
  void dispose() {
    CloudLogger().debug('ListPage disposed', {
      'eventType': 'PAGE_LIFECYCLE',
      'action': 'PAGE_DISPOSED',
      'userId': _authService.currentUser?.uid
    });
    super.dispose();
  }

  Future<void> _fetchCalendarEvents() async {
    final stopwatch = Stopwatch()..start();
    
    CloudLogger().info('Fetching calendar events for list view', {
      'eventType': 'DATA_FETCH',
      'action': 'FETCH_EVENTS_STARTED',
      'viewType': 'list',
      'userId': _authService.currentUser?.uid
    });
    
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
        
        stopwatch.stop();
        CloudLogger().error('Failed to get Calendar API client', {
          'eventType': 'API_ERROR',
          'action': 'FETCH_EVENTS_FAILED',
          'reason': 'NULL_API_CLIENT',
          'durationMs': stopwatch.elapsedMilliseconds,
          'userId': _authService.currentUser?.uid
        });
        return;
      }

      // Get events from primary calendar for next 30 days
      final now = DateTime.now();
      final days = now.add(Duration(days: 30));
      
      final apiStopwatch = Stopwatch()..start();
      final events = await calendarApi.events.list(
        'primary',
        timeMin: now.toUtc(),
        timeMax: days.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      apiStopwatch.stop();

      setState(() {
        _events = events.items ?? [];
        _isLoading = false;
      });
      
      stopwatch.stop();
      CloudLogger().info('Calendar events fetched successfully for list view', {
        'eventType': 'DATA_FETCH',
        'action': 'FETCH_EVENTS_COMPLETED',
        'eventCount': events.items?.length ?? 0,
        'timeRangeStart': now.toIso8601String(),
        'timeRangeEnd': days.toIso8601String(),
        'apiFetchDurationMs': apiStopwatch.elapsedMilliseconds,
        'totalDurationMs': stopwatch.elapsedMilliseconds,
        'userId': _authService.currentUser?.uid
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching calendar events: $e';
      });
      
      stopwatch.stop();
      CloudLogger().error('Error fetching calendar events for list view', {
        'eventType': 'API_ERROR',
        'action': 'FETCH_EVENTS_ERROR',
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'userId': _authService.currentUser?.uid
      });
    }
  }

  Future<void> _deleteEvent(calendar.Event event) async {
    CloudLogger().userAction('delete_event_dialog_shown', {
      'eventId': event.id,
      'eventTitle': event.summary,
      'screen': 'ListPage',
      'userId': _authService.currentUser?.uid
    });
    
    // Show confirmation dialog before deleting
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Task/Event'),
        content: Text('Are you sure you want to clear this task "${event.summary}"?'),
        actions: [
          TextButton(
            onPressed: () {
              CloudLogger().userAction('delete_event_cancelled', {
                'eventId': event.id,
                'eventTitle': event.summary,
                'userId': _authService.currentUser?.uid
              });
              Navigator.of(context).pop(false);
            },
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              CloudLogger().userAction('delete_event_confirmed', {
                'eventId': event.id,
                'eventTitle': event.summary,
                'userId': _authService.currentUser?.uid
              });
              Navigator.of(context).pop(true);
            },
            child: Text('CLEAR'),
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
      'action': 'DELETE_EVENT_STARTED',
      'eventId': event.id,
      'eventTitle': event.summary,
      'userId': _authService.currentUser?.uid
    });
    
    try {
      final calendarApi = await _authService.getCalendarApi();
      
      if (calendarApi == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get Calendar API client';
        });
        
        stopwatch.stop();
        CloudLogger().error('Failed to get Calendar API client for delete', {
          'eventType': 'API_ERROR',
          'action': 'DELETE_EVENT_FAILED',
          'reason': 'NULL_API_CLIENT',
          'eventId': event.id,
          'durationMs': stopwatch.elapsedMilliseconds,
          'userId': _authService.currentUser?.uid
        });
        return;
      }

      // Delete the event
      final apiStopwatch = Stopwatch()..start();
      await calendarApi.events.delete('primary', event.id!);
      apiStopwatch.stop();
      
      stopwatch.stop();
      CloudLogger().info('Calendar event deleted successfully', {
        'eventType': 'DATA_MUTATION',
        'action': 'DELETE_EVENT_COMPLETED',
        'eventId': event.id,
        'apiCallDurationMs': apiStopwatch.elapsedMilliseconds,
        'totalDurationMs': stopwatch.elapsedMilliseconds,
        'userId': _authService.currentUser?.uid
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task cleared successfully')),
      );
      
      // Refresh the calendar
      _fetchCalendarEvents();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error clearing event: $e';
      });
      
      stopwatch.stop();
      CloudLogger().error('Error deleting calendar event', {
        'eventType': 'API_ERROR',
        'action': 'DELETE_EVENT_ERROR',
        'eventId': event.id,
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'userId': _authService.currentUser?.uid
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing event')),
      );
    }
  }

  Future<void> _viewEventDetails(calendar.Event event) async {
    CloudLogger().userAction('view_event_details', {
      'eventId': event.id,
      'eventTitle': event.summary,
      'eventDate': event.start?.dateTime?.toIso8601String(),
      'source': 'ListPage',
      'userId': _authService.currentUser?.uid
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
    
    CloudLogger().pageView('ListPage', {
      'returnedFrom': 'EventDetailsPage',
      'userId': _authService.currentUser?.uid
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
              CloudLogger().userAction('refresh_events_button_tapped', {
                'source': 'ListPage',
                'currentEventCount': _events.length,
                'userId': _authService.currentUser?.uid
              });
              _fetchCalendarEvents();
            },
            tooltip: 'Refresh Tasks/Events',
          ),
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              CloudLogger().userAction('navigate_to_profile', {
                'from': 'ListPage',
                'userId': _authService.currentUser?.uid
              });
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(user: _authService.currentUser!),
                ),
              ).then((_) {
                CloudLogger().pageView('ListPage', {
                  'returnedFrom': 'ProfilePage',
                  'userId': _authService.currentUser?.uid
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
                      'Next 30 days',
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
                                CloudLogger().userAction('retry_fetch_events_button_tapped', {
                                  'source': 'ListPage',
                                  'previousError': _errorMessage,
                                  'userId': _authService.currentUser?.uid
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
                    : _events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 80,
                                  color: Colors.blue.shade200,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No events scheduled',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap the + button to create a new Task/Event',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue.shade600,
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
                              child: ListView.builder(
                                padding: EdgeInsets.only(top: 16, bottom: 80),
                                itemCount: _events.length,
                                itemBuilder: (context, index) {
                                  final event = _events[index];
                                  final start = event.start?.dateTime ?? DateTime.now();
                                  final end = event.end?.dateTime ?? DateTime.now();
                                  
                                  // Show date header for each new date
                                  bool showHeader = index == 0 || 
                                    !isSameDay(start, _events[index - 1].start?.dateTime);
                                  
                                  if (showHeader && index > 0) {
                                    // Log when user scrolls to a new date section
                                    CloudLogger().debug('User viewed new date section', {
                                      'eventType': 'USER_INTERACTION',
                                      'action': 'VIEW_DATE_SECTION',
                                      'date': DateFormat('yyyy-MM-dd').format(start),
                                      'position': index,
                                      'userId': _authService.currentUser?.uid
                                    });
                                  }
                                  
                                  final formattedStartTime = DateFormat('h:mm a').format(start);
                                  final formattedEndTime = DateFormat('h:mm a').format(end);
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (showHeader)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            left: 24, 
                                            right: 24, 
                                            top: index == 0 ? 8 : 24, 
                                            bottom: 12
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat('EEEE').format(start),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('MMMM d, yyyy').format(start),
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Card(
                                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: InkWell(
                                          onTap: () => _viewEventDetails(event),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Column(
                                              children: [
                                                ListTile(
                                                  leading: Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.event,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    event.summary ?? 'Untitled Task',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 14,
                                                            color: Colors.grey.shade600,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            '$formattedStartTime - $formattedEndTime',
                                                            style: TextStyle(
                                                              color: Colors.grey.shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (event.location != null && event.location!.isNotEmpty)
                                                        Padding(
                                                          padding: EdgeInsets.only(top: 4),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.location_on,
                                                                size: 14,
                                                                color: Colors.grey.shade600,
                                                              ),
                                                              SizedBox(width: 4),
                                                              Expanded(
                                                                child: Text(
                                                                  event.location!,
                                                                  style: TextStyle(
                                                                    color: Colors.grey.shade700,
                                                                    fontSize: 12,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  isThreeLine: true,
                                                  trailing: Icon(
                                                    Icons.chevron_right,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    TextButton.icon(
                                                      icon: Icon(
                                                        Icons.edit,
                                                        size: 18,
                                                      ),
                                                      label: Text('Edit'),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.blue.shade700,
                                                      ),
                                                      onPressed: () async {
                                                        CloudLogger().userAction('edit_event_button_tapped', {
                                                          'eventId': event.id,
                                                          'eventTitle': event.summary,
                                                          'source': 'ListPage',
                                                          'userId': _authService.currentUser?.uid
                                                        });
                                                        
                                                        final result = await Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => EditEventPage(event: event),
                                                          ),
                                                        );
                                                        
                                                        CloudLogger().pageView('ListPage', {
                                                          'returnedFrom': 'EditEventPage',
                                                          'editResult': result.toString(),
                                                          'userId': _authService.currentUser?.uid
                                                        });
                                                        
                                                        if (result == true) {
                                                          _fetchCalendarEvents();
                                                        }
                                                      },
                                                    ),
                                                    TextButton.icon(
                                                      icon: Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                      ),
                                                      label: Text('Clear'),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.red,
                                                      ),
                                                      onPressed: () {
                                                        CloudLogger().userAction('clear_event_button_tapped', {
                                                          'eventId': event.id,
                                                          'eventTitle': event.summary,
                                                          'source': 'ListPage',
                                                          'userId': _authService.currentUser?.uid
                                                        });
                                                        _deleteEvent(event);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
            ),
            
            // Calendar view button
            Positioned(
              left: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: "switchToCalendar",
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                elevation: 4,
                onPressed: () {
                  CloudLogger().userAction('switch_to_calendar_view', {
                    'from': 'ListPage',
                    'eventCount': _events.length,
                    'userId': _authService.currentUser?.uid
                  });
                  
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CalendarPage(),
                    ),
                  );
                },
                child: Icon(Icons.calendar_month),
                tooltip: 'Switch to Calendar View',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "addEvent",
        backgroundColor: Colors.blue.shade700,
        onPressed: () async {
          CloudLogger().userAction('add_task_button_tapped', {
            'source': 'ListPage',
            'userId': _authService.currentUser?.uid
          });
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventPage(),
            ),
          );
          
          CloudLogger().pageView('ListPage', {
            'returnedFrom': 'CreateEventPage',
            'createResult': result.toString(),
            'userId': _authService.currentUser?.uid
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
  
  // Helper function to check if two dates are the same day
  bool isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}