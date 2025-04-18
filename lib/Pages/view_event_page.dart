import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gotask/services/cloud_logger.dart';
import 'edit_event_page.dart';

class EventDetailsPage extends StatefulWidget {
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
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  bool _isLoadingMap = true;
  LatLng? _locationCoordinates;
  String? _locationError;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    
    CloudLogger().pageView('EventDetailsPage', {
      'eventId': widget.event.id,
      'eventTitle': widget.event.summary,
      'hasLocation': widget.event.location != null && widget.event.location!.isNotEmpty,
      'hasDescription': widget.event.description != null && widget.event.description!.isNotEmpty
    });
    
    _getLocationCoordinates();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    
    CloudLogger().debug('EventDetailsPage disposed', {
      'eventType': 'PAGE_LIFECYCLE',
      'action': 'PAGE_DISPOSED',
      'eventId': widget.event.id
    });
    
    super.dispose();
  }

  Future<void> _getLocationCoordinates() async {
    final stopwatch = Stopwatch()..start();
    
    if (widget.event.location == null || widget.event.location!.isEmpty) {
      stopwatch.stop();
      
      CloudLogger().info('No location specified for event', {
        'eventType': 'LOCATION_FETCH',
        'action': 'NO_LOCATION',
        'eventId': widget.event.id,
        'durationMs': stopwatch.elapsedMilliseconds
      });
      
      setState(() {
        _isLoadingMap = false;
        _locationError = "No location specified";
      });
      return;
    }

    CloudLogger().info('Fetching location coordinates', {
      'eventType': 'LOCATION_FETCH',
      'action': 'FETCH_STARTED',
      'eventId': widget.event.id,
      'location': widget.event.location
    });
    
    try {
      final locations = await locationFromAddress(widget.event.location!);
      
      if (locations.isNotEmpty) {
        stopwatch.stop();
        
        CloudLogger().info('Location coordinates fetched successfully', {
          'eventType': 'LOCATION_FETCH',
          'action': 'FETCH_COMPLETED',
          'eventId': widget.event.id,
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
          'durationMs': stopwatch.elapsedMilliseconds
        });
        
        setState(() {
          _locationCoordinates = LatLng(locations.first.latitude, locations.first.longitude);
          _isLoadingMap = false;
        });
      } else {
        stopwatch.stop();
        
        CloudLogger().warn('Location not found', {
          'eventType': 'LOCATION_FETCH',
          'action': 'LOCATION_NOT_FOUND',
          'eventId': widget.event.id,
          'location': widget.event.location,
          'durationMs': stopwatch.elapsedMilliseconds
        });
        
        setState(() {
          _isLoadingMap = false;
          _locationError = "Could not find location";
        });
      }
    } catch (e) {
      stopwatch.stop();
      
      CloudLogger().error('Error fetching location coordinates', {
        'eventType': 'LOCATION_FETCH',
        'action': 'FETCH_ERROR',
        'eventId': widget.event.id,
        'location': widget.event.location,
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds
      });
      
      setState(() {
        _isLoadingMap = false;
        _locationError = "Error finding location";
      });
    }
  }

  Future<void> _navigateToLocation() async {
    CloudLogger().userAction('navigate_to_location_button_tapped', {
      'eventId': widget.event.id,
      'eventTitle': widget.event.summary,
      'location': widget.event.location
    });
    
    if (widget.event.location == null || widget.event.location!.isEmpty) {
      CloudLogger().warn('Cannot navigate to location - no location specified', {
        'eventType': 'NAVIGATION',
        'action': 'NAVIGATION_FAILED',
        'reason': 'NO_LOCATION',
        'eventId': widget.event.id
      });
      return;
    }

    // Google Maps URL for navigation
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.event.location!)}',
    );

    CloudLogger().info('Attempting to launch maps application', {
      'eventType': 'NAVIGATION',
      'action': 'LAUNCH_MAPS_STARTED',
      'eventId': widget.event.id,
      'mapUrl': googleMapsUrl.toString()
    });
    
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
        
        CloudLogger().info('Maps application launched successfully', {
          'eventType': 'NAVIGATION',
          'action': 'LAUNCH_MAPS_SUCCESS',
          'eventId': widget.event.id
        });
      } else {
        CloudLogger().error('Could not launch maps application', {
          'eventType': 'NAVIGATION',
          'action': 'LAUNCH_MAPS_FAILED',
          'eventId': widget.event.id,
          'reason': 'CANNOT_LAUNCH_URL'
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps for navigation')),
        );
      }
    } catch (e) {
      CloudLogger().error('Error launching maps application', {
        'eventType': 'NAVIGATION',
        'action': 'LAUNCH_MAPS_ERROR',
        'eventId': widget.event.id,
        'error': e.toString(),
        'errorType': e.runtimeType.toString()
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening maps for navigation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final startDateTime = widget.event.start?.dateTime ?? DateTime.now();
    final endDateTime = widget.event.end?.dateTime ?? DateTime.now();
    
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(startDateTime);
    final formattedStartTime = DateFormat('h:mm a').format(startDateTime);
    final formattedEndTime = DateFormat('h:mm a').format(endDateTime);
    final duration = endDateTime.difference(startDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    String durationText = '';
    if (hours > 0) {
      durationText += '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    if (minutes > 0) {
      durationText += durationText.isNotEmpty ? ' ' : '';
      durationText += '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom app bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade800,
                    Colors.blue.shade600,
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                title: Text(
                  'Event Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Padding(
                  padding: EdgeInsets.only(top: 30, left: 16, right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                CloudLogger().userAction('event_details_back_button_pressed', {
                  'eventId': widget.event.id
                });
                Navigator.of(context).pop();
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit),
                tooltip: 'Edit Event',
                onPressed: () async {
                  CloudLogger().userAction('edit_event_from_details_tapped', {
                    'eventId': widget.event.id,
                    'eventTitle': widget.event.summary
                  });
                  
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditEventPage(event: widget.event),
                    ),
                  );
                  
                  CloudLogger().pageView('EventDetailsPage', {
                    'returnedFrom': 'EditEventPage',
                    'editResult': result.toString(),
                    'eventId': widget.event.id
                  });
                  
                  if (result == true) {
                    CloudLogger().info('Event updated, returning to previous screen', {
                      'eventType': 'EVENT_UPDATE',
                      'action': 'UPDATE_COMPLETED_RETURNING',
                      'eventId': widget.event.id
                    });
                    
                    widget.onEventUpdated();
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event summary/title
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event.summary ?? 'Untitled Event',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Event details card
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            // Date row
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            Divider(height: 30),
                            
                            // Time row
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.access_time,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Time',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '$formattedStartTime - $formattedEndTime',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (durationText.isNotEmpty) ...[
                                        SizedBox(height: 2),
                                        Text(
                                          '($durationText)',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            if (widget.event.location != null && widget.event.location!.isNotEmpty) ...[
                              Divider(height: 30),
                              
                              // Location row
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Location',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          widget.event.location!,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Description section
                    if (widget.event.description != null && widget.event.description!.isNotEmpty) ...[
                      SizedBox(height: 24),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            widget.event.description!,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    // Map section
                    SizedBox(height: 24),
                    Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: _isLoadingMap
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                                    ),
                                  )
                                : _locationCoordinates != null
                                    ? Stack(
                                        children: [
                                          GoogleMap(
                                            initialCameraPosition: CameraPosition(
                                              target: _locationCoordinates!,
                                              zoom: 14,
                                            ),
                                            markers: {
                                              Marker(
                                                markerId: MarkerId('eventLocation'),
                                                position: _locationCoordinates!,
                                                infoWindow: InfoWindow(
                                                  title: widget.event.summary,
                                                  snippet: widget.event.location,
                                                ),
                                              ),
                                            },
                                            myLocationEnabled: false,
                                            zoomControlsEnabled: true,
                                            mapToolbarEnabled: false,
                                            onMapCreated: (GoogleMapController controller) {
                                              _mapController = controller;
                                              
                                              CloudLogger().debug('Google Map created', {
                                                'eventType': 'MAP_INTERACTION',
                                                'action': 'MAP_CREATED',
                                                'eventId': widget.event.id
                                              });
                                              
                                              Future.delayed(Duration(milliseconds: 200), () {
                                                controller.animateCamera(
                                                  CameraUpdate.newLatLngZoom(_locationCoordinates!, 14),
                                                );
                                              });
                                            },
                                          ),
                                          Positioned(
                                            right: 8,
                                            bottom: 8,
                                            child: FloatingActionButton.small(
                                              backgroundColor: Colors.blue.shade700,
                                              foregroundColor: Colors.white,
                                              onPressed: _navigateToLocation,
                                              child: Icon(Icons.directions),
                                              tooltip: 'Navigate',
                                            ),
                                          ),
                                        ],
                                      )
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.location_off,
                                                size: 60,
                                                color: Colors.grey.shade500,
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                _locationError ?? 'No location specified',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                          ),
                          if (_locationCoordinates != null)
                            InkWell(
                              onTap: _navigateToLocation,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions, color: Colors.blue.shade700),
                                    SizedBox(width: 8),
                                    Text(
                                      'Navigate to location',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Delete button
                    SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.delete_outline),
                        label: Text(
                          'Delete Event',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          CloudLogger().userAction('delete_event_button_tapped', {
                            'eventId': widget.event.id,
                            'eventTitle': widget.event.summary,
                            'source': 'EventDetailsPage'
                          });
                          
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete Event'),
                              content: Text('Are you sure you want to delete "${widget.event.summary}"?'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    CloudLogger().userAction('delete_event_cancelled', {
                                      'eventId': widget.event.id,
                                      'eventTitle': widget.event.summary
                                    });
                                    Navigator.of(context).pop(false);
                                  },
                                  child: Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    CloudLogger().userAction('delete_event_confirmed', {
                                      'eventId': widget.event.id,
                                      'eventTitle': widget.event.summary
                                    });
                                    Navigator.of(context).pop(true);
                                  },
                                  child: Text('DELETE'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
                                ),
                              ],
                            ),
                          ) ?? false;

                          if (shouldDelete) {
                            CloudLogger().info('Deleting event and returning to previous screen', {
                              'eventType': 'EVENT_DELETION',
                              'action': 'DELETE_AND_RETURN',
                              'eventId': widget.event.id
                            });
                            
                            widget.onEventDeleted();
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                    
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}