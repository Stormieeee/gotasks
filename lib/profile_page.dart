import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gotask/feedback.dart';
import 'package:gotask/home_Page.dart';
import 'auth_service.dart';

class ProfilePage extends StatelessWidget {
  final AuthService _authService = AuthService();
  final User user;

  ProfilePage({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        title: Text('My Profile'),
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
                                user.photoURL != null
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                              backgroundColor: Colors.grey.shade200,
                              child: user.photoURL == null
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
                              user.displayName ?? 'User',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            // User email
                            SizedBox(height: 8),
                            Text(
                              user.email ?? '',
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
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => FeedbackPage(user: user)),
                                  );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Feedback feature coming soon'))
                                );
                              },
                            ),
                            
                            ListTile(
                              leading: Icon(Icons.help_outline, color: Colors.blue.shade700),
                              title: Text('Help & Support'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                // Implement help functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Help center coming soon'))
                                );
                              },
                            ),
                            
                            ListTile(
                              leading: Icon(Icons.info_outline, color: Colors.blue.shade700),
                              title: Text('About'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
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
                                // Show confirmation dialog
                                bool confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Sign Out'),
                                    content: Text('Are you sure you want to sign out?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: Text('CANCEL'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: Text('SIGN OUT'),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      ),
                                    ],
                                  ),
                                ) ?? false;
                                
                                if (confirm) {
                                  await _authService.signOut();
                                  // Navigate to HomePage and remove all previous routes
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => HomePage(title: 'GoTask')),
                                    (route) => false, // This removes all previous routes
                                  );
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