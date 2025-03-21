import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'calendar_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  User? _user;

  @override
  void initState() {
    super.initState();
    _authService.authStateChanges.listen((User? user) {
      setState(() {
        _user = user;
      });
      
      // If user just logged in, navigate to Calendar Page
      if (user != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => CalendarPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          if (_user != null)
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async {
                await _authService.signOut();
              },
            ),
        ],
      ),
      body: Center(
        child: _user == null
            ? ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: Image.network(
                  'https://developers.google.com/identity/images/g-logo.png',
                  height: 24,
                ),
                label: Text('Sign in with Google'),
                onPressed: () async {
                    print("Sign-in button pressed");
                    await _authService.signInWithGoogle();
                    print("Sign-in method completed");
                },
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(_user!.photoURL ?? ''),
                    radius: 40,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Welcome, ${_user!.displayName}!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(_user!.email ?? ''),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => CalendarPage()),
                      );
                    },
                    child: Text('View Calendar'),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await _authService.signOut();
                    },
                    child: Text('Sign Out'),
                  ),
                ],
              ),
      ),
    );
  }
}