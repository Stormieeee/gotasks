import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:gotask/services/cloud_logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ], 
  );

  Future<UserCredential?> signInWithGoogle() async {
    CloudLogger().info('Google sign-in process initiated', {
      'eventType': 'AUTH_FLOW',
      'action': 'SIGNIN_STARTED',
      'method': 'google'
    });
    
    try {
      // Trigger the authentication flow
      final stopwatch = Stopwatch()..start();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      stopwatch.stop();
      
      if (googleUser == null) {
        CloudLogger().info('Google sign-in cancelled by user', {
          'eventType': 'AUTH_FLOW',
          'action': 'SIGNIN_CANCELLED',
          'durationMs': stopwatch.elapsedMilliseconds
        });
        return null;
      }

      CloudLogger().info('Google account selected', {
        'eventType': 'AUTH_FLOW',
        'action': 'GOOGLE_ACCOUNT_SELECTED',
        'email': googleUser.email,
        'displayName': googleUser.displayName,
        'durationMs': stopwatch.elapsedMilliseconds
      });

      // Obtain the auth details from the request
      final authStopwatch = Stopwatch()..start();
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      authStopwatch.stop();
      
      CloudLogger().info('Google authentication details obtained', {
        'eventType': 'AUTH_FLOW',
        'action': 'GOOGLE_AUTH_OBTAINED',
        'hasAccessToken': googleAuth.accessToken != null,
        'hasIdToken': googleAuth.idToken != null,
        'durationMs': authStopwatch.elapsedMilliseconds
      });

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with the credential
      final firebaseStopwatch = Stopwatch()..start();
      final userCredential = await _auth.signInWithCredential(credential);
      firebaseStopwatch.stop();
      
      CloudLogger().info('Firebase sign-in successful', {
        'eventType': 'AUTH_FLOW',
        'action': 'SIGNIN_COMPLETED',
        'uid': userCredential.user?.uid,
        'isNewUser': userCredential.additionalUserInfo?.isNewUser,
        'displayName': userCredential.user?.displayName,
        'email': userCredential.user?.email,
        'emailVerified': userCredential.user?.emailVerified,
        'authProvider': 'google.com',
        'durationMs': firebaseStopwatch.elapsedMilliseconds,
        'totalDurationMs': stopwatch.elapsedMilliseconds + authStopwatch.elapsedMilliseconds + firebaseStopwatch.elapsedMilliseconds
      });
      
      // Set user ID in logger for future logs
      if (userCredential.user?.uid != null) {
        CloudLogger().setUserId(userCredential.user!.uid);
      }
      
      return userCredential;
    } catch (e) {
      CloudLogger().error('Google sign-in failed', {
        'eventType': 'AUTH_FLOW',
        'action': 'SIGNIN_ERROR',
        'error': e.toString(),
        'errorType': e.runtimeType.toString()
      });
      return null;
    }
  }

  // Get Google Calendar client
  Future<calendar.CalendarApi?> getCalendarApi() async {
    CloudLogger().info('Requesting Calendar API access', {
      'eventType': 'API_ACCESS',
      'service': 'GoogleCalendar'
    });
    
    try {
      final stopwatch = Stopwatch()..start();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      stopwatch.stop();
      
      if (googleUser == null) {
        CloudLogger().warn('Silent sign-in failed for Calendar API access', {
          'eventType': 'API_ACCESS',
          'service': 'GoogleCalendar',
          'status': 'FAILED',
          'reason': 'NO_SIGNED_IN_USER',
          'durationMs': stopwatch.elapsedMilliseconds
        });
        return null;
      }

      final authStopwatch = Stopwatch()..start();
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      authStopwatch.stop();

      if (accessToken == null) {
        CloudLogger().error('Failed to get access token for Calendar API', {
          'eventType': 'API_ACCESS',
          'service': 'GoogleCalendar',
          'status': 'FAILED',
          'reason': 'NO_ACCESS_TOKEN',
          'email': googleUser.email,
          'durationMs': authStopwatch.elapsedMilliseconds
        });
        return null;
      }

      final authClient = AuthClient(
        http.Client(),
        accessToken,
      );

      CloudLogger().info('Calendar API access granted', {
        'eventType': 'API_ACCESS',
        'service': 'GoogleCalendar',
        'status': 'SUCCESS',
        'email': googleUser.email,
        'durationMs': stopwatch.elapsedMilliseconds + authStopwatch.elapsedMilliseconds
      });

      return calendar.CalendarApi(authClient);
    } catch (e) {
      CloudLogger().error('Error getting Calendar API access', {
        'eventType': 'API_ACCESS',
        'service': 'GoogleCalendar',
        'status': 'ERROR',
        'error': e.toString(),
        'errorType': e.runtimeType.toString()
      });
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    CloudLogger().info('User sign-out initiated', {
      'eventType': 'AUTH_FLOW',
      'action': 'SIGNOUT_STARTED',
      'uid': currentUser?.uid,
      'email': currentUser?.email
    });
    
    try {
      final stopwatch = Stopwatch()..start();
      await _auth.signOut();
      await _googleSignIn.signOut();
      stopwatch.stop();
      
      CloudLogger().info('User signed out successfully', {
        'eventType': 'AUTH_FLOW',
        'action': 'SIGNOUT_COMPLETED',
        'durationMs': stopwatch.elapsedMilliseconds
      });
      
      // Clear user ID from logger
      CloudLogger().clearUserId();
    } catch (e) {
      CloudLogger().error('Error during sign-out', {
        'eventType': 'AUTH_FLOW',
        'action': 'SIGNOUT_ERROR',
        'error': e.toString(),
        'errorType': e.runtimeType.toString()
      });
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges {
    // Log authentication state changes
    return _auth.authStateChanges().map((User? user) {
      if (user != null) {
        CloudLogger().info('Auth state changed: User signed in', {
          'eventType': 'AUTH_STATE',
          'state': 'SIGNED_IN',
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'isAnonymous': user.isAnonymous,
          'emailVerified': user.emailVerified,
          'providerIds': user.providerData.map((info) => info.providerId).toList(),
        });
        
        // Set user ID in logger
        CloudLogger().setUserId(user.uid);
      } else {
        CloudLogger().info('Auth state changed: User signed out', {
          'eventType': 'AUTH_STATE',
          'state': 'SIGNED_OUT'
        });
        
        // Clear user ID from logger
        CloudLogger().clearUserId();
      }
      return user;
    });
  }
}

// Helper class for authenticated HTTP requests
class AuthClient extends http.BaseClient {
  final http.Client _client;
  final String _accessToken;

  AuthClient(this._client, this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final String requestId = DateTime.now().millisecondsSinceEpoch.toString();
    
    CloudLogger().debug('Sending authenticated API request', {
      'eventType': 'API_REQUEST',
      'requestId': requestId,
      'url': request.url.toString(),
      'method': request.method,
      'headers': request.headers.toString(),
    });
    
    request.headers['Authorization'] = 'Bearer $_accessToken';
    
    final stopwatch = Stopwatch()..start();
    return _client.send(request).then((response) {
      stopwatch.stop();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        CloudLogger().info('API request successful', {
          'eventType': 'API_RESPONSE',
          'requestId': requestId,
          'url': request.url.toString(),
          'method': request.method,
          'statusCode': response.statusCode,
          'durationMs': stopwatch.elapsedMilliseconds
        });
      } else {
        CloudLogger().warn('API request failed', {
          'eventType': 'API_RESPONSE',
          'requestId': requestId,
          'url': request.url.toString(),
          'method': request.method,
          'statusCode': response.statusCode,
          'durationMs': stopwatch.elapsedMilliseconds
        });
      }
      
      return response;
    }).catchError((error) {
      stopwatch.stop();
      
      CloudLogger().error('API request error', {
        'eventType': 'API_ERROR',
        'requestId': requestId,
        'url': request.url.toString(),
        'method': request.method,
        'error': error.toString(),
        'errorType': error.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds
      });
      
      throw error;
    });
  }
}