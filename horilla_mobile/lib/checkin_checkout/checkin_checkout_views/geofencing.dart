import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import '../../horilla_main/login.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final List<LocationWithRadius> locations = [];
  LocationWithRadius? selectedLocation;
  final PopupController _popupController = PopupController();
  late final AnimatedMapController _mapController;
  double _currentRadius = 50.0;
  LatLng? _tappedCoordinates;
  Position? userLocation;
  bool _showCurrentLocationCircle = false; // For current location from FAB
  bool _showUserLocationCircle = false; // For geofence location from API
  List<dynamic> responseData = [];

  @override
  void initState() {
    super.initState();
    _mapController = AnimatedMapController(vsync: this);
    getGeoFenceLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Fetching location name by using latitude and longitude
  Future<String> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String name = "${place.locality ?? ''}, ${place.country ?? ''}".trim();
        return name.isEmpty ? "Unknown Location" : name;
      }
      return "Unknown Location";
    } catch (e) {
      print('Error getting location name: $e');
      return "Unknown Location";
    }
  }

  Future<void> createGeoFenceLocation() async {
    final prefs = await SharedPreferences.getInstance();
    var companyId = prefs.getInt("company_id");
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/');
    var response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'latitude': selectedLocation?.coordinates.latitude,
        'longitude': selectedLocation?.coordinates.longitude,
        'radius_in_meters': selectedLocation?.radius,
        'start': true,
        'company_id': companyId
      }),
    );
    if (response.statusCode == 201) {
      await showCreateAnimation();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error in Saving'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> updateGeoFenceLocation() async {
    var locationId = responseData[0]['id'];
    final prefs = await SharedPreferences.getInstance();
    var companyId = prefs.getInt("company_id");
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/$locationId/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'latitude': selectedLocation?.coordinates.latitude,
        'longitude': selectedLocation?.coordinates.longitude,
        'radius_in_meters': selectedLocation?.radius,
        'start': true,
        'company_id': companyId
      }),
    );
    if (response.statusCode == 200) {
      await showCreateAnimation();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error in Saving'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> deleteGeoFenceLocation() async {
    final prefs = await SharedPreferences.getInstance();
    var locationId = responseData[0]['id'];
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/$locationId/');
    var response = await http.delete(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode == 204) {
      await showDeleteAnimation();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error in delete'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }


  // Fetching geofence location by using latitude and longitude
  Future<void> getGeoFenceLocation() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/');

    try {
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = data[0]['latitude'];
          final lng = data[0]['longitude'];
          final rad = data[0]['radius_in_meters'];

          if (lat != null && lng != null && rad != null) {
            final locationName = await _getLocationName(lat, lng);
            final location = LocationWithRadius(
              LatLng(lat, lng),
              locationName,
              (rad).toDouble(),
            );

            setState(() {
              responseData = data;
              _showUserLocationCircle = true;
              locations.add(location);
              _mapController.animateTo(dest: location.coordinates, zoom: 12.0);
            });
          }
        }
      } else {
        print('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching geofence data: $e");
    }
  }


  Future<void> showCreateAnimation() async {
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
                      "Geofence Location Added Successfully",
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
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(),
        ),
      );
    });
  }

  Future<void> showDeleteAnimation() async {
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
                      "Geofence Location Deleted Successfully",
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
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(),
        ),
      );
    });
  }
  // Fetching current location by using geolocator
  Future<Position?> fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print('Error fetching location: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        automaticallyImplyLeading: false,
        title: const Text('Geofencing Map', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController.mapController,
              options: MapOptions(
                center: userLocation != null
                    ? LatLng(userLocation!.latitude, userLocation!.longitude)
                    : LatLng(40.0, 0.0),
                zoom: userLocation != null ? 12.0 : 2.0,
                minZoom: 2.0,
                maxZoom: 18.0,
                interactiveFlags: InteractiveFlag.all,
                onTap: (_, latLng) async {
                  String locationName = await _getLocationName(
                    latLng.latitude,
                    latLng.longitude,
                  );
                  setState(() {
                    _tappedCoordinates = latLng;
                    _showCurrentLocationCircle = false; // Hide only current location circle
                    final newLocation = LocationWithRadius(
                      latLng,
                      locationName,
                      _currentRadius,
                    );
                    locations.add(newLocation);
                    selectedLocation = newLocation;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cybrosys.horilla',
                ),
                CircleLayer(
                  circles: [
                    if (selectedLocation != null)
                      CircleMarker(
                        point: selectedLocation!.coordinates,
                        color: Colors.blue.withOpacity(0.3),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2.0,
                        radius: selectedLocation!.radius,
                      ),
                    if (_showCurrentLocationCircle && userLocation != null)
                      CircleMarker(
                        point: LatLng(userLocation!.latitude, userLocation!.longitude),
                        color: Colors.green.withOpacity(0.3),
                        borderColor: Colors.green,
                        borderStrokeWidth: 2.0,
                        radius: 50.0,
                      ),
                    if (_showUserLocationCircle && responseData.isNotEmpty)
                      CircleMarker(
                        point: LatLng(responseData[0]['latitude'], responseData[0]['longitude']),
                        color: Colors.green.withOpacity(0.3),
                        borderColor: Colors.green,
                        borderStrokeWidth: 2.0,
                        radius: responseData[0]['radius_in_meters'].toDouble(),
                      ),
                  ],
                ),
                PopupMarkerLayerWidget(
                  options: PopupMarkerLayerOptions(
                    popupController: _popupController,
                    markers: locations
                        .map((loc) => Marker(
                      point: loc.coordinates,
                      width: 40.0,
                      height: 40.0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedLocation = loc;
                            _tappedCoordinates = null;
                          });
                          _mapController.animateTo(
                            dest: loc.coordinates,
                            zoom: 12.0,
                          );
                        },
                        child: Icon(
                          Icons.location_on,
                          color: selectedLocation == loc
                              ? Colors.blue
                              : Colors.red,
                          size: 40.0,
                        ),
                      ),
                    ))
                        .toList(),
                    popupDisplayOptions: PopupDisplayOptions(
                      builder: (BuildContext context, Marker marker) {
                        final loc = locations.firstWhere(
                              (loc) => loc.coordinates == marker.point,
                        );
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                loc.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('Radius: ${loc.radius.toStringAsFixed(1)} m'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selectedLocation != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Location: ${selectedLocation!.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            locations.remove(selectedLocation);
                            selectedLocation = null;
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Geofence Radius: '),
                      Expanded(
                        child: Slider(
                          value: selectedLocation!.radius,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label:
                          '${(selectedLocation!.radius).toStringAsFixed(2)} m',
                          onChanged: (value) {
                            setState(() {
                              final index = locations.indexOf(selectedLocation!);
                              locations[index] = LocationWithRadius(
                                selectedLocation!.coordinates,
                                selectedLocation!.name,
                                value,
                              );
                              selectedLocation = locations[index];
                            });
                          },
                        ),
                      ),
                      Text(
                          '${(selectedLocation!.radius).toStringAsFixed(2)} m'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await showGeofencingDelete(context);
                          setState(() {
                            locations.remove(selectedLocation);
                            selectedLocation = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await showGeofencingSetting(context);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newLocation = await fetchCurrentLocation();
          if (newLocation != null) {
            String locationName = await _getLocationName(
              newLocation.latitude,
              newLocation.longitude,
            );
            setState(() {
              userLocation = newLocation;
              _showCurrentLocationCircle = true; // Show current location circle
              final newLoc = LocationWithRadius(
                LatLng(newLocation.latitude, newLocation.longitude),
                locationName,
                _currentRadius,
              );
              locations.add(newLoc);
              selectedLocation = newLoc;
              _mapController.animateTo(
                dest: LatLng(newLocation.latitude, newLocation.longitude),
                zoom: 12.0,
              );
            });
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> showGeofencingSetting(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Set Geofencing Location"),
          content: const Text("Do you want to set this location for Geofencing?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                var geo_fencing = prefs.getBool("geo_fencing");
                if (geo_fencing == true) {
                  await updateGeoFenceLocation();
                }
                else {
                  await createGeoFenceLocation();
                }
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<void> showGeofencingDelete(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Geofencing Location"),
          content: const Text("Do you want to delete this location for Geofencing?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await deleteGeoFenceLocation();
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }
}

class LocationWithRadius {
  final LatLng coordinates;
  final String name;
  double radius; // in meters

  LocationWithRadius(this.coordinates, this.name, this.radius);
}
