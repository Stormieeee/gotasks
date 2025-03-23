import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gotask/Pages/faq_page.dart';
import 'package:gotask/Pages/feedback.dart';
import 'package:gotask/Pages/home_Page.dart';
import 'package:gotask/services/auth_service.dart';
import 'package:gotask/services/cloud_logger.dart';

class ProfilePage extends StatefulWidget {
  final User user;

  ProfilePage({required this.user});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    CloudLogger().pageView('ProfilePage', {
      'userId': widget.user.uid,
      'userEmail': widget.user.email,
    });
  }

  @override
  void dispose() {
    CloudLogger().debug('ProfilePage disposed', {
      'eventType': 'PAGE_LIFECYCLE',
      'action': 'PAGE_DISPOSED',
      'userId': widget.user.uid
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        title: Text('My Profile'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            CloudLogger().userAction('profile_back_button_pressed', {
              'userId': widget.user.uid
            });
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Profile card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // Profile picture
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: 
                                widget.user.photoURL != null
                                  ? NetworkImage(widget.user.photoURL!)
                                  : null,
                              backgroundColor: Colors.grey.shade200,
                              child: widget.user.photoURL == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey.shade700,
                                  )
                                : null,
                            ),
                            
                            SizedBox(height: 24),
                            
                            // User name
                            Text(
                              widget.user.displayName ?? 'User',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            // User email
                            SizedBox(height: 8),
                            Text(
                              widget.user.email ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            
                            Divider(height: 40),
                            
                            // Account info section
                            ListTile(
                              leading: Icon(Icons.account_circle, color: Colors.blue.shade700),
                              title: Text(
                                'Account Information',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Connected with Google'),
                            ),
                            
                            ListTile(
                              leading: Icon(Icons.calendar_today, color: Colors.blue.shade700),
                              title: Text(
                                'Calendar Access',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Google Calendar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Actions card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.feedback_outlined, color: Colors.blue.shade700),
                              title: Text('Send Feedback'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                CloudLogger().userAction('navigate_to_feedback', {
                                  'source': 'ProfilePage',
                                  'userId': widget.user.uid
                                });
                                
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => FeedbackPage(user: widget.user)),
                                ).then((_) {
                                  CloudLogger().pageView('ProfilePage', {
                                    'returnedFrom': 'FeedbackPage',
                                    'userId': widget.user.uid
                                  });
                                });
                              },
                            ),
                            
                            ListTile(
                              leading: Icon(Icons.help_outline, color: Colors.blue.shade700),
                              title: Text('Frequently Asked Questions'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                CloudLogger().userAction('navigate_to_faq', {
                                  'source': 'ProfilePage',
                                  'userId': widget.user.uid
                                });
                                
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => FAQPage()),
                                ).then((_) {
                                  CloudLogger().pageView('ProfilePage', {
                                    'returnedFrom': 'FAQPage',
                                    'userId': widget.user.uid
                                  });
                                });
                              },
                            ),
                            
                            ListTile(
                              leading: Icon(Icons.info_outline, color: Colors.blue.shade700),
                              title: Text('About'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                CloudLogger().userAction('open_about_dialog', {
                                  'source': 'ProfilePage',
                                  'userId': widget.user.uid
                                });
                                
                                // Show about dialog
                                showAboutDialog(
                                  context: context,
                                  applicationName: 'GoTask',
                                  applicationVersion: '1.0.0',
                                  applicationLegalese: '© 2025 GoTask',
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(top: 16),
                                      child: Text('A simple and elegant calendar app for managing your tasks and events.'),
                                    ),
                                  ],
                                );
                              },
                            ),
                            
                            Divider(),
                            
                            ListTile(
                              leading: Icon(Icons.logout, color: Colors.red),
                              title: Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                CloudLogger().userAction('sign_out_button_tapped', {
                                  'source': 'ProfilePage',
                                  'userId': widget.user.uid
                                });
                                
                                // Show confirmation dialog
                                bool confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Sign Out'),
                                    content: Text('Are you sure you want to sign out?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          CloudLogger().userAction('sign_out_cancelled', {
                                            'userId': widget.user.uid
                                          });
                                          Navigator.of(context).pop(false);
                                        },
                                        child: Text('CANCEL'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          CloudLogger().userAction('sign_out_confirmed', {
                                            'userId': widget.user.uid
                                          });
                                          Navigator.of(context).pop(true);
                                        },
                                        child: Text('SIGN OUT'),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      ),
                                    ],
                                  ),
                                ) ?? false;
                                
                                if (confirm) {
                                  final stopwatch = Stopwatch()..start();
                                  CloudLogger().info('User sign-out initiated', {
                                    'eventType': 'AUTH_FLOW',
                                    'action': 'SIGNOUT_STARTED',
                                    'userId': widget.user.uid
                                  });
                                  
                                  try {
                                    await _authService.signOut();
                                    
                                    stopwatch.stop();
                                    CloudLogger().info('User signed out successfully', {
                                      'eventType': 'AUTH_FLOW',
                                      'action': 'SIGNOUT_COMPLETED',
                                      'previousUserId': widget.user.uid,
                                      'durationMs': stopwatch.elapsedMilliseconds
                                    });
                                    
                                    CloudLogger().userAction('navigate_to_home_after_signout', {
                                      'previousUserId': widget.user.uid
                                    });
                                    
                                    // Navigate to HomePage and remove all previous routes
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (context) => HomePage(title: 'GoTask')),
                                      (route) => false, // This removes all previous routes
                                    );
                                  } catch (e) {
                                    stopwatch.stop();
                                    CloudLogger().error('Error during sign-out', {
                                      'eventType': 'AUTH_FLOW',
                                      'action': 'SIGNOUT_ERROR',
                                      'error': e.toString(),
                                      'errorType': e.runtimeType.toString(),
                                      'userId': widget.user.uid,
                                      'durationMs': stopwatch.elapsedMilliseconds
                                    });
                                    
                                    // Show error message to user
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error signing out. Please try again.'),
                                        backgroundColor: Colors.red.shade600,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // App info
                    Text(
                      'GoTask v1.0.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}