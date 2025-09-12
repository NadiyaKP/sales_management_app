import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'punchin_details.dart';
import '../../theme/app_theme.dart';

List<CameraDescription> cameras = [];
CameraController? _cameraController;
XFile? _imageFile;

class CameraPageScreen extends StatefulWidget {
  const CameraPageScreen({super.key});

  @override
  State<CameraPageScreen> createState() => _CameraPageScreenState();
}

class _CameraPageScreenState extends State<CameraPageScreen> {
  bool _isCameraInitialized = false;
  bool isLoading = false;
  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = false;
  List<String> customerNames = [];
  List<String> filteredCustomerNames = [];
  String? selectedCustomer;
  String? selectedCustId;
  Map<String, String> customerIdMap = {};
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();

  bool _showCustomerDropdown = false;
  final FocusNode _customerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _keyboardVisible = false;

  static const Color primaryColor = AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    _customerSearchController.addListener(_filterCustomers);
    _customerFocusNode.addListener(_onCustomerFocusChange);
    fetchCustomers();
    _initializeCamera();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    try {
      // Check if location service is enabled
      _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      setState(() {
        _locationPermissionGranted = permission == LocationPermission.always || 
                                    permission == LocationPermission.whileInUse;
      });
      
      if (!_locationServiceEnabled || !_locationPermissionGranted) {
        await _requestLocationPermission();
      }
    } catch (e) {
      debugPrint("Error checking location status: $e");
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      // Request permission
      LocationPermission permission = await Geolocator.requestPermission();
      
      // Check if service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      setState(() {
        _locationPermissionGranted = permission == LocationPermission.always || 
                                    permission == LocationPermission.whileInUse;
        _locationServiceEnabled = serviceEnabled;
      });
      
      if (!_locationPermissionGranted) {
        _showLocationPermissionDialog();
      } else if (!_locationServiceEnabled) {
        _showLocationServiceDialog();
      }
    } catch (e) {
      debugPrint("Error requesting location permission: $e");
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Punch-in feature requires location permission to track your attendance. '
          'Please grant location permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Service Disabled'),
        content: const Text(
          'Punch-in feature requires location services to be enabled. '
          'Please enable location services on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _noteController.dispose();
    _locationController.dispose();
    _customerSearchController.removeListener(_filterCustomers);
    _customerSearchController.dispose();
    _customerFocusNode.removeListener(_onCustomerFocusChange);
    _customerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCustomerFocusChange() {
    setState(() {
      _showCustomerDropdown = _customerFocusNode.hasFocus && filteredCustomerNames.isNotEmpty;
    });
    _scrollToField();
  }

  void _scrollToField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _filterCustomers() {
    String query = _customerSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredCustomerNames = List.from(customerNames);
      } else {
        filteredCustomerNames = customerNames
            .where((customer) => customer.toLowerCase().contains(query))
            .toList();
      }
      _showCustomerDropdown = _customerFocusNode.hasFocus && filteredCustomerNames.isNotEmpty;
    });
  }

  void _selectCustomer(String customerName) {
    setState(() {
      selectedCustomer = customerName;
      selectedCustId = customerIdMap[customerName];
      _customerSearchController.text = customerName;
      _showCustomerDropdown = false;
    });
    _customerFocusNode.unfocus();
  }

  Future<void> fetchCustomers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');
    
    try {
      final response = await http.post(
        Uri.parse('$url/get_customers.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['result'] == '1') {
          final List<dynamic> customers = data['customerdet'];
          setState(() {
            customerNames =
                customers.map((e) => e['cust_name'] as String).toList();
            customerIdMap = {
              for (var e in customers)
                e['cust_name'] as String: e['custid'] as String
            };
            filteredCustomerNames = List.from(customerNames);
          });
        }
      }
    } catch (e) {
      _showError('Error fetching customers: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras[0], 
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        if (mounted) {
          _showError("No cameras available on this device");
        }
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to initialize camera: ${e.toString()}");
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_locationPermissionGranted || !_locationServiceEnabled) {
      await _requestLocationPermission();
      if (!_locationPermissionGranted || !_locationServiceEnabled) {
        _showError("Location permission and service are required for punch-in");
        return;
      }
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError("Camera is not ready");
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      _showError("Location is required");
      return;
    }

    if (selectedCustomer == null) {
      _showError("Please select a customer");
      return;
    }

    if (_noteController.text.trim().isEmpty) {
      _showError("Note is required");
      return;
    }

    String custId = selectedCustId ?? customerIdMap[selectedCustomer] ?? '';
    if (custId.isEmpty) {
      _showError("Customer ID not found");
      return;
    }

    // Show location access confirmation dialog
    bool? confirmLocationAccess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Access'),
          content: const Text(
            'Your current location will be accessed for this punch-in. '
            'Do you want to allow location access?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Dismiss'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    // If user dismissed the dialog or clicked "Dismiss", stop here
    if (confirmLocationAccess != true) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Take picture first
      final image = await _cameraController!.takePicture();
      File convertedImage = await _convertToJpgFormat(File(image.path));

      // Get location with better error handling
      final locationService = LocationService();
      Position? position;
      
      try {
        position = await locationService.getCurrentLocation();
      } catch (locationError) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          
          // Show dialog asking if user wants to continue without location
          bool? continueWithoutLocation = await _showLocationErrorDialog(locationError.toString());
          
          if (continueWithoutLocation == true) {
            // Use default coordinates if user chooses to continue
            position = Position(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: DateTime.now(),
              accuracy: 0.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            );
            
            setState(() {
              isLoading = true;
            });
          } else {
            return; // User choose not to continue
          }
        } else {
          return;
        }
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
        _imageFile = XFile(convertedImage.path);
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPage(
            imageFile: _imageFile!,
            position: position!,
            customerName: selectedCustomer!,
            customerId: custId,
            location: _locationController.text.trim(),
            note: _noteController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showError("Error capturing image: ${e.toString()}");
      }
    }
  }

  Future<bool?> _showLocationErrorDialog(String error) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Failed to get location: $error'),
              const SizedBox(height: 16),
              const Text('Would you like to continue without location data?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<File> _convertToJpgFormat(File imageFile) async {
    try {
      // Read the original file
      Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Create a new file with .jpg extension
      String tempPath = '${imageFile.parent.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      File jpgFile = File(tempPath);
      
      // Write the bytes to the new file
      await jpgFile.writeAsBytes(imageBytes);
      
      // Delete the original file if it's not already a jpg
      if (!imageFile.path.toLowerCase().endsWith('.jpg') && 
          !imageFile.path.toLowerCase().endsWith('.jpeg')) {
        await imageFile.delete();
      }
      
      return jpgFile;
    } catch (e) {
      debugPrint("Error converting to JPG: $e");
      // If conversion fails, return the original file
      return imageFile;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Widget _buildCustomerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Customer Name', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TextField(
                controller: _customerSearchController,
                focusNode: _customerFocusNode,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'Type to search customer...',
                  suffixIcon: Icon(Icons.search, color: Colors.grey),
                ),
                onChanged: (value) {
                  if (customerNames.contains(value)) {
                    setState(() {
                      selectedCustomer = value;
                      selectedCustId = customerIdMap[value];
                    });
                  } else {
                    setState(() {
                      selectedCustomer = null;
                      selectedCustId = null;
                    });
                  }
                },
              ),
              if (_showCustomerDropdown && filteredCustomerNames.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filteredCustomerNames.length,
                    itemBuilder: (context, index) {
                      String customerName = filteredCustomerNames[index];
                      return InkWell(
                        onTap: () => _selectCustomer(customerName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index < filteredCustomerNames.length - 1 
                                    ? Colors.grey.shade200 
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (selectedCustomer == null && _customerSearchController.text.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4.0, left: 12.0),
            child: Text(
              'Please select a customer from the dropdown',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  bool get _isFormComplete {
    return selectedCustomer != null && 
           _locationController.text.trim().isNotEmpty &&
           _noteController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    _keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Punch-In',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Form fields section
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_locationPermissionGranted || !_locationServiceEnabled)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange[800]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _locationPermissionGranted 
                                    ? 'Please enable location services'
                                    : 'Location permission required for punch-in',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _requestLocationPermission,
                              child: Text(
                                'Enable',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildCustomerField(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location *',
                        hintText: 'Enter location...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      textInputAction: TextInputAction.next,
                      onTap: _scrollToField,
                      onChanged: (value) {
                        setState(() {}); 
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note *',
                        hintText: 'Enter your notes...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      onTap: _scrollToField,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            // Camera preview section - dynamically sized based on form state
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isFormComplete && !_keyboardVisible
                  ? MediaQuery.of(context).size.height * 0.4 
                  : MediaQuery.of(context).size.height * 0.2, 
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: _cameraController != null && _cameraController!.value.isInitialized
                    ? CameraPreview(_cameraController!)
                    : const Center(
                        child: Text(
                          "Camera not available",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
              ),
            ),
            
            // Button section
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isFormComplete && _locationPermissionGranted && _locationServiceEnabled 
                          ? _takePicture 
                          : null,
                      child: Text(
                        !_locationPermissionGranted || !_locationServiceEnabled
                            ? "Enable Location First"
                            : _isFormComplete 
                                ? "Take Picture"
                                : selectedCustomer == null
                                    ? "Select Customer First"
                                    : _locationController.text.isEmpty
                                        ? "Enter Location"
                                        : "Enter Note",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  if (isLoading)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      child: const CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationService {
  Future<bool> checkPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled. Please enable location services.");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permissions are denied. Please grant location permission.");
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied. Please enable them in app settings.");
      }
      
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<Position> getCurrentLocation() async {
    try {
      await checkPermission(); 
      
      Position? lastPosition;
      try {
        lastPosition = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: false,
        );
      } catch (e) {
        // Ignore error
      }
      
      if (lastPosition != null && 
          DateTime.now().difference(lastPosition.timestamp).inMinutes < 5) {
        return lastPosition;
      }
      
      Position position;
      
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30),
        );
      } catch (e) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 20),
          );
        } catch (e) {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 10),
            );
          } catch (e) {
            if (lastPosition != null) {
              return lastPosition;
            }
            
            throw Exception(
              "Unable to get location. Please check if:\n"
              "• Location services are enabled\n"
              "• You have a clear view of the sky (for GPS)\n"
              "• You're not in a building with poor signal\n"
              "• Try moving to a different location"
            );
          }
        }
      }
      
      return position;
    } catch (e) {
      rethrow;
    }
  }
}

class LocationPage extends StatefulWidget {
  final XFile imageFile;
  final Position position;
  final String customerName;
  final String customerId;
  final String location;
  final String note;

  const LocationPage({
    super.key, 
    required this.imageFile, 
    required this.position, 
    required this.customerName,
    required this.customerId,
    required this.location,
    required this.note,
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  bool _isSaving = false;
  static const Color primaryColor = Color(0xFF1976D2);

  Future<String> _convertImageToBase64() async {
    try {
      File imageFile = File(widget.imageFile.path);
      
      // Ensure the file is a JPEG by checking extension
      if (!widget.imageFile.path.toLowerCase().endsWith('.jpg') && 
          !widget.imageFile.path.toLowerCase().endsWith('.jpeg')) {
        // Convert to JPEG if it's not already
        String tempPath = '${imageFile.parent.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        File jpgFile = File(tempPath);
        await jpgFile.writeAsBytes(await imageFile.readAsBytes());
        imageFile = jpgFile;
      }
      
      Uint8List imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);
      
      // Format the base64 string as a data URI with content type
      String formattedBase64 = "data:image/jpeg;base64,$base64String";
      
      debugPrint("=== COMPLETE BASE64 IMAGE DATA ===");
      debugPrint("Image file path: ${imageFile.path}");
      debugPrint("Image size: ${imageBytes.length} bytes");
      debugPrint("Base64 length: ${formattedBase64.length} characters");
      debugPrint("Base64 data: $formattedBase64");
      debugPrint("=== END BASE64 IMAGE DATA ===");
      
      return formattedBase64;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _savePunchInDetails() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      String base64Image = await _convertImageToBase64();
      debugPrint("=== BASE64 IN API REQUEST ===");
      debugPrint("Base64 image data for API: $base64Image");
      debugPrint("=== END BASE64 IN API REQUEST ===");
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');
      
      if (url == null || unid == null || slex == null) {
        throw Exception('Missing configuration data');
      }
      
      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "customer_name": widget.customerName,
        "custid": widget.customerId, 
        "action": "insert",
        "location": widget.location,
        "longt": widget.position.longitude.toString(),
        "latit": widget.position.latitude.toString(),
        "notes": widget.note,
        "image_data": base64Image,
      };
      
      // Debug: Print API endpoint
      debugPrint("=== PUNCH-IN API REQUEST ===");
      debugPrint("Endpoint: $url/action/punch-in.php");
      debugPrint("Method: POST");
      debugPrint("Headers: Content-Type: application/json");
      
      // Debug: Print request body (excluding image data for readability)
      Map<String, dynamic> debugRequestBody = Map.from(requestBody);
      debugRequestBody['image_data'] = '[BASE64_IMAGE_DATA - ${base64Image.length} characters]';
      debugPrint("Request Body: ${jsonEncode(debugRequestBody)}");
      debugPrint("=============================");
      
      final response = await http.post(
        Uri.parse('$url/action/punch-in.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      
      // Debug: Print API response
      debugPrint("=== PUNCH-IN API RESPONSE ===");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Headers: ${response.headers}");
      debugPrint("Response Body: ${response.body}");
      debugPrint("==============================");
      
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Server returned empty response');
        }
        
        Map<String, dynamic> responseData;
        try {
          responseData = json.decode(response.body);
        } catch (e) {
          throw Exception('Invalid JSON response from server');
        }
        
        // Debug: Print parsed response data
        debugPrint("=== PARSED RESPONSE DATA ===");
        debugPrint("Parsed JSON: ${jsonEncode(responseData)}");
        debugPrint("=============================");
        
        bool isSuccess = false;
        String message = '';
        
        if (responseData.containsKey('result')) {
          isSuccess = responseData['result'] == '1' || responseData['result'] == 1;
          message = responseData['message'] ?? '';
        } else if (responseData.containsKey('status')) {
          isSuccess = responseData['status'] == 'success';
          message = responseData['message'] ?? responseData['msg'] ?? '';
        } else if (responseData.containsKey('success')) {
          isSuccess = responseData['success'] == true || responseData['success'] == 'true';
          message = responseData['message'] ?? '';
        }
        
        debugPrint("=== RESPONSE PROCESSING ===");
        debugPrint("Success: $isSuccess");
        debugPrint("Message: $message");
        debugPrint("============================");
        
        if (isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message.isNotEmpty ? message : 'Punch-in saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => PunchInDetailsPage()), 
              (Route<dynamic> route) => false,
            );
          }
        } else {
          throw Exception(message.isNotEmpty ? message : 'Failed to save punch-in details');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Debug: Print error information
      debugPrint("=== PUNCH-IN API ERROR ===");
      debugPrint("Error: ${e.toString()}");
      debugPrint("===========================");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving punch-in: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Location & Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(
                    File(widget.imageFile.path),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Customer:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.customerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Location:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.location,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.position.latitude == 0.0 && widget.position.longitude == 0.0
                                        ? "Location not available"
                                        : "Lat: ${widget.position.latitude.toStringAsFixed(6)}",
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                  if (!(widget.position.latitude == 0.0 && widget.position.longitude == 0.0))
                                    Text(
                                      "Lng: ${widget.position.longitude.toStringAsFixed(6)}",
                                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Notes:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.note,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isSaving ? null : _savePunchInDetails,
                    child: _isSaving
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Saving...",
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          )
                        : const Text(
                            "Save",
                            style: TextStyle(fontSize: 16),
                          ),
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