import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:horilla/checkin_checkout/checkin_checkout_views/setup_imageface.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../res/consts/app_colors.dart'; // Adjust path as needed
import '../controllers/face_detection_controller.dart'; // Adjust path as needed

class FaceScanner extends StatefulWidget {
  final Map<String, dynamic> userDetails;
  final String? attendanceState; // CHECKED_IN, CHECKED_OUT, or NOT_CHECKED_IN
  final Position? userLocation;

  const FaceScanner({
    Key? key,
    required this.userDetails,
    required this.attendanceState,
    required this.userLocation,
  }) : super(key: key);

  @override
  _FaceScannerState createState() => _FaceScannerState();
}

class _FaceScannerState extends State<FaceScanner> with SingleTickerProviderStateMixin {
  late FaceScannerController _controller;
  bool _isCameraInitialized = false;
  bool _isComparing = false;
  String? _employeeImageBase64;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoadingEmployeeImage = true;
  bool _isDetectionPaused = false; // Flag to control face detection loop

  @override
  void initState() {
    super.initState();
    _controller = FaceScannerController();
    _setupAnimations();
    _initializeController();
  }

  Future<void> _initializeController() async {
    final prefs = await SharedPreferences.getInstance();
    var face_detection_image = prefs.getString("face_detection_image");
    try {
      await _controller.initializeCamera();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      await _fetchBiometricImage();
      setState(() {
        _isLoadingEmployeeImage = false;
      });
      if (face_detection_image != 'null') {
        _startRealTimeFaceDetection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initialization failed: $e')),
        );
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  // Fetching biometric image and convert into base64
  Future<void> _fetchBiometricImage() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var face_detection_image = prefs.getString("face_detection_image");
    if (face_detection_image != 'null') {
      String? imagePathOrBase64 = face_detection_image;
      if (imagePathOrBase64 != null && imagePathOrBase64.isNotEmpty) {
        if (imagePathOrBase64.startsWith('data:image') || imagePathOrBase64.contains(';base64,')) {
          setState(() {
            _employeeImageBase64 = imagePathOrBase64.split(',').last;
          });
        } else if (imagePathOrBase64.startsWith('/')) {
          var imageUri = Uri.parse('$typedServerUrl$imagePathOrBase64');
          var imageResponse = await http.get(imageUri, headers: {
            "Authorization": "Bearer $token",
          });
          if (imageResponse.statusCode == 200) {
            setState(() {
              _employeeImageBase64 = base64Encode(imageResponse.bodyBytes);
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to fetch image from path.')),
            );
          }
        } else {
          setState(() {
            _employeeImageBase64 = imagePathOrBase64;
          });
        }
      } else {
        showImageAlertDialog(context);
      }
    }
    else {
      showImageAlertDialog(context);
    }
  }

  void showImageAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Employee Image Not Set"),
          content: Text("Setup a New FaceImage?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pop(); // Go back
              },
              child: Text("No"),
            ),
            TextButton(
              onPressed: () async {
                final cameras = await availableCameras();
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => CameraSetupPage(cameras: cameras,)),
                );
              },
              child: Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  // Detecting face on real time continuosly and compare face matching
  void _startRealTimeFaceDetection() async {
    while (_isCameraInitialized && !_isDetectionPaused) {
      final image = await _controller.captureImage();
      if (image != null && mounted && _employeeImageBase64 != null) {
        setState(() {
          _isComparing = true;
        });

        try {
          bool isMatched = await _controller.compareFaces(
            File(image.path),
            _employeeImageBase64!,
          );

          if (isMatched) {
            _handleComparisonResult(true);
            break; // Exit the loop if a match is found
          } else {
            setState(() {
              _isDetectionPaused = true; // Pause detection
            });
            await _showIncorrectFaceAlert();
            setState(() {
              _isDetectionPaused = false; // Resume detection after alert
            });
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Face comparison failed: $e')),
          );
        } finally {
          setState(() {
            _isComparing = false;
          });
        }
      }
      await Future.delayed(const Duration(milliseconds: 500)); // Delay between captures
    }
  }

  Future<void> _showIncorrectFaceAlert() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Incorrect Face"),
          content: const Text("The detected face does not match. Please try again."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleComparisonResult(bool isMatched) async {
    if (!isMatched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face verification failed. Please try again.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var geo_fencing = prefs.getBool("geo_fencing");

    if (geo_fencing == true) {
      if (widget.userLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location unavailable. Cannot proceed.')),
        );
        return;
      }
    }



    if (widget.attendanceState == 'NOT_CHECKED_IN') {
      // Check-in
      var uri = Uri.parse('$typedServerUrl/api/attendance/clock-in/');
      if (geo_fencing == true) {
        var response_geofence = await http.post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "latitude": widget.userLocation!.latitude,
            "longitude": widget.userLocation!.longitude,
          }),
        );

        if (response_geofence.statusCode == 200) {
          Navigator.pop(context, {'checkedIn': true});
        } else {
          String errorMessage = getErrorMessage(response_geofence.body);
          showCheckInFailedDialog(context, errorMessage);
        }
      }
      else {
        var response = await http.post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
          }),
        );

        if (response.statusCode == 200) {
          Navigator.pop(context, {'checkedIn': true});
        } else {
          String errorMessage = getErrorMessage(response.body);
          showCheckInFailedDialog(context, errorMessage);
        }
      }
    } else if (widget.attendanceState == 'CHECKED_IN') {
      // Check-out
      var uri = Uri.parse('$typedServerUrl/api/attendance/clock-out/');
      if (geo_fencing == true) {
        var response_geofence = await http.post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "latitude": widget.userLocation!.latitude,
            "longitude": widget.userLocation!.longitude,
          }),
        );
        if (response_geofence.statusCode == 200) {
          Navigator.pop(context, {'checkedOut': true});
        } else {
          String errorMessage = getErrorMessage(response_geofence.body);
          showCheckInFailedDialog(context, errorMessage);
        }
      }
      else {
        var response = await http.post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
          }),
        );
        if (response.statusCode == 200) {
          Navigator.pop(context, {'checkedOut': true});
        } else {
          String errorMessage = getErrorMessage(response.body);
          showCheckInFailedDialog(context, errorMessage);
        }
      }
    }
  }

  String getErrorMessage(String responseBody) {
    try {
      final Map<String, dynamic> decoded = json.decode(responseBody);
      return decoded['message'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Error parsing server response';
    }
  }

  void showCheckInFailedDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Check-in Failed'),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildImageContainer(double screenHeight, double screenWidth) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isComparing ? _scaleAnimation.value : 1.0,
              child: Container(
                height: screenHeight * 0.4,
                width: screenWidth * 0.7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _isCameraInitialized && _controller.cameraController.value.isInitialized
                      ? CameraPreview(_controller.cameraController)
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            );
          },
        ),
        if (_isComparing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: const Icon(Icons.face_retouching_natural, color: Colors.white, size: 50),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Detecting Faces...',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Face Detection', style: TextStyle(color: whiteColor)),
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.1),
                _buildImageContainer(screenHeight, screenWidth),
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
