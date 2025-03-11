import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

enum Category { bar, restaurant, cafe }

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Map App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _markers = [];
  LatLng? _currentLocation;
  Category? _selectedCategory;
  double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    await Permission.location.request();
    Position position = await _determinePosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    _mapController.move(_currentLocation!, _currentZoom);
  }

  Future<Position> _determinePosition() async {
    if (await Permission.location.isDenied) {
      return Future.error("Location permission denied");
    }
    return await Geolocator.getCurrentPosition();
  }

  void _showMarkerDialog(TapPosition tapPosition, LatLng latLng) {
    TextEditingController titleController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    Category? selectedCategory;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Add Marker"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: InputDecoration(labelText: "Title")),
                TextField(controller: descriptionController, decoration: InputDecoration(labelText: "Description")),
                DropdownButton<Category>(
                  hint: Text("Select Category"),
                  value: selectedCategory,
                  onChanged: (Category? newValue) {
                    setDialogState(() {
                      selectedCategory = newValue;
                    });
                  },
                  items: Category.values.map((Category category) {
                    return DropdownMenuItem<Category>(
                      value: category,
                      child: Row(
                        children: [
                          Icon(_getCategoryIcon(category), color: _getCategoryColor(category)),
                          SizedBox(width: 8),
                          Text(category.toString().split('.').last),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
              TextButton(
                onPressed: () {
                  if (selectedCategory != null) {
                    setState(() {
                      _markers.add({
                        'point': latLng,
                        'title': titleController.text,
                        'description': descriptionController.text,
                        'category': selectedCategory,
                      });
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMarkerDetails(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Close"))],
      ),
    );
  }

  void _trackLocation() async {
    Position position = await _determinePosition();
    _mapController.move(LatLng(position.latitude, position.longitude), _currentZoom);
  }

  void _zoomIn() {
    _currentZoom += 1.0;
    if (_currentZoom > 19.0) _currentZoom = 19.0;
    _mapController.move(_mapController.center, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom -= 1.0;
    if (_currentZoom < 3.0) _currentZoom = 3.0;
    _mapController.move(_mapController.center, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Flutter Map Example")),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.blueAccent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: Category.values.map((category) {
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = _selectedCategory == category ? null : category;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedCategory == category ? Colors.white : Colors.blue,
                    foregroundColor: _selectedCategory == category ? Colors.blue : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(category)),
                      SizedBox(width: 8),
                      Text(category.toString().split('.').last),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _currentLocation == null
                ? Center(child: CircularProgressIndicator())
                : Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              center: _currentLocation,
                              zoom: _currentZoom,
                              onTap: _showMarkerDialog,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: ['a', 'b', 'c'],
                              ),
                              MarkerLayer(
                                markers: _markers
                                    .where((marker) => _selectedCategory == null || marker['category'] == _selectedCategory)
                                    .map((marker) => Marker(
                                          width: 120.0,
                                          height: 120.0,
                                          point: marker['point'],
                                          child: GestureDetector(
                                            onTap: () => _showMarkerDetails(marker['title'], marker['description']),
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              onEnter: (_) => setState(() {}),
                                              onExit: (_) => setState(() {}),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    marker['title'],
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      backgroundColor: Colors.white.withOpacity(0.7),
                                                    ),
                                                  ),
                                                  Icon(
                                                    _getCategoryIcon(marker['category']),
                                                    color: _getCategoryColor(marker['category']),
                                                    size: 40,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 10,
                            bottom: 80,
                            child: Column(
                              children: [
                                FloatingActionButton(
                                  mini: true,
                                  heroTag: "zoomIn",
                                  onPressed: _zoomIn,
                                  child: Icon(Icons.add),
                                ),
                                SizedBox(height: 10),
                                FloatingActionButton(
                                  mini: true,
                                  heroTag: "zoomOut",
                                  onPressed: _zoomOut,
                                  child: Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _trackLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }

  Color _getCategoryColor(Category category) {
    switch (category) {
      case Category.bar:
        return Colors.red;
      case Category.restaurant:
        return Colors.green;
      case Category.cafe:
        return Colors.blue;
    }
  }

  IconData _getCategoryIcon(Category category) {
    switch (category) {
      case Category.bar:
        return Icons.local_bar;
      case Category.restaurant:
        return Icons.restaurant;
      case Category.cafe:
        return Icons.local_cafe;
    }
  }
}