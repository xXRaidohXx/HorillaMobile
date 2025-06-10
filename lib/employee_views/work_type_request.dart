import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class WorkTypeRequestPage extends StatefulWidget {
  final String selectedEmployerId;
  final String selectedEmployeeFullName;

  const WorkTypeRequestPage(
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

class _WorkTypeRequestPageState extends State<WorkTypeRequestPage> {
  final ScrollController _scrollController = ScrollController();
  final _pageController = PageController(initialPage: 0);
  final _controller = NotchBottomBarController(index: -1);
  final TextEditingController _typeAheadEditController =
  TextEditingController();
  final TextEditingController _typeAheadEditWorkTypeController =
  TextEditingController();
  final TextEditingController _typeCreateAheadController =
  TextEditingController();
  final TextEditingController _typeAheadCreateWorkTypeController =
  TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  TextEditingController createRequestedDateController = TextEditingController();
  TextEditingController createRequestedTillController = TextEditingController();
  TextEditingController descriptionSelect = TextEditingController();
  TextEditingController yearController = TextEditingController();
  TextEditingController workedHoursController = TextEditingController();
  TextEditingController pendingHoursController = TextEditingController();
  TextEditingController overtimeHoursController = TextEditingController();
  List<Map<String, dynamic>> requests = [];
  List<dynamic> filteredRecords = [];
  List employeeIdValue = [''];
  List<String> workTypeItems = [];
  List<Map<String, dynamic>> allEmployeeList = [];
  bool permissionCheck = false;
  bool approveRejectCheck = false;
  bool _validateWorkType = false;
  bool _validateRequestedDate = false;
  bool _validateRequestedTill = false;
  bool _validateDescription = false;
  bool isLoading = true;
  bool isAction = true;
  bool hasNoRecords = false;
  bool isSaveClick = true;
  int requestsCount = 0;
  int maxCount = 5;
  int currentPage = 1;
  int? selectedEmployerId;
  String searchText = '';
  String? _errorMessage;
  String? selectedEmployee;
  String? createEmployee;
  String? selectedEmployeeId;
  String employeeId = '';
  String selectedEmployeeFullName = '';
  String? editEmployee;
  String? selectedEditEmployeeId;
  String? selectedCreateEmployeeId;
  String? createWorkType;
  String? selectedCreateWorkType;
  String? editWorkType;
  String? selectedEditWorkType;
  late Map<String, dynamic> arguments;
  late String baseUrl = '';
  var employeeItems = [''];
  var selectedMonth;
  Map<String, dynamic> employeeDetails = {};
  Map<String, String> employeeIdMap = {};
  Map<String, String> workTypeIdMap = {};
  bool isCreateButtonVisible = true;


  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    prefetchData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      permissionChecks();
      approveRejectChecks();
      getWorkTypeRequest();
      getEmployeeDetails();
      getEmployees();
      getWorkType();
      getBaseUrl();
      _simulateLoading();
      createVisibility();
    });
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(seconds: 5));
    setState(() {});
  }

  Future<void> createVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    var employeeId = prefs.getInt("employee_id");
    if (employeeId == int.parse(widget.selectedEmployerId)) {
      setState(() {
        isCreateButtonVisible = true;
      });
    }
    else {
      setState(() {
        isCreateButtonVisible = false;
      });
    }
  }

  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
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
  void approveRejectChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    var uri =
    Uri.parse('$typedServerUrl/api/base/worktype-request-approve-permission-check/$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    print('ttttttttttttttttt');
    print(response.statusCode);
    print(response.body);
    if (response.statusCode == 200) {
      approveRejectCheck = true;
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
      getWorkTypeRequest();
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

  Future<void> getWorkTypeRequest() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    employeeId = widget.selectedEmployerId;
    setState(() {
      hasNoRecords = false;
    });
    if (currentPage != 0) {
      var uri = Uri.parse(
          '$typedServerUrl/api/base/individual-worktype-request?employee_id=$employeeId&page=$currentPage&search=$searchText');
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
          '$typedServerUrl/api/base/worktype-requests?employee_id=$employeeId&search=$searchText');
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
  Future<void> getEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    var uri = Uri.parse(
        '$typedServerUrl/api/employee/employee-selector?employee_id=$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    print('Request URI: $uri');
    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      setState(() {
        // Clear previous data
        employeeItems.clear();
        employeeIdMap.clear();

        // Decode response
        var employees = jsonDecode(response.body)['results'];

        // Filter to display only the current logged-in user's details
        var currentUserDetails = employees.firstWhere(
              (employee) => employee['id'] == employeeId,
          orElse: () => null, // Handle case if no match is found
        );

        if (currentUserDetails != null) {
          final firstName = currentUserDetails['employee_first_name'] ?? '';
          final lastName = currentUserDetails['employee_last_name'] ?? '';
          final fullName = (firstName.isEmpty ? '' : firstName) +
              (lastName.isEmpty ? '' : ' $lastName');
          String employeeIdStr = "${currentUserDetails['id']}";

          // Add current user's details
          employeeItems.add(fullName);
          employeeIdMap[fullName] = employeeIdStr;

          // Set allEmployeeList with only the logged-in user details
          allEmployeeList = [currentUserDetails];
        }
      });
    }
  }

  // Future<void> getEmployees() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   var token = prefs.getString("token");
  //   var typedServerUrl = prefs.getString("typed_url");
  //   var employeeId = prefs.getInt("employee_id");
  //     var uri = Uri.parse(
  //         '$typedServerUrl/api/employee/employee-selector?employee_id=$employeeId');
  //     var response = await http.get(uri, headers: {
  //       "Content-Type": "application/json",
  //       "Authorization": "Bearer $token",
  //     });
  //     print('eeeeeeeeeeeeeeeeeeeeeeeee $uri');
  //     print(response.statusCode);
  //     print(response.body);
  //     if (response.statusCode == 200) {
  //       setState(() {
  //         for (var employee in jsonDecode(response.body)['results']) {
  //           final firstName = employee['employee_first_name'] ?? '';
  //           final lastName = employee['employee_last_name'] ?? '';
  //           final fullName = (firstName.isEmpty ? '' : firstName) +
  //               (lastName.isEmpty ? '' : ' $lastName');
  //           String employeeId = "${employee['id']}";
  //           employeeItems.add(fullName);
  //           employeeIdMap[fullName] = employeeId;
  //         }
  //         allEmployeeList = List<Map<String, dynamic>>.from(
  //           jsonDecode(response.body)['results'],
  //         );
  //       });
  //     }
  //
  // }

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
        getWorkTypeRequest();
        selectedMonth = 'Select Month';
      });
    }
  }

  Future<void> rejectWorkTypeRequest(
      Map<String, dynamic> updatedDetails) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    int requestId = updatedDetails['id'];
    var uri = Uri.parse(
        '$typedServerUrl/api/base/worktype-requests-cancel/$requestId/');
    var response = await http.put(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() async {
        isSaveClick = false;
        await getWorkTypeRequest();
      });
    } else {
      isSaveClick = true;
    }
  }

  Future<void> approveWorkTypeRequest(
      Map<String, dynamic> updatedDetails) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    int requestId = updatedDetails['id'];
    var uri = Uri.parse(
        '$typedServerUrl/api/base/worktype-requests-approve/$requestId/');
    var response = await http.put(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() async {
        isSaveClick = false;
        await getWorkTypeRequest();
      });
    } else {
      isSaveClick = true;
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

  Future<void> getWorkType() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/base/worktypes');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      List<dynamic> workTypesData = jsonDecode(response.body);
      setState(() {
        for (var rec in workTypesData) {
          final workType = rec['work_type'] ?? '';
          String workTypeId = "${rec['id']}";
          workTypeItems.add(workType);
          workTypeIdMap[workType] = workTypeId;
        }
      });
    }
  }

  void showApproveAnimation() {
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
                      "WorkType Approved Successfully",
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

  void showUpdateAnimation() {
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
                      "WorkType Updated Successfully",
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

  void showRejectAnimation() {
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
                      "WorkType Rejected Successfully",
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
      });
    }
  }

  Future<void> updateWorkTypeRequest(
      Map<String, dynamic> updatedDetails) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    String workTypeRequestId = updatedDetails['id'].toString();
    var uri = Uri.parse(
        '$typedServerUrl/api/base/worktype-requests/$workTypeRequestId/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "employee_id": updatedDetails['employee_id'],
        "requested_date": updatedDetails['requested_date'],
        "requested_till": updatedDetails['requested_till'],
        "description": updatedDetails['description'],
        "work_type_id": updatedDetails['work_type_id'],
      }),
    );
    if (response.statusCode == 200) {
      isSaveClick = false;
      _errorMessage = null;
      getWorkTypeRequest();
      setState(() {});
    } else {
      isSaveClick = true;
      var responseData = jsonDecode(response.body);
      if (responseData.containsKey('non_field_errors')) {
        _errorMessage = responseData['non_field_errors'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('requested_date')) {
        _errorMessage = responseData['requested_date'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('requested_till')) {
        _errorMessage = responseData['requested_till'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('description')) {
        _errorMessage = responseData['description'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('work_type_id')) {
        _errorMessage = responseData['work_type_id'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('employee_id')) {
        _errorMessage = responseData['employee_id'].join('\n');
        setState(() {});
      }
      setState(() {});
    }
  }

  Future<void> createWorkTypeRequest(
      Map<String, dynamic> createdDetails) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/base/worktype-requests/');
    var response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "employee_id": createdDetails['employee_id'],
        "requested_date": createdDetails['requested_date'],
        "requested_till": createdDetails['requested_till'],
        "description": createdDetails['description'],
        "work_type_id": createdDetails['work_type_id'],
      }),
    );
    if (response.statusCode == 201) {
      isSaveClick = false;
      _errorMessage = null;
      getWorkTypeRequest();
      setState(() {});
    } else {
      isSaveClick = true;
      var responseData = jsonDecode(response.body);
      if (responseData.containsKey('non_field_errors')) {
        _errorMessage = responseData['non_field_errors'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('requested_date')) {
        _errorMessage = responseData['requested_date'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('requested_till')) {
        _errorMessage = responseData['requested_till'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('description')) {
        _errorMessage = responseData['description'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('work_type_id')) {
        _errorMessage = responseData['work_type_id'].join('\n');
        setState(() {});
      }
      if (responseData.containsKey('employee_id')) {
        _errorMessage = responseData['employee_id'].join('\n');
        setState(() {});
      }
      setState(() {});
    }
  }

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
                    Image.asset(imagePath),
                    const SizedBox(height: 16),
                    const Text(
                      "WorkType Created Successfully",
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
                    Image.asset(imagePath),
                    const SizedBox(height: 16),
                    const Text(
                      "WorkType Deleted Successfully",
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
                    Image.asset(imagePath),
                    const SizedBox(height: 16),
                    const Text(
                      "WorkType Updated Successfully",
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

  Future<void> deleteWorkTypeRequest(int requestId) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
    Uri.parse('$typedServerUrl/api/base/worktype-requests/$requestId/');
    var response = await http.delete(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        isSaveClick = false;
        getWorkTypeRequest();
      });
    } else {
      isSaveClick = false;
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

  void _showEditWorkTypeRequest(
      BuildContext context, Map<String, dynamic> record) {
    TextEditingController editRequestedDateController =
    TextEditingController(text: record['requested_date'] ?? '');
    TextEditingController editRequestedTillController =
    TextEditingController(text: record['requested_till'] ?? '');
    TextEditingController descriptionSelect =
    TextEditingController(text: record['description'] ?? '');
    _typeAheadEditController.text = (record['employee_first_name'] ?? "") +
        " " +
        (record['employee_last_name'] ?? "");
    _typeAheadEditWorkTypeController.text = record['work_type_name'] ?? "";
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
                        "Edit WorkType",
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                labelStyle: TextStyle(color: Colors.grey[350]),
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
                                editEmployee = suggestion;
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
                            'Requesting Work Type',
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TypeAheadField<String>(
                            textFieldConfiguration: TextFieldConfiguration(
                              controller: _typeAheadEditWorkTypeController,
                              decoration: InputDecoration(
                                labelText: 'Search Work Type',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                labelStyle: TextStyle(color: Colors.grey[350]),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            suggestionsCallback: (pattern) {
                              return workTypeItems
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
                                editWorkType = suggestion;
                                selectedEditWorkType =
                                workTypeIdMap[suggestion];
                                _validateWorkType = false;
                              });
                              _typeAheadEditWorkTypeController.text =
                                  suggestion;
                            },
                            noItemsFoundBuilder: (context) => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'No WorkTypes Found',
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
                            "Requested Date",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            readOnly: true,
                            controller: editRequestedDateController,
                            onTap: () async {
                              final selectedDate = await showCustomDatePicker(
                                  context, DateTime.now());
                              if (selectedDate != null) {
                                DateTime parsedDate = DateFormat('yyyy-MM-dd')
                                    .parse(selectedDate);
                                setState(() {
                                  editRequestedDateController.text =
                                      DateFormat('yyyy-MM-dd')
                                          .format(parsedDate);
                                  _validateRequestedDate = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Choose a Requested Date',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              errorText: _validateRequestedDate
                                  ? 'Please Choose a Requested date'
                                  : null,
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            "Requested Till",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            readOnly: true,
                            controller: editRequestedTillController,
                            onTap: () async {
                              final selectedDate = await showCustomDatePicker(
                                  context, DateTime.now());
                              if (selectedDate != null) {
                                DateTime parsedDate = DateFormat('yyyy-MM-dd')
                                    .parse(selectedDate);
                                setState(() {
                                  editRequestedTillController.text =
                                      DateFormat('yyyy-MM-dd')
                                          .format(parsedDate);
                                  _validateRequestedTill = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Choose a Requested Till',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              errorText: _validateRequestedTill
                                  ? 'Please Choose a Requested Till'
                                  : null,
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            'Description',
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            controller: descriptionSelect,
                            decoration: InputDecoration(
                              labelText: "Description",
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              border: const OutlineInputBorder(),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                              errorText: _validateDescription
                                  ? 'Description cannot be empty'
                                  : null,
                            ),
                            onChanged: (newValue) {
                              descriptionSelect.text = newValue;
                              _validateDescription = newValue.isEmpty;
                            },
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
                            if (descriptionSelect.text.isEmpty) {
                              setState(() {
                                isSaveClick = true;
                                _validateDescription = true;
                                Navigator.of(context).pop(true);
                                _showEditWorkTypeRequest(context, record);
                              });
                            } else {
                              Map<String, dynamic> updatedDetails = {
                                'id': record['id'],
                                "employee_id": selectedEditEmployeeId ??
                                    record['employee_id'].toString(),
                                "work_type_id": selectedEditWorkType ??
                                    record['work_type_id'].toString(),
                                "requested_date":
                                editRequestedTillController.text,
                                "requested_till":
                                editRequestedTillController.text,
                                "description": descriptionSelect.text,
                              };
                              await updateWorkTypeRequest(updatedDetails);
                              setState(() {
                                isAction = false;
                              });
                              if (_errorMessage == null ||
                                  _errorMessage!.isEmpty) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => WorkTypeRequestPage(
                                          selectedEmployerId:
                                          widget.selectedEmployerId,
                                          selectedEmployeeFullName:
                                          widget.selectedEmployeeFullName)),
                                );
                                showUpdateAnimation();
                              } else {
                                Navigator.of(context).pop(true);
                                _showEditWorkTypeRequest(context, record);
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

  void _showCreateWorkTypeRequest(
      BuildContext context, selectedEmployeeFullName, selectedEmployerId) {
    _typeCreateAheadController.text = widget.selectedEmployeeFullName;
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
                        "Add WorkType",
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
                              controller: _typeCreateAheadController,
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
                                _typeCreateAheadController.text = suggestion;
                                createEmployee = suggestion;
                                selectedCreateEmployeeId =
                                employeeIdMap[suggestion];
                              });
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
                            'Requesting Work Type',
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TypeAheadField<String>(
                            textFieldConfiguration: TextFieldConfiguration(
                              controller: _typeAheadCreateWorkTypeController,
                              decoration: InputDecoration(
                                labelText: 'Search Requesting Work Type',
                                labelStyle: TextStyle(color: Colors.grey[350]),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                errorText: _validateWorkType
                                    ? 'Please Select a Requesting Work Type'
                                    : null,
                              ),
                            ),
                            suggestionsCallback: (pattern) {
                              return workTypeItems
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
                                _typeAheadCreateWorkTypeController.text =
                                    suggestion;
                                createWorkType = suggestion;
                                selectedCreateWorkType =
                                workTypeIdMap[suggestion];
                                _validateWorkType = false;
                              });
                            },
                            noItemsFoundBuilder: (context) => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'No Requesting WorkTypes Found',
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
                            "Requested Date",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            readOnly: true,
                            controller: createRequestedDateController,
                            onTap: () async {
                              final selectedDate = await showCustomDatePicker(
                                  context, DateTime.now());
                              if (selectedDate != null) {
                                DateTime parsedDate = DateFormat('yyyy-MM-dd')
                                    .parse(selectedDate);
                                setState(() {
                                  createRequestedDateController.text =
                                      DateFormat('yyyy-MM-dd')
                                          .format(parsedDate);
                                  _validateRequestedDate = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Choose Requested date',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                              errorText: _validateRequestedDate
                                  ? 'Please select a Requested date'
                                  : null,
                              hintText: 'Select a Requested Date',
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            "Requested Till",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            readOnly: true,
                            controller: createRequestedTillController,
                            onTap: () async {
                              final selectedDate = await showCustomDatePicker(
                                  context, DateTime.now());
                              if (selectedDate != null) {
                                DateTime parsedDate = DateFormat('yyyy-MM-dd')
                                    .parse(selectedDate);
                                setState(() {
                                  createRequestedTillController.text =
                                      DateFormat('yyyy-MM-dd')
                                          .format(parsedDate);
                                  _validateRequestedTill = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Choose Requested Till',
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                              errorText: _validateRequestedTill
                                  ? 'Please select a Requested Till'
                                  : null,
                              hintText: 'Select a Requested Till',
                            ),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.03),
                          const Text(
                            'Description',
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(
                              height:
                              MediaQuery.of(context).size.height * 0.01),
                          TextField(
                            controller: descriptionSelect,
                            decoration: InputDecoration(
                              labelText: "Description",
                              labelStyle: TextStyle(color: Colors.grey[350]),
                              border: const OutlineInputBorder(),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10.0),
                              errorText: _validateDescription
                                  ? 'Description cannot be empty'
                                  : null,
                            ),
                            onChanged: (newValue) {
                              descriptionSelect.text = newValue;
                              _validateDescription = newValue.isEmpty;
                            },
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
                            });
                            if (_typeAheadCreateWorkTypeController
                                .text.isEmpty) {
                              setState(() {
                                isSaveClick = true;
                                _validateWorkType = true;
                                _validateRequestedDate = false;
                                _validateRequestedTill = false;
                                _validateDescription = false;
                                Navigator.of(context).pop(true);
                                _showCreateWorkTypeRequest(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
                              });
                            } else if (createRequestedDateController
                                .text.isEmpty) {
                              setState(() {
                                isSaveClick = true;
                                _validateWorkType = false;
                                _validateRequestedDate = true;
                                _validateRequestedTill = false;
                                _validateDescription = false;
                                Navigator.of(context).pop(true);
                                _showCreateWorkTypeRequest(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
                              });
                            } else if (createRequestedTillController
                                .text.isEmpty) {
                              setState(() {
                                isSaveClick = true;
                                _validateWorkType = false;
                                _validateRequestedDate = false;
                                _validateRequestedTill = true;
                                _validateDescription = false;
                                Navigator.of(context).pop(true);
                                _showCreateWorkTypeRequest(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
                              });
                            } else if (descriptionSelect.text.isEmpty) {
                              setState(() {
                                isSaveClick = true;
                                _validateWorkType = false;
                                _validateRequestedDate = false;
                                _validateRequestedTill = false;
                                _validateDescription = true;
                                Navigator.of(context).pop(true);
                                _showCreateWorkTypeRequest(
                                    context,
                                    selectedEmployeeFullName,
                                    selectedEmployerId);
                              });
                            } else {
                              isAction = true;
                              Map<String, dynamic> createdDetails = {
                                "employee_id": selectedCreateEmployeeId ??
                                    widget.selectedEmployerId,
                                "work_type_id": selectedCreateWorkType,
                                "requested_date":
                                createRequestedDateController.text,
                                "requested_till":
                                createRequestedTillController.text,
                                "description": descriptionSelect.text,
                              };
                              await createWorkTypeRequest(createdDetails);
                              setState(() {
                                isAction = false;
                              });
                              if (_errorMessage == null ||
                                  _errorMessage!.isEmpty) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => WorkTypeRequestPage(
                                          selectedEmployerId:
                                          widget.selectedEmployerId,
                                          selectedEmployeeFullName:
                                          widget.selectedEmployeeFullName)),
                                );
                                showCreateAnimation();
                              } else {
                                Navigator.of(context).pop(true);
                                _showCreateWorkTypeRequest(
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
                                  employeeDetails['employee_first_name'] +
                                      " " +
                                      employeeDetails[
                                      'employee_last_name'] ??
                                      '',
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
                          height: MediaQuery.of(context).size.height * 0.005),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Work Type',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Flexible(
                            child: Text(
                              '${record['work_type_name'] ?? 'None'}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Previous work type',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Flexible(
                            child: Text(
                              '${record['previous_work_type_name'] ?? 'None'}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Requested date',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Flexible(
                            child: Text(
                              '${record['requested_date'] ?? 'None'}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Requested till',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Flexible(
                            child: Text(
                              '${record['requested_till'] ?? 'None'}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Is permanent work type',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Flexible(
                            child: Text(
                              record['is_permanent_work_type'] ? 'Yes' : 'No',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.01),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (!record['canceled'] && !record['approved'])
                      Row(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isSaveClick = true;
                                  showDialog(
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
                                          height: MediaQuery.of(context)
                                              .size
                                              .height *
                                              0.1,
                                          child: const Center(
                                            child: Text(
                                              "Are you sure you want to Reject this WorkType Request?",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 17),
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
                                                  setState(() {
                                                    rejectWorkTypeRequest(
                                                        record);
                                                    Navigator.pop(context);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              WorkTypeRequestPage(
                                                                  selectedEmployerId:
                                                                  widget
                                                                      .selectedEmployerId,
                                                                  selectedEmployeeFullName:
                                                                  widget
                                                                      .selectedEmployeeFullName)),
                                                    );
                                                    showRejectAnimation();
                                                  });
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
                                              child: const Text("Continue",
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                backgroundColor: Colors.red,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Reject',
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  showDialog(
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
                                          height: MediaQuery.of(context)
                                              .size
                                              .height *
                                              0.1,
                                          child: const Center(
                                            child: Text(
                                              "Are you sure you want to Approve this WorkType Request?",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 17),
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
                                                  approveWorkTypeRequest(
                                                      record);
                                                  Navigator.pop(context);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            WorkTypeRequestPage(
                                                                selectedEmployerId:
                                                                widget
                                                                    .selectedEmployerId,
                                                                selectedEmployeeFullName:
                                                                widget
                                                                    .selectedEmployeeFullName)),
                                                  );
                                                  showApproveAnimation();
                                                }
                                              },
                                              style: ButtonStyle(
                                                backgroundColor:
                                                MaterialStateProperty.all<
                                                    Color>(Colors.green),
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
                                              child: const Text("Continue",
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                  MediaQuery.of(context).size.width * 0.05,
                                  vertical:
                                  MediaQuery.of(context).size.height * 0.01,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Approve',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!record['canceled'] && record['approved'])
                      Row(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isSaveClick = true;
                                  showDialog(
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
                                          height: MediaQuery.of(context)
                                              .size
                                              .height *
                                              0.1,
                                          child: const Center(
                                            child: Text(
                                              "Are you sure you want to Reject this WorkType Request?",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 17),
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                if (isSaveClick == true) {
                                                  setState(() {
                                                    isSaveClick = false;
                                                    rejectWorkTypeRequest(
                                                        record);

                                                    Navigator.pop(context);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              WorkTypeRequestPage(
                                                                  selectedEmployerId:
                                                                  widget
                                                                      .selectedEmployerId,
                                                                  selectedEmployeeFullName:
                                                                  widget
                                                                      .selectedEmployeeFullName)),
                                                    );
                                                    showRejectAnimation();
                                                  });
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
                                              child: const Text("Continue",
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: const Flexible(
                                child: Text(
                                  'Reject',
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                backgroundColor: Colors.green.withOpacity(0.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Approve',
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (record['canceled'] && !record['approved'])
                      Row(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                backgroundColor: Colors.red.withOpacity(0.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Reject',
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                backgroundColor: Colors.green.withOpacity(0.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Approve',
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.486,
          height: MediaQuery.of(context).size.height * 0.28,
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
                              record['employee_first_name'] +
                                  ' ' +
                                  (record['employee_last_name'] ?? ''),
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
                      if (!record['canceled'] && !record['approved'])
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
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
                                      _errorMessage = null;
                                      isAction = false;
                                    });
                                    _showEditWorkTypeRequest(context, record);
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
                                padding:
                                const EdgeInsets.symmetric(vertical: 0.0),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 18.0,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    setState(() {
                                      isSaveClick = true;
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            backgroundColor: Colors.white,
                                            title: Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
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
                                                  "Are you sure you want to delete this work type request?",
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
                                                      var workTypeRequestId =
                                                      record['id'];
                                                      await deleteWorkTypeRequest(
                                                          workTypeRequestId);
                                                      Navigator.pop(context);
                                                      setState(() {
                                                        requests.removeWhere(
                                                                (record) =>
                                                            record['id'] ==
                                                                workTypeRequestId);
                                                      });

                                                      // Show delete animation
                                                      showDeleteAnimation();
                                                    }
                                                  },
                                                  style: ButtonStyle(
                                                    backgroundColor:
                                                    MaterialStateProperty
                                                        .all<Color>(
                                                        Colors.red),
                                                    shape: MaterialStateProperty
                                                        .all<
                                                        RoundedRectangleBorder>(
                                                      RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(8.0),
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
                                    });
                                  },
                                ),
                              ),
                            ),
                            SizedBox(
                                width:
                                MediaQuery.of(context).size.width * 0.005),
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
                    child: ListView(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Requested Work Type',
                                style: TextStyle(color: Colors.grey.shade700)),
                            Flexible(
                              child: Text(
                                '${record['work_type_name'] ?? 'None'}',
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Previous/Current Work Type',
                                style: TextStyle(color: Colors.grey.shade700)),
                            Flexible(
                              child: Text(
                                '${record['previous_work_type_name'] ?? 'None'}',
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Requested Date',
                                style: TextStyle(color: Colors.grey.shade700)),
                            Flexible(
                              child: Text(
                                '${record['requested_date'] ?? 'None'}',
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Requested Till',
                                style: TextStyle(color: Colors.grey.shade700)),
                            Flexible(
                              child: Text(
                                '${record['requested_till'] ?? 'None'}',
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (!record['canceled'] && !record['approved'])
                                Row(
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            isSaveClick = true;
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "Confirmation",
                                                        style: TextStyle(
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            color:
                                                            Colors.black),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.close),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  content: SizedBox(
                                                    height:
                                                    MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                        0.1,
                                                    child: const Center(
                                                      child: Text(
                                                        "Are you sure you want to Reject this WorkType Request?",
                                                        style: TextStyle(
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            color: Colors.black,
                                                            fontSize: 17),
                                                      ),
                                                    ),
                                                  ),
                                                  actions: [
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () {
                                                          if (isSaveClick ==
                                                              true) {
                                                            setState(() {
                                                              isSaveClick =
                                                              false;
                                                              rejectWorkTypeRequest(
                                                                  record);
                                                              Navigator.pop(
                                                                  context);
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder: (context) => WorkTypeRequestPage(
                                                                        selectedEmployerId:
                                                                        widget
                                                                            .selectedEmployerId,
                                                                        selectedEmployeeFullName:
                                                                        widget.selectedEmployeeFullName)),
                                                              );
                                                              showRejectAnimation();
                                                            });
                                                          }
                                                        },
                                                        style: ButtonStyle(
                                                          backgroundColor:
                                                          MaterialStateProperty
                                                              .all<Color>(
                                                              Colors
                                                                  .red),
                                                          shape: MaterialStateProperty
                                                              .all<
                                                              RoundedRectangleBorder>(
                                                            RoundedRectangleBorder(
                                                              borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                  8.0),
                                                            ),
                                                          ),
                                                        ),
                                                        child: const Text(
                                                            "Continue",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8.0),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Flexible(
                                              child: Text(
                                                'Reject',
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          setState(() {
                                            isSaveClick = true;
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "Confirmation",
                                                        style: TextStyle(
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            color:
                                                            Colors.black),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.close),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  content: SizedBox(
                                                    height:
                                                    MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                        0.1,
                                                    child: const Center(
                                                      child: Text(
                                                        "Are you sure you want to Approve this WorkType Request?",
                                                        style: TextStyle(
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            color: Colors.black,
                                                            fontSize: 17),
                                                      ),
                                                    ),
                                                  ),
                                                  actions: [
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () async {
                                                          if (isSaveClick ==
                                                              true) {
                                                            setState(() {
                                                              isSaveClick =
                                                              false;
                                                              approveWorkTypeRequest(
                                                                  record);
                                                              Navigator.pop(
                                                                  context);
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder: (context) => WorkTypeRequestPage(
                                                                        selectedEmployerId:
                                                                        widget
                                                                            .selectedEmployerId,
                                                                        selectedEmployeeFullName:
                                                                        widget.selectedEmployeeFullName)),
                                                              );
                                                              showApproveAnimation();
                                                            });
                                                          }
                                                        },
                                                        style: ButtonStyle(
                                                          backgroundColor:
                                                          MaterialStateProperty
                                                              .all<Color>(
                                                              Colors
                                                                  .green),
                                                          shape: MaterialStateProperty
                                                              .all<
                                                              RoundedRectangleBorder>(
                                                            RoundedRectangleBorder(
                                                              borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                  8.0),
                                                            ),
                                                          ),
                                                        ),
                                                        child: const Text(
                                                            "Continue",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8.0),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            const Flexible(
                                              child: Flexible(
                                                child: Text(
                                                  'Approve',
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (!record['canceled'] && record['approved'])
                                Row(
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            isSaveClick = true;
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "Confirmation",
                                                        style: TextStyle(
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            color:
                                                            Colors.black),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.close),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  content: SizedBox(
                                                    height:
                                                    MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                        0.1,
                                                    child: const Center(
                                                      child: Text(
                                                        "Are you sure you want to Reject this WorkType Request?",
                                                        style: TextStyle(
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            color: Colors.black,
                                                            fontSize: 17),
                                                      ),
                                                    ),
                                                  ),
                                                  actions: [
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () async {
                                                          if (isSaveClick ==
                                                              true) {
                                                            setState(() {
                                                              isSaveClick =
                                                              false;
                                                              rejectWorkTypeRequest(
                                                                  record);
                                                              Navigator.pop(
                                                                  context);
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder: (context) => WorkTypeRequestPage(
                                                                        selectedEmployerId:
                                                                        widget
                                                                            .selectedEmployerId,
                                                                        selectedEmployeeFullName:
                                                                        widget.selectedEmployeeFullName)),
                                                              );
                                                              showRejectAnimation();
                                                            });
                                                          }
                                                        },
                                                        style: ButtonStyle(
                                                          backgroundColor:
                                                          MaterialStateProperty
                                                              .all<Color>(
                                                              Colors
                                                                  .red),
                                                          shape: MaterialStateProperty
                                                              .all<
                                                              RoundedRectangleBorder>(
                                                            RoundedRectangleBorder(
                                                              borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                  8.0),
                                                            ),
                                                          ),
                                                        ),
                                                        child: const Text(
                                                            "Continue",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8.0),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Reject',
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      child: ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8.0),
                                          ),
                                          backgroundColor:
                                          Colors.green.withOpacity(0.5),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Approve',
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (record['canceled'] && !record['approved'])
                                Row(
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      child: ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8.0),
                                          ),
                                          backgroundColor:
                                          Colors.red.withOpacity(0.5),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Reject',
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      child: ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8.0),
                                          ),
                                          backgroundColor:
                                          Colors.green.withOpacity(0.5),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Approve',
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
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
        title: const Text('Work Type Request',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // if (permissionCheck)
                Container(
                  alignment: Alignment.centerRight,
                  child: Visibility(
                    visible: isCreateButtonVisible,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _typeAheadCreateWorkTypeController.clear();
                          createRequestedDateController.clear();
                          createRequestedTillController.clear();
                          descriptionSelect.clear();
                          _validateWorkType = false;
                          _validateRequestedDate = false;
                          _validateRequestedTill = false;
                          _validateDescription = false;
                          _errorMessage = null;
                          isAction = false;
                        });
                        _showCreateWorkTypeRequest(
                            context, selectedEmployeeFullName, createEmployee);
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
                ),
                // ),
              ],
            ),
          ),
        ],
      ),
      body: isLoading ? _buildLoadingWidget() : _buildEmployeeDetailsWidget(),
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
          itemCount: 3,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.486,
                height: MediaQuery.of(context).size.height * 0.28,
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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