import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:horilla_mobile/checkin_checkout_views/stopwatch.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:shimmer/shimmer.dart';

class CheckInCheckOutFormPage extends StatefulWidget {
  const CheckInCheckOutFormPage({super.key});

  @override
  _CheckInCheckOutFormPageState createState() =>
      _CheckInCheckOutFormPageState();
}

class StateInfo {
  final Color color;
  final String displayString;

  StateInfo(this.color, this.displayString);
}

class _CheckInCheckOutFormPageState extends State<CheckInCheckOutFormPage> {
  List<Map<String, dynamic>> attendanceList = [];
  List<Map<String, dynamic>> attendanceLists = [];
  late String swipeDirection;
  late String baseUrl = '';
  late Timer t;
  late String requestsEmpMyFirstName = '';
  late String requestsEmpMyLastName = '';
  late String requestsEmpMyBadgeId = '';
  late String requestsEmpMyDepartment = '';
  late String requestsEmpProfile = '';
  late String requestsEmpMyWorkInfoId = '';
  late String requestsEmpMyShiftName = '';
  bool clockCheckBool = false;
  bool switchValue = false;
  bool clockCheckedIn = false;
  bool isLoading = true;
  bool isCheckIn = false;
  bool _isProcessingDrag = false;
  bool checkIn = false;
  String? checkInFormattedTime = '00:00';
  String elapsedTimeString = '00:00:00';
  String? checkOutFormattedTime = '00:00';
  String? checkInFormattedTimeTopR;
  String? workingTime = '00:00:00';
  String? clockIn;
  String? clockInTimes;
  String? duration;
  String? timeDisplay;
  final StopwatchManager stopwatchManager = StopwatchManager();
  final _controller = NotchBottomBarController(index: 1);
  int initialTabIndex = 1;
  int maxCount = 5;
  Map<String, dynamic> arguments = {};
  Duration elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    prefetchData();
    _loadClockState();
    getLoginEmployeeRecord();
    getBaseUrl();
    workingTime = formatDuration(stopwatchManager.elapsed);
    elapsedTimeString =
        stopwatchManager.elapsed.toString().split('.').first.padLeft(8, '0');
    t = Timer.periodic(const Duration(milliseconds: 3000), (timer) {
      setState(() {});
    });
    if (clockCheckBool) {}
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await getCheckIn();
    if (checkIn == true) {
      isCheckIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          clockCheckedIn = true;
          clockCheckBool = true;
          DateTime now = DateTime.now();
          timeDisplay = clockIn;
          checkInFormattedTimeTopR = DateFormat('h:mm').format(now);
          Duration clockInTime = Duration.zero;
          String? clockTimeString = duration;
          if (clockTimeString != null) {
            List<String> timeComponents = clockTimeString.split(':');
            int hours = int.parse(timeComponents[0]);
            int minutes = int.parse(timeComponents[1]);
            int seconds = int.parse(timeComponents[2].split('.')[0]);
            clockInTime =
                Duration(hours: hours, minutes: minutes, seconds: seconds);
          }
          stopwatchManager.startStopwatch(initialTime: clockInTime);
          _saveClockState(clockCheckedIn, 1, checkInFormattedTime.toString());
          swipeDirection = 'Swipe to Check-out';
        });
      });
    } else {
      isCheckIn = false;
      clockCheckedIn = false;
      clockCheckBool = false;
      timeDisplay = clockInTimes;
      Duration clockInTime = Duration.zero;
      String? clockTimeString = duration;
      elapsedTimeString = duration ?? '';
      if (clockTimeString != null) {
        List<String> timeComponents = clockTimeString.split(':');
        int hours = int.parse(timeComponents[0]);
        int minutes = int.parse(timeComponents[1]);
        int seconds = int.parse(timeComponents[2].split('.')[0]);
        clockInTime =
            Duration(hours: hours, minutes: minutes, seconds: seconds);
        elapsedTime = clockInTime;
      }
      swipeDirection = 'Swipe to Check-In';
    }
  }

  /// Fetches the check-in status from the server and updates the UI state accordingly.
  Future<void> getCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/attendance/checking-in');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      var responseBody = jsonDecode(response.body);
      if (jsonDecode(response.body)['status'] == true) {
        setState(() {
          checkIn = true;
          clockIn = responseBody['clock_in'];
          duration = responseBody['duration'];
        });
      } else {
        setState(() {
          checkIn = false;
          clockInTimes = responseBody['clock_in_time'];
          duration = responseBody['duration'];
        });
      }
    }
  }

  /// Prefetches employee data from the server and stores it in the arguments map.
  void prefetchData() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    var uri = Uri.parse('$typedServerUrl/api/employee/employees/$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    arguments = {};
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
        'employee_profile': responseData['employee_profile']
      };
    }
  }

  /// Loads the clock-in and clock-out states from SharedPreferences.
  _loadClockState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (isCheckIn == true) {
        clockCheckedIn = prefs.getBool('clockCheckedIn') ?? true;
      } else {
        clockCheckedIn = prefs.getBool('clockCheckedIn') ?? false;
      }
      checkInFormattedTime = (prefs.getString('checkin') ?? '00:00') as String?;
      checkOutFormattedTime =
          (prefs.getString('checkout') ?? '00:00') as String?;
    });
  }

  /// Saves the clock-in or clock-out state to SharedPreferences.
  _saveClockState(bool isCheckedIn, int option, [String? check]) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('clockCheckedIn', isCheckedIn);
    if (check != null && option == 2) {
      prefs.setString('checkout', check);
    } else {
      prefs.setString('checkin', check!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  final List<Widget> bottomBarPages = [
    const Home(),
    const Overview(),
    const User(),
  ];

  /// Fetches the base URL from shared preferences and updates the state.
  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
  }

  /// Retrieves all employee attendance records from the server and updates the state.
  Future<void> getAllEmployeeAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/attendance/attendance/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        attendanceLists = List<Map<String, dynamic>>.from(
          jsonDecode(response.body)['results'],
        );
        for (var employee in attendanceLists) {
          attendanceList.add(employee);
        }
      });
    }
  }

  /// Fetches the logged-in employee's record from the server and updates the state.
  Future<void> getLoginEmployeeRecord() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    var uri = Uri.parse('$typedServerUrl/api/employee/employees/$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      var responseBody = jsonDecode(response.body);
      setState(() {
        requestsEmpMyFirstName = responseBody['employee_first_name'] ?? '';
        requestsEmpMyLastName = responseBody['employee_last_name'] ?? '';
        requestsEmpMyBadgeId = responseBody['badge_id'] ?? '';
        requestsEmpMyDepartment = responseBody['job_position_name'] ?? '';
        requestsEmpProfile = responseBody['employee_profile'] ?? '';
        requestsEmpMyWorkInfoId = responseBody['employee_work_info_id'] ?? '';
      });
      getLoginEmployeeWorkInfoRecord(requestsEmpMyWorkInfoId);
    }
  }

  /// Retrieves the work information of the logged-in employee and updates the state.
  Future<void> getLoginEmployeeWorkInfoRecord(requestsEmpMyWorkInfoId) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/employee/employee-work-information/$requestsEmpMyWorkInfoId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      var responseBody = jsonDecode(response.body);
      setState(() {
        var shiftName = responseBody['shift_name'];
        if (shiftName != null) {
          requestsEmpMyShiftName = shiftName;
          isLoading = false;
        } else {
          requestsEmpMyShiftName = "None";
          isLoading = false;
        }
      });
    }
  }

  /// Posts a checkout request to the server for the logged-in employee.
  Future<void> postCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/attendance/clock-out/');
    var response = await http.post(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {});
    }
  }

  /// Posts a check-in request to the server for the logged-in employee.
  Future<void> postCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/attendance/clock-in/');
    var response = await http.post(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {});
    }
  }

  /// Clears the token from shared preferences to log out the user.
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
            onPressed: () async {
              await clearToken();
              stopwatchManager.resetStopwatch();
              Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),
      body: isLoading ? _buildLoadingWidget() : _buildCheckInCheckoutWidget(),
      bottomNavigationBar: (bottomBarPages.length <= maxCount)
          ? AnimatedNotchBottomBar(
              notchBottomBarController: _controller,
              color: Colors.red,
              showLabel: true,
              notchColor: Colors.red,
              kBottomRadius: 28.0,
              kIconSize: 24.0,
              removeMargins: false,
              bottomBarWidth: MediaQuery.of(context).size.width * 1,
              durationInMilliSeconds: 500,
              bottomBarItems: const [
                BottomBarItem(
                  inActiveItem: Icon(
                    Icons.home_filled,
                    color: Colors.white,
                  ),
                  activeItem: Icon(
                    Icons.home_filled,
                    color: Colors.white,
                  ),
                ),
                BottomBarItem(
                  inActiveItem: Icon(
                    Icons.update_outlined,
                    color: Colors.white,
                  ),
                  activeItem: Icon(
                    Icons.update_outlined,
                    color: Colors.white,
                  ),
                ),
                BottomBarItem(
                  inActiveItem: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                  activeItem: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),
              ],
              onTap: (index) async {
                switch (index) {
                  case 0:
                    Future.delayed(const Duration(milliseconds: 1000), () {
                      Navigator.pushNamed(context, '/home');
                    });
                    break;
                  case 1:
                    Future.delayed(const Duration(milliseconds: 1000), () {
                      Navigator.pushNamed(
                          context, '/employee_checkin_checkout');
                    });
                    break;
                  case 2:
                    Future.delayed(const Duration(milliseconds: 1000), () {
                      Navigator.pushNamed(context, '/employees_form',
                          arguments: arguments);
                    });
                    break;
                }
              },
            )
          : null,
    );
  }

  void storeCheckoutTime() {
    elapsedTime = stopwatchManager.elapsed;

    elapsedTimeString = elapsedTime.toString().split('.').first.padLeft(8, '0');
  }

  Widget _buildLoadingWidget() {
    checkInFormattedTime = timeDisplay;
    return ListView(
      children: [
        if (clockCheckBool || clockCheckedIn)
          Container(
            color: Colors.red,
            height: MediaQuery.of(context).size.height * 0.25,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Clock In',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        '00:00:00',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.access_alarm),
                            color: Colors.white,
                            iconSize: 40,
                          ),
                          StreamBuilder<int>(
                            stream: Stream.periodic(
                                const Duration(milliseconds: 1), (_) {
                              return stopwatchManager.elapsed.inMilliseconds;
                            }),
                            builder: (context, snapshot) {
                              return Text(
                                '${Duration(milliseconds: snapshot.data ?? 0)}'
                                    .substring(0, 7),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 25,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Clocked In: Today at ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            checkInFormattedTime ??
                                DateFormat('h:mm').format(DateTime.now()) +
                                    (DateTime.now().hour < 12 ? ' AM' : ' PM'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            color: Colors.red,
            height: MediaQuery.of(context).size.height * 0.25,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Clock Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: Stream.periodic(
                            const Duration(milliseconds: 1000), (_) {
                          return stopwatchManager.elapsed.inMilliseconds;
                        }),
                        builder: (context, snapshot) {
                          return Text(
                            Duration(milliseconds: snapshot.data ?? 0)
                                .toString()
                                .split('.')
                                .first
                                .padLeft(8, '0'),
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.access_alarm),
                            color: Colors.white,
                            iconSize: 40,
                          ),
                          Text(
                            elapsedTimeString,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        if (clockCheckBool || clockCheckedIn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 1,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[50]!),
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade400.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 90.0,
                                  height: 90.0,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 20.0,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 5.0),
                                      Container(
                                        height: 120.0,
                                        width: 90.0,
                                        color: Colors.grey[300],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5.0),
                            Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 5.0),
                            Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 5.0),
                            Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 1,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[50]!),
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade400.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 90.0,
                                  height: 90.0,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 20.0,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 5.0),
                                      Container(
                                        height: 120.0,
                                        width: 90.0,
                                        color: Colors.grey[300],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5.0),
                            Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 5.0),
                            Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 5.0),
                            Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (details.primaryDelta! < 0) {
              setState(() {
                clockCheckedIn = true;
                swipeDirection = 'Swipe to Check-In';
              });
            } else if (details.primaryDelta! > 0) {
              setState(() {
                clockCheckedIn = true;
                swipeDirection = 'Swipe to Check-out';
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 0.0, bottom: 8.0),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.07,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.0),
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInCheckoutWidget() {
    checkInFormattedTime = timeDisplay;
    return ListView(
      children: [
        if (clockCheckBool || clockCheckedIn)
          Container(
            color: Colors.red,
            height: MediaQuery.of(context).size.height * 0.25,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Clock In',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          '00:00:00',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.access_alarm),
                              color: Colors.white,
                              iconSize: 40,
                            ),
                            StreamBuilder<int>(
                              stream: Stream.periodic(
                                  const Duration(milliseconds: 1), (_) {
                                return stopwatchManager.elapsed.inMilliseconds;
                              }),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  int milliseconds = snapshot.data!;
                                  Duration duration =
                                      Duration(milliseconds: milliseconds);
                                  String formattedTime =
                                      '${duration.inHours.toString().padLeft(2, '0')}:'
                                      '${(duration.inMinutes % 60).toString().padLeft(2, '0')}:'
                                      '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
                                  return Text(
                                    formattedTime,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 25,
                                    ),
                                  );
                                } else {
                                  return const Text(
                                    '00:00:00',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 25,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Clocked In: Today at ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              checkInFormattedTime ??
                                  DateFormat('h:mm').format(DateTime.now()) +
                                      (DateTime.now().hour < 12
                                          ? ' AM'
                                          : ' PM'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            color: Colors.red,
            height: MediaQuery.of(context).size.height * 0.25,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Clock Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: Stream.periodic(const Duration(milliseconds: 1),
                            (_) {
                          return stopwatchManager.stopwatch.elapsedMilliseconds;
                        }),
                        builder: (context, snapshot) {
                          final duration =
                              Duration(milliseconds: snapshot.data ?? 0);
                          DateFormat('HH:mm:ss').format(
                            DateTime(0).add(duration),
                          );
                          return Text(
                            elapsedTimeString,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.access_alarm),
                            color: Colors.white,
                            iconSize: 40,
                          ),
                          Text(
                            elapsedTimeString,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        if (clockCheckBool || clockCheckedIn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 0.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade50.withOpacity(0.3),
                    spreadRadius: 7,
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              width: MediaQuery.of(context).size.width * 0.50,
              height: MediaQuery.of(context).size.height * 0.3,
              child: Card(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.white, width: 0.0),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                color: Colors.white,
                elevation: 0.1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40.0,
                            height: 40.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.grey, width: 1.0),
                            ),
                            child: Stack(
                              children: [
                                if (requestsEmpProfile.isNotEmpty)
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: Image.network(
                                        baseUrl + requestsEmpProfile,
                                        fit: BoxFit.cover,
                                        errorBuilder: (BuildContext context,
                                            Object exception,
                                            StackTrace? stackTrace) {
                                          return const Icon(Icons.person,
                                              color: Colors.grey);
                                        },
                                      ),
                                    ),
                                  ),
                                if (requestsEmpProfile.isEmpty)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[400],
                                      ),
                                      child: const Icon(Icons.person),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width * 0.01),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$requestsEmpMyFirstName $requestsEmpMyLastName',
                                  style: const TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  requestsEmpMyBadgeId,
                                  style: const TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.005),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Department'),
                            Text(requestsEmpMyDepartment),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Check-In'),
                            Text('$checkInFormattedTime'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Shift'),
                            Text(requestsEmpMyShiftName),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 0.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade50.withOpacity(0.3),
                    spreadRadius: 7,
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              width: MediaQuery.of(context).size.width * 0.50,
              height: MediaQuery.of(context).size.height * 0.3,
              child: Card(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.white, width: 0.0),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                color: Colors.white,
                elevation: 0.1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40.0,
                            height: 40.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.grey, width: 1.0),
                            ),
                            child: Stack(
                              children: [
                                if (requestsEmpProfile.isNotEmpty)
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: Image.network(
                                        baseUrl + requestsEmpProfile,
                                        fit: BoxFit.cover,
                                        errorBuilder: (BuildContext context,
                                            Object exception,
                                            StackTrace? stackTrace) {
                                          return const Icon(Icons.person,
                                              color: Colors.grey);
                                        },
                                      ),
                                    ),
                                  ),
                                if (requestsEmpProfile.isEmpty)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[400],
                                      ),
                                      child: const Icon(Icons.person),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width * 0.01),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$requestsEmpMyFirstName $requestsEmpMyLastName',
                                  style: const TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  requestsEmpMyBadgeId,
                                  style: const TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.005),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Department'),
                            Text(requestsEmpMyDepartment),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Check-Out'),
                            Text('$checkOutFormattedTime'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Shift'),
                            Text(requestsEmpMyShiftName),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        GestureDetector(
          onPanUpdate: (details) {
            if (!_isProcessingDrag) {
              if (details.delta.dx.abs() > details.delta.dy.abs() &&
                  details.delta.dx.abs() > 10) {
                _isProcessingDrag = true;
                if (details.delta.dx < 0) {
                  setState(() {
                    postCheckout();
                    isCheckIn = false;
                    clockCheckedIn = false;
                    stopwatchManager.stopStopwatch();
                    storeCheckoutTime();
                    Duration initialElapsedTime = stopwatchManager.elapsed;
                    workingTime = formatDuration(initialElapsedTime);
                    clockCheckBool = false;
                    DateTime now = DateTime.now();
                    checkOutFormattedTime = DateFormat('h:mm a').format(now);
                    swipeDirection = 'Swipe to Check-In';
                    _saveClockState(
                        clockCheckedIn, 2, checkOutFormattedTime.toString());
                  });
                } else if (details.delta.dx > 0) {
                  setState(() {
                    postCheckIn();
                    isCheckIn = true;
                    clockCheckedIn = true;
                    clockCheckBool = true;
                    DateTime now = DateTime.now();
                    checkInFormattedTime = DateFormat('h:mm a').format(now);
                    checkInFormattedTimeTopR = DateFormat('h:mm').format(now);
                    _saveClockState(
                        clockCheckedIn, 1, checkInFormattedTime.toString());

                    if (duration?.isNotEmpty ?? false) {
                      String durationString = duration.toString();

                      try {
                        List<String> parts = durationString.split(':');
                        if (parts.length == 3) {
                          int hours = int.parse(parts[0]);
                          int minutes = int.parse(parts[1]);
                          int seconds = int.parse(parts[2]);
                          Duration initialElapsedTime = Duration(
                              hours: hours, minutes: minutes, seconds: seconds);
                          stopwatchManager.startStopwatch(
                              initialTime: initialElapsedTime);
                        }
                      } catch (e) {}
                    } else {}

                    swipeDirection = 'Swipe to Check-out';
                  });
                }
              }
            }
          },
          onPanEnd: (details) {
            _isProcessingDrag = false;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.07,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: clockCheckedIn ? Colors.red : Colors.green,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (swipeDirection == 'Swipe to Check-In' || !clockCheckedIn)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.12,
                        height: MediaQuery.of(context).size.height * 0.06,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.green,
                          size: 30.0,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Text(
                        swipeDirection,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (swipeDirection == 'Swipe to Check-out' || clockCheckedIn)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.12,
                        height: MediaQuery.of(context).size.height * 0.06,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.red,
                          size: 30.0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/home');
    });
    return Container(
      color: Colors.white,
      child: const Center(child: Text('Page 1')),
    );
  }
}

class Overview extends StatelessWidget {
  const Overview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white, child: const Center(child: Text('Page 2')));
  }
}

class User extends StatelessWidget {
  const User({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/user');
    });
    return Container(
      color: Colors.white,
      child: const Center(child: Text('Page 1')),
    );
  }
}
