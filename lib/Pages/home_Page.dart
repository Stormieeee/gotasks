import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gotask/Pages/list_page.dart';
import 'package:gotask/services/auth_service.dart';
import 'package:gotask/services/cloud_logger.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    CloudLogger().pageView('HomePage', {
      'source': 'initState',
      'isAuthenticated': _user != null
    });
    
    _authService.authStateChanges.listen((User? user) {
      final bool wasSignedIn = _user != null;
      final bool isNowSignedIn = user != null;
      
      // Track auth state changes
      if (!wasSignedIn && isNowSignedIn) {
        CloudLogger().info('User signed in', {
          'eventType': 'AUTH_STATE',
          'action': 'SIGN_IN_COMPLETED',
          'userId': user!.uid,
          'email': user.email,
          'displayName': user.displayName,
          'provider': user.providerData.isNotEmpty ? user.providerData[0].providerId : 'unknown'
        });
      } else if (wasSignedIn && !isNowSignedIn) {
        CloudLogger().info('User signed out', {
          'eventType': 'AUTH_STATE',
          'action': 'SIGN_OUT_COMPLETED',
          'previousUserId': _user!.uid
        });
      }
      
      setState(() {
        _user = user;
      });
      
      // If user just logged in, navigate to List Page
      if (user != null && mounted) {
        CloudLogger().info('Navigating to List Page after sign in', {
          'eventType': 'NAVIGATION',
          'action': 'AUTO_NAVIGATE_AFTER_SIGN_IN',
          'destination': 'ListPage',
          'userId': user.uid
        });
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ListPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    CloudLogger().debug('HomePage disposed', {
      'eventType': 'PAGE_LIFECYCLE',
      'action': 'PAGE_DISPOSED',
      'isAuthenticated': _user != null,
      'userId': _user?.uid
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _user == null ? _buildLoginScreen() : _buildProfileScreen(),
    );
  }

  Widget _buildLoginScreen() {
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and app name
                  Icon(
                    Icons.event_note,
                    size: 80,
                    color: Colors.white,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'GoTask',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your calendar made simple',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 60),
                  
                  // Sign in card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            'Sign in to continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 30),
                          _isLoading
                              ? CircularProgressIndicator()
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    elevation: 2,
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    minimumSize: Size(double.infinity, 50),
                                  ),
                                  icon: Image.network(
                                    'https://developers.google.com/identity/images/g-logo.png',
                                    height: 24,
                                  ),
                                  label: Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onPressed: () async {
                                    CloudLogger().userAction('google_sign_in_button_tapped', {
                                      'eventType': 'AUTH_FLOW',
                                      'action': 'SIGN_IN_INITIATED',
                                      'method': 'google'
                                    });
                                    
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    
                                    final stopwatch = Stopwatch()..start();
                                    
                                    try {
                                      final userCredential = await _authService.signInWithGoogle();
                                      
                                      stopwatch.stop();
                                      
                                      if (userCredential != null) {
                                        CloudLogger().info('Google sign-in successful', {
                                          'eventType': 'AUTH_FLOW',
                                          'action': 'SIGN_IN_SUCCESS',
                                          'method': 'google',
                                          'userId': userCredential.user?.uid,
                                          'isNewUser': userCredential.additionalUserInfo?.isNewUser,
                                          'durationMs': stopwatch.elapsedMilliseconds
                                        });
                                      } else {
                                        // User canceled sign-in
                                        CloudLogger().info('Google sign-in cancelled by user', {
                                          'eventType': 'AUTH_FLOW',
                                          'action': 'SIGN_IN_CANCELLED',
                                          'method': 'google',
                                          'durationMs': stopwatch.elapsedMilliseconds
                                        });
                                      }
                                    } catch (e) {
                                      stopwatch.stop();
                                      
                                      CloudLogger().error('Google sign-in failed', {
                                        'eventType': 'AUTH_FLOW',
                                        'action': 'SIGN_IN_ERROR',
                                        'method': 'google',
                                        'error': e.toString(),
                                        'errorType': e.runtimeType.toString(),
                                        'durationMs': stopwatch.elapsedMilliseconds
                                      });
                                    } finally {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 40),
                  
                  // Footer text
                  Text(
                    '© 2025 GoTask',
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
    );
  }

  Widget _buildProfileScreen() {
    return Container(
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
          child: Card(
            margin: EdgeInsets.all(24),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(_user!.photoURL ?? ''),
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Welcome, ${_user!.displayName}!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    _user!.email ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: Icon(Icons.calendar_today),
                    label: Text('Go to Calendar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      CloudLogger().userAction('go_to_calendar_button_tapped', {
                        'eventType': 'NAVIGATION',
                        'action': 'MANUAL_NAVIGATE',
                        'source': 'ProfileScreen',
                        'destination': 'ListPage',
                        'userId': _user!.uid
                      });
                      
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => ListPage()),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: Icon(Icons.logout),
                    label: Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      CloudLogger().userAction('sign_out_button_tapped', {
                        'eventType': 'AUTH_FLOW',
                        'action': 'SIGN_OUT_INITIATED',
                        'userId': _user!.uid
                      });
                      
                      final stopwatch = Stopwatch()..start();
                      
                      try {
                        await _authService.signOut();
                        
                        stopwatch.stop();
                        
                        CloudLogger().info('Sign out successful', {
                          'eventType': 'AUTH_FLOW',
                          'action': 'SIGN_OUT_SUCCESS',
                          'previousUserId': _user!.uid,
                          'durationMs': stopwatch.elapsedMilliseconds
                        });
                      } catch (e) {
                        stopwatch.stop();
                        
                        CloudLogger().error('Sign out failed', {
                          'eventType': 'AUTH_FLOW',
                          'action': 'SIGN_OUT_ERROR',
                          'userId': _user!.uid,
                          'error': e.toString(),
                          'errorType': e.runtimeType.toString(),
                          'durationMs': stopwatch.elapsedMilliseconds
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}