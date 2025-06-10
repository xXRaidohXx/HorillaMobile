import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../horilla_main/login.dart';
import 'checkin_checkout_form.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CameraSetupPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraSetupPage({required this.cameras});

  @override
  _CameraSetupPageState createState() => _CameraSetupPageState();
}

class _CameraSetupPageState extends State<CameraSetupPage> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  XFile? _capturedImage;
  XFile? pickedFile;
  String fileName = '';
  String filePath = '';
  int selectedCameraIndex = 0;
  final ImagePicker _picker = ImagePicker();
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }


  Future<void> updateEmployeeImage(
      Map<String, dynamic> updatedDetails, String fileName, String filePath, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var request = http.MultipartRequest('POST',
        Uri.parse('$typedServerUrl/api/facedetection/setup/'));
    try {
      var attachment = await http.MultipartFile.fromPath('image', filePath);
      request.files.add(attachment);
      request.headers['Authorization'] = 'Bearer $token';
      var response = await request.send();
      if (response.statusCode == 201) {
        showCreateAnimation(context);
      } else {
        showErrorDialog(context, 'Error uploading image. Please try again.');
      }
    } catch (e) {
      print('Exception: $e');
      showErrorDialog(context, 'Something went wrong. Please try again.');
    }
  }

  void showCreateAnimation(BuildContext context) {
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
                      "Face Image Uploaded Successfully",
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(),
        ),
      );
    });
  }

  void showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
  // Setup camera by using camera package
  Future<void> _setupCamera() async {
    try {
      CameraDescription? frontCamera;
      CameraDescription? backCamera;

      for (var camera in widget.cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
        } else if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
        }
      }

      CameraDescription selectedCamera;
      if (selectedCameraIndex == 0 && frontCamera != null) {
        selectedCamera = frontCamera;
      } else if (backCamera != null) {
        selectedCamera = backCamera;
      } else {
        selectedCamera = widget.cameras.first;
      }

      _controller = CameraController(selectedCamera, ResolutionPreset.medium);
      _initializeControllerFuture = _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _isControllerInitialized = true;
          });
        }
      }).catchError((e) {
        print('Error initializing camera: $e');
      });
    } catch (e) {
      print('Error setting up camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2 || _controller == null) return;

    setState(() {
      _capturedImage = null;
      _isControllerInitialized = false;
      selectedCameraIndex = (selectedCameraIndex + 1) % 2;
    });

    // await _controller?.dispose();
    await _setupCamera();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_isControllerInitialized) return;

    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      if (mounted) {
        setState(() => _capturedImage = image);
      }
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() {
          _capturedImage = XFile(picked.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _retakePicture() {
    if (mounted) {
      setState(() => _capturedImage = null);
    }
  }

  Future<void> _submitPicture() async {
    if (_capturedImage == null) return;

    final prefs = await SharedPreferences.getInstance();
    var empId = prefs.getInt("employee_id");
    pickedFile = _capturedImage;
    fileName = _capturedImage!.name;
    filePath = _capturedImage!.path;
    Map<String, dynamic> updatedDetails = {
      "id": empId,
    };
    await updateEmployeeImage(updatedDetails, fileName, filePath, context);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CheckInCheckOutFormPage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Face Image Capture', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red[700],
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                selectedCameraIndex == 0 ? Icons.camera_rear : Icons.camera_front,
                color: Colors.white,
              ),
              onPressed: widget.cameras.length > 1 ? _switchCamera : null,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 400,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red[700]!, width: 3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: _capturedImage == null
                            ? FutureBuilder<void>(
                          future: _initializeControllerFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done) {
                              if (snapshot.hasError || _controller == null || !_isControllerInitialized) {
                                return const Center(child: Text('Camera Error'));
                              }
                              return CameraPreview(_controller!);
                            }
                            return Center(
                              child: CircularProgressIndicator(
                                color: Colors.red[700],
                              ),
                            );
                          },
                        )
                            : Image.file(
                          File(_capturedImage!.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_capturedImage == null) ...[
                      ElevatedButton.icon(
                        onPressed: _isControllerInitialized ? _takePicture : null,
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text('Capture', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library, color: Colors.white),
                        label: const Text('Gallery', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                    if (_capturedImage != null) ...[
                      OutlinedButton.icon(
                        onPressed: _retakePicture,
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        label: const Text('Retake'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[700]!),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _submitPicture,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('Submit', style: TextStyle(color: Colors.white)),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed)) {
                                return Colors.green.withOpacity(0.6); // Dull color when pressed
                              }
                              return Colors.green; // Default background color
                            },
                          ),
                          foregroundColor: MaterialStateProperty.all(Colors.white), // Icon and text color
                          padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class DisplayImagePage extends StatelessWidget {
  final String imagePath;
  const DisplayImagePage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Center(child: Text('Your Face Image', style: TextStyle(color: Colors.white))),
          backgroundColor: Colors.red[700],
        ),
        body: Container(
          color: Colors.grey[200],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckInCheckOutFormPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text('Go to Home Page', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
