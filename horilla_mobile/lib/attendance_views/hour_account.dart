import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:shimmer/shimmer.dart';

class HourAccountFormPage extends StatefulWidget {
  const HourAccountFormPage({super.key});

  @override
  _HourAccountFormPageState createState() => _HourAccountFormPageState();
}

class StateInfo {
  final Color color;
  final String displayString;

  StateInfo(this.color, this.displayString);
}

class _HourAccountFormPageState extends State<HourAccountFormPage> {
  TextEditingController yearController = TextEditingController();
  TextEditingController workedHoursController = TextEditingController();
  TextEditingController pendingHoursController = TextEditingController();
  TextEditingController overtimeHoursController = TextEditingController();
  final TextEditingController _typeAheadController = TextEditingController();
  final TextEditingController _typeAheadCreateController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _pageController = PageController(initialPage: 0);
  final _controller = NotchBottomBarController(index: -1);
  List<Map<String, dynamic>> requests = [];
  List<String> months = [
    'Select Month',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  List<String> monthsLowerCase = [
    'select month',
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december'
  ];
  List<int> yearList =
      List<int>.generate(100, (index) => DateTime.now().year - index);
  List<dynamic> filteredRecords = [];
  List<Map<String, dynamic>> allEmployeeList = [];
  List employeeIdValue = [''];
  String searchText = '';
  String? _errorMessage;
  String? selectedEmployeeId;
  String? selectedEmployee;
  String? createEmployee;
  String workHoursSpent = '';
  String pendingHoursSpent = '';
  String overtimeHoursSpent = '';
  int requestsCount = 0;
  int maxCount = 5;
  int currentPage = 1;
  int? selectedYear;
  Map<String, String> employeeIdMap = {};
  var employeeItems = [''];
  var selectedMonth;
  bool userCreatePermissionCheck = false;
  bool userDeletePermissionCheck = false;
  bool userUpdatePermissionCheck = false;
  bool _validateEmployee = false;
  bool _validateMonth = false;
  bool _validateYear = false;
  bool _validateWorkHour = false;
  bool _validatePendingHour = false;
  bool _validateOvertime = false;
  bool permissionCheck = false;
  bool isLoading = true;
  bool isAction = true;
  bool hasNoRecords = false;
  bool isSaveClick = true;
  bool permissionOverview = true;
  bool permissionAttendance = false;
  bool permissionAttendanceRequest = false;
  bool permissionHourAccount = false;
  late Map<String, dynamic> arguments;
  late String baseUrl = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    permissionChecks();
    getHourAccountRecords();
    getEmployees();
    prefetchData();
    getBaseUrl();
    userPermissionChecks();
    _simulateLoading();
  }

  /// Simulates a loading process by waiting for 5 seconds before calling setState.
  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(seconds: 5));
    setState(() {});
  }

  /// Fetches the base URL from SharedPreferences and updates the state.
  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
  }

  /// Checks if the user has required permissions to perform certain actions.
  Future<void> permissionChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
        Uri.parse('$typedServerUrl/api/attendance/permission-check/attendance');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      permissionCheck = true;
      permissionOverview = true;
      permissionAttendance = true;
      permissionAttendanceRequest = true;
      permissionHourAccount = true;
    } else {
      permissionAttendanceRequest = true;
      permissionHourAccount = true;
    }
  }

  /// Checks the user permissions for adding, deleting, or changing attendance overtime.
  Future<void> userPermissionChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    var addUri = Uri.parse(
        '$typedServerUrl/api/base/check-user-level?employee_id=$employeeId&perm=attendance.add_attendanceovertime');
    var addResponse = await http.get(addUri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (addResponse.statusCode == 200) {
      userCreatePermissionCheck = true;
    } else {
      userCreatePermissionCheck = false;
    }
    var deleteUri = Uri.parse(
        '$typedServerUrl/api/base/check-user-level?employee_id=$employeeId&perm=attendance.delete_attendanceovertime');
    var deleteResponse = await http.get(deleteUri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (deleteResponse.statusCode == 200) {
      userDeletePermissionCheck = true;
    } else {
      userDeletePermissionCheck = false;
    }
    var changeUri = Uri.parse(
        '$typedServerUrl/api/base/check-user-level?employee_id=$employeeId&perm=attendance.change_attendanceovertime');
    var changeResponse = await http.get(changeUri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (changeResponse.statusCode == 200) {
      userUpdatePermissionCheck = true;
    } else {
      userUpdatePermissionCheck = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  /// Handles scroll events to load more records when reaching the end of the list.
  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      currentPage++;
      getHourAccountRecords();
    }
  }

  /// Prefetches employee data from the server and updates the state.
  final List<Widget> bottomBarPages = [
    const Home(),
    const Overview(),
    const User(),
  ];

  /// Fetches hour account records based on the current page and search text.
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
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      arguments = {
        'employee_id': responseData['id'] ?? '',
        'employee_name': (responseData['employee_first_name'] ?? '') +
            ' ' +
            (responseData['employee_last_name'] ?? ''),
        'badge_id': responseData['badge_id'] ?? '',
        'email': responseData['email'] ?? '',
        'phone': responseData['phone'] ?? '',
        'date_of_birth': responseData['dob'] ?? '',
        'gender': responseData['gender'] ?? '',
        'address': responseData['address'] ?? '',
        'country': responseData['country'] ?? '',
        'state': responseData['state'] ?? '',
        'city': responseData['city'] ?? '',
        'qualification': responseData['qualification'] ?? '',
        'experience': responseData['experience'] ?? '',
        'marital_status': responseData['marital_status'] ?? '',
        'children': responseData['children'] ?? '',
        'emergency_contact': responseData['emergency_contact'] ?? '',
        'emergency_contact_name': responseData['emergency_contact_name'] ?? '',
        'employee_work_info_id': responseData['employee_work_info_id'] ?? '',
        'employee_bank_details_id':
            responseData['employee_bank_details_id'] ?? '',
        'employee_profile': responseData['employee_profile'] ?? '',
        'job_position_name': responseData['job_position_name'] ?? ''
      };
    }
  }

  /// Fetches a list of employees and updates the employee data.
  Future<void> getHourAccountRecords() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      hasNoRecords = false;
    });
    if (currentPage != 0) {
      var uri = Uri.parse(
          '$typedServerUrl/api/attendance/attendance-hour-account?page=$currentPage&search=$searchText');
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });
      if (response.statusCode == 200) {
        setState(() {
          requests.addAll(
            List<Map<String, dynamic>>.from(
              jsonDecode(response.body)['results'],
            ),
          );
          requestsCount = jsonDecode(response.body)['count'];
          String serializeMap(Map<String, dynamic> map) {
            return jsonEncode(map);
          }

          Map<String, dynamic> deserializeMap(String jsonString) {
            return jsonDecode(jsonString);
          }

          List<String> mapStrings = requests.map(serializeMap).toList();
          Set<String> uniqueMapStrings = mapStrings.toSet();
          requests = uniqueMapStrings.map(deserializeMap).toList();

          filteredRecords = filterRecords(searchText);
          setState(() {
            isLoading = false;
          });
        });
      } else {
        setState(() {
          isLoading = false;
          hasNoRecords = true;
        });
      }
    } else {
      currentPage = 1;
      var uri = Uri.parse(
          '$typedServerUrl/api/attendance/attendance-hour-account?search=$searchText');
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });
      if (response.statusCode == 200) {
        setState(() {
          requests.addAll(
            List<Map<String, dynamic>>.from(
              jsonDecode(response.body)['results'],
            ),
          );
          requestsCount = jsonDecode(response.body)['count'];
          String serializeMap(Map<String, dynamic> map) {
            return jsonEncode(map);
          }

          Map<String, dynamic> deserializeMap(String jsonString) {
            return jsonDecode(jsonString);
          }

          List<String> mapStrings = requests.map(serializeMap).toList();
          Set<String> uniqueMapStrings = mapStrings.toSet();
          requests = uniqueMapStrings.map(deserializeMap).toList();

          filteredRecords = filterRecords(searchText);
          setState(() {
            isLoading = false;
          });
        });
      } else {
        setState(() {
          isLoading = false;
          hasNoRecords = true;
        });
      }
    }
  }

  /// Adds an overtime entry to the attendance hour account.
  Future<void> getEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      employeeItems.clear();
      employeeIdMap.clear();
      allEmployeeList.clear();
    });

    for (var page = 1;; page++) {
      var uri = Uri.parse(
          '$typedServerUrl/api/employee/employee-selector?page=$page');
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var employeeResults = data['results'];

        if (employeeResults.isEmpty) {
          break;
        }

        setState(() {
          for (var employee in employeeResults) {
            final firstName = employee['employee_first_name'] ?? '';
            final lastName = employee['employee_last_name'] ?? '';
            final fullName = (firstName.isEmpty ? '' : firstName) +
                (lastName.isEmpty ? '' : ' $lastName');
            String employeeId = "${employee['id']}";

            employeeItems.add(fullName);
            employeeIdMap[fullName] = employeeId;
          }

          allEmployeeList.addAll(
            List<Map<String, dynamic>>.from(employeeResults),
          );
        });
      } else {
        throw Exception('Failed to load employee data');
      }
    }
  }

  /// Updates an existing hour account record with the provided details.
  Future<void> addOvertime() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
        Uri.parse('$typedServerUrl/api/attendance/attendance-hour-account/');
    var response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "employee_id": employeeIdValue[employeeIdValue.length - 1],
        "month": selectedMonth,
        "year": yearController.text,
        "worked_hours": workedHoursController.text,
        "pending_hours": pendingHoursController.text,
        "overtime": overtimeHoursController.text
      }),
    );
    if (response.statusCode == 200) {
      setState(() {
        currentPage = 0;
        getHourAccountRecords();
        selectedMonth = 'Select Month';
      });
    }
  }

  /// Updates an existing hour account record.
  Future<void> updateHourAccountRecords(updatedDetails) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var hourAccountId = updatedDetails['id'];
    var uri = Uri.parse(
        '$typedServerUrl/api/attendance/attendance-hour-account/$hourAccountId/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "employee_id": updatedDetails['employee_id'],
        "month": updatedDetails['month'],
        "year": updatedDetails['year'],
        "worked_hours": updatedDetails['worked_hours'],
        "pending_hours": updatedDetails['pending_hours'],
        "overtime": updatedDetails['overtime']
      }),
    );
    if (response.statusCode == 200) {
      isSaveClick = false;
      currentPage = 0;
      requests.clear();
      getHourAccountRecords();
      setState(() {});
    } else {
      isSaveClick = true;
    }
  }

  /// Creates a new hour account record.
  Future<void> createHourAccountRecords(createdDetails) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
        Uri.parse('$typedServerUrl/api/attendance/attendance-hour-account/');
    var response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "employee_id": createdDetails['employee_id'],
        "month": createdDetails['month'],
        "year": createdDetails['year'],
        "worked_hours": createdDetails['worked_hours'],
        "pending_hours": createdDetails['pending_hours'],
        "overtime": createdDetails['overtime']
      }),
    );
    if (response.statusCode == 200) {
      isSaveClick = false;
      currentPage = 0;
      requests.clear();
      getHourAccountRecords();
      setState(() {});
    } else {
      isSaveClick = true;
      var responseData = jsonDecode(response.body);
      if (responseData.containsKey('employee_id')) {
        _errorMessage = responseData['employee_id'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('month')) {
        _errorMessage = responseData['month'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('year')) {
        _errorMessage = responseData['year'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('worked_hours')) {
        _errorMessage = responseData['worked_hours'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('pending_hours')) {
        _errorMessage = responseData['pending_hours'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('overtime')) {
        _errorMessage = responseData['overtime'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('non_field_errors')) {
        _errorMessage = responseData['non_field_errors'].join('\n');
        setState(() {});
      }
      setState(() {});
    }
  }

  /// Displays a dialog animation for a successfully created hour account.
  void showCreateAnimation() {
    String jsonContent = '''
{
  "imagePath": "Assets/gif22.gif"
}
''';
    Map<String, dynamic> jsonData = json.decode(jsonContent);
    String imagePath = jsonData['imagePath'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(imagePath,
                        width: 180, height: 180, fit: BoxFit.cover),
                    const SizedBox(height: 16),
                    const Text(
                      "Hour Account Created Successfully",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop();
    });
  }

  /// Displays a dialog animation for a successfully deleted hour account.
  void showDeleteAnimation() {
    String jsonContent = '''
{
  "imagePath": "Assets/gif22.gif"
}
''';
    Map<String, dynamic> jsonData = json.decode(jsonContent);
    String imagePath = jsonData['imagePath'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(imagePath,
                        width: 180, height: 180, fit: BoxFit.cover),
                    const SizedBox(height: 16),
                    const Text(
                      "Hour Account Deleted Successfully",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop();
    });
  }

  /// Displays a dialog animation for a successfully updated hour account.
  void showEditAnimation() {
    String jsonContent = '''
{
  "imagePath": "Assets/gif22.gif"
}
''';
    Map<String, dynamic> jsonData = json.decode(jsonContent);
    String imagePath = jsonData['imagePath'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(imagePath,
                        width: 180, height: 180, fit: BoxFit.cover),
                    const SizedBox(height: 16),
                    const Text(
                      "Hour Account Updated Successfully",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop();
    });
  }

  /// Deletes an hour account record.
  Future<void> deleteHourAccountRecord(int hourAccountId) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/attendance/attendance-hour-account/$hourAccountId/');

    var response = await http.delete(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 204) {
      setState(() {
        isSaveClick = false;
        requests.removeWhere((item) => item['id'] == hourAccountId);
        currentPage = 0;
        getHourAccountRecords();
        requests.removeWhere((item) => item['id'] == hourAccountId);
      });
    } else {
      isSaveClick = true;
    }
  }

  /// Filters hour account records based on the search text.
  List<Map<String, dynamic>> filterRecords(String searchText) {
    if (searchText.isEmpty) {
      return requests;
    } else {
      return requests.where((record) {
        final firstName = record['employee_first_name'] ?? '';
        final lastName = record['employee_last_name'] ?? '';
        final fullName = (firstName + ' ' + lastName).toLowerCase();
        return fullName.contains(searchText.toLowerCase());
      }).toList();
    }
  }

  void _showEditHourAccount(BuildContext context, Map<String, dynamic> record) {
    TextEditingController yearController =
        TextEditingController(text: record['year'] ?? '');
    TextEditingController workedEditingHoursController =
        TextEditingController(text: record['worked_hours'] ?? '');
    TextEditingController pendingEditingHoursController =
        TextEditingController(text: record['pending_hours'] ?? '');
    TextEditingController overtimeEditingHoursController =
        TextEditingController(text: record['overtime'] ?? '');
    _typeAheadController.text = (record['employee_first_name'] ?? "") +
        " " +
        (record['employee_last_name'] ?? "");
    showDialog(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Stack(
            children: [
              AlertDialog(
                backgroundColor: Colors.white,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Edit Hour Account",
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _errorMessage ?? '',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        const Text(
                          'Employee',
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        TypeAheadField<String>(
                          textFieldConfiguration: TextFieldConfiguration(
                            controller: _typeAheadController,
                            decoration: InputDecoration(
                              labelText: 'Search Employee',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          suggestionsCallback: (pattern) {
                            return employeeItems
                                .where((item) => item
                                    .toLowerCase()
                                    .contains(pattern.toLowerCase()))
                                .toList();
                          },
                          itemBuilder: (context, String suggestion) {
                            return ListTile(
                              title: Text(suggestion),
                            );
                          },
                          onSuggestionSelected: (String suggestion) {
                            setState(() {
                              selectedEmployee = suggestion;
                              selectedEmployeeId = employeeIdMap[suggestion];
                              _validateEmployee = false;
                            });
                            _typeAheadController.text = suggestion;
                          },
                          noItemsFoundBuilder: (context) => const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'No Employees Found',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          errorBuilder: (context, error) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Error: $error',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          hideOnEmpty: true,
                          hideOnError: false,
                          suggestionsBoxDecoration: SuggestionsBoxDecoration(
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.23),
                          ),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        const Text(
                          'Month',
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        DropdownButtonFormField<String>(
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                vertical:
                                    MediaQuery.of(context).size.height * 0.01,
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.008),
                          ),
                          value: record['month'],
                          onChanged: (newValue) {
                            setState(() {
                              selectedMonth = newValue;
                            });
                          },
                          items: months.map((String month) {
                            return DropdownMenuItem<String>(
                              value: monthsLowerCase[months.indexOf(month)],
                              child: Text(month),
                            );
                          }).toList(),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        const Text(
                          'Year',
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Select Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedYear,
                              items: yearList
                                  .map<DropdownMenuItem<int>>((int year) {
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    year.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (int? newValue) {
                                setState(() {
                                  selectedYear = newValue!;
                                });
                              },
                              hint: const Text('Select Year'),
                            ),
                          ),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Text(
                                      'Worked Hours',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.01),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: TextField(
                                      controller: workedEditingHoursController,
                                      keyboardType: TextInputType.datetime,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                        _TimeInputFormatter(),
                                      ],
                                      onChanged: (valueTime) {
                                        workedEditingHoursController.text =
                                            valueTime;
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Text(
                                      'Pending Hours',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.01),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: TextField(
                                      controller: pendingEditingHoursController,
                                      keyboardType: TextInputType.datetime,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                        _TimeInputFormatter(),
                                      ],
                                      onChanged: (valueTime) {
                                        pendingEditingHoursController.text =
                                            valueTime;
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.02),
                        const Text(
                          'Overtime',
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: TextField(
                            controller: overtimeEditingHoursController,
                            keyboardType: TextInputType.datetime,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _TimeInputFormatter(),
                            ],
                            onChanged: (valueTime) {
                              overtimeEditingHoursController.text = valueTime;
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 10.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (isSaveClick == true) {
                          isSaveClick = false;
                          isAction = true;
                          Map<String, dynamic> updatedDetails = {
                            'id': record['id'],
                            'employee_id':
                                selectedEmployeeId ?? record['employee_id'],
                            'month': selectedMonth ?? record['month'],
                            'year': selectedYear,
                            'worked_hours': workedEditingHoursController.text,
                            'pending_hours': pendingEditingHoursController.text,
                            'overtime': overtimeEditingHoursController.text,
                          };
                          await updateHourAccountRecords(updatedDetails);
                          setState(() {
                            isAction = false;
                          });
                          Navigator.of(context).pop(true);
                          showEditAnimation();
                        }
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all<Color>(Colors.red),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                        ),
                      ),
                      child: const Text('Save',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              if (isAction)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          );
        });
      },
    );
  }

  void _showCreateHourAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Stack(
            children: [
              AlertDialog(
                backgroundColor: Colors.white,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Add Hour Account",
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _errorMessage ?? '',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        const Text(
                          'Employee',
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        TypeAheadField<String>(
                          textFieldConfiguration: TextFieldConfiguration(
                            controller: _typeAheadCreateController,
                            decoration: InputDecoration(
                              labelText: 'Search Employee',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              border: const OutlineInputBorder(),
                              errorText: _validateEmployee
                                  ? 'Please Select an Employee'
                                  : null,
                            ),
                          ),
                          suggestionsCallback: (pattern) {
                            return employeeItems
                                .where((item) => item
                                    .toLowerCase()
                                    .contains(pattern.toLowerCase()))
                                .toList();
                          },
                          itemBuilder: (context, String suggestion) {
                            return ListTile(
                              title: Text(suggestion),
                            );
                          },
                          onSuggestionSelected: (String suggestion) {
                            setState(() {
                              createEmployee = suggestion;
                              selectedEmployeeId = employeeIdMap[suggestion];
                              _validateEmployee = false;
                            });
                            _typeAheadCreateController.text = suggestion;
                          },
                          noItemsFoundBuilder: (context) => const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'No Employees Found',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          errorBuilder: (context, error) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Error: $error',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          hideOnEmpty: true,
                          hideOnError: false,
                          suggestionsBoxDecoration: SuggestionsBoxDecoration(
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.23),
                          ),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        const Text(
                          'Month',
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        DropdownButtonFormField<String>(
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Select Month',
                            labelStyle: TextStyle(color: Colors.grey[350]),
                            border: const OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                vertical:
                                    MediaQuery.of(context).size.height * 0.01,
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.008),
                            errorText:
                                _validateMonth ? 'Please select a Month' : null,
                          ),
                          value: selectedMonth,
                          onChanged: (newValue) {
                            setState(() {
                              selectedMonth = newValue;
                              _validateMonth = false;
                            });
                          },
                          items: months.map((String month) {
                            return DropdownMenuItem<String>(
                              value: monthsLowerCase[months.indexOf(month)],
                              child: Text(month),
                            );
                          }).toList(),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        const Text(
                          'Year',
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Select Year',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            errorText:
                                _validateYear ? 'Please select a Year' : null,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedYear,
                              items: yearList
                                  .map<DropdownMenuItem<int>>((int year) {
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    year.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (int? newValue) {
                                setState(() {
                                  selectedYear = newValue!;
                                  yearController.text = selectedYear.toString();
                                  _validateYear = false;
                                });
                              },
                              hint: const Text('Select Year'),
                            ),
                          ),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Text(
                                      'Worked Hours',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.01),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: TextField(
                                      controller: workedHoursController,
                                      keyboardType: TextInputType.datetime,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                        _TimeInputFormatter(),
                                      ],
                                      onChanged: (valueTime) {
                                        workHoursSpent = valueTime;
                                        _validateWorkHour = false;
                                      },
                                      decoration: InputDecoration(
                                        border: const OutlineInputBorder(),
                                        labelText: '00:00',
                                        labelStyle:
                                            TextStyle(color: Colors.grey[350]),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10.0),
                                        errorText: _validateWorkHour
                                            ? 'Please select a WorkHour Spent'
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Text(
                                      'Pending Hours',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.01),
                                  Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: TextField(
                                      controller: pendingHoursController,
                                      keyboardType: TextInputType.datetime,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                        _TimeInputFormatter(),
                                      ],
                                      onChanged: (valueTime) {
                                        pendingHoursSpent = valueTime;
                                        _validatePendingHour = false;
                                      },
                                      decoration: InputDecoration(
                                          border: const OutlineInputBorder(),
                                          labelText: '00:00',
                                          labelStyle: TextStyle(
                                              color: Colors.grey[350]),
                                          errorText: _validatePendingHour
                                              ? 'Please select PendingHour Spent'
                                              : null,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10.0)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.03),
                        const Text(
                          'Overtime',
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: TextField(
                            controller: overtimeHoursController,
                            keyboardType: TextInputType.datetime,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _TimeInputFormatter(),
                            ],
                            onChanged: (valueTime) {
                              overtimeHoursSpent = valueTime;
                              _validateOvertime = false;
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: '00:00',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              errorText: _validateOvertime
                                  ? 'Please select Overtime'
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (isSaveClick == true) {
                          isSaveClick = false;
                          if (_typeAheadCreateController.text.isEmpty) {
                            setState(() {
                              isSaveClick = true;
                              _validateEmployee = true;
                              _validateMonth = false;
                              _validateYear = false;
                              _validateWorkHour = false;
                              _validatePendingHour = false;
                              _validateOvertime = false;
                              Navigator.of(context).pop();
                              _showCreateHourAccount(context);
                            });
                          } else if (selectedMonth == null) {
                            setState(() {
                              isSaveClick = true;
                              _validateEmployee = false;
                              _validateMonth = true;
                              _validateYear = false;
                              _validateWorkHour = false;
                              _validatePendingHour = false;
                              _validateOvertime = false;
                              Navigator.of(context).pop();
                              _showCreateHourAccount(context);
                            });
                          } else if (yearController.text.isEmpty) {
                            setState(() {
                              isSaveClick = true;
                              _validateYear = true;
                              _validateEmployee = false;
                              _validateMonth = false;
                              _validateWorkHour = false;
                              _validatePendingHour = false;
                              _validateOvertime = false;
                              Navigator.of(context).pop();
                              _showCreateHourAccount(context);
                            });
                          } else if (workedHoursController.text.isEmpty) {
                            setState(() {
                              isSaveClick = true;
                              _validateEmployee = false;
                              _validateMonth = false;
                              _validateYear = false;
                              _validateWorkHour = true;
                              _validatePendingHour = false;
                              _validateOvertime = false;
                              Navigator.of(context).pop();
                              _showCreateHourAccount(context);
                            });
                          } else if (pendingHoursController.text.isEmpty) {
                            setState(() {
                              isSaveClick = true;
                              _validateEmployee = false;
                              _validateMonth = false;
                              _validateYear = false;
                              _validateWorkHour = false;
                              _validatePendingHour = true;
                              _validateOvertime = false;
                              Navigator.of(context).pop();
                              _showCreateHourAccount(context);
                            });
                          } else if (overtimeHoursController.text.isEmpty) {
                            setState(() {
                              isSaveClick = true;
                              _validateEmployee = false;
                              _validateMonth = false;
                              _validateYear = false;
                              _validateWorkHour = false;
                              _validatePendingHour = false;
                              _validateOvertime = true;
                              Navigator.of(context).pop();
                              _showCreateHourAccount(context);
                            });
                          } else {
                            isAction = true;
                            Map<String, dynamic> createdDetails = {
                              'employee_id': selectedEmployeeId,
                              'month': selectedMonth,
                              'year': yearController.text,
                              'worked_hours': workedHoursController.text,
                              'pending_hours': pendingHoursController.text,
                              'overtime': overtimeHoursController.text,
                            };
                            await createHourAccountRecords(createdDetails);
                            setState(() {
                              isAction = false;
                            });
                            isAction = false;
                            if (_errorMessage == null ||
                                _errorMessage!.isEmpty) {
                              Navigator.of(context).pop(true);
                              showCreateAnimation();
                            } else {
                              Navigator.of(context).pop();
                              _showCreateHourAccount(context);
                            }
                          }
                        }
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all<Color>(Colors.red),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                        ),
                      ),
                      child: const Text('Save',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              if (isAction)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          );
        });
      },
    );
  }

  Widget buildListItem(Map<String, dynamic> record, baseUrl) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(""),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.5,
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
                                if (record['employee_profile_url'] != null &&
                                    record['employee_profile_url'].isNotEmpty)
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: Image.network(
                                        baseUrl +
                                            record['employee_profile_url'],
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
                                if (record['employee_profile_url'] == null ||
                                    record['employee_profile_url'].isEmpty)
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
                                  record['employee_first_name'] +
                                          " " +
                                          record['employee_last_name'] ??
                                      '',
                                  style: const TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                ),
                                Text(
                                  record['badge_id'] != null
                                      ? '${record['badge_id']}'
                                      : '',
                                  style: const TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                              ),
                              SizedBox(
                                  width: MediaQuery.of(context).size.width *
                                      0.008),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.005),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Month',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text(
                            record['month'] != null &&
                                    record['month'].isNotEmpty
                                ? '${record['month'][0].toUpperCase()}${record['month'].substring(1)}'
                                : 'None',
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Year',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['year'] ?? 'None'}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Worked Hours',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['worked_hours'] ?? 'None'}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pending Hour',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['pending_hours'] ?? 'None'}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Overtime',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['overtime'] ?? 'None'}'),
                        ],
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.01),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.486,
          height: MediaQuery.of(context).size.height * 0.25,
          decoration: BoxDecoration(
            color: Colors.white,
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
                          border: Border.all(color: Colors.grey, width: 1.0),
                        ),
                        child: Stack(
                          children: [
                            if (record['employee_profile_url'] != null &&
                                record['employee_profile_url'].isNotEmpty)
                              Positioned.fill(
                                child: ClipOval(
                                  child: Image.network(
                                    baseUrl + record['employee_profile_url'],
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
                            if (record['employee_profile_url'] == null ||
                                record['employee_profile_url'].isEmpty)
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
                      SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['employee_first_name'] +
                                  ' ' +
                                  (record['employee_last_name'] ?? ''),
                              style: const TextStyle(
                                  fontSize: 16.0, fontWeight: FontWeight.bold),
                              maxLines: 2,
                            ),
                            Text(
                              record['badge_id'] != null
                                  ? '${record['badge_id']}'
                                  : '',
                              style: const TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.005),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Visibility(
                            visible: userUpdatePermissionCheck,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15.0),
                                  bottomLeft: Radius.circular(15.0),
                                ),
                                color: Colors.blue[100],
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 0.0),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 18.0,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isSaveClick = true;
                                      _errorMessage = null;
                                      isAction = false;
                                      selectedYear = int.parse(record['year']);
                                    });
                                    _showEditHourAccount(context, record);
                                  },
                                ),
                              ),
                            ),
                          ),
                          Visibility(
                            visible: userDeletePermissionCheck,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(15.0),
                                  bottomRight: Radius.circular(15.0),
                                ),
                                color: Colors.red[100],
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 0.0),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 18.0,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    isSaveClick = true;
                                    await showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          backgroundColor: Colors.white,
                                          title: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Confirmation",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop(true);
                                                },
                                              ),
                                            ],
                                          ),
                                          content: SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.1,
                                            child: const Center(
                                              child: Text(
                                                "Are you sure you want to delete this hour account?",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 17,
                                                ),
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  if (isSaveClick == true) {
                                                    isSaveClick = false;
                                                    var hourAccountId =
                                                        record['id'];
                                                    await deleteHourAccountRecord(
                                                        hourAccountId);
                                                    Navigator.of(context)
                                                        .pop(true);
                                                    showDeleteAnimation();
                                                  }
                                                },
                                                style: ButtonStyle(
                                                  backgroundColor:
                                                      MaterialStateProperty.all<
                                                          Color>(Colors.red),
                                                  shape:
                                                      MaterialStateProperty.all<
                                                          RoundedRectangleBorder>(
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  "Continue",
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width * 0.005),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Month',
                                style: TextStyle(color: Colors.grey.shade700)),
                            Text(
                              record['month'] != null &&
                                      record['month'].isNotEmpty
                                  ? '${record['month'][0].toUpperCase()}${record['month'].substring(1)}'
                                  : 'None',
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Year',
                                style: TextStyle(color: Colors.grey.shade700)),
                            Text('${record['year']}'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Worked Hours',
                                style: TextStyle(color: Colors.grey.shade700)),
                            Text('${record['worked_hours']}'),
                          ],
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text('Hour Account',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (userCreatePermissionCheck)
                  Container(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isSaveClick = true;
                          _validateEmployee = false;
                          _validateMonth = false;
                          _validateYear = false;
                          _validateWorkHour = false;
                          _validatePendingHour = false;
                          _validateOvertime = false;
                          _errorMessage = null;
                          selectedYear = null;
                          selectedEmployee = " ";
                          selectedMonth = null;
                          isAction = false;
                          _typeAheadCreateController.clear();
                          yearController.clear();
                          workedHoursController.clear();
                          pendingHoursController.clear();
                          overtimeHoursController.clear();
                        });
                        _showCreateHourAccount(context);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(75, 50),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                      child: const Text('CREATE',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: isLoading ? _buildLoadingWidget() : _buildEmployeeDetailsWidget(),
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset('Assets/horilla-logo.png'),
                ),
              ),
            ),
            permissionOverview
                ? ListTile(
                    title: const Text('Overview'),
                    onTap: () {
                      Navigator.pushNamed(context, '/attendance_overview');
                    },
                  )
                : const SizedBox.shrink(),
            permissionAttendance
                ? ListTile(
                    title: const Text('Attendance'),
                    onTap: () {
                      Navigator.pushNamed(context, '/attendance_attendance');
                    },
                  )
                : const SizedBox.shrink(),
            permissionAttendanceRequest
                ? ListTile(
                    title: const Text('Attendance Request'),
                    onTap: () {
                      Navigator.pushNamed(context, '/attendance_request');
                    },
                  )
                : const SizedBox.shrink(),
            permissionHourAccount
                ? ListTile(
                    title: const Text('Hour Account'),
                    onTap: () {
                      Navigator.pushNamed(context, '/employee_hour_account');
                    },
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
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
              durationInMilliSeconds: 300,
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
                    Navigator.pushNamed(context, '/home');
                    break;
                  case 1:
                    Navigator.pushNamed(context, '/employee_checkin_checkout');
                    break;
                  case 2:
                    Navigator.pushNamed(context, '/employees_form',
                        arguments: arguments);
                    break;
                }
              },
            )
          : null,
    );
  }

  Widget shimmerListTile() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListTile(
        title: Container(
          width: double.infinity,
          height: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    elevation: 0,
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: Colors.grey),
                          color: Colors.white,
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            hintText: 'Search',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 4.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          Expanded(
            child: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) {
                return Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
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
                      child: Card(
                        shape: RoundedRectangleBorder(
                          side:
                              const BorderSide(color: Colors.white, width: 0.0),
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
                                children: [
                                  Container(
                                    width: 40.0,
                                    height: 40.0,
                                    color: Colors.grey[300],
                                  ),
                                ],
                              ),
                              SizedBox(
                                  height: MediaQuery.of(context).size.height *
                                      0.005),
                              Container(
                                height: 20.0,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 20.0,
                                width: 80.0,
                                color: Colors.grey[300],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDetailsWidget() {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          onChanged: (employeeSearchValue) {
                            setState(() {
                              searchText = employeeSearchValue;
                              requests.clear();
                              hasNoRecords = false;
                              getHourAccountRecords();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: TextStyle(
                                color: Colors.blueGrey.shade300, fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            prefixIcon: Transform.scale(
                              scale: 0.8,
                              child: Icon(Icons.search,
                                  color: Colors.blueGrey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 4.0),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            if (requestsCount == 0)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_outlined,
                        color: Colors.black,
                        size: 92,
                      ),
                      SizedBox(height: 20),
                      Text(
                        "There are no records to display",
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: searchText.isEmpty
                        ? requests.length
                        : filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = searchText.isEmpty
                          ? requests[index]
                          : filteredRecords[index];
                      return buildListItem(record, baseUrl);
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
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

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    if (text.length == 1 && int.tryParse(text)! > 2) {
      return TextEditingValue(
          text: '0$text:', selection: const TextSelection.collapsed(offset: 3));
    } else if (text.length == 3) {
      return TextEditingValue(
          text: '${text.substring(0, 2)}:${text.substring(2)}',
          selection: const TextSelection.collapsed(offset: 4));
    } else if (text.length == 4) {
      return TextEditingValue(
          text: '${text.substring(0, 2)}:${text.substring(2)}',
          selection: const TextSelection.collapsed(offset: 5));
    } else if (text.length > 5) {
      return TextEditingValue(
        text: text.substring(0, 5),
        selection: const TextSelection.collapsed(offset: 5),
      );
    }
    return newValue;
  }
}
