import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'edit_event_page.dart';

class EventDetailsPage extends StatelessWidget {
  final calendar.Event event;
  final Function onEventDeleted;
  final Function onEventUpdated;

  const EventDetailsPage({
    Key? key,
    required this.event,
    required this.onEventDeleted,
    required this.onEventUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startDateTime = event.start?.dateTime ?? DateTime.now();
    final endDateTime = event.end?.dateTime ?? DateTime.now();
    
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(startDateTime);
    final formattedStartTime = DateFormat('h:mm a').format(startDateTime);
    final formattedEndTime = DateFormat('h:mm a').format(endDateTime);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditEventPage(event: event),
                ),
              );
              
              if (result == true) {
                onEventUpdated();
                Navigator.pop(context); // Return to calendar after update
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.summary ?? 'Untitled Event',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            '$formattedStartTime - $formattedEndTime',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      if (event.location != null && event.location!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.location!,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (event.description != null && event.description!.isNotEmpty) ...[
                SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          event.description!,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  icon: Icon(Icons.delete),
                  label: Text('Delete Event'),
                  onPressed: () async {
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

                    if (shouldDelete) {
                      onEventDeleted();
                      Navigator.pop(context); // Return to calendar after deletion
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}