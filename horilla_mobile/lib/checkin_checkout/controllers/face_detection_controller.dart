import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_api_beta/flutter_face_api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../res/utilities/alertDialogs.dart';
import '../../res/utilities/snackBar.dart';
import 'package:http/http.dart' as http;

class FaceScannerController {
  late CameraController cameraController;
  late CameraDescription selectedCamera;
  late OdooClient client;
  Position? currentLocation;
  var faceSdk = FaceSDK.instance;
  MatchFacesImage? storedFaceImage;
  Map<String, dynamic>? employeeDetails;
  bool _isInitialized = false;

  Future<void> initializeFaceSDK() async {
    try {
      final result = await faceSdk.initialize();
      final success = result.$1;
      final error = result.$2;

      if (!success) {
        throw Exception("Face SDK initialization failed: ${error?.message}");
      }
      log('Face SDK initialized successfully');
    } catch (e) {
      log('Error initializing Face SDK: $e');
      rethrow;
    }
  }

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await cameraController.initialize();
      print('uuuuuuuuu');
      log('Camera initialized successfully');
    } catch (e) {
      log('Error initializing camera: $e');
      rethrow;
    }
  }

  Future<XFile?> captureImage() async {
    if (!cameraController.value.isInitialized) {
      log('Camera not initialized');
      return null;
    }
    try {
      final image = await cameraController.takePicture();
      print('gtgtgtgtgt');
      log('Image captured successfully');
      return image;
    } catch (e) {
      log('Error capturing image: $e');
      rethrow;
    }
  }

  Future<bool> compareFaces(File capturedImageFile, String storedImageBase64) async {
    try {
      final storedImageBytes = base64Decode(storedImageBase64);
      final capturedImageBytes = await capturedImageFile.readAsBytes();
      final storedFaceImage = MatchFacesImage(storedImageBytes, ImageType.PRINTED);
      final capturedFaceImage = MatchFacesImage(capturedImageBytes, ImageType.LIVE);
      final request = MatchFacesRequest([storedFaceImage, capturedFaceImage]);
      final response = await faceSdk.matchFaces(request);
      final split = await faceSdk.splitComparedFaces(response.results, 0.75);

      if (split.matchedFaces.isNotEmpty) {
        final similarity = split.matchedFaces[0].similarity;
        log('Face comparison similarity: $similarity');
        return similarity >= 0.80;
      }
      log('No matched faces found');
      return false;
    } catch (e) {
      log('Error in face comparison: $e');
      rethrow;
    }
  }

  void dispose() {
    if (cameraController.value.isInitialized) {
      cameraController.dispose();
      log('Camera controller disposed');
    }
  }
}
