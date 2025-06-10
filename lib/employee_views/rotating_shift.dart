import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class RotatingShiftPage extends StatefulWidget {
  final String selectedEmployerId;
  final String selectedEmployeeFullName;

  const RotatingShiftPage(
      {super.key,
        required this.selectedEmployerId,
        required this.selectedEmployeeFullName});

  @override
  _WorkTypeRequestPageState createState() => _WorkTypeRequestPageState();
}

class StateInfo {
  final Color color;
  final String displayString;

  StateInfo(this.color, this.displayString);
}

class _WorkTypeRequestPageState extends State<RotatingShiftPage> {
  TextEditingController yearController = TextEditingController();
  TextEditingController workedHoursController = TextEditingController();
  TextEditingController pendingHoursController = TextEditingController();
  TextEditingController overtimeHoursController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _pageController = PageController(initialPage: 0);
  final _controller = NotchBottomBarController(index: -1);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _typeAheadEditController =
  TextEditingController();
  final TextEditingController _typeAheadEditRotatingShiftController =
  TextEditingController();
  final TextEditingController _typeAheadAddRotatingController =
  TextEditingController();
  final TextEditingController _rotateCreateDayController =
  TextEditingController(text: "0");
  final TextEditingController _rotateDayController = TextEditingController();
  final TextEditingController _typeAheadCreateRotatingShiftController =
  TextEditingController();
  TextEditingController createRotateStartDateController =
  TextEditingController();
  List<Map<String, dynamic>> requests = [];
  List<dynamic> filteredRecords = [];
  List employeeIdValue = [''];
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
  List<String> rotateShiftItems = [];
  List<Map<String, dynamic>> allEmployeeList = [];
  String employeeId = '';
  String selectedEmployeeFullName = '';
  String searchText = '';
  String? selectedEmployee;
  String? createEmployee;
  String? _errorMessage;
  String? editEmployee;
  String? selectedCreateEmployeeId;
  String? editRotatedShift;
  String? selectedEditRotatedShift;
  String? selectedEditEmployeeId;
  String? createRotatedShift;
  String? selectedCreateRotatedShift;
  String? selectedCreateBasedOnValue;
  int requestsCount = 0;
  int maxCount = 5;
  int currentPage = 1;
  var employeeItems = [''];
  var selectedMonth;
  Map<String, dynamic> employeeDetails = {};
  Map<String, String> rotateShiftIdMap = {};
  Map<String, String> employeeIdMap = {};
  late Map<String, dynamic> arguments;
  late String baseUrl = '';
  bool switchValue = false;
  bool permissionCheck = false;
  bool accessCheck = false;
  bool isLoading = true;
  bool _isShimmerVisible = true;
  bool isAction = true;
  bool hasNoRecords = false;
  bool isSaveClick = true;
  bool _validateRequestedDate = false;
  bool _validateRotateShift = false;
  bool _validateBasedOn = false;
  bool _validateRotateDay = false;
  int? selectedEmployerId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    prefetchData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      permissionChecks();
      accessChecks();
      getRotatingShiftRequest();
      getEmployees();
      getBaseUrl();
      _simulateLoading();
      getEmployeeDetails();
      getRotatingShift();
    });
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(seconds: 5));
    setState(() {});
  }

  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
  }
  void accessChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var employeeId = prefs.getInt("employee_id");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
    Uri.parse('$typedServerUrl/api/base/rotating-shift-create-permission-check/$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      accessCheck = true;
    }
  }

  void permissionChecks() async {
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
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      currentPage++;
      getRotatingShiftRequest();
    }
  }

  /// widget list
  final List<Widget> bottomBarPages = [
    const Home(),
    const Overview(),
    const User(),
  ];

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

  Future<void> getRotatingShiftRequest() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    employeeId = widget.selectedEmployerId;
    setState(() {
      hasNoRecords = false;
    });
    if (currentPage != 0) {
      var uri = Uri.parse(
          '$typedServerUrl /api/base/individual-rotating-shifts?employee_id=$employeeId&page=$currentPage&search=$searchText');
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
          _isShimmerVisible = false;

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
          '$typedServerUrl/api/base/rotating-shift-assigns?employee_id=$employeeId&search=$searchText');
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
          _isShimmerVisible = false;

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

  Future<void> getEmployeeDetails() async {
    employeeId = widget.selectedEmployerId;
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/employee/employees/$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        employeeDetails = jsonDecode(response.body);
        setState(() {
          isLoading = false;
        });
      });
    }
  }

  Future<void> getRotatingShift() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/base/rotating-shifts/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      List<dynamic> responseBody = jsonDecode(response.body);

      setState(() {
        for (var rec in responseBody) {
          final rotatedShift = rec['name'] ?? '';
          String rotatedShiftId = "${rec['id']}";
          rotateShiftItems.add(rotatedShift);
          rotateShiftIdMap[rotatedShift] = rotatedShiftId;
        }
      });
    }
  }

  Future<void> getEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    for (var page = 1;; page++) {
      var uri = Uri.parse(
          '$typedServerUrl/api/employee/employee-selector?page=$page');
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });
      if (response.statusCode == 200) {
        setState(() {
          for (var employee in jsonDecode(response.body)['results']) {
            final firstName = employee['employee_first_name'] ?? '';
            final lastName = employee['employee_last_name'] ?? '';
            final fullName = (firstName.isEmpty ? '' : firstName) +
                (lastName.isEmpty ? '' : ' $lastName');
            String employeeId = "${employee['id']}";
            employeeItems.add(fullName);
            employeeIdMap[fullName] = employeeId;
          }
          allEmployeeList = List<Map<String, dynamic>>.from(
            jsonDecode(response.body)['results'],
          );
        });
      }
    }
  }

  Future<String?> showCustomDatePicker(
      BuildContext context, DateTime initialDate) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      return "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";
    }
    return null;
  }

  Future<void> updateRotatingShift(Map<String, dynamic> updatedDetails) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    String rotatingShiftId = updatedDetails['id'].toString();
    var uri = Uri.parse(
        '$typedServerUrl/api/base/rotating-shift-assigns/$rotatingShiftId/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "employee_id": updatedDetails['employee_id'],
        "rotating_shift_id": updatedDetails['rotating_shift_id'],
        "start_date": updatedDetails['start_date'],
        "based_on": updatedDetails['based_on'],
        "rotate_after_day": updatedDetails['rotate_after_day'],
      }),
    );
    if (response.statusCode == 200) {
      isSaveClick = false;
      _errorMessage = null;
      getRotatingShiftRequest();
      setState(() {});
    } else {
      isSaveClick = true;
      var responseData = jsonDecode(response.body);
      if (responseData.containsKey('non_field_errors')) {
        _errorMessage = responseData['non_field_errors'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('rotate_after_day')) {
        _errorMessage = responseData['rotate_after_day'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('based_on')) {
        _errorMessage = responseData['based_on'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('start_date')) {
        _errorMessage = responseData['start_date'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('rotating_shift_id')) {
        _errorMessage = responseData['rotating_shift_id'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('employee_id')) {
        _errorMessage = responseData['employee_id'].join('\n');
        setState(() {});
      }
      setState(() {});
    }
  }

  Future<void> createRotatingShiftRequest(
      Map<String, dynamic> createdDetails) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/base/rotating-shift-assigns/');
    var response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "employee_id": createdDetails['employee_id'],
        "rotating_shift_id": createdDetails['rotating_shift_id'],
        "start_date": createdDetails['start_date'],
        "based_on": createdDetails['based_on'],
        "rotate_after_day": createdDetails['rotate_after_day'],
      }),
    );
    if (response.statusCode == 201) {
      isSaveClick = false;
      _errorMessage = null;
      getRotatingShiftRequest();
      setState(() {});
    } else {
      isSaveClick = true;
      var responseData = jsonDecode(response.body);
      if (responseData.containsKey('non_field_errors')) {
        _errorMessage = responseData['non_field_errors'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('rotating_work_type_id')) {
        _errorMessage = responseData['rotating_work_type_id'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('start_date')) {
        _errorMessage = responseData['start_date'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('based_on')) {
        _errorMessage = responseData['based_on'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('rotate_after_day')) {
        _errorMessage = responseData['rotate_after_day'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('employee_id')) {
        _errorMessage = responseData['employee_id'].join('\n');
        setState(() {});
      }
      setState(() {});
    }
  }

  void showCreateRotatingShiftAnimation() {
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
                    Image.asset(imagePath),
                    const SizedBox(height: 16),
                    const Text(
                      "Shift Created Successfully",
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

  void showDeleteRotatingShiftAnimation() {
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
                    Image.asset(imagePath),
                    const SizedBox(height: 16),
                    const Text(
                      "Shift Deleted Successfully",
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

  void showRotateShiftUpdateAnimation() {
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
                    Image.asset(imagePath),
                    const SizedBox(height: 16),
                    const Text(
                      "Shift Updated Successfully",
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

  Future<void> deleteRotatingShiftRequest(int requestId) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/base/rotating-shift-assigns/$requestId/');
    var response = await http.delete(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        isSaveClick = false;
        getRotatingShiftRequest();
      });
    } else {
      isSaveClick = true;
    }
  }

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

  void _showEditRotatingShift(
      BuildContext context, Map<String, dynamic> record) {
    TextEditingController editStartDateController =
    TextEditingController(text: record['start_date'] ?? '');
    TextEditingController rotateDayController = TextEditingController(
        text: (record['rotate_after_day'] ?? '0').toString());
    final List<DropdownMenuItem<String>> basedOnItems = [
      const DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
      const DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
      const DropdownMenuItem(value: 'after', child: Text('After')),
    ];
    String selectedBasedOnValue = record['based_on'] ?? 'monthly';
    _typeAheadEditController.text = widget.selectedEmployeeFullName;
    _typeAheadEditRotatingShiftController.text =
        record['rotating_shift_name'] ?? "";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Stack(
              children: [
                AlertDialog(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Edit Rotating Shift",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 21),
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
                    height: MediaQuery.of(context).size.height * 0.50,
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
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            'Employee',
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TypeAheadField<String>(
                            textFieldConfiguration: TextFieldConfiguration(
                              controller: _typeAheadEditController,
                              decoration: InputDecoration(
                                labelText: 'Search Employee',
                                labelStyle: TextStyle(color: Colors.grey[350]),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
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
                                createEmployee = suggestion;
                                selectedEditEmployeeId =
                                employeeIdMap[suggestion];
                              });
                              _typeAheadEditController.text = suggestion;
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
                                  MediaQuery.of(context).size.height *
                                      0.23), // Limit height
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            'Rotating Shift',
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TypeAheadField<String>(
                            textFieldConfiguration: TextFieldConfiguration(
                              controller: _typeAheadEditRotatingShiftController,
                              decoration: InputDecoration(
                                labelText: 'Search Rotating Shift',
                                labelStyle: TextStyle(color: Colors.grey[350]),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            suggestionsCallback: (pattern) {
                              return rotateShiftItems
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
                                editRotatedShift = suggestion;
                                selectedEditRotatedShift =
                                rotateShiftIdMap[suggestion];
                                _validateRotateShift = false;
                              });
                              _typeAheadEditRotatingShiftController.text =
                                  suggestion;
                            },
                            noItemsFoundBuilder: (context) => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'No Shift Found',
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
                                  MediaQuery.of(context).size.height *
                                      0.23), // Limit height
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            "Start Date",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            readOnly: true,
                            controller: editStartDateController,
                            onTap: () async {
                              final selectedDate = await showCustomDatePicker(
                                  context, DateTime.now());
                              if (selectedDate != null) {
                                DateTime parsedDate = DateFormat('yyyy-MM-dd')
                                    .parse(selectedDate);
                                setState(() {
                                  editStartDateController.text =
                                      DateFormat('yyyy-MM-dd')
                                          .format(parsedDate);
                                  _validateRequestedDate = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Select a Start Date',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                              errorText: _validateRequestedDate
                                  ? 'Please select a Start Date'
                                  : null,
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            "Based On",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          DropdownButtonFormField<String>(
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                            value: selectedBasedOnValue,
                            items: basedOnItems,
                            onChanged: (newValue) {
                              setState(() {
                                selectedBasedOnValue = newValue!;
                              });
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Choose Based On',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            "Rotate After Day",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            controller: rotateDayController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Rotate After Day',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 10.0),
                              suffixIcon: IntrinsicHeight(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 24.0,
                                      width: 24.0,
                                      child: IconButton(
                                        padding: const EdgeInsets.all(0),
                                        icon: const Icon(Icons.arrow_drop_up,
                                            size: 16.0),
                                        onPressed: () {
                                          int currentValue = int.parse(
                                              rotateDayController.text);
                                          setState(() {
                                            rotateDayController.text =
                                                (currentValue + 1).toString();
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      height: 24.0,
                                      width: 24.0,
                                      child: IconButton(
                                        padding: const EdgeInsets.all(0),
                                        icon: const Icon(Icons.arrow_drop_down,
                                            size: 16.0),
                                        onPressed: () {
                                          int currentValue = int.parse(
                                              rotateDayController.text);
                                          setState(() {
                                            rotateDayController.text =
                                                (currentValue > 0
                                                    ? currentValue - 1
                                                    : 0)
                                                    .toString();
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          if (isSaveClick == true) {
                            isSaveClick = false;
                            setState(() {
                              _errorMessage = null;
                              isAction = true;
                            });
                            Map<String, dynamic> updatedDetails = {
                              'id': record['id'],
                              "employee_id": selectedEditEmployeeId ??
                                  record['employee_id'].toString(),
                              "rotating_shift_id": selectedEditRotatedShift ??
                                  record['rotating_shift_id'].toString(),
                              "start_date": editStartDateController.text,
                              "based_on": selectedBasedOnValue,
                              "rotate_after_day": rotateDayController.text,
                            };
                            await updateRotatingShift(updatedDetails);
                            setState(() {
                              isAction = false;
                            });
                            if (_errorMessage == null ||
                                _errorMessage!.isEmpty) {
                              Navigator.of(context).pop(true);
                              showRotateShiftUpdateAnimation();
                            } else {
                              Navigator.of(context).pop(true);
                              _showEditRotatingShift(context, record);
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
          },
        );
      },
    );
  }

  void _showCreateRotatingShift(
      BuildContext context, selectedEmployeeFullName, selectedEmployerId) {
    final List<DropdownMenuItem<String>> basedOnItems = [
      const DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
      const DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
      const DropdownMenuItem(value: 'after', child: Text('After')),
    ];
    _typeAheadAddRotatingController.text = widget.selectedEmployeeFullName;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Stack(
              children: [
                AlertDialog(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Add Rotating Shift",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 21),
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
                    height: MediaQuery.of(context).size.height * 0.50,
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
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            'Employee',
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TypeAheadField<String>(
                            textFieldConfiguration: TextFieldConfiguration(
                              controller: _typeAheadAddRotatingController,
                              decoration: InputDecoration(
                                labelText: 'Search Employee',
                                labelStyle: TextStyle(color: Colors.grey[350]),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
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
                                selectedCreateEmployeeId =
                                employeeIdMap[suggestion];
                              });
                              _typeAheadAddRotatingController.text = suggestion;
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
                                  MediaQuery.of(context).size.height *
                                      0.23), // Limit height
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            'Rotating Shift',
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TypeAheadField<String>(
                            textFieldConfiguration: TextFieldConfiguration(
                              controller:
                              _typeAheadCreateRotatingShiftController,
                              decoration: InputDecoration(
                                labelText: 'Search Rotating Shift',
                                labelStyle: TextStyle(color: Colors.grey[350]),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                errorText: _validateRotateShift
                                    ? 'Please Select a Rotating Shift'
                                    : null,
                              ),
                            ),
                            suggestionsCallback: (pattern) {
                              return rotateShiftItems
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
                                createRotatedShift = suggestion;
                                selectedCreateRotatedShift =
                                rotateShiftIdMap[suggestion];
                                _validateRotateShift = false;
                              });
                              _typeAheadCreateRotatingShiftController.text =
                                  suggestion;
                            },
                            noItemsFoundBuilder: (context) => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'No Rotating Shift Found',
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
                                  MediaQuery.of(context).size.height *
                                      0.23), // Limit height
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            "Start Date",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            readOnly: true,
                            controller: createRotateStartDateController,
                            onTap: () async {
                              final selectedDate = await showCustomDatePicker(
                                  context, DateTime.now());
                              if (selectedDate != null) {
                                DateTime parsedDate = DateFormat('yyyy-MM-dd')
                                    .parse(selectedDate);
                                setState(() {
                                  createRotateStartDateController.text =
                                      DateFormat('yyyy-MM-dd')
                                          .format(parsedDate);
                                  _validateRequestedDate = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Select Start Date',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              errorText: _validateRequestedDate
                                  ? 'Please select a Start date'
                                  : null,
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                              hintText: 'Select a Start Date',
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            "Based On",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          DropdownButtonFormField<String>(
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                            items: basedOnItems,
                            onChanged: (newValue) {
                              setState(() {
                                selectedCreateBasedOnValue = newValue!;
                                _validateBasedOn = false;
                              });
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Select Based On',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              errorText: _validateBasedOn
                                  ? 'Please select a Based On'
                                  : null,
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                              hintText: 'Select a Based On',
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            "Rotate After Day",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            controller: _rotateCreateDayController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Rotate After Day',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              errorText: _validateRotateDay
                                  ? 'Please select a Rotate After Day'
                                  : null,
                              hintText: 'Select a Rotate After Day',
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 10.0),
                              suffixIcon: IntrinsicHeight(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 24.0,
                                      width: 24.0,
                                      child: IconButton(
                                        padding: const EdgeInsets.all(0),
                                        icon: const Icon(Icons.arrow_drop_up,
                                            size: 16.0),
                                        onPressed: () {
                                          int currentValue = int.parse(
                                              _rotateCreateDayController.text);
                                          setState(() {
                                            _validateRotateDay = false;
                                            _rotateCreateDayController.text =
                                                (currentValue + 1).toString();
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      height: 24.0,
                                      width: 24.0,
                                      child: IconButton(
                                        padding: const EdgeInsets.all(0),
                                        icon: const Icon(Icons.arrow_drop_down,
                                            size: 16.0),
                                        onPressed: () {
                                          int currentValue = int.parse(
                                              _rotateDayController.text);
                                          setState(() {
                                            _validateRotateDay = false;
                                            _rotateDayController.text =
                                                (currentValue > 0
                                                    ? currentValue - 1
                                                    : 0)
                                                    .toString();
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          if (isSaveClick == true) {
                            isSaveClick = false;
                            setState(() {
                              _errorMessage = null;
                              isAction = true;
                            });
                            if (_typeAheadCreateRotatingShiftController
                                .text.isEmpty) {
                              setState(() {
                                isAction = false;
                                isSaveClick = true;
                                _validateRotateShift = true;
                                _validateRequestedDate = false;
                                _validateBasedOn = false;
                                _validateRotateDay = false;
                                Navigator.of(context).pop(true);
                                _showCreateRotatingShift(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
                              });
                            } else if (createRotateStartDateController
                                .text.isEmpty) {
                              setState(() {
                                isAction = false;
                                isSaveClick = true;
                                _validateRotateShift = false;
                                _validateRequestedDate = true;
                                _validateBasedOn = false;
                                _validateRotateDay = false;
                                Navigator.of(context).pop(true);
                                _showCreateRotatingShift(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
                              });
                            } else if (selectedCreateBasedOnValue == " ") {
                              setState(() {
                                isAction = false;
                                isSaveClick = true;
                                _validateRotateShift = false;
                                _validateRequestedDate = false;
                                _validateBasedOn = true;
                                _validateRotateDay = false;
                                Navigator.of(context).pop(true);
                                _showCreateRotatingShift(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
                              });
                            } else if (_rotateCreateDayController
                                .text.isEmpty) {
                              setState(() {
                                isAction = false;
                                isSaveClick = true;
                                _validateRotateShift = false;
                                _validateRequestedDate = false;
                                _validateBasedOn = false;
                                _validateRotateDay = true;
                                Navigator.of(context).pop(true);
                                _showCreateRotatingShift(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
                              });
                            } else {
                              Map<String, dynamic> createdDetails = {
                                "employee_id": selectedCreateEmployeeId ??
                                    widget.selectedEmployerId,
                                "rotating_shift_id": selectedCreateRotatedShift,
                                "start_date":
                                createRotateStartDateController.text,
                                "based_on": selectedCreateBasedOnValue,
                                "rotate_after_day":
                                _rotateCreateDayController.text,
                              };
                              await createRotatingShiftRequest(createdDetails);
                              setState(() {
                                isAction = false;
                              });
                              if (_errorMessage == null ||
                                  _errorMessage!.isEmpty) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => RotatingShiftPage(
                                          selectedEmployerId:
                                          widget.selectedEmployerId,
                                          selectedEmployeeFullName:
                                          widget.selectedEmployeeFullName)),
                                );
                                showCreateRotatingShiftAnimation();
                              } else {
                                Navigator.of(context).pop(true);
                                _showCreateRotatingShift(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
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
          },
        );
      },
    );
  }

  Widget buildListItem(Map<String, dynamic> record, baseUrl) {
    final image = employeeDetails['employee_profile'] ?? '';

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(" "),
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
                height: MediaQuery.of(context).size.height * 0.4,
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
                                if (employeeDetails['employee_profile'] !=
                                    null &&
                                    employeeDetails['employee_profile']
                                        .isNotEmpty)
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: Image.network(
                                        baseUrl +
                                            employeeDetails['employee_profile'],
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
                                if (employeeDetails['employee_profile'] ==
                                    null ||
                                    employeeDetails['employee_profile'].isEmpty)
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
                                  widget.selectedEmployeeFullName,
                                  style: const TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                ),
                                Text(
                                  employeeDetails['badge_id'] != null
                                      ? '(${employeeDetails['badge_id']})'
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
                          height: MediaQuery.of(context).size.height * 0.02),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Title',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Flexible(
                            child: Text(
                              '${record['rotating_shift_name'] ?? 'None'}',
                              softWrap: true,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Based On',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['based_on'] ?? 'None'}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Start Date',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['start_date'] ?? 'None'}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Shift',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['current_shift_name'] ?? 'None'}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next Shift',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['next_shift_name'] ?? 'None'}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next Change Date',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text('${record['next_change_date'] ?? 'None'}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text(
                              record['is_active'] ? 'Is Active' : 'Not Active'),
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
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[50]!),
            borderRadius: BorderRadius.circular(8.0),
            color: Colors.white,
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
              borderRadius: BorderRadius.circular(8.0),
            ),
            color: Colors.white,
            elevation: 0.0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                            if (employeeDetails['employee_profile'] != null &&
                                employeeDetails['employee_profile'].isNotEmpty)
                              Positioned.fill(
                                child: ClipOval(
                                  child: Image.network(
                                    baseUrl +
                                        employeeDetails['employee_profile'],
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
                            if (employeeDetails['employee_profile'] == null ||
                                employeeDetails['employee_profile'].isEmpty)
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
                              employeeDetails['employee_first_name'] +
                                  ' ' +
                                  (employeeDetails['employee_last_name'] ?? ''),
                              style: const TextStyle(
                                  fontSize: 16.0, fontWeight: FontWeight.bold),
                              maxLines: 2,
                            ),
                            Text(
                              employeeDetails['badge_id'] != null
                                  ? '(${employeeDetails['badge_id']})'
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
                      if (accessCheck) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15.0),
                              bottomLeft: Radius.circular(15.0),
                            ),
                            color: Colors.blue[100],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 0.0),
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 18.0,
                                color: Colors.blue,
                              ),
                              onPressed: () async {
                                _errorMessage = null;
                                isAction = false;
                                _showEditRotatingShift(context, record);
                              },
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(15.0),
                              bottomRight: Radius.circular(15.0),
                            ),
                            color: Colors.red[100],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 0.0),
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
                                              Navigator.of(context).pop(true);
                                            },
                                          ),
                                        ],
                                      ),
                                      content: SizedBox(
                                        height:
                                        MediaQuery.of(context).size.height *
                                            0.1,
                                        child: const Center(
                                          child: Text(
                                            "Are you sure you want to delete this Rotating Shift?",
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
                                                var requestId = record['id'];
                                                await deleteRotatingShiftRequest(
                                                    requestId);
                                                Navigator.of(context).pop(true);
                                                showDeleteRotatingShiftAnimation();
                                              }
                                            },
                                            style: ButtonStyle(
                                              backgroundColor:
                                              MaterialStateProperty.all<
                                                  Color>(Colors.red),
                                              shape: MaterialStateProperty.all<
                                                  RoundedRectangleBorder>(
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(8.0),
                                                ),
                                              ),
                                            ),
                                            child: const Text(
                                              "Continue",
                                              style:
                                              TextStyle(color: Colors.white),
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
                      ],
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.02,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Title',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Flexible(
                            child: Text(
                              record['rotating_shift_name'] != null
                                  ? record['rotating_shift_name'].toString()
                                  : "None",
                              textAlign: TextAlign.right,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Start Date',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            record['start_date'] != null
                                ? record['start_date'].toString()
                                : "None",
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current Shift',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            record['current_shift_name'] != null
                                ? record['current_shift_name'].toString()
                                : "None",
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Next Switch',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            record['next_change_date'] != null
                                ? record['next_change_date'].toString()
                                : "None",
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Next Shift',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            record['next_shift_name'] != null
                                ? record['next_shift_name'].toString()
                                : "None",
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ],
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
    final bool permissionCheck =
    ModalRoute.of(context)?.settings.arguments != null
        ? ModalRoute.of(context)!.settings.arguments as bool
        : false;
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: const Text('Rotating Shift',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.all(12.0),
        //     child: Row(
        //       mainAxisAlignment: MainAxisAlignment.end,
        //       children: [
        //         // if (permissionCheck)
        //         Container(
        //           alignment: Alignment.centerRight,
        //           child: ElevatedButton(
        //             onPressed: () {
        //               setState(() {
        //                 _errorMessage = null;
        //                 _typeAheadCreateRotatingShiftController.clear();
        //                 createRotateStartDateController.clear();
        //                 selectedCreateBasedOnValue = " ";
        //                 _rotateCreateDayController.text = "0";
        //                 _validateRotateShift = false;
        //                 _validateRequestedDate = false;
        //                 _validateBasedOn = false;
        //                 _validateRotateDay = false;
        //                 isAction = false;
        //               });
        //               _showCreateRotatingShift(context,
        //                   selectedEmployeeFullName, selectedEmployerId);
        //             },
        //             style: ElevatedButton.styleFrom(
        //               minimumSize: const Size(75, 50),
        //               backgroundColor: Colors.white,
        //               shape: RoundedRectangleBorder(
        //                 borderRadius: BorderRadius.circular(4.0),
        //                 side: const BorderSide(color: Colors.red),
        //               ),
        //             ),
        //             child: const Text('CREATE',
        //                 style: TextStyle(color: Colors.red)),
        //           ),
        //         ),
        //         // ),
        //       ],
        //     ),
        //   ),
        // ],
      ),
      body: _isShimmerVisible
          ? _buildLoadingWidget()
          : _buildEmployeeDetailsWidget(),
      bottomNavigationBar: (bottomBarPages.length <= maxCount)
          ? AnimatedNotchBottomBar(
        /// Provide NotchBottomBarController
        notchBottomBarController: _controller,
        color: Colors.red,
        showLabel: true,
        notchColor: Colors.red,
        kBottomRadius: 28.0,
        kIconSize: 24.0,

        /// restart app if you change removeMargins
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

  Widget _buildLoadingWidget() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300] ?? Colors.grey,
        highlightColor: Colors.grey[100] ?? Colors.white,
        child: ListView.builder(
          itemCount: 10,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[50]!),
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white,
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
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  color: Colors.white,
                  elevation: 0.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 40.0,
                              width: 40.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: Colors.grey, width: 1.0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 100.0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmployeeDetailsWidget() {
    return Column(
      children: [
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
              // Adjust the padding as needed
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