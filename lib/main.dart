import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gotask/services/cloud_logger.dart';
import 'services/firebase_options.dart';
import 'package:gotask/Pages/home_Page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Log application startup
  print('Application starting...');
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
    
    // Initialize logger
    await CloudLogger.init();
    
    // Log successful initialization
    CloudLogger().info('Application initialized successfully', {
      'platform': DefaultFirebaseOptions.currentPlatform.projectId,
      'appVersion': '1.0.0', // Replace with your actual version
      'buildNumber': '1', // Replace with your actual build number
    });
    
    runApp(MyApp());
  } catch (e) {
    print('Error during initialization: $e');
    // Still run the app even if Firebase fails to initialize
    runApp(MyApp());
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Log app build event
    CloudLogger().info('Application build started');
    
    final app = MaterialApp(
      title: 'GoTasks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomePage(title: 'GoTasks'),
      navigatorObservers: [
        // Add a route observer for logging navigation events
        RouteObserver<PageRoute>(),
      ],
      // Add route change logging
      onGenerateRoute: (settings) {
        CloudLogger().pageView(settings.name ?? 'unknown_route', {
          'arguments': settings.arguments?.toString(),
        });
        
        // Return null to let the normal routing happen
        return null;
      },
    );
    
    // Log app build completed
    CloudLogger().info('Application build completed');
    
    return app;
  }
}