import 'dart:async';
import 'dart:convert';
import 'package:flutter_face_api_beta/flutter_face_api.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attendance_views/attendance_attendance.dart';
import 'attendance_views/attendance_overview.dart';
import 'attendance_views/attendance_request.dart';
import 'attendance_views/hour_account.dart';
import 'attendance_views/my_attendance_view.dart';
import 'checkin_checkout/checkin_checkout_views/checkin_checkout_form.dart';
import 'employee_views/employee_form.dart';
import 'employee_views/employee_list.dart';
import 'horilla_leave/all_assigned_leave.dart';
import 'horilla_leave/leave_allocation_request.dart';
import 'horilla_leave/leave_overview.dart';
import 'horilla_leave/leave_request.dart';
import 'horilla_leave/leave_types.dart';
import 'horilla_leave/my_leave_request.dart';
import 'horilla_leave/selected_leave_type.dart';
import 'horilla_main/login.dart';
import 'horilla_main/home.dart';
import 'horilla_main/notifications_list.dart';
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
var faceSdk = FaceSDK.instance;
int currentPage = 1;
bool isFirstFetch = true;
Set<int> seenNotificationIds = {};
List<Map<String, dynamic>> notifications = [];
int notificationsCount = 0;
bool isLoading = true;
Timer? _notificationTimer;
late Map<String, dynamic> arguments = {};
List<Map<String, dynamic>> fetchedNotifications = [];
Map<String, dynamic> newNotificationList = {};


@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse notificationResponse) async {
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    final context = await navigatorKey.currentState?.context;
    if (context != null) {
      _onSelectNotification(context);
    }
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await faceSdk.initialize();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/horilla_logo');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  // Initialize
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) async {
      final context = await navigatorKey.currentState?.context;
      if (context != null) {
        _onSelectNotification(context);
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  _notificationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
    fetchNotifications();
    unreadNotificationsCount();
  });


  runApp(LoginApp());
  clearSharedPrefs();
}

void clearSharedPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('clockCheckedIn');
  await prefs.remove('checkout');
  await prefs.remove('checkin');
}

void _onSelectNotification(BuildContext context) {
  Navigator.pushNamed(context, '/notifications_list');
  markAllReadNotification();
}

// Function to show a notification
void _showNotification() async {
  FlutterRingtonePlayer().playNotification();
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
      'your_channel_id', // Unique channel ID
      'your_channel_name', // Channel name for notifications
      channelDescription: 'your_channel_description',
      importance: Importance.max, // Max importance for notifications
      priority: Priority.high, // High priority
      playSound: false,
      silent: true
    // sound: null
    // sound: RawResourceAndroidNotificationSound(
    //     'android_notification'), // Custom sound
  );

  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);
  final timestamp = DateTime.parse(newNotificationList['timestamp']);
  final timeAgo = timeago.format(timestamp);
  final user = arguments['employee_name'];
  print('$timeAgo by User $user');

  await flutterLocalNotificationsPlugin.show(
    newNotificationList['id'], // Notification ID
    newNotificationList['verb'], // Title of the notification
    '$timeAgo by User', // Body of the notification
    platformChannelSpecifics,
    payload: 'your_payload', // Optional payload to pass to the app
  );
}

void prefetchData() async {
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString("token");
  var typed_serverUrl = prefs.getString("typed_url");
  var employeeId = prefs.getInt("employee_id");
  var uri = Uri.parse('$typed_serverUrl/api/employee/employees/$employeeId');
  var response = await http.get(uri, headers: {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  });

  if (response.statusCode == 200) {
    final responseData = jsonDecode(response.body);
    arguments = {
      'employee_id': responseData['id'],
      'employee_name': responseData['employee_first_name'] +
          ' ' +
          responseData['employee_last_name'],
      'badge_id': responseData['badge_id'],
      'email': responseData['email'],
      'phone': responseData['phone'],
      'date_of_birth': responseData['dob'],
      'gender': responseData['gender'],
      'address': responseData['address'],
      'country': responseData['country'],
      'state': responseData['state'],
      'city': responseData['city'],
      'qualification': responseData['qualification'],
      'experience': responseData['experience'],
      'marital_status': responseData['marital_status'],
      'children': responseData['children'],
      'emergency_contact': responseData['emergency_contact'],
      'emergency_contact_name': responseData['emergency_contact_name'],
      'employee_work_info_id': responseData['employee_work_info_id'],
      'employee_bank_details_id': responseData['employee_bank_details_id'],
      'employee_profile': responseData['employee_profile'],
      'job_position_name': responseData['job_position_name']
    };
  }
}


Future<void> markAllReadNotification() async {
  print('llllll');
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString("token");
  var typed_serverUrl = prefs.getString("typed_url");
  var uri = Uri.parse('$typed_serverUrl/api/notifications/notifications/bulk-read/');
  var response = await http.post(uri, headers: {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  });
  print(response.statusCode);

  if (response.statusCode == 200) {
    notifications.clear();
    unreadNotificationsCount();
    fetchNotifications();
  }
}


Future<void> fetchNotifications() async {
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString("token");
  var typed_serverUrl = prefs.getString("typed_url");
  if (currentPage != 0) {
    var uri = Uri.parse(
        '$typed_serverUrl/api/notifications/notifications/list/unread?page=$currentPage');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      List<Map<String, dynamic>> fetchedNotifications =
      List<Map<String, dynamic>>.from(
        jsonDecode(response.body)['results']
            .where((notification) => notification['deleted'] == false)
            .toList(),
      );
      if (fetchedNotifications.isNotEmpty) {
        newNotificationList = fetchedNotifications[0];
        List<int> newNotificationIds = fetchedNotifications
            .map((notification) => notification['id'] as int)
            .toList();
        print(newNotificationList['id']);

        // Check for any new notification IDs
        bool hasNewNotifications =
        newNotificationIds.any((id) => !seenNotificationIds.contains(id));

        if (!isFirstFetch && hasNewNotifications) {
          _playNotificationSound();
        }

        // Update the seenNotificationIds set with new IDs
        seenNotificationIds.addAll(newNotificationIds);

        // Update notifications list and other states
        notifications = fetchedNotifications;
        notificationsCount = jsonDecode(response.body)['count'];
        isFirstFetch = false;
        final timestamp = DateTime.parse(newNotificationList['timestamp']);
        final timeAgo = timeago.format(timestamp);
        final user = arguments['employee_name'];
        print('$timeAgo by User $user');
        isLoading = false;

      } else {
        print("No notifications available.");
      }
    }
  } else {
    currentPage = 1;
    var uri = Uri.parse(
        '$typed_serverUrl/api/notifications/notifications/list/unread');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      List<Map<String, dynamic>> fetchedNotifications =
      List<Map<String, dynamic>>.from(
        jsonDecode(response.body)['results'].where((notification) => notification['deleted'] == false)
            .toList(),
      );
      if (fetchedNotifications.isNotEmpty) {
        newNotificationList = fetchedNotifications[0];
        List<int> newNotificationIds = fetchedNotifications
            .map((notification) => notification['id'] as int)
            .toList();
        print(newNotificationList['id']);

        bool hasNewNotifications =
        newNotificationIds.any((id) => !seenNotificationIds.contains(id));

        if (!isFirstFetch && hasNewNotifications) {
          _playNotificationSound();
        }

        seenNotificationIds.addAll(newNotificationIds);

        notifications = fetchedNotifications;
        notificationsCount = jsonDecode(response.body)['count'];
        isFirstFetch = false;
        final timestamp = DateTime.parse(newNotificationList['timestamp']);
        final timeAgo = timeago.format(timestamp);
        final user = arguments['employee_name'];
        print('$timeAgo by User $user');
        isLoading = false;

      } else {
        print("No notifications available.");
      }
    }
  }
}

Future<void> unreadNotificationsCount() async {
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString("token");
  var typed_serverUrl = prefs.getString("typed_url");
  var uri =
  Uri.parse('$typed_serverUrl/api/notifications/notifications/list/unread');
  var response = await http.get(uri, headers: {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  });

  if (response.statusCode == 200) {
    notificationsCount = jsonDecode(response.body)['count'];
    isLoading = false;
  }
}

void _playNotificationSound() {
  _showNotification();
}

class LoginApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Page',
      navigatorKey: navigatorKey, // Set navigator key for global context access
      home: FutureBuilderPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) => HomePage(),
        '/employees_list': (context) => EmployeeListPage(),
        '/employees_form': (context) => EmployeeFormPage(),
        '/attendance_overview': (context) => AttendanceOverview(),
        '/attendance_attendance': (context) => AttendanceAttendance(),
        '/attendance_request': (context) => AttendanceRequest(),
        '/my_attendance_view': (context) => MyAttendanceViews(),
        '/employee_hour_account': (context) => HourAccountFormPage(),
        '/employee_checkin_checkout': (context) => CheckInCheckOutFormPage(),
        '/leave_overview': (context) => LeaveOverview(),
        '/leave_types': (context) => LeaveTypes(),
        '/my_leave_request': (context) => MyLeaveRequest(),
        '/leave_request': (context) => LeaveRequest(),
        '/leave_allocation_request': (context) => LeaveAllocationRequest(),
        '/all_assigned_leave': (context) => AllAssignedLeave(),
        '/selected_leave_type': (context) => SelectedLeaveType(),
        '/notifications_list': (context) => NotificationsList(),
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Adjust background color as desired
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'Assets/horilla-logo.png', // Path to your logo
              width: 150, // You can adjust the size of the logo
              height: 150,
            ),
          ],
        ),
      ),
    );
  }
}

class FutureBuilderPage extends StatefulWidget {
  const FutureBuilderPage({super.key});

  @override
  State<FutureBuilderPage> createState() => _FutureBuilderPageState();
}

class _FutureBuilderPageState extends State<FutureBuilderPage> {
  late Future<bool> _futurePath;

  @override
  void initState() {
    super.initState();
    _futurePath = _initialize();
  }

  Future<bool> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    var sessionId = prefs.getString("token");
    return sessionId != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: Future.delayed(const Duration(seconds: 2), () => _futurePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen(); // Display your custom SplashScreen widget
        }

        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data == true) {
            return const HomePage();
          } else {
            return LoginPage();
          }
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }


  @override
  void dispose() {
    super.dispose();
  }
}
