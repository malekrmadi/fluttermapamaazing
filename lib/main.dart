import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

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
    TextEditingController nameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController tagsController = TextEditingController();
    Category? selectedCategory;
    double initialRating = 0.0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Add Place"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController, 
                    decoration: InputDecoration(labelText: "Name")
                  ),
                  TextField(
                    controller: descriptionController, 
                    decoration: InputDecoration(labelText: "Description"),
                    maxLines: 3,
                  ),
                  SizedBox(height: 10),
                  Text("Category:"),
                  DropdownButton<Category>(
                    isExpanded: true,
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
                  SizedBox(height: 10),
                  Text("Initial Rating:"),
                  Slider(
                    value: initialRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: initialRating.toStringAsFixed(1),
                    onChanged: (double value) {
                      setDialogState(() {
                        initialRating = value;
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: tagsController, 
                    decoration: InputDecoration(
                      labelText: "Tags (comma separated)",
                      hintText: "e.g. Italian, Outdoor, Family-friendly"
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Location: ${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
              TextButton(
                onPressed: () {
                  if (selectedCategory != null) {
                    // Parse tags from comma-separated string
                    List<String> tags = tagsController.text
                        .split(',')
                        .map((tag) => tag.trim())
                        .where((tag) => tag.isNotEmpty)
                        .toList();
                    
                    Map<String, dynamic> placeData = {
                      'name': nameController.text,
                      'description': descriptionController.text,
                      'category': selectedCategory.toString().split('.').last,
                      'location': {
                        'latitude': latLng.latitude,
                        'longitude': latLng.longitude
                      },
                      'rating': initialRating,
                      'reviewsCount': 0,
                      'tags': tags
                    };
                    
                    setState(() {
                      _markers.add({
                        'point': latLng,
                        'title': nameController.text,
                        'description': descriptionController.text,
                        'category': selectedCategory,
                        'rating': initialRating,
                        'reviewsCount': 0,
                        'tags': tags,
                      });
                    });
                    
                    // Output JSON to console
                    print(JsonEncoder.withIndent('  ').convert(placeData));
                    
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

  void _showMarkerDetails(Map<String, dynamic> markerData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(markerData['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(markerData['description']),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 5),
                Text('${markerData['rating'].toStringAsFixed(1)} (${markerData['reviewsCount']} reviews)'),
              ],
            ),
            SizedBox(height: 10),
            if ((markerData['tags'] as List).isNotEmpty) ...[
              Text('Tags:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: (markerData['tags'] as List).map((tag) => Chip(
                  label: Text(tag),
                  backgroundColor: Colors.blue.shade100,
                )).toList(),
              ),
            ],
          ],
        ),
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
      appBar: AppBar(title: Text("Flutter Map Places")),
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
                                            onTap: () => _showMarkerDetails(marker),
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              onEnter: (_) => setState(() {}),
                                              onExit: (_) => setState(() {}),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.8),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      marker['title'],
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                  Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Icon(
                                                        _getCategoryIcon(marker['category']),
                                                        color: _getCategoryColor(marker['category']),
                                                        size: 40,
                                                      ),
                                                      if ((marker['rating'] as double) > 0)
                                                        Positioned(
                                                          bottom: 0,
                                                          child: Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: Colors.amber,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              (marker['rating'] as double).toStringAsFixed(1),
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.black,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
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