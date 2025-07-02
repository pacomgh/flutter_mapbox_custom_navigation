import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//---- navigation libraries -----//
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_navigation/mapbox_model.dart' as mapbox_model;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
// import 'dart:math' show atan2, degrees;
import 'dart:math' show cos, sqrt, asin;

import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  mapbox.MapboxOptions.setAccessToken('YOUR_ACCESS_TOKEN');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navegación Mapbox',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: NavigationMap(),
    );
  }
}

class NavigationMap extends StatefulWidget {
  final String mapboxAccessToken = 'YOUR_ACCESS_TOKEN';

  @override
  State<NavigationMap> createState() => _NavigationMapState();
}

class _NavigationMapState extends State<NavigationMap> {
  //to realtime location
  StreamSubscription<geo.Position>? positionStreamSubscription;
  //to draw user market
  mapbox.PointAnnotation? userMarker;
  //to add annotations to map
  mapbox.PointAnnotationManager? pointAnnotationManager;
  String coordinates = '';

  mapbox.MapboxMap? _mapboxMapController;
  geo.Position? _currentPosition;

  // final mapbox.Point _destination = mapbox.Point(
  //   coordinates: mapbox.Position(-101.654688, 21.113962),
  // );
  // Recuerda: Longitud, Latitud// Ejemplo: Catedral de León
  final mapbox.Point otherPoint = mapbox.Point(
    coordinates: mapbox.Position(-101.6808, 21.1253),
  ); // Recuerda: Longitud, Latitud// Ejemplo: Catedral de León

  // List<List<double>> _routeCoordinates = [];
  List<dynamic> mapboxGeometry = [];
  //to use static places
  // primero va lng
  List<mapbox.Point> deliverPoints = [
    //dilo maps
    // mapbox.Point(coordinates: mapbox.Position(-101.6740238, 21.1160227)),
    //dilo mapbox
    mapbox.Point(coordinates: mapbox.Position(-101.67142131, 21.11600757)),
    //forum maps
    // mapbox.Point(coordinates: mapbox.Position(-101.6630901, 21.115909)),
    //forum mapbox
    mapbox.Point(coordinates: mapbox.Position(-101.66048546, 21.11595034)),
    //poliforum maps
    // mapbox.Point(coordinates: mapbox.Position(-101.6631432, 21.1159041)),
    //poliforum mapbox
    mapbox.Point(coordinates: mapbox.Position(-101.65460351, 21.1141399)),
    //vity plaza mapbox
    mapbox.Point(
      coordinates: mapbox.Position(-101.68285433651064, 21.16990091870788),
    ),
  ];

  List<mapbox.Point> selectedPoints = [];
  //to store final coordinates and steps
  List<mapbox.Position> routeCoordinates = [];
  List<mapbox.Position> routeSegmentsCoordinates = [];
  List<dynamic> _routeSteps = [];
  int _currentRouteStepIndex = 0;
  FlutterTts flutterTts = FlutterTts();
  bool _isNavigating = false;

  //to list traffic segments
  mapbox_model.MapboxModel? mapboxModel;
  List<int> trafficIndexesList = [];
  List<MapboxFeature> trafficSegments = [];
  List<String> congestionList = [];

  //to search places
  // Lista para guardar info del lugar
  List<Map<String, dynamic>> _addedLocations = [];
  final TextEditingController _searchController = TextEditingController();
  // --- Para la funcionalidad de búsqueda nativa ---
  List<Map<String, dynamic>> _suggestions = []; // Lista para las sugerencias
  Timer? _debounce; // Para el debounce de la búsqueda

  //spoken steps
  // En _NavigationMapState (añade esta variable)
  bool _hasSpokenInstructionForCurrentStep = false;

  mapbox.PolylineAnnotationManager? _polylineAnnotationManager;
  mapbox.PolylineAnnotation? _routePolyline;

  int currentIndexStep = 0;

  late final featureCollection;
  List<mapbox.Feature> features = [];
  int indexRemoveSedmentPolyline = 0;

  // Esto podría ser un Map para asociar un ID de segmento de ruta con el ID de la Feature en el mapa.
  Map<String, String> _segmentToFeatureIdMap = {};

  List<String> _drawnSegmentIds = [];
  // Cantidad de segmentos a dibujar
  final int _segmentPointsThreshold = 2;

  int _lastConsumedSegmentIndex = -1;
  // Nueva lista para nuestros segmentos lógicos
  List<RouteSegmentVisual> routeVisualSegments = [];
  // Asegúrate de que esta lista esté disponible
  // Asegúrate de que esta lista esté disponible
  // Para la ruta recorrida
  // Ruta base (gris)
  mapbox.PolylineAnnotation? _traversedPolyline;
  // Para la ruta no recorrida (base)
  // Ruta recorrida (azul)
  mapbox.PolylineAnnotation? _unTraversedPolyline;
  // Nuevo: El índice del último segmento lógico recorrido
  int _lastTraversedSegmentIndex = -1;
  bool _isMapReady = false;
  int _highestTraversedPointIndex = -1;

  // Asegúrate de inicializar Uuid
  final Uuid uuid = Uuid();

  // Para almacenar los marcadores de destino
  List<mapbox.PointAnnotation> _destinationMarkers = [];

  // _onMapCreated(mapbox.MapboxMap mapboxMap) {
  //   mapboxMap = mapboxMap;
  // }

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    WidgetsBinding.instance.addPostFrameCallback((timestamp) async {
      await _getCurrentLocation();
      // await createMarker(
      //   assetPaTh: 'assets/user_marker.png',
      //   lat: _currentPosition!.latitude,
      //   lng: _currentPosition!.longitude,
      // );
    });
    _initTextToSpeech();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navegación Mapbox')),
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(
                child: CircularProgressIndicator(),
              ) // Cambia color para que destaque
              : mapbox.MapWidget(
                // resourceOptions: ResourceOptions(
                //   accessToken: widget.mapboxAccessToken,
                // ),
                // onMapCreated: _onMapCreated,
                cameraOptions: mapbox.CameraOptions(
                  center: mapbox.Point(
                    coordinates: mapbox.Position(
                      //to test sf airport
                      // -122.385374,
                      // 37.61501,
                      //-------
                      _currentPosition!.longitude,
                      _currentPosition!.latitude,
                    ),
                  ),
                  zoom: 15.0,
                ),
                onMapCreated: (controller) async {
                  print('🌟 creando mapa');
                  _mapboxMapController = controller;
                  print('DEBUG: onMapCreated - _mapboxMapController asignado.');

                  // Intentamos crear el PointAnnotationManager aquí, una vez que el mapa esté listo.
                  pointAnnotationManager ??=
                      await _mapboxMapController!.annotations
                          .createPointAnnotationManager();
                  print('DEBUG: PointAnnotationManager inicializado.');

                  // Si _currentPosition ya está disponible, creamos el marcador de usuario
                  if (_currentPosition != null && userMarker == null) {
                    await createMarker(
                      assetPaTh: 'assets/user_marker.png',
                      lat: _currentPosition!.latitude,
                      lng: _currentPosition!.longitude,
                      isUserMarker: true,
                    );
                    print('DEBUG: Marcador de usuario creado en onMapCreated.');
                  }

                  // Una vez que el controlador y los elementos básicos están listos,
                  // marcamos el mapa como listo para mostrarse
                  setState(() {
                    _isMapReady = true;
                  });

                  // _listMapLayers(); // Puedes dejar esto para depuración si lo necesitas
                  // _mapboxMapController = controller;
                  // if (_currentPosition != null &&
                  //     // _routeCoordinates.isNotEmpty) {
                  //     routeCoordinates.isNotEmpty) {
                  //   // _addRouteToMap();
                  // }
                  // _listMapLayers();
                },
                onStyleLoadedListener: (style) async {
                  // if (_currentPosition != null) {
                  //   // _addMarkers();
                  //   await createMarker(
                  //     assetPaTh: 'assets/user_marker.png',
                  //     //to test sf airport
                  //     // lng: -122.385374,
                  //     // lat: 37.61501,
                  //     //-------
                  //     lat: _currentPosition!.latitude,
                  //     lng: _currentPosition!.longitude,
                  //     isUserMarker: true,
                  //   );
                  // }
                },
              ),
          // Caja de búsqueda (TextField con sugerencias)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar lugar...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _suggestions = []; // Limpiar sugerencias
                                  });
                                },
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
                    ),
                    onChanged: (val) {
                      // Si el campo tiene texto, re-mostrar sugerencias al tocarlo
                      if (_searchController.text.isNotEmpty &&
                          _suggestions.isEmpty) {
                        // _getPlaceSuggestions(_searchController.text);
                        _getPlaceSuggestions(val);
                      }
                    },
                    // onTap: () {
                    //   // Si el campo tiene texto, re-mostrar sugerencias al tocarlo
                    //   if (_searchController.text.isNotEmpty &&
                    //       _suggestions.isEmpty) {
                    //     _getPlaceSuggestions(_searchController.text);
                    //   }
                    // },
                  ),
                  // Lista de sugerencias (se muestra solo si hay sugerencias)
                  if (_suggestions.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.builder(
                        shrinkWrap:
                            true, // Importante para que ListView.builder no ocupe todo el espacio disponible
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            title: Text(suggestion['name']),
                            onTap: () {
                              print('suggestion 💔 ${_searchController.text}');
                              _onSuggestionSelected(suggestion);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Lista de coordenadas agregadas
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lugares Agregados:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_addedLocations.isEmpty)
                    const Text('Aún no has agregado lugares.')
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _addedLocations.length,
                        itemBuilder: (context, index) {
                          // print('🌻 added locations ${_addedLocations[index]}');
                          final location = _addedLocations[index];
                          final double lng = location['point'].coordinates.lng;
                          final double lat = location['point'].coordinates.lat;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width:
                                          MediaQuery.of(context).size.width *
                                          .7,
                                      child: Text(
                                        '${location['name']} (Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)})',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        // Asegúrate de pasar la referencia al marcador y el índice
                                        final markerReference =
                                            location['marker']
                                                as mapbox.PointAnnotation?;
                                        if (markerReference != null) {
                                          _removeSingleDestinationMarker(
                                            markerReference,
                                            index,
                                          );
                                        } else {
                                          // Si por alguna razón la referencia al marcador no está,
                                          // aún puedes intentar remover por índice (menos seguro)
                                          setState(() {
                                            _addedLocations.removeAt(index);
                                            selectedPoints.removeAt(index);
                                          });
                                          print(
                                            '⚠️ No se encontró referencia al marcador para eliminarlo del mapa.',
                                          );
                                        }
                                        // setState(() {
                                        //   _addedLocations.removeAt(index);
                                        //   selectedPoints.removeAt(index);
                                        // });
                                      },
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(color: Colors.grey, thickness: .5),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          //botones de zoom
          Positioned(
            top: 60,
            bottom: 150,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag:
                      "zoomInBtn", // Añade un heroTag único para evitar errores
                  onPressed: _zoomIn,
                  mini: true,
                  child: const Icon(Icons.add),
                ),
                // const SizedBox(height: 5),
                FloatingActionButton(
                  heroTag: "zoomOutBtn", // Añade un heroTag único
                  onPressed: _zoomOut,
                  mini: true,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          Positioned(
            top: 160,
            right: 20,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isNavigating)
                  FloatingActionButton(
                    // onPressed: () {},
                    onPressed: _startNavigation,
                    child: const Icon(Icons.navigation),
                  ),
                if (_isNavigating)
                  FloatingActionButton(
                    onPressed: _stopNavigation,
                    child: const Icon(Icons.stop),
                  ),
                SizedBox(height: 2),
                FloatingActionButton(
                  onPressed: () {
                    _updateCameraPosition(
                      mapbox.Position(
                        _currentPosition!.longitude,
                        _currentPosition!.latitude,
                      ),
                    );
                  },
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //all functional methods

  Future<void> _initTextToSpeech() async {
    await flutterTts.setLanguage('es-MX');
    await flutterTts.setSpeechRate(0.4);
  }

  Future<void> _requestLocationPermission() async {
    print('🌟🌟🌟🌟 request epermision');
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      print('Permiso de ubicación denegado.');
    }
  }

  // Un método auxiliar para mostrar SnackBar
  void _showSnackBar(String message) {
    if (mounted && ScaffoldMessenger.of(context).mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    print('㊗️ location');
    try {
      _mapboxMapController?.location.updateSettings(
        mapbox.LocationComponentSettings(enabled: true),
      );
      const geo.LocationSettings locationSettings = geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high, // Mayor precisión
        // Actualizar solo si la posición cambia más de 5 metros
        distanceFilter: 5,
        // timeLimit: Duration(milliseconds: 250),
      );
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      // _currentPosition = geo.Position(
      //   longitude: -122.39470445734368,
      //   latitude: 37.7080221537549,
      //   timestamp: DateTime.timestamp(),
      //   accuracy: 10,
      //   altitude: 3,
      //   altitudeAccuracy: 2,
      //   heading: 0,
      //   headingAccuracy: 0,
      //   speed: 0,
      //   speedAccuracy: 0,
      // );

      //movimiento usuario

      // _currentPosition = position;

      if (pointAnnotationManager != null && userMarker != null) {
        pointAnnotationManager!.update(
          mapbox.PointAnnotation(
            id: userMarker!.id,
            geometry: mapbox.Point(
              coordinates: mapbox.Position(
                _currentPosition!.longitude,
                _currentPosition!.latitude,
              ),
            ),
            image: userMarker!.image,
          ),
        );
      }

      positionStreamSubscription = geo.Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (geo.Position position) async {
          _currentPosition = position;
          print('👮‍♀️👮‍♀️👮‍♀️👮‍♀️👮‍♀️');

          // Actualizar el marcador del usuario directamente sin setState
          if (pointAnnotationManager != null && userMarker != null) {
            // Crea una copia del marcador existente con la nueva geometría
            final updatedMarker = mapbox.PointAnnotation(
              id: userMarker!.id, // Mismo ID para actualizar el existente
              geometry: mapbox.Point(
                coordinates: mapbox.Position(
                  _currentPosition!.longitude,
                  _currentPosition!.latitude,
                ),
              ),
              image: userMarker!.image, // Mantener la misma imagen
              // Puedes añadir aquí otras opciones que quieras mantener del marcador original
            );
            await pointAnnotationManager!.update(updatedMarker);
          } else if (pointAnnotationManager != null && userMarker == null) {
            // Si por alguna razón el marcador no se inicializó, créalo aquí
            await createMarker(
              assetPaTh: 'assets/user_marker.png',
              lat: _currentPosition!.latitude,
              lng: _currentPosition!.longitude,
              isUserMarker: true,
            );
          }

          if (_isNavigating) {
            _setNavigationPerspective(
              targetLat: _currentPosition!.latitude,
              targetLng: _currentPosition!.longitude,
              bearing:
                  _currentPosition!.heading, // Ajustar el rumbo de la cámara
            );
            _checkRouteProgress(); // <-- LLAMADA CLAVE
            // _updateRouteVisuals();
          }

          // Actualizar el marcador del usuario (si es necesario)

          //setState(() {}); // Actualiza la UI con la nueva posición
        },
        onError: (error) {
          print('Error al obtener la ubicación: $error');
        },
      );

      print('🌟 position ${position.longitude}');

      // setState(() {
      _currentPosition = position;
      // if (_mapboxMapController != null && !_isNavigating) {
      //   _updateCameraPosition(
      //     mapbox.Position(position.latitude, position.longitude),
      //   );
      // } else if (_mapboxMapController != null && _isNavigating) {
      //   _updateCameraPosition(
      //     mapbox.Position(position.latitude, position.longitude),
      //   );
      //   // En una app real, aquí se activaría la lógica de voz basada en los pasos
      // } else if (_mapboxMapController != null) {
      //   _updateCameraPosition(
      //     mapbox.Position(position.latitude, position.longitude),
      //   );
      // }
      // });
      // Future.delayed(Duration.zero, () async {
      //   // await _getRoute();
      // });
    } catch (e) {
      print('Error al obtener la ubicación: $e');
    }
    setState(() {});
  }

  void _updateCameraPosition(mapbox.Position latLng) {
    _mapboxMapController?.flyTo(
      // Usar flyTo en lugar de animateCamera
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(latLng.lng, latLng.lat),
        ),
        zoom: 15.0,
      ),

      mapbox.MapAnimationOptions(
        duration: 1000,
      ), // Puedes ajustar la duración de la animación
    );
  }

  // Future<void> _getRoute() async {
  //   print('🌟 get route');
  //   final String baseUrl =
  //       'https://api.mapbox.com/directions/v5/mapbox/driving';
  //   // 'https://api.mapbox.com/directions/v5/mapbox/driving-traffic';
  //   selectedPoints.insert(
  //     0,
  //     mapbox.Point(
  //       coordinates: mapbox.Position(
  //         _currentPosition!.longitude,
  //         _currentPosition!.latitude,
  //       ),
  //     ),
  //   );

  //   if (selectedPoints.length < 2) {
  //     print(
  //       '🖐️ Advertencia: Necesitas seleccionar al menos un lugar para calcular una ruta.',
  //     );
  //     // Limpia cualquier ruta anterior si es necesario
  //     if (_routePolyline != null) {
  //       await _polylineAnnotationManager?.delete(_routePolyline!);
  //       _routePolyline = null;
  //     }
  //     setState(() {
  //       routeCoordinates = [];
  //       routeSegmentsCoordinates = [];
  //       _routeSteps = [];
  //       _currentRouteStepIndex = 0;
  //       _isNavigating = false;
  //       // Reinicia cualquier otra variable de estado relacionada con la ruta
  //     });
  //     return;
  //   }
  //   print('🌟 coordinates ${selectedPoints.length}');
  //   // 2. Construir la cadena de coordenadas para la API
  //   String coordinatesString = selectedPoints
  //       .map((point) {
  //         return '${point.coordinates.lng},${point.coordinates.lat}';
  //       })
  //       .join(';');
  //   // for (var i = 1; i < selectedPoints.length; i++) {
  //   //   coordinates +=
  //   //       // '${deliverPoints[i - 1].coordinates.lng},${deliverPoints[i - 1].coordinates.lat};${deliverPoints[i].coordinates.lng},${deliverPoints[i].coordinates.lat};';
  //   //       '${selectedPoints[i - 1].coordinates.lng},${selectedPoints[i - 1].coordinates.lat};${selectedPoints[i].coordinates.lng},${selectedPoints[i].coordinates.lat};';
  //   // }
  //   // print('🌟 coordinates $coordinates');
  //   // String tempCoordinaes = coordinates.substring(0, coordinates.length - 1);

  //   // coordinates = '';
  //   // coordinates = tempCoordinaes;
  //   final String accessToken = widget.mapboxAccessToken;
  //   final String url =
  //       '$baseUrl/$coordinatesString?access_token=$accessToken&geometries=geojson&overview=full&steps=true&language=es&annotations=congestion';
  //   print('🌟 url $url');

  //   //sugerido por gemini
  //   try {
  //     final response = await http.get(Uri.parse(url));

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       mapboxModel = mapbox_model.mapboxModelFromJson(response.body);

  //       if (data['routes'] != null && data['routes'].isNotEmpty) {
  //         print('✅ Ruta obtenida exitosamente.');

  //         final route = data['routes'][0]; // Tomamos la primera ruta sugerida

  //         // **Manejo de múltiples legs (tramos de la ruta)**
  //         List<mapbox.Position> fullRouteCoords = [];
  //         List<dynamic> allSteps = [];
  //         List<mapbox_model.Leg> allLegs = []; // Para tu MapboxModel

  //         for (var leg in route['legs']) {
  //           print('#️⃣ leg contetnt ${leg['geometry']['coordinates'][0][1]}');
  //           // Asegúrate de que tu modelo mapbox_model.Leg pueda ser deserializado.
  //           // Si mapboxModel ya maneja esto, puedes confiar en él.
  //           // Esto es más un enfoque manual si no usas el modelo directamente aquí.

  //           // Extraer geometría de cada leg
  //           // Las coordenadas son List<dynamic> donde cada elemento es List<double> [lng, lat]
  //           List<dynamic> legCoordinates =
  //               leg['geometry'] != null ? leg['geometry']['coordinates'] : [];

  //           // Añadir las coordenadas de este leg a la lista completa
  //           for (var coordPair in legCoordinates) {
  //             fullRouteCoords.add(mapbox.Position(coordPair[0], coordPair[1]));
  //           }

  //           // Añadir los pasos de cada leg
  //           if (leg['steps'] != null) {
  //             allSteps.addAll(leg['steps']);
  //           }

  //           // Construir el objeto Leg para el MapboxModel si es necesario
  //           // Esto depende de cómo quieras procesar tus modelos.
  //           // mapbox_model.Leg currentLeg = mapbox_model.Leg.fromJson(leg);
  //           // allLegs.add(currentLeg);
  //         }

  //         // Asigna la geometría completa y todos los pasos
  //         // La lista de todas las coordenadas de la ruta
  //         print(
  //           '🐛DEBUG: fullRouteCoords tiene ${fullRouteCoords.length} puntos antes de asignar a routeCoordinates.',
  //         );
  //         routeCoordinates = fullRouteCoords;
  //         print(
  //           '🐛DEBUG: routeCoordinates ahora tiene ${routeCoordinates.length} puntos.',
  //         );
  //         _routeSteps = allSteps; // Todos los pasos combinados

  //         // Actualizar tu modelo principal de Mapbox
  //         mapboxModel = mapbox_model.mapboxModelFromJson(response.body);

  //         // Procesar información de tráfico y crear segmentos (ahora con todos los legs)
  //         if (mapboxModel!.routes != null && mapboxModel!.routes!.isNotEmpty) {
  //           await getTrafficList(mapboxModel!.routes![0]);
  //           // Ahora createCoordinatesSegments también procesará todos los legs del modelo
  //           await createCoordinatesSegments(
  //             legList: mapboxModel!.routes![0].legs!,
  //           );
  //         }

  //         // Dibuja la ruta en el mapa después de obtenerla y procesarla
  //         // Asumo que tienes esta función para dibujar la polilínea inicial.
  //         // await _addRouteToMap();
  //         //TODO: change for addpolyline

  //         setState(() {
  //           // Actualiza cualquier UI relacionada con la obtención de la ruta
  //           _currentRouteStepIndex = 0; // Reinicia el índice de pasos
  //           _hasSpokenInstructionForCurrentStep =
  //               false; // Reinicia bandera de voz
  //         });
  //       } else {
  //         print(
  //           '⚠️ No se encontraron rutas válidas en la respuesta de Mapbox.',
  //         );
  //         _showSnackBar(
  //           'No se pudo encontrar una ruta para los puntos seleccionados.',
  //         );
  //         // Considera limpiar rutas anteriores si no se encuentra una nueva.
  //       }
  //     } else {
  //       // Manejo de errores HTTP más específico
  //       String errorMessage =
  //           'Error al obtener la ruta. Código: ${response.statusCode}';
  //       if (response.body.isNotEmpty) {
  //         try {
  //           final errorData = jsonDecode(response.body);
  //           if (errorData['message'] != null) {
  //             errorMessage += '\nMensaje: ${errorData['message']}';
  //           }
  //         } catch (e) {
  //           errorMessage += '\nRespuesta: ${response.body}';
  //         }
  //       }
  //       print('❌ $errorMessage');
  //       _showSnackBar(errorMessage);
  //     }
  //   } catch (e) {
  //     print('❌ Excepción al obtener la ruta: $e');
  //     _showSnackBar(
  //       'Ocurrió un error al intentar obtener la ruta. Verifica tu conexión.',
  //     );
  //   }
  // }

  //v2 gemini
  Future<void> _getRoute() async {
    print('🌟 get route');
    final String baseUrl =
        'https://api.mapbox.com/directions/v5/mapbox/driving';

    selectedPoints.insert(
      0,
      mapbox.Point(
        coordinates: mapbox.Position(
          _currentPosition!.longitude,
          _currentPosition!.latitude,
        ),
      ),
    );

    if (selectedPoints.length < 2) {
      print(
        '🖐️ Advertencia: Necesitas seleccionar al menos un lugar para calcular una ruta.',
      );
      // Limpia cualquier ruta anterior si es necesario
      _removePolyline(); // Reusa la función de limpieza de polilíneas
      _highestTraversedPointIndex = -1; // Reiniciar
      setState(() {
        routeCoordinates.clear(); // Limpiar
        routeSegmentsCoordinates.clear(); // Limpiar
        _routeSteps.clear(); // Limpiar
        _currentRouteStepIndex = 0;
        _isNavigating = false;
      });
      return;
    }

    print('🌟 coordinates ${selectedPoints.length}');
    String coordinatesString = selectedPoints
        .map((point) => '${point.coordinates.lng},${point.coordinates.lat}')
        .join(';');

    final String accessToken = widget.mapboxAccessToken;
    final String url =
        '$baseUrl/$coordinatesString?access_token=$accessToken&geometries=geojson&overview=full&steps=true&language=es&annotations=congestion';
    print('🌟 url $url');
    print('🌟 url ${await http.get(Uri.parse(url))}');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          print('✅ Ruta obtenida exitosamente.');

          // *** CAMBIO CLAVE AQUÍ: Asigna el modelo una sola vez ***
          mapboxModel = mapbox_model.mapboxModelFromJson(response.body);
          print('DEBUG: mapboxModel asignado.');

          // Accede a la ruta principal del modelo
          final mapbox_model.Route? route = mapboxModel!.routes?.first;

          if (route != null) {
            // Poblar routeCoordinates directamente desde la geometría de la ruta principal
            if (route.geometry?.coordinates != null) {
              routeCoordinates =
                  route.geometry!.coordinates!
                      .map(
                        (coordPair) =>
                            mapbox.Position(coordPair[0], coordPair[1]),
                      )
                      .toList();
              print(
                'DEBUG: routeCoordinates poblada con ${routeCoordinates.length} puntos desde el modelo.',
              );
            } else {
              print(
                '⚠️ Advertencia: route.geometry.coordinates es nulo o vacío en el modelo.',
              );
              // Puedes tener un fallback aquí si realmente necesitas iterar sobre los steps si la geometría principal falta.
              // Por ahora, confiaremos en overview=full para llenar route.geometry.coordinates.
              routeCoordinates
                  .clear(); // Asegúrate de que esté vacía si no se puede poblar.
            }

            // Poblar _routeSteps desde el modelo (combinando todos los steps de todos los legs)
            _routeSteps.clear();
            if (route.legs != null) {
              for (var leg in route.legs!) {
                if (leg.steps != null) {
                  _routeSteps.addAll(
                    leg.steps!.map((s) => s.toJson()),
                  ); // Convierte Step model a Map<String,dynamic> para tu _routeSteps List<dynamic>
                }
              }
            }
            print('DEBUG: _routeSteps tiene ${_routeSteps.length} pasos.');

            // Procesar información de tráfico y crear segmentos
            await getTrafficList(route); // Pasa la ruta del modelo directamente
            await createCoordinatesSegments(
              legList: route.legs!,
            ); // Pasa los legs del modelo
            print(
              'DEBUG: getTrafficList y createCoordinatesSegments completados.',
            );
          } else {
            print('⚠️ El modelo no contiene rutas válidas.');
            routeCoordinates.clear();
            _routeSteps.clear();
            routeVisualSegments.clear();
            trafficSegments.clear();
            _highestTraversedPointIndex = -1;
          }

          setState(() {
            _currentRouteStepIndex = 0;
            _hasSpokenInstructionForCurrentStep = false;
          });

          // Llamada a _addRouteToMap()
          await _addPolyline(); // Asegúrate de que esta línea esté descomentada aquí.
          print('DEBUG: _addRouteToMap() completado desde _getRoute().');
        } else {
          print(
            '⚠️ No se encontraron rutas válidas en la respuesta de Mapbox.',
          );
          _showSnackBar(
            'No se pudo encontrar una ruta para los puntos seleccionados.',
          );
          routeCoordinates.clear();
          _routeSteps.clear();
          routeVisualSegments.clear();
          trafficSegments.clear();
          _highestTraversedPointIndex = -1;
        }
      } else {
        String errorMessage =
            'Error al obtener la ruta. Código: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData['message'] != null) {
              errorMessage += '\nMensaje: ${errorData['message']}';
            }
          } catch (e) {
            errorMessage += '\nRespuesta: ${response.body}';
          }
        }
        print('❌ $errorMessage');
        _showSnackBar(errorMessage);
        routeCoordinates.clear();
        _routeSteps.clear();
        routeVisualSegments.clear();
        trafficSegments.clear();
        _highestTraversedPointIndex = -1;
      }
    } catch (e) {
      print('❌ Excepción al obtener la ruta: $e');
      _showSnackBar(
        'Ocurrió un error al intentar obtener la ruta. Verifica tu conexión.',
      );
      routeCoordinates.clear();
      _routeSteps.clear();
      routeVisualSegments.clear();
      trafficSegments.clear();
      _highestTraversedPointIndex = -1;
    }
  }

  // v1 own
  // Future<void> getTrafficList(mapbox_model.Route routeModel) async {
  //   final List<dynamic> congestionLevels =
  //       routeModel.legs![0].annotation!.congestion!;
  //   String congestionLevel = '';
  //   for (
  //     int i = 0;
  //     i < routeModel.legs![0].annotation!.congestion!.length;
  //     i++
  //   ) {
  //     print(
  //       '😅 congestion lenght ${routeModel.legs![0].annotation!.congestion!.length}',
  //     );
  //     // Si rawCoordinates son pares de LatLng como [[lng, lat], [lng, lat], ...]
  //     // if (i + 1 < routeModel.geometry!.coordinates!.length) {
  //     //   final startCoord = routeModel.geometry!.coordinates![i];
  //     //   final endCoord = routeModel.geometry!.coordinates![i + 1];

  //     switch (congestionLevels[i]) {
  //       case mapbox_model.Congestion.LOW:
  //         congestionLevel = "low";
  //         break;
  //       case mapbox_model.Congestion.MODERATE:
  //         congestionLevel = "moderate";
  //         break;
  //       case mapbox_model.Congestion.HEAVY:
  //         congestionLevel = "heavy";
  //         break;
  //       case mapbox_model.Congestion.UNKNOWN:
  //         congestionLevel = "unknown";
  //         break;
  //       default:
  //     }

  //     // print('😅 congestion level $congestionLevel');
  //     congestionList.add(congestionLevel);
  //     print('😅 congestion level ${congestionList[i]}');

  //     // trafficSegments.add(
  //     //   MapboxFeature(
  //     //     // Una clase simple para representar tu Feature
  //     //     geometry: {
  //     //       'type': 'LineString',
  //     //       // 'coordinates': [startCoord, endCoord],
  //     //       'coordinates': routeCoordinates,
  //     //     },
  //     //     properties: {'mapbox_congestion_level': congestionLevel},
  //     //   ),
  //     // );
  //     // }
  //   }

  //   // for (var i = 0; i < trafficList.length; i++) {
  //   //   print('😅 ${trafficList[i]}');
  //   //   if (trafficList[i] != Congestion.UNKNOWN) {
  //   //     trafficIndexesList.add(i);
  //   //   }
  //   // }
  // }

  //v2 gemini
  Future<void> getTrafficList(mapbox_model.Route routeModel) async {
    print(
      '🌟 getTrafficList: Procesando niveles de congestión para la ruta...',
    );

    // Limpiar listas anteriores antes de rellenar
    congestionList.clear();
    trafficIndexesList.clear();
    trafficSegments.clear(); // Limpiamos los segmentos de tráfico anteriores

    if (routeModel.legs == null || routeModel.legs!.isEmpty) {
      print(
        '⚠️ Advertencia: No hay legs en el modelo de ruta para procesar congestión.',
      );
      return;
    }

    // Acumularemos todas las coordenadas de la ruta completa para referencia.
    // Esto ya debería estar en `routeCoordinates` de tu `_getRoute` function,
    // pero lo hacemos aquí por seguridad y claridad al asociar la congestión.
    List<mapbox.Position> fullRouteCoordinatesFromModel = [];
    // Usamos la geometría completa de la ruta si está disponible (overview=full)
    if (routeModel.geometry != null &&
        routeModel.geometry!.coordinates != null) {
      fullRouteCoordinatesFromModel =
          routeModel.geometry!.coordinates!
              .map((coordPair) => mapbox.Position(coordPair[0], coordPair[1]))
              .toList();
    } else {
      // Si no, concatenamos las geometrías de los pasos de cada leg
      for (var leg in routeModel.legs!) {
        if (leg.steps != null) {
          for (var step in leg.steps!) {
            if (step.geometry != null && step.geometry!.coordinates != null) {
              for (var coordPair in step.geometry!.coordinates!) {
                fullRouteCoordinatesFromModel.add(
                  mapbox.Position(coordPair[0], coordPair[1]),
                );
              }
            }
          }
        }
      }
    }

    // Índice para recorrer `fullRouteCoordinatesFromModel`
    int globalCoordinateIndex = 0;

    // Iterar a través de cada 'leg' (tramo) de la ruta
    for (int legIndex = 0; legIndex < routeModel.legs!.length; legIndex++) {
      final currentLeg = routeModel.legs![legIndex];

      if (currentLeg.annotation == null ||
          currentLeg.annotation!.congestion == null) {
        print(
          'ℹ️ Leg $legIndex no tiene anotaciones de congestión. Saltando este leg.',
        );
        // Incrementar el globalCoordinateIndex por las coordenadas de este leg si no tiene congestión
        // Esto es crucial para mantener la alineación si los legs tienen geometrías propias.
        if (currentLeg.steps != null) {
          for (var step in currentLeg.steps!) {
            if (step.geometry != null && step.geometry!.coordinates != null) {
              globalCoordinateIndex += step.geometry!.coordinates!.length;
            }
          }
        }
        continue; // Pasa al siguiente leg si no hay datos de congestión
      }

      final List<mapbox_model.Congestion> congestionLevelsForLeg =
          currentLeg.annotation!.congestion!;

      // Iterar sobre los niveles de congestión de este leg
      for (int i = 0; i < congestionLevelsForLeg.length; i++) {
        String currentCongestionLevelString = "unknown"; // Default
        switch (congestionLevelsForLeg[i]) {
          case mapbox_model.Congestion.LOW:
            currentCongestionLevelString = "low";
            break;
          case mapbox_model.Congestion.MODERATE:
            currentCongestionLevelString = "moderate";
            break;
          case mapbox_model.Congestion.HEAVY:
            currentCongestionLevelString = "heavy";
            break;
          case mapbox_model.Congestion.SEVERE:
            currentCongestionLevelString = "severe";
            break;
          case mapbox_model.Congestion.UNKNOWN:
            currentCongestionLevelString = "unknown";
            break;
        }
        congestionList.add(currentCongestionLevelString);

        // Si el nivel no es UNKNOWN, lo añadimos a la lista de índices de tráfico.
        // Este índice se refiere al índice dentro de la lista 'congestionList' combinada.
        if (congestionLevelsForLeg[i] != mapbox_model.Congestion.UNKNOWN) {
          trafficIndexesList.add(congestionList.length - 1);
        }

        // Para crear `MapboxFeature`s para la visualización de tráfico:
        // Mapbox Directions API proporciona la congestión para *segmentos* de la polilínea.
        // Cada elemento en `congestionLevelsForLeg` corresponde a un segmento entre
        // `(globalCoordinateIndex + i)` y `(globalCoordinateIndex + i + 1)` en la
        // `fullRouteCoordinatesFromModel`.

        if ((globalCoordinateIndex + i + 1) <
            fullRouteCoordinatesFromModel.length) {
          final startCoord =
              fullRouteCoordinatesFromModel[globalCoordinateIndex + i];
          final endCoord =
              fullRouteCoordinatesFromModel[globalCoordinateIndex + i + 1];

          trafficSegments.add(
            MapboxFeature(
              geometry: {
                'type': 'LineString',
                'coordinates': [
                  [startCoord.lng, startCoord.lat],
                  [endCoord.lng, endCoord.lat],
                ],
              },
              properties: {
                'mapbox_congestion_level': currentCongestionLevelString,
              },
            ),
          );
        }
      }
      // Después de procesar todos los segmentos de congestión de este leg,
      // actualiza el `globalCoordinateIndex` para el inicio del siguiente leg.
      // Esto es crucial si la congestión está indexada por la geometría total de la ruta.
      // Si la congestión se aplica a cada punto consecutivo del leg.geometry.coordinates,
      // entonces sumamos la longitud de las coordenadas de los pasos del leg.
      if (currentLeg.steps != null) {
        for (var step in currentLeg.steps!) {
          if (step.geometry != null && step.geometry!.coordinates != null) {
            globalCoordinateIndex += step.geometry!.coordinates!.length;
          }
        }
      }
    }
    print(
      '✅ Finalizado el procesamiento de congestión. Total de segmentos de congestión: ${trafficSegments.length}',
    );
  }

  //v1 own
  // Future<void> createCoordinatesSegments({required List<Leg> legList}) async {
  //   for (var i = 0; i < legList.length; i++) {
  //     for (var j = 0; j < legList[i].steps!.length; i++) {
  //       if (legList[i].steps![j].geometry!.coordinates!.length < 5) {
  //         for (
  //           var k = 0;
  //           k < legList[i].steps![j].geometry!.coordinates!.length;
  //           k++
  //         ) {
  //           routeSegmentsCoordinates.add(
  //             mapbox.Position(
  //               legList[i].steps![j].geometry!.coordinates![k][0],
  //               legList[i].steps![j].geometry!.coordinates![k][1],
  //             ),
  //           );
  //         }
  //       } else {
  //         for (var k = 0; k <= 5; k++) {
  //           routeSegmentsCoordinates.add(
  //             mapbox.Position(
  //               legList[i].steps![j].geometry!.coordinates![k][0],
  //               legList[i].steps![j].geometry!.coordinates![k][1],
  //             ),
  //           );
  //         }
  //         legList[i].steps![j].geometry!.coordinates!.removeRange(0, 5);
  //       }
  //     }
  //   }
  // }

  //v2 gemini
  // Future<void> createCoordinatesSegments({
  //   required List<mapbox_model.Leg> legList,
  // }) async {
  //   print('🌟 createCoordinatesSegments: Iniciando segmentación de la ruta...');

  //   routeSegmentsCoordinates
  //       .clear(); // Limpiar cualquier coordenada anterior acumulada
  //   routeVisualSegments.clear(); // Limpiar segmentos visuales anteriores
  //   features.clear(); // Limpiar features anteriores (si las usabas para esto)

  //   // Primero, concatena TODAS las coordenadas de la ruta completa de todos los legs y steps.
  //   // Es crucial que esta sea la misma secuencia de coordenadas que usas para dibujar
  //   // la polilínea completa de la ruta.
  //   // Tu `_getRoute` ya las obtiene en `routeCoordinates`.
  //   // Aquí podemos asegurarnos de que `routeCoordinates` esté poblada con todos los puntos.
  //   if (routeCoordinates.isEmpty) {
  //     // Si `routeCoordinates` no está llena por `_getRoute`, la llenamos aquí
  //     for (var leg in legList) {
  //       if (leg.steps != null) {
  //         for (var step in leg.steps!) {
  //           if (step.geometry != null && step.geometry!.coordinates != null) {
  //             for (var coordPair in step.geometry!.coordinates!) {
  //               routeCoordinates.add(
  //                 mapbox.Position(coordPair[0], coordPair[1]),
  //               );
  //             }
  //           }
  //         }
  //       }
  //     }
  //   }

  //   // Ahora, segmenta la `routeCoordinates` completa
  //   final int totalCoordinates = routeCoordinates.length;
  //   int currentSegmentStartIndex = 0;
  //   // Inicializa Uuid aquí si no lo haces como variable de clase global
  //   final Uuid uuid = Uuid();

  //   while (currentSegmentStartIndex < totalCoordinates - 1) {
  //     int segmentEndIndex = currentSegmentStartIndex + _segmentPointsThreshold;
  //     if (segmentEndIndex >= totalCoordinates) {
  //       segmentEndIndex =
  //           totalCoordinates - 1; // Asegura que no exceda el final de la lista
  //     }

  //     List<mapbox.Position> segmentCoords = [];
  //     // Incluye el punto final del segmento anterior como el inicio del actual para continuidad
  //     // Esto asegura que los segmentos se "unan" visualmente
  //     if (currentSegmentStartIndex > 0) {
  //       segmentCoords.add(routeCoordinates[currentSegmentStartIndex - 1]);
  //     }

  //     // Asegúrate de que el segmento tenga al menos dos puntos para formar una línea
  //     if (segmentEndIndex - currentSegmentStartIndex < 1) {
  //       // Esto puede ocurrir si solo queda un punto al final. Lo añadimos si es el caso.
  //       segmentCoords.add(routeCoordinates[currentSegmentStartIndex]);
  //     } else {
  //       // Agrega los puntos dentro del rango del segmento
  //       for (int i = currentSegmentStartIndex; i <= segmentEndIndex; i++) {
  //         segmentCoords.add(routeCoordinates[i]);
  //       }
  //     }

  //     // Asegurarse de que el segmento tenga al menos 2 puntos para formar una LineString
  //     if (segmentCoords.length >= 2) {
  //       final String segmentId =
  //           uuid.v4(); // Generar un ID único para este segmento

  //       routeVisualSegments.add(
  //         RouteSegmentVisual(
  //           id: segmentId,
  //           coordinates: segmentCoords,
  //           isTraversed: false, // Inicialmente ningún segmento está recorrido
  //         ),
  //       );
  //     }

  //     // Mueve el índice de inicio al final del segmento actual para el siguiente
  //     // Asegúrate de avanzar correctamente para evitar solapamientos o saltos.
  //     // Avanzamos por el número de puntos del umbral, pero el último punto es el inicio del siguiente
  //     currentSegmentStartIndex += _segmentPointsThreshold;
  //   }

  //   print(
  //     '✅ Segmentación de ruta completada. Total de segmentos visuales creados: ${routeVisualSegments.length}',
  //   );

  //   // Opcional: Si quieres ver las coordenadas de un segmento
  //   // if (routeVisualSegments.isNotEmpty) {
  //   //   print('Primer segmento de ejemplo: ${routeVisualSegments[0].coordinates.map((p) => '${p.lng},${p.lat}').join(';')}');
  //   // }
  // }

  //v3 gemini
  // Future<void> createCoordinatesSegments({
  //   required List<mapbox_model.Leg> legList,
  // }) async {
  //   print(
  //     '🌟 createCoordinatesSegments: Iniciando segmentación de la ruta por pasos...',
  //   );

  //   routeVisualSegments.clear(); // Limpiar segmentos visuales anteriores
  //   // No necesitas limpiar `routeCoordinates` aquí, ya _getRoute lo maneja si se genera completa.

  //   // Acumulamos todas las coordenadas de la ruta completa para referencia general
  //   // Esto lo hace _getRoute() en `routeCoordinates`.
  //   // Aquí podemos asegurarnos de que `_routeSteps` esté poblada correctamente.
  //   if (_routeSteps.isEmpty &&
  //       mapboxModel?.routes != null &&
  //       mapboxModel!.routes!.isNotEmpty) {
  //     // Esto solo ocurriría si _getRoute() no llenó _routeSteps por alguna razón.
  //     // Normalmente, _routeSteps ya estaría llena.
  //     for (var leg in mapboxModel!.routes![0].legs!) {
  //       if (leg.steps != null) {
  //         _routeSteps.addAll(leg.steps!);
  //       }
  //     }
  //   }

  //   int globalSegmentCounter = 0; // Para IDs únicos

  //   // Iterar a través de cada paso de la ruta completa (de todos los legs)
  //   // Usamos _routeSteps que ya combina todos los pasos de todos los legs.
  //   for (int stepIndex = 0; stepIndex < _routeSteps.length; stepIndex++) {
  //     final currentStep = _routeSteps[stepIndex];
  //     if (currentStep['geometry'] == null ||
  //         currentStep['geometry']['coordinates'] == null) {
  //       continue; // Salta si el paso no tiene geometría
  //     }

  //     // Convertir las coordenadas del paso a mapbox.Position
  //     List<mapbox.Position> stepCoords =
  //         (currentStep['geometry']['coordinates'] as List)
  //             .map((coordPair) => mapbox.Position(coordPair[0], coordPair[1]))
  //             .toList();

  //     // Si el step tiene pocas coordenadas (es corto), lo consideramos un solo segmento
  //     if (stepCoords.length <= _segmentPointsThreshold) {
  //       if (stepCoords.length >= 2) {
  //         // Un segmento necesita al menos 2 puntos
  //         final String segmentId = uuid.v4();
  //         routeVisualSegments.add(
  //           RouteSegmentVisual(
  //             id: segmentId,
  //             coordinates: stepCoords,
  //             isTraversed: false,
  //             stepIndex: stepIndex, // Asociar al índice del step
  //             segmentNumber: globalSegmentCounter,
  //           ),
  //         );
  //         globalSegmentCounter++;
  //       }
  //     } else {
  //       // Si el step es largo, subdividirlo en segmentos más pequeños
  //       int currentStepCoordIndex = 0;
  //       while (currentStepCoordIndex < stepCoords.length - 1) {
  //         int segmentEndCoordIndex =
  //             currentStepCoordIndex + _segmentPointsThreshold;
  //         if (segmentEndCoordIndex >= stepCoords.length) {
  //           segmentEndCoordIndex =
  //               stepCoords.length - 1; // Último punto del step
  //         }

  //         // Asegurarse de que el segmento tenga al menos 2 puntos
  //         List<mapbox.Position> subSegmentCoords = [];
  //         // Incluir el último punto del segmento anterior para continuidad si es una subdivisión interna del step
  //         if (currentStepCoordIndex > 0 &&
  //             currentStepCoordIndex ==
  //                 (currentStepCoordIndex - _segmentPointsThreshold + 1)) {
  //           // Evitar añadir el mismo punto si es el inicio del step
  //           subSegmentCoords.add(stepCoords[currentStepCoordIndex - 1]);
  //         }

  //         // Añadir puntos del sub-segmento
  //         for (int i = currentStepCoordIndex; i <= segmentEndCoordIndex; i++) {
  //           subSegmentCoords.add(stepCoords[i]);
  //         }

  //         if (subSegmentCoords.length >= 2) {
  //           final String segmentId = uuid.v4();
  //           routeVisualSegments.add(
  //             RouteSegmentVisual(
  //               id: segmentId,
  //               coordinates: subSegmentCoords,
  //               isTraversed: false,
  //               stepIndex: stepIndex, // Asociar al índice del step
  //               segmentNumber: globalSegmentCounter,
  //             ),
  //           );
  //           globalSegmentCounter++;
  //         }

  //         currentStepCoordIndex += _segmentPointsThreshold;
  //       }
  //     }
  //   }

  //   print(
  //     '✅ Segmentación de ruta completada. Total de segmentos visuales creados: ${routeVisualSegments.length}',
  //   );

  //   // Puedes verificar los primeros segmentos creados:
  //   // if (routeVisualSegments.isNotEmpty) {
  //   //   print('Primer segmento visual: ID: ${routeVisualSegments[0].id}, Puntos: ${routeVisualSegments[0].coordinates.length}');
  //   // }
  // }

  // v4 gemini
  Future<void> createCoordinatesSegments({
    required List<mapbox_model.Leg> legList,
  }) async {
    print(
      '🌟 createCoordinatesSegments: Iniciando segmentación de la ruta por pasos...',
    );

    routeVisualSegments.clear(); // Limpiar segmentos visuales anteriores

    // Asegurarse de que _routeSteps esté poblada y sea una List<Step> o List<dynamic> con Map<String, dynamic>
    // Si _routeSteps contiene instancias de mapbox_model.Step, no necesitamos mapboxModel.routes![0].legs!
    // Y la forma de acceso es con '.' notación.

    // Si _routeSteps se llena con Map<String, dynamic> (por .toJson()), esta parte está bien:
    // (currentStep['geometry']['coordinates'] as List)

    // Si _routeSteps se llena con instancias de mapbox_model.Step, así es como debes acceder:
    List<dynamic> effectiveRouteSteps;
    if (_routeSteps.isNotEmpty && _routeSteps.first is mapbox_model.Step) {
      effectiveRouteSteps =
          _routeSteps.cast<mapbox_model.Step>(); // Castear si son objetos Step
    } else {
      // Si _routeSteps fue llenado con Map<String, dynamic> (ej. `s.toJson()`)
      // o está vacío, procedemos con los pasos del modelo.
      // Asumiremos que si no es de tipo Step, entonces es Map<String, dynamic> o vacío.
      // Esto es un punto crítico. La forma más segura es volver a obtener los pasos del modelo:
      effectiveRouteSteps = [];
      if (mapboxModel != null &&
          mapboxModel!.routes != null &&
          mapboxModel!.routes!.isNotEmpty) {
        for (var leg in mapboxModel!.routes![0].legs!) {
          if (leg.steps != null) {
            effectiveRouteSteps.addAll(
              leg.steps!,
            ); // Aquí serán instancias de mapbox_model.Step
          }
        }
      }
      // Asegurarse de que _routeSteps se actualice con estos si no estaba.
      if (_routeSteps.isEmpty) {
        _routeSteps = effectiveRouteSteps;
      }
    }

    int globalSegmentCounter = 0;

    for (
      int stepIndex = 0;
      stepIndex < effectiveRouteSteps.length;
      stepIndex++
    ) {
      final currentStep =
          effectiveRouteSteps[stepIndex]
              as mapbox_model.Step; // <-- ¡Castear a Step!

      if (currentStep.geometry == null ||
          currentStep.geometry!.coordinates == null) {
        // <-- ¡Usar notación de punto!
        continue;
      }

      // Convertir las coordenadas del paso a mapbox.Position
      List<mapbox.Position> stepCoords =
          currentStep
              .geometry!
              .coordinates! // <-- ¡Usar notación de punto!
              .map((coordPair) => mapbox.Position(coordPair[0], coordPair[1]))
              .toList();

      // ... (el resto de tu lógica de subdivisión de segmentos, sin cambios en esta parte) ...
      if (stepCoords.length <= _segmentPointsThreshold) {
        if (stepCoords.length >= 2) {
          final String segmentId = uuid.v4();
          routeVisualSegments.add(
            RouteSegmentVisual(
              id: segmentId,
              coordinates: stepCoords,
              isTraversed: false,
              stepIndex: stepIndex,
              isHidden: false,
              segmentNumber: globalSegmentCounter,
            ),
          );
          globalSegmentCounter++;
        }
      } else {
        int currentStepCoordIndex = 0;
        while (currentStepCoordIndex < stepCoords.length - 1) {
          int segmentEndCoordIndex =
              currentStepCoordIndex + _segmentPointsThreshold;
          if (segmentEndCoordIndex >= stepCoords.length) {
            segmentEndCoordIndex = stepCoords.length - 1;
          }

          List<mapbox.Position> subSegmentCoords = [];
          if (currentStepCoordIndex > 0 &&
              currentStepCoordIndex ==
                  (currentStepCoordIndex - _segmentPointsThreshold + 1)) {
            subSegmentCoords.add(stepCoords[currentStepCoordIndex - 1]);
          }

          for (int i = currentStepCoordIndex; i <= segmentEndCoordIndex; i++) {
            subSegmentCoords.add(stepCoords[i]);
          }

          if (subSegmentCoords.length >= 2) {
            final String segmentId = uuid.v4();
            routeVisualSegments.add(
              RouteSegmentVisual(
                id: segmentId,
                coordinates: subSegmentCoords,
                isTraversed: false,
                isHidden: false,
                stepIndex: stepIndex,
                segmentNumber: globalSegmentCounter,
              ),
            );
            globalSegmentCounter++;
          }
          currentStepCoordIndex += _segmentPointsThreshold;
        }
      }
    }

    print(
      '✅ Segmentación de ruta completada. Total de segmentos visuales creados: ${routeVisualSegments.length}',
    );
  }

  // Future<void> createMarker({
  //   required String assetPaTh,
  //   required double lat,
  //   required double lng,
  //   required bool isUserMarker,
  // }) async {
  //   // print('🟢 lat1 $lat, lng1 $lng');
  //   // print(
  //   //   '🟢 lat2 ${_currentPosition!.latitude}, lng2 ${_currentPosition!.longitude}',
  //   // );
  //   // if (_mapboxMapController != null && _currentPosition != null) {
  //   //   _mapboxMapController!.annotations.createPointAnnotationManager().then((
  //   //     pointAnnotationManager,
  //   //   ) async {
  //   final ByteData bytes = await rootBundle.load(assetPaTh);
  //   final Uint8List list = bytes.buffer.asUint8List();

  //   pointAnnotationManager ??=
  //       await _mapboxMapController!.annotations.createPointAnnotationManager();

  //   if (isUserMarker) {
  //     if (userMarker != null) {
  //       try {
  //         await pointAnnotationManager!.delete(userMarker!);
  //         userMarker = null; // Clear the reference after deletion
  //       } catch (e) {
  //         print('Error deleting old user marker: $e');
  //         // This error itself might be the one you're seeing if the old marker was already gone.
  //         // You might need to be careful with the order of operations.
  //       }
  //     }
  //     // 2. Crear las opciones para el marcador
  //     mapbox.PointAnnotationOptions option = mapbox.PointAnnotationOptions(
  //       geometry: mapbox.Point(
  //         coordinates: mapbox.Position(lng, lat),
  //       ), // Coordenadas de ejemplo
  //       // Asegúrate de tener esta imagen en tus assets y cargada en el estilo
  //       image: list,
  //       textField: 'Mi Marcador Auto',
  //       textColor: Colors.red.value,
  //     );
  //     // pointAnnotationManager =
  //     //     await _mapboxMapController!.annotations
  //     //         .createPointAnnotationManager();
  //     userMarker = (await pointAnnotationManager!.create(option));
  //   } else {
  //     var options = <mapbox.PointAnnotationOptions>[];
  //     options.add(
  //       mapbox.PointAnnotationOptions(
  //         geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
  //         image: list,
  //       ),
  //     );
  //     await pointAnnotationManager!.createMulti(options);
  //   }

  //   setState(() {});
  // }

  // v2 gemini
  // Future<void> createMarker({
  //   required String assetPaTh,
  //   required double lat,
  //   required double lng,
  //   required bool isUserMarker,
  // }) async {
  //   // Asegúrate de que _mapboxMapController no sea nulo antes de continuar
  //   if (_mapboxMapController == null) {
  //     print(
  //       '❌ Error: _mapboxMapController es nulo. No se pueden crear marcadores.',
  //     );
  //     return;
  //   }

  //   // Carga la imagen del asset
  //   final ByteData bytes = await rootBundle.load(assetPaTh);
  //   final Uint8List list = bytes.buffer.asUint8List();

  //   // Inicializa el pointAnnotationManager si es nulo.
  //   // Es mejor inicializarlo en `onMapCreated` o `initState`
  //   // para asegurar que esté listo cuando el mapa lo esté,
  //   // pero esta es una buena salvaguarda.
  //   pointAnnotationManager ??=
  //       await _mapboxMapController!.annotations.createPointAnnotationManager();

  //   if (isUserMarker) {
  //     // Si ya existe un marcador de usuario, lo intentamos eliminar.
  //     // Esto es más robusto si `userMarker` ya tiene un ID asignado.
  //     if (userMarker != null) {
  //       try {
  //         await pointAnnotationManager!.delete(userMarker!);
  //         userMarker =
  //             null; // Limpia la referencia después de la eliminación exitosa
  //         print('✅ Marcador de usuario anterior eliminado.');
  //       } catch (e) {
  //         // Capturamos cualquier error durante la eliminación.
  //         // Si el marcador ya no existe en el manager, `delete` puede lanzar un error.
  //         // Esto no debería detener la creación del nuevo marcador.
  //         print(
  //           '⚠️ Advertencia: Error al intentar eliminar marcador de usuario anterior: $e',
  //         );
  //       }
  //     }

  //     // 2. Crear las opciones para el nuevo marcador del usuario
  //     mapbox.PointAnnotationOptions option = mapbox.PointAnnotationOptions(
  //       geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
  //       image: list, // La imagen cargada del asset
  //       textField: 'Mi Ubicación', // Un texto descriptivo
  //       textColor: Colors.blue.value, // Cambié a azul para el usuario
  //     );

  //     // Crea el nuevo marcador y asigna su referencia a userMarker
  //     userMarker = await pointAnnotationManager!.create(option);
  //     print('✅ Marcador de usuario creado en Lat: $lat, Lng: $lng');
  //   } else {
  //     // Lógica para crear otros marcadores (no el de usuario)
  //     var options = <mapbox.PointAnnotationOptions>[];
  //     options.add(
  //       mapbox.PointAnnotationOptions(
  //         geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
  //         image: list, // La imagen cargada
  //       ),
  //     );
  //     // *** CAMBIO CLAVE AQUÍ: Filtrar los posibles nulls ***
  //     final List<mapbox.PointAnnotation?> createdMarkersWithNulls =
  //         await pointAnnotationManager!.createMulti(options);

  //     // Filtrar cualquier null y añadir solo los marcadores válidos
  //     final List<mapbox.PointAnnotation> validCreatedMarkers =
  //         createdMarkersWithNulls.whereType<mapbox.PointAnnotation>().toList();
  //     // Añadir solo los válidos a la lista de destinos
  //     _destinationMarkers.addAll(validCreatedMarkers);

  //     // Usamos createMulti incluso para uno solo, es una API flexible.
  //     //  await pointAnnotationManager!.createMulti(options);
  //     print('✅ Marcador adicional creado en Lat: $lat, Lng: $lng');
  //   }

  //   // Consideración para `setState`:
  //   // Si los únicos cambios visuales son en el mapa (marcadores),
  //   // y estos se manejan a través de `pointAnnotationManager.create/update/delete`,
  //   // entonces `setState` aquí podría no ser estrictamente necesario para la UI del mapa.
  //   // Sin embargo, si otros widgets fuera del mapa dependen del estado de los marcadores
  //   // (ej. una lista de puntos, un contador), entonces mantenlo.
  //   // Por ahora, lo mantenemos por seguridad.
  //   if (mounted) {
  //     // Asegura que el widget esté montado antes de llamar a setState
  //     setState(() {});
  //   }
  // }

  // v3 gemini
  Future<List<mapbox.PointAnnotation>> createMarker({
    required String assetPaTh,
    required double lat,
    required double lng,
    required bool isUserMarker,
  }) async {
    // Asegúrate de que _mapboxMapController no sea nulo antes de continuar
    if (_mapboxMapController == null) {
      print(
        '❌ Error: _mapboxMapController es nulo. No se pueden crear marcadores.',
      );
      return []; // Retorna una lista vacía si el controlador no está listo
    }

    // Carga la imagen del asset
    final ByteData bytes = await rootBundle.load(assetPaTh);
    final Uint8List list = bytes.buffer.asUint8List();

    // Inicializa el pointAnnotationManager si es nulo.
    // Esto es una buena salvaguarda si no se inicializó en onMapCreated.
    pointAnnotationManager ??=
        await _mapboxMapController!.annotations.createPointAnnotationManager();

    // Esta lista almacenará los marcadores que se crearán y se devolverán
    List<mapbox.PointAnnotation> createdValidMarkers = [];

    if (isUserMarker) {
      // --- Lógica para el Marcador del Usuario ---
      if (userMarker != null) {
        try {
          await pointAnnotationManager!.delete(userMarker!);
          userMarker =
              null; // Limpia la referencia después de la eliminación exitosa
          print('✅ Marcador de usuario anterior eliminado.');
        } catch (e) {
          print(
            '⚠️ Advertencia: Error al intentar eliminar marcador de usuario anterior: $e',
          );
        }
      }

      // Crear las opciones para el nuevo marcador del usuario
      mapbox.PointAnnotationOptions option = mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
        image: list, // La imagen cargada del asset
        textField: 'Mi Ubicación', // Un texto descriptivo
        textColor: Colors.blue.value, // Color para el texto del marcador
      );

      // Crea el nuevo marcador y asigna su referencia a userMarker
      userMarker = await pointAnnotationManager!.create(option);
      if (userMarker != null) {
        createdValidMarkers.add(userMarker!); // Añadir a la lista a devolver
        print('✅ Marcador de usuario creado en Lat: $lat, Lng: $lng');
      } else {
        print('⚠️ Fallo al crear el marcador de usuario.');
      }
    } else {
      // --- Lógica para Otros Marcadores (Destinos) ---
      mapbox.PointAnnotationOptions option = mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
        image: list, // La imagen cargada
      );

      // Usamos createMulti incluso para uno solo, es una API flexible y devuelve una lista.
      final List<mapbox.PointAnnotation?> createdMarkersWithNulls =
          await pointAnnotationManager!.createMulti([
            option,
          ]); // createMulti espera una lista

      // Filtrar cualquier null y añadir solo los marcadores válidos
      final List<mapbox.PointAnnotation> validMarkersFromMulti =
          createdMarkersWithNulls.whereType<mapbox.PointAnnotation>().toList();

      _destinationMarkers.addAll(
        validMarkersFromMulti,
      ); // Añadir a la lista global de destinos
      createdValidMarkers.addAll(
        validMarkersFromMulti,
      ); // Añadir a la lista a devolver
      print(
        '✅ Marcador adicional creado en Lat: $lat, Lng: $lng. Añadido a _destinationMarkers y devuelto.',
      );
    }

    // No necesitamos setState() aquí. La creación/actualización/eliminación de anotaciones
    // en Mapbox Maps Flutter ya actualiza el mapa directamente.
    // El setState() si fuera necesario sería en el widget padre si la UI de Flutter (fuera del mapa)
    // necesita reflejar cambios en _destinationMarkers o userMarker.
    // if (mounted) {
    //   setState(() {});
    // }

    return createdValidMarkers; // Siempre devuelve una lista de marcadores válidos
  }

  Future<void> _setNavigationPerspective({
    required double targetLat,
    required double targetLng,
    double zoom = 15.0, // Zoom por defecto
    double pitch = 50.0, // Inclinación por defecto para vista 3D
    double bearing = 0.0, // 0 grados = Norte arriba por defecto
  }) async {
    if (_mapboxMapController == null) {
      print('Error: MapboxMapController no está inicializado.');
      return;
    }

    final cameraOptions = mapbox.CameraOptions(
      center: mapbox.Point(
        coordinates: mapbox.Position(targetLng, targetLat),
      ), // Longitud, Latitud
      zoom: zoom,
      pitch: pitch, // Inclinación en grados
      bearing: bearing, // Rotación en grados (0-360)
    );

    // Usamos flyTo para una animación suave y natural
    await _mapboxMapController!.flyTo(
      cameraOptions,
      mapbox.MapAnimationOptions(
        duration: 1000,
      ), // Duración de la animación en ms
    );

    print(
      'Perspectiva del mapa cambiada a: Lat $targetLat, Lng $targetLng, Zoom $zoom, Pitch $pitch, Bearing $bearing',
    );
  }

  // void _startNavigation() async {
  //   // print('🟡 deliver points');
  //   await _getRoute();
  //   routeCoordinates = [];
  //   setState(() {
  //     // print('🟡 deliver points 2 + ${deliverPoints.length}');
  //     for (var i = 0; i < selectedPoints.length; i++) {
  //       createMarker(
  //         assetPaTh: 'assets/red_marker.png',
  //         // lat: deliverPoints[i].coordinates.lat.toDouble(),
  //         // lng: deliverPoints[i].coordinates.lng.toDouble(),
  //         lat: selectedPoints[i].coordinates.lat.toDouble(),
  //         lng: selectedPoints[i].coordinates.lng.toDouble(),
  //         isUserMarker: false,
  //       );
  //     }
  //     // for (var i = 0; i < deliverPoints.length; i++) {
  //     for (var i = 0; i < mapboxGeometry.length; i++) {
  //       // print('🟡 deliver points for = i $i');
  //       routeCoordinates.add(
  //         mapbox.Position(mapboxGeometry[i][0], mapboxGeometry[i][1]),
  //       );
  //     }
  //     // }
  //     Future.delayed(Duration.zero, () async {
  //       await _addPolyline();
  //     });
  //     // _startLocationTracking();
  //     _isNavigating = true;
  //     if (_routeSteps.isNotEmpty) {
  //       flutterTts.speak(_routeSteps.first['maneuver']['instruction']);
  //       _currentRouteStepIndex++;
  //     }
  //   });
  //   _listMapLayers();
  // }

  // v2 gemini
  void _startNavigation() async {
    print('🟡 _startNavigation: Iniciando navegación...');

    _highestTraversedPointIndex = -1; // Asegurarse de que se reinicia
    _lastTraversedSegmentIndex = -1; // Asegurarse de que se reinicia
    _currentRouteStepIndex = 0; // Asegurarse de que se reinicia
    _hasSpokenInstructionForCurrentStep =
        false; // Asegurarse de que se reinicia

    // 1. Obtener la ruta completa de Mapbox.
    // _getRoute() ya debe poblar this.routeCoordinates con la geometría completa
    // y this._routeSteps con todos los pasos.
    await _getRoute();

    // --- ELIMINAR ESTA LÍNEA ---
    // routeCoordinates = []; // Esto borraría las coordenadas que _getRoute acaba de obtener.
    // -------------------------

    // 2. Crear los segmentos visuales de la ruta para el seguimiento dinámico.
    // Esta función usará this.routeCoordinates.
    await createCoordinatesSegments(legList: mapboxModel!.routes![0].legs!);
    // Nota: Si `createCoordinatesSegments` ya llena `this.routeCoordinates` internamente,
    // y `_getRoute` también, asegúrate de que no haya duplicación o conflicto.
    // Idealmente, `_getRoute` llena `routeCoordinates` y `createCoordinatesSegments` la usa.

    setState(() {
      // 3. Añadir marcadores para los puntos de destino.
      // selectedPoints ya debe contener los puntos seleccionados por el usuario.
      // _getRoute() inserta el _currentPosition al inicio de la ruta,
      // pero esos no deben tener un marcador 'red_marker'.
      // Los selectedPoints son solo tus destinos intermedios y finales.
      // Asegúrate de que selectedPoints no incluya el punto inicial de la ruta
      // insertado por _getRoute() si no quieres un marcador rojo en el inicio.
      for (var i = 0; i < selectedPoints.length; i++) {
        createMarker(
          assetPaTh: 'assets/red_marker.png',
          lat: selectedPoints[i].coordinates.lat.toDouble(),
          lng: selectedPoints[i].coordinates.lng.toDouble(),
          isUserMarker: false, // Estos no son el marcador del usuario
        );
      }

      // --- ELIMINAR ESTE BUCLE ---
      // for (var i = 0; i < mapboxGeometry.length; i++) {
      //   // Esto es redundante si _getRoute ya pobló routeCoordinates
      //   routeCoordinates.add(
      //     mapbox.Position(mapboxGeometry[i][0], mapboxGeometry[i][1]),
      //   );
      // }
      // -------------------------

      // 4. Dibujar la polilínea inicial de la ruta (todos los segmentos).
      // Ahora, _addPolyline() debería usar `routeVisualSegments`.
      // La llamada Future.delayed(Duration.zero) no es necesaria si `routeCoordinates`
      // y `routeVisualSegments` ya están listos.
      // Llama a _addRouteToMap() que dibujará la ruta base y posiblemente los segmentos de tráfico.
      Future.delayed(Duration.zero, () async {
        // Lo mantengo por si hay alguna inicialización tardía del mapa
        await _addPolyline(); // Usaremos esta para dibujar la ruta segmentada
      });

      _isNavigating = true; // Establecer el estado de navegación

      // 5. Reproducir la primera instrucción de voz.
      if (_routeSteps.isNotEmpty) {
        // Correctly access as Map<String, dynamic>
        final Map<String, dynamic> firstStep =
            _routeSteps.first as Map<String, dynamic>; // <-- Corrected casting
        flutterTts.speak(
          firstStep['maneuver']['instruction'],
        ); // <-- Access using [] notation
        _currentRouteStepIndex++;
        _hasSpokenInstructionForCurrentStep = true;
      }
      // if (_routeSteps.isNotEmpty) {
      //   // Asegúrate de que _routeSteps ya esté poblada por _getRoute()
      //   flutterTts.speak(_routeSteps.first['maneuver']['instruction']);
      //   _currentRouteStepIndex++;
      //   _hasSpokenInstructionForCurrentStep = true; // Marcar que ya se habló
      // }
    });

    _listMapLayers(); // Para depuración
    print('✅ _startNavigation: Navegación iniciada.');
  }

  // void _stopNavigation() {
  //   setState(() {
  //     _isNavigating = false;
  //     // _mapboxMapController!.style.removeStyleLayer('route-line-layer');
  //     // _mapboxMapController!.style.removeStyleSource('route-source');
  //   });
  //   _removePolyline();
  // }

  //v2 gemini
  void _stopNavigation() async {
    // Hacerlo async para el await de delete
    print('🔴 _stopNavigation: Deteniendo navegación...');
    setState(() {
      _isNavigating = false;
      _addedLocations = [];
    });

    // Limpiar todas las polilíneas de la ruta y los marcadores de destino
    await _removePolyline(); // Eliminar la ruta segmentada (base y recorrida)
    await _removeAllDestinationMarkers(); // Necesitarás crear esta función

    // Limpiar estados relacionados con la ruta
    routeCoordinates.clear();
    routeSegmentsCoordinates.clear();
    routeVisualSegments.clear();
    features.clear();
    trafficSegments.clear();
    congestionList.clear();
    trafficIndexesList.clear();
    _routeSteps.clear();
    _currentRouteStepIndex = 0;
    _hasSpokenInstructionForCurrentStep = false;
    _lastConsumedSegmentIndex = -1;
    _lastTraversedSegmentIndex = -1;
    _highestTraversedPointIndex = -1;
    selectedPoints = [];

    // Si también quieres detener el stream de ubicación:
    // positionStreamSubscription?.cancel();

    print('✅ _stopNavigation: Navegación detenida y ruta eliminada.');
  }

  // Nueva función auxiliar para eliminar todos los marcadores de destino
  // Asume que los marcadores de destino se pueden distinguir del marcador de usuario
  // o que se guardan sus referencias en una lista separada.
  Future<void> _removeAllDestinationMarkers() async {
    if (pointAnnotationManager == null) {
      print('ℹ️ _removeAllDestinationMarkers: pointAnnotationManager es nulo.');
      return;
    }

    if (_destinationMarkers.isNotEmpty) {
      try {
        // *** CAMBIO CLAVE AQUÍ: Eliminar marcadores uno por uno ***
        for (var marker in _destinationMarkers) {
          await pointAnnotationManager!.delete(marker);
          print('DEBUG: Marcador ${marker.id} eliminado.');
        }

        _destinationMarkers.clear(); // Limpiar la lista después de eliminarlos
        print('✅ Todos los marcadores de destino eliminados exitosamente.');
      } catch (e) {
        print('❌ Error al eliminar marcadores de destino: $e');
      }
    } else {
      print('ℹ️ No hay marcadores de destino para eliminar.');
    }
    // if (pointAnnotationManager != null) {
    //   // Si tus marcadores de destino no están en una lista separada,
    //   // podrías necesitar una forma de distinguirlos o simplemente
    //   // borrarlos todos excepto el de usuario.
    //   // Una opción es mantener una List<PointAnnotation> para los destinos.
    //   // Por ahora, asumiré que los marcadores de destino se añadirán a una lista interna
    //   // o que puedes diferenciarlos.

    //   // Ejemplo (requiere almacenar los IDs de los marcadores de destino):
    //   // if (destinationMarkers.isNotEmpty) {
    //   //   await pointAnnotationManager!.deleteMulti(destinationMarkers.map((m) => m.id).toList());
    //   //   destinationMarkers.clear();
    //   // }

    //   // O si solo tienes el marcador de usuario y los de destino y quieres borrarlos todos
    //   // excepto el de usuario, sería más complejo sin IDs específicos.
    //   // La forma más fácil es mantener una lista de PointAnnotation para los destinos.

    //   // Placeholder: Puedes implementar la lógica específica aquí.
    //   print('ℹ️ Implementar _removeAllDestinationMarkers si es necesario.');
    // }
  }

  //v2 gemini
  String _toHexColorString(int argbValue) {
    // Mask out the alpha channel (0xFFFFFF) and convert to 6-digit hex
    return '#${(argbValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  // Future<void> _addPolyline() async {
  //   if (_mapboxMapController == null) return;

  //   print('🌟 _addRouteToMap: Añadiendo la ruta y capas de tráfico al mapa...');

  //   // Limpiar sources y layers existentes para evitar duplicados
  //   if (await _mapboxMapController!.style.styleLayerExists(
  //     'route-base-layer',
  //   )) {
  //     await _mapboxMapController!.style.removeStyleLayer('route-base-layer');
  //   }
  //   if (await _mapboxMapController!.style.styleLayerExists(
  //     'route-traffic-layer',
  //   )) {
  //     await _mapboxMapController!.style.removeStyleLayer('route-traffic-layer');
  //   }
  //   if (await _mapboxMapController!.style.styleSourceExists(
  //     'route-geojson-source',
  //   )) {
  //     await _mapboxMapController!.style.removeStyleSource(
  //       'route-geojson-source',
  //     );
  //   }

  //   // --- 2. Preparar Features para la Capa Base de Segmentos (Par/Impar) ---
  //   List<mapbox.Feature> baseSegmentFeatures = [];
  //   for (var visualSegment in routeVisualSegments) {
  //     baseSegmentFeatures.add(
  //       mapbox.Feature(
  //         id: visualSegment.id, // Usamos el ID único del segmento
  //         geometry: mapbox.LineString(coordinates: visualSegment.coordinates),
  //         properties: {
  //           'segment_number':
  //               visualSegment.segmentNumber, // Propiedad para el estilo
  //         },
  //       ),
  //     );
  //   }

  //   //debug
  //   final baseSegmentFeatureCollection = mapbox.FeatureCollection(
  //     features: baseSegmentFeatures,
  //   );
  //   final debugGeoJsonString = jsonEncode(
  //     baseSegmentFeatureCollection.toJson(),
  //   );
  //   print('DEBUG: JSON de Segmentos Base: $debugGeoJsonString');

  //   // await _mapboxMapController!.style.addSource(
  //   //   mapbox.GeoJsonSource(
  //   //     id: 'route-base-segments-source',
  //   //     data: debugGeoJsonString, // Usa la variable debug
  //   //   ),
  //   // );

  //   if (baseSegmentFeatures.isNotEmpty) {
  //     final baseSegmentFeatureCollection = mapbox.FeatureCollection(
  //       features: baseSegmentFeatures,
  //     );

  //     await _mapboxMapController!.style.addSource(
  //       mapbox.GeoJsonSource(
  //         id: 'route-base-segments-source', // Nueva fuente para los segmentos base
  //         data: jsonEncode(baseSegmentFeatureCollection.toJson()),
  //       ),
  //     );

  //     // await _mapboxMapController!.style.addSource(
  //     //   mapbox.GeoJsonSource(
  //     //     id: 'route-base-segments-source',
  //     //     data: debugGeoJsonString, // Usa la variable debug
  //     //   ),
  //     // );

  //     await _mapboxMapController!.style.addLayer(
  //       mapbox.LineLayer(
  //         id: 'route-base-segments-layer', // Nueva capa para los segmentos base
  //         sourceId: 'route-base-segments-source',
  //         lineWidth: 5.0,
  //         lineJoin: mapbox.LineJoin.ROUND,
  //         lineCap: mapbox.LineCap.ROUND,
  //         lineColorExpression: [
  //           'match',
  //           [
  //             '%',
  //             ['get', 'segment_number'],
  //             2,
  //           ],
  //           0, // If it's 0 (even)
  //           _toHexColorString(Colors.purple.toARGB32()), // <-- CORRECTED
  //           1, // If it's 1 (odd)
  //           _toHexColorString(Colors.orange.toARGB32()), // <-- CORRECTED
  //           _toHexColorString(Colors.grey.toARGB32()), // <-- CORRECTED
  //         ],
  //         // *** EXPRESIÓN CLAVE PARA COLORES PAR/IMPAR ***
  //         // lineColorExpression: [
  //         //   'match',
  //         //   [
  //         //     '%',
  //         //     ['get', 'segment_number'],
  //         //     2,
  //         //   ], // Calcula modulo 2 del segment_number
  //         //   0, // Si es 0 (par)
  //         //   Colors.purple.toARGB32(), // Color para segmentos pares
  //         //   1, // Si es 1 (impar)
  //         //   Colors.orange.toARGB32(), // Color para segmentos impares
  //         //   Colors.grey.toARGB32(), // Fallback (debería ser innecesario)
  //         // ],
  //       ),
  //     );
  //   }

  //   List<mapbox.Feature> allRouteFeatures = [];

  //   for (var trafficSeg in trafficSegments) {
  //     allRouteFeatures.add(
  //       mapbox.Feature(
  //         id:
  //             'traffic_${trafficSeg.properties['mapbox_congestion_level']}_${allRouteFeatures.length}',
  //         geometry: mapbox.LineString(
  //           coordinates:
  //               (trafficSeg.geometry['coordinates'] as List)
  //                   .map((c) => mapbox.Position(c[0], c[1]))
  //                   .toList(),
  //         ),
  //         properties: trafficSeg.properties,
  //       ),
  //     );
  //   }

  //   // if (_polylineAnnotationManager == null) {
  //   //   _polylineAnnotationManager =
  //   //       await _mapboxMapController!.annotations
  //   //           .createPolylineAnnotationManager();
  //   // }

  //   _polylineAnnotationManager ??=
  //       await _mapboxMapController!.annotations
  //           .createPolylineAnnotationManager();

  //   if (_unTraversedPolyline != null) {
  //     await _polylineAnnotationManager!.delete(_unTraversedPolyline!);
  //     _unTraversedPolyline = null;
  //   }
  //   if (_traversedPolyline != null) {
  //     await _polylineAnnotationManager!.delete(_traversedPolyline!);
  //     _traversedPolyline = null;
  //   }

  //   // Crear la PolylineAnnotation para la ruta base (no recorrida)
  //   _unTraversedPolyline = await _polylineAnnotationManager!.create(
  //     mapbox.PolylineAnnotationOptions(
  //       geometry: mapbox.LineString(coordinates: routeCoordinates),
  //       lineColor: Colors.green.toARGB32(),
  //       lineWidth: 5.0,
  //       lineOpacity: .5,
  //       // ELIMINADAS: lineJoin y lineCap
  //     ),
  //   );

  //   // Crear la PolylineAnnotation para la parte recorrida (inicialmente vacía o solo el primer punto)
  //   _traversedPolyline = await _polylineAnnotationManager!.create(
  //     mapbox.PolylineAnnotationOptions(
  //       geometry: mapbox.LineString(coordinates: []),
  //       lineColor: Colors.blue.toARGB32(),
  //       lineWidth: 5.0,
  //       // ELIMINADAS: lineJoin y lineCap
  //     ),
  //   );

  //   if (allRouteFeatures.isNotEmpty) {
  //     final trafficFeatureCollection = mapbox.FeatureCollection(
  //       features: allRouteFeatures,
  //     );
  //     await _mapboxMapController!.style.addSource(
  //       mapbox.GeoJsonSource(
  //         id: 'route-traffic-source',
  //         data: jsonEncode(trafficFeatureCollection.toJson()),
  //         // data: jsonEncode(trafficFeatureCollection.toJson()),
  //       ),
  //     );

  //     await _mapboxMapController!.style.addLayer(
  //       mapbox.LineLayer(
  //         id: 'route-traffic-layer',
  //         sourceId: 'route-traffic-source',
  //         lineColor: Colors.grey.toARGB32(),
  //         lineWidth: 5.0,
  //         lineJoin:
  //             mapbox.LineJoin.ROUND, // Estos SÍ son válidos para LineLayer
  //         lineCap: mapbox.LineCap.ROUND, // Estos SÍ son válidos para LineLayer
  //         lineOpacity: .2,
  //         lineColorExpression: [
  //           'match',
  //           ['get', 'mapbox_congestion_level'],
  //           'low',
  //           Colors.green.toARGB32(),
  //           'moderate',
  //           Colors.yellow.toARGB32(),
  //           'heavy',
  //           Colors.red.toARGB32(),
  //           'severe',
  //           Colors.purple.toARGB32(),
  //           'unknown',
  //           Colors.grey.toARGB32(),
  //           Colors.grey.toARGB32(),
  //         ],
  //       ),
  //     );
  //   }

  //   print('DEBUG: _traversedPolyline ID: ${_traversedPolyline?.id}');
  //   print('✅ _traversedPolyline inicializada y lista.');

  //   // Forzar un setState inicial para asegurar que todo se renderice
  //   if (mounted) {
  //     setState(() {});
  //   }

  //   print('✅ _addRouteToMap: Ruta y capas de tráfico añadidas exitosamente.');
  // }

  // v3 gemini}

  Future<void> _addPolyline() async {
    if (_mapboxMapController == null) return;

    print(
      '🌟 _addRouteToMap: Añadiendo la ruta base de segmentos (para borrado)...',
    );

    // 1. Limpiar TODAS las capas y fuentes relevantes existentes
    // Esto asegura un lienzo limpio.
    if (await _mapboxMapController!.style.styleLayerExists(
      'route-base-segments-layer',
    )) {
      await _mapboxMapController!.style.removeStyleLayer(
        'route-base-segments-layer',
      );
    }
    if (await _mapboxMapController!.style.styleSourceExists(
      'route-base-segments-source',
    )) {
      await _mapboxMapController!.style.removeStyleSource(
        'route-base-segments-source',
      );
    }
    // Si tenías capas de tráfico y quieres asegurarte de que también se limpien al inicio:
    if (await _mapboxMapController!.style.styleLayerExists(
      'route-traffic-layer',
    )) {
      await _mapboxMapController!.style.removeStyleLayer('route-traffic-layer');
    }
    if (await _mapboxMapController!.style.styleSourceExists(
      'route-traffic-source',
    )) {
      await _mapboxMapController!.style.removeStyleSource(
        'route-traffic-source',
      );
    }

    // Limpiar cualquier PolylineAnnotation residual (como la línea azul anterior)
    _polylineAnnotationManager ??=
        await _mapboxMapController!.annotations
            .createPolylineAnnotationManager();
    // Eliminar cualquier _traversedPolyline residual si existía
    if (_traversedPolyline != null) {
      await _polylineAnnotationManager!.delete(_traversedPolyline!);
      _traversedPolyline = null;
    }

    // 2. Preparar y añadir la Capa Base de Segmentos (Morado/Naranja que se hará transparente)
    List<mapbox.Feature> baseSegmentFeatures = [];
    for (var visualSegment in routeVisualSegments) {
      baseSegmentFeatures.add(
        mapbox.Feature(
          id: visualSegment.id, // ID único del segmento
          geometry: mapbox.LineString(coordinates: visualSegment.coordinates),
          properties: {
            'segment_number': visualSegment.segmentNumber,
            'is_traversed':
                visualSegment.isTraversed, // Inicialmente false para todos
            'is_hidden': visualSegment.isHidden,
          },
        ),
      );
    }

    if (baseSegmentFeatures.isNotEmpty) {
      final baseSegmentFeatureCollection = mapbox.FeatureCollection(
        features: baseSegmentFeatures,
      );
      await _mapboxMapController!.style.addSource(
        mapbox.GeoJsonSource(
          id: 'route-base-segments-source', // Fuente para los segmentos de la ruta base
          data: jsonEncode(baseSegmentFeatureCollection.toJson()),
        ),
      );

      await _mapboxMapController!.style.addLayer(
        mapbox.LineLayer(
          id: 'route-base-segments-layer', // Capa para los segmentos de la ruta base
          sourceId: 'route-base-segments-source',
          lineWidth: 5.0,
          lineJoin: mapbox.LineJoin.ROUND,
          lineCap: mapbox.LineCap.ROUND,
          // EXPRESIÓN CLAVE: Si 'is_traversed' es true, el color es transparente
          lineColorExpression: [
            'case',
            [
              '==',
              [
                '%',
                ['get', 'segment_number'],
                2,
              ],
              0,
            ], // Si es par
            _toHexColorString(Colors.purple.toARGB32()),
            _toHexColorString(
              Colors.orange.toARGB32(),
            ), // Si es impar (fallback)
          ],
          // *** ¡AÑADE EL FILTRO AQUÍ! ***
          filter: [
            '==', // Opera el filtro como 'si esta propiedad es igual a este valor'
            [
              'get',
              'is_hidden',
            ], // Obtiene el valor de la propiedad 'is_hidden'
            false, // Solo muestra la Feature si 'is_hidden' es FALSE
          ],
          // lineColorExpression: [
          //   'case',
          //   [
          //     '==',
          //     ['get', 'is_traversed'],
          //     true,
          //   ], // Si el segmento está recorrido
          //   // _toHexColorString(Colors.white.toARGB32()), // <-- ¡PRUEBA CON ESTE!
          //   // O si ves que el fondo es un gris muy claro, puedes probar:
          //   _toHexColorString(Colors.grey[50]!.toARGB32()),
          //   // _toHexColorStringRGB(Colors.grey[100]!.toARGB32()),

          //   // Si el segmento NO está recorrido (colores par/impar)
          //   [
          //     '==',
          //     [
          //       '%',
          //       ['get', 'segment_number'],
          //       2,
          //     ],
          //     0,
          //   ], // Si es par
          //   _toHexColorString(Colors.purple.toARGB32()),
          //   _toHexColorString(
          //     Colors.orange.toARGB32(),
          //   ), // Si es impar (fallback)
          // ],
          // lineColorExpression: [
          //   'case',
          //   [
          //     '==',
          //     [
          //       '%',
          //       ['get', 'segment_number'],
          //       2,
          //     ],
          //     0,
          //   ], // Si es par
          //   _toHexColorString(Colors.purple.toARGB32()),
          //   _toHexColorString(
          //     Colors.orange.toARGB32(),
          //   ), // Si es impar (fallback)
          // ],
          // *** CAMBIO 2: line-opacity controlara la visibilidad (borrado) ***
          // lineOpacityExpression: [
          //   'case',
          //   [
          //     '==',
          //     ['get', 'is_traversed'],
          //     true,
          //   ], // Si 'is_traversed' es true
          //   0.0, // Opacidad 0.0 (completamente transparente)
          //   1.0, // Opacidad 1.0 (completamente opaco, su color original)
          // ],
          // lineWidthExpression: [
          //   'case',
          //   [
          //     '==',
          //     ['get', 'is_traversed'],
          //     true,
          //   ], // Si el segmento está recorrido
          //   0.0, // Ancho 0.0 (invisible)
          //   5.0, // Ancho 5.0 (visible si no está recorrido)
          // ],
          // lineColorExpression: [
          //   'match',
          //   ['get', 'is_traversed'], // Pregunta por la propiedad 'is_traversed'
          //   true, // Si es TRUE (segmento recorrido)
          //   _toHexColorString(
          //     Colors.transparent.toARGB32(),
          //   ), // Hacemos el segmento COMPLETAMENTE TRANSPARENTE
          //   // Si es FALSE (segmento NO recorrido) o la propiedad no existe
          //   [
          //     '%',
          //     ['get', 'segment_number'],
          //     2,
          //   ], // Lógica original par/impar
          //   0,
          //   _toHexColorString(Colors.purple.toARGB32()),
          //   1,
          //   _toHexColorString(Colors.orange.toARGB32()),
          //   _toHexColorString(Colors.grey.toARGB32()), // Fallback
          // ],
        ),
      );
      print('DEBUG: Capa route-base-segments-layer AÑADIDA.');
    }

    // Ya no necesitamos añadir capas de tráfico aquí si el objetivo es solo el borrado.
    // Si las quieres de vuelta, asegúrate de que se añadan AQUÍ, después de la capa base de segmentos.

    // Ya no inicializamos _traversedPolyline (la línea azul)
    // porque el objetivo es solo borrar los segmentos base.

    // Forzar un setState inicial para asegurar que todo se renderice
    if (mounted) {
      setState(() {});
    }

    print('✅ _addRouteToMap: Ruta base de segmentos añadida exitosamente.');
  }

  ///modificadosv2
  // Future<void> _addPolyline() async {
  //   if (_mapboxMapController == null) return;

  //   // Reinicia las features cada vez que añades la ruta completa
  //   features = [];
  //   // Reinicia el mapeo también
  //   _segmentToFeatureIdMap = {};

  //   print('🏈 ${_routeSteps.length}');
  //   // _routeSteps no se está usando aquí, ¿debería ser mapboxModel?
  //   print('🏈 legs ${mapboxModel!.routes![0].legs!.length}');
  //   int globalStepCounter = 0;
  //   for (var k = 0; k < mapboxModel!.routes![0].legs!.length; k++) {
  //     // print('🏀 k $k');
  //     for (int i = 0; i < mapboxModel!.routes![0].legs![k].steps!.length; i++) {
  //       // Reinicia las coordenadas para CADA NUEVO SEGMENTO (step)
  //       List<mapbox.Position> segmentCoordinates = [];
  //       // print('🏉 i $i');

  //       // Bucle para recolectar TODAS las coordenadas de un step/segmento
  //       for (
  //         var j = 0;
  //         j <
  //             mapboxModel!
  //                 .routes![0]
  //                 .legs![k]
  //                 .steps![i]
  //                 .geometry!
  //                 .coordinates!
  //                 .length;
  //         j++
  //       ) {
  //         // print('🏈 j $j');
  //         segmentCoordinates.add(
  //           mapbox.Position(
  //             mapboxModel!
  //                 .routes![0]
  //                 .legs![k]
  //                 .steps![i]
  //                 .geometry!
  //                 .coordinates![j][0],
  //             mapboxModel!
  //                 .routes![0]
  //                 .legs![k]
  //                 .steps![i]
  //                 .geometry!
  //                 .coordinates![j][1],
  //           ),
  //         );
  //       } // FIN del bucle 'j' (todas las coordenadas para un segmento)

  //       // *************** CREA LA FEATURE PARA ESTE SEGMENTO ***************
  //       // Usa el contador global para generar un ID de segmento único y secuencial
  //       final segmentId = 'segment_$globalStepCounter';

  //       final lineString = mapbox.LineString(coordinates: segmentCoordinates);
  //       // El ID de la Feature también usa el segmentId
  //       final featureId = 'route_feature_$segmentId';
  //       final feature = mapbox.Feature(
  //         // ID único para esta Feature en Mapbox
  //         id: featureId,
  //         geometry: lineString,
  //         properties: {
  //           // Propiedad para identificar el segmento
  //           'segment_id': segmentId,
  //           // Puedes usar esto para estilos
  //           // 'mapbox_congestion_level': 'unknown',
  //           'mapbox_congestion_level': congestionList,
  //         },
  //       );

  //       // Añade la Feature completa del segmento a la lista global
  //       features.add(feature);
  //       // Guarda el mapeo segmentId -> featureId
  //       _segmentToFeatureIdMap[segmentId] = featureId;
  //       // Incrementa el contador para el próximo segmento
  //       globalStepCounter++;
  //       // FIN del bucle 'i' (steps)
  //     }
  //     // FIN del bucle 'k' (legs)
  //   }

  //   // ... el resto de tu código para crear FeatureCollection, añadir fuente y capa ...
  //   final featureCollection = mapbox.FeatureCollection(features: features);
  //   this.featureCollection =
  //       featureCollection; // Asumiendo que 'this.featureCollection' es para otro propósito

  //   final geoJsonString = featureCollection.toJson();

  //   if (await _mapboxMapController!.style.styleSourceExists('route-source')) {
  //     print('✅ eliminated sources');
  //     await _mapboxMapController!.style.removeStyleSource('route-source');
  //   }

  //   await _mapboxMapController!.style.addSource(
  //     mapbox.GeoJsonSource(id: 'route-source', data: jsonEncode(geoJsonString)),
  //   );

  //   if (await _mapboxMapController!.style.styleLayerExists(
  //     'route-line-layer',
  //   )) {
  //     await _mapboxMapController!.style.removeStyleLayer('route-line-layer');
  //   }

  //   await _mapboxMapController!.style.addLayer(
  //     mapbox.LineLayer(
  //       id: 'route-line-layer',
  //       sourceId: 'route-source',
  //       lineColor: Colors.blue.toARGB32(),
  //       lineWidth: 5.0,
  //       lineJoin: mapbox.LineJoin.ROUND,
  //       lineCap: mapbox.LineCap.ROUND,
  //       lineWidthExpression: [
  //         'interpolate',
  //         ['exponential', 1.5],
  //         ['zoom'],
  //         4.0,
  //         6.0,
  //         10.0,
  //         7.0,
  //         13.0,
  //         9.0,
  //         16.0,
  //         3.0,
  //         19.0,
  //         7.0,
  //         22.0,
  //         21.0,
  //       ],
  //       lineBorderWidthExpression: [
  //         'interpolate',
  //         ['exponential', 1.5],
  //         ['zoom'],
  //         9.0,
  //         1.0,
  //         16.0,
  //         3.0,
  //       ],
  //       lineColorExpression: [
  //         'match',
  //         ['get', 'mapbox_congestion_level'],
  //         'low',
  //         Colors.blue.toARGB32(),
  //         // Colors.green.toARGB32(),
  //         'moderate',
  //         Colors.yellow.toARGB32(),
  //         'heavy',
  //         Colors.red.toARGB32(),
  //         'severe',
  //         Colors.purple.toARGB32(),
  //         'unknown',
  //         Colors.grey.toARGB32(),
  //         // Colors.blue.toARGB32(),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _saveGeoJsonToDocuments(
    String geoJsonContent,
    String fileName,
  ) async {
    try {
      // 1. Obtener el directorio de documentos de la aplicación
      final directory = await getApplicationDocumentsDirectory();

      // Construye la ruta completa del archivo
      // Puedes crear subdirectorios si lo deseas, por ejemplo:
      // final appSpecificDirectory = Directory('${directory.path}/GeoJsonRoutes');
      // if (!await appSpecificDirectory.exists()) {
      //   await appSpecificDirectory.create(recursive: true);
      // }
      // final filePath = '${appSpecificDirectory.path}/$fileName.json';

      final filePath = '${directory.path}/$fileName.json';
      final file = File(filePath);

      // 2. Escribir el contenido JSON en el archivo
      await file.writeAsString(geoJsonContent);
      print('✅ Archivo JSON guardado en: $filePath');

      // Si aún quieres la opción de compartir después de guardar, puedes añadirlo aquí
      // await Share.shareXFiles([XFile(filePath)], text: 'GeoJSON guardado localmente.');
    } catch (e) {
      print('❌ Error al guardar el archivo JSON en documentos: $e');
    }
  }

  Future<void> _listMapLayers() async {
    if (_mapboxMapController == null) return;

    try {
      // Usar getStyleLayers() para obtener un listado de los IDs de las capas
      final allLayerIds = await _mapboxMapController!.style.getStyleLayers();

      print('✅ Capas actuales en el mapa (IDs):');
      for (var layerId in allLayerIds) {
        print('  - ID: ${layerId!.id}');
        // Si necesitas el tipo o más propiedades, tendrías que obtener la capa individualmente
        // y luego acceder a sus propiedades. Por ejemplo:
        // final layer = await _mapboxMapController!.style.getLayer(layerId);
        // print('    Type: ${layer.type}'); // Esto puede variar dependiendo del tipo de capa
      }
    } catch (e) {
      print('❌ Error al listar las capas del mapa: $e');
    }
  }

  //v2
  // Future<void> _removePolylineSegment(String segmentId) async {
  //   if (_mapboxMapController == null) return;

  //   print('🔴 segment id: $segmentId');
  //   final featureIdToRemove = _segmentToFeatureIdMap[segmentId];
  //   if (featureIdToRemove == null) {
  //     print('🔴 No feature ID found for segment: $segmentId');
  //     return;
  //   }

  //   // Filtra la Feature que queremos eliminar de la lista 'features'
  //   // Esta es la lista que se usó para construir el FeatureCollection original.
  //   print('😥 antes de remover: ${features.length}');
  //   features.removeWhere((feature) => feature.id == featureIdToRemove);
  //   print('😥 despues de remover: ${features.length}');

  //   // Crea una nueva FeatureCollection con las Features restantes
  //   final updatedFeatureCollection = mapbox.FeatureCollection(
  //     // Ahora 'features' ya no contiene la Feature eliminada
  //     features: features,
  //   );

  //   // Convierte el FeatureCollection a JSON String
  //   final updatedGeoJsonString = jsonEncode(updatedFeatureCollection.toJson());
  //   print('😥 geo updated: $updatedGeoJsonString');
  //   // _saveGeoJsonToDocuments(updatedGeoJsonString, 'geotest');

  //   // 1. Eliminar la capa si existe
  //   if (await _mapboxMapController!.style.styleLayerExists(
  //     'route-line-layer',
  //   )) {
  //     await _mapboxMapController!.style.removeStyleLayer('route-line-layer');
  //   }
  //   // 2. Eliminar la fuente si existe
  //   if (await _mapboxMapController!.style.styleSourceExists('route-source')) {
  //     await _mapboxMapController!.style.removeStyleSource('route-source');
  //   }

  //   // 3. Añadir la fuente con los datos ACTUALIZADOS
  //   await _mapboxMapController!.style.addSource(
  //     mapbox.GeoJsonSource(id: 'route-source', data: updatedGeoJsonString),
  //   );

  //   // 4. Volver a añadir la capa
  //   await _mapboxMapController!.style.addLayer(
  //     mapbox.LineLayer(
  //       id: 'route-line-layer',
  //       sourceId: 'route-source',
  //       lineColor:
  //           Colors.blue.toARGB32(), // Asegúrate de tener tus estilos aquí
  //       lineWidth: 5.0,
  //       lineJoin: mapbox.LineJoin.ROUND,
  //       lineCap: mapbox.LineCap.ROUND,
  //       lineWidthExpression: [
  //         'interpolate',
  //         ['exponential', 1.5],
  //         ['zoom'],
  //         4.0,
  //         6.0,
  //         10.0,
  //         7.0,
  //         13.0,
  //         9.0,
  //         16.0,
  //         3.0,
  //         19.0,
  //         7.0,
  //         22.0,
  //         21.0,
  //       ],
  //       lineBorderWidthExpression: [
  //         'interpolate',
  //         ['exponential', 1.5],
  //         ['zoom'],
  //         9.0,
  //         1.0,
  //         16.0,
  //         3.0,
  //       ],
  //       lineColorExpression: [
  //         'match',
  //         ['get', 'mapbox_congestion_level'],
  //         'low',
  //         Colors.green.toARGB32(),
  //         'moderate',
  //         Colors.yellow.toARGB32(),
  //         'heavy',
  //         Colors.red.toARGB32(),
  //         'severe',
  //         Colors.purple.toARGB32(),
  //         'unknown',
  //         Colors.grey.toARGB32(),
  //         Colors.blue.toARGB32(),
  //       ],
  //     ),
  //   );

  //   // Actualiza los datos de la fuente GeoJSON completa una sola vez
  //   // Esto recrea la fuente con el nuevo conjunto de Features.
  //   await _mapboxMapController!.style.updateGeoJSONSourceFeatures(
  //     'route-source',
  //     updatedGeoJsonString,
  //     // Pasamos la lista de Features actualizada
  //     features,
  //   );

  //   // Eliminar el ID del mapeo
  //   _segmentToFeatureIdMap.remove(segmentId);
  //   setState(() {}); // Para que el UI se actualice si depende de este estado.
  // }

  // Future<void> _removePolyline() async {
  //   if (_mapboxMapController == null) return;

  //   // 1. Elimina la capa de línea
  //   if (await _mapboxMapController!.style.styleLayerExists(
  //     'route-line-layer',
  //   )) {
  //     print(
  //       '🟠 exist layer ${await _mapboxMapController!.style.styleLayerExists('route-line-layer')}',
  //     );
  //     await _mapboxMapController!.style.removeStyleLayer('route-line-layer');
  //   }

  //   // 2. Elimina la fuente de datos GeoJSON
  //   if (await _mapboxMapController!.style.styleSourceExists('route-source')) {
  //     print(
  //       '🟠 exist route source ${await _mapboxMapController!.style.styleSourceExists('route-source')}',
  //     );
  //     await _mapboxMapController!.style.removeStyleSource('route-source');
  //   }
  // }

  // v2 gemini
  // Future<void> _removePolyline() async {
  //   if (_mapboxMapController == null) return;

  //   print('🔴 _removePolyline: Iniciando eliminación de polilíneas y capas...');

  //   // --- 1. Eliminar las PolylineAnnotations (ruta base y ruta recorrida) ---
  //   if (_polylineAnnotationManager != null) {
  //     if (_unTraversedPolyline != null) {
  //       try {
  //         await _polylineAnnotationManager!.delete(_unTraversedPolyline!);
  //         _unTraversedPolyline = null;
  //         print('✅ _unTraversedPolyline eliminado.');
  //       } catch (e) {
  //         print('⚠️ Advertencia: Error al eliminar _unTraversedPolyline: $e');
  //       }
  //     }
  //     if (_traversedPolyline != null) {
  //       try {
  //         await _polylineAnnotationManager!.delete(_traversedPolyline!);
  //         _traversedPolyline = null;
  //         print('✅ _traversedPolyline eliminado.');
  //       } catch (e) {
  //         print('⚠️ Advertencia: Error al eliminar _traversedPolyline: $e');
  //       }
  //     }
  //     // You might also want to dispose the manager if it's no longer needed,
  //     // but often it's kept alive for subsequent route calculations.
  //     // await _polylineAnnotationManager!.dispose();
  //     // _polylineAnnotationManager = null;
  //   }

  //   // --- 2. Eliminar la capa de tráfico ---
  //   if (await _mapboxMapController!.style.styleLayerExists(
  //     'route-traffic-layer',
  //   )) {
  //     await _mapboxMapController!.style.removeStyleLayer('route-traffic-layer');
  //     print('✅ Capa de tráfico (route-traffic-layer) eliminada.');
  //   }

  //   // --- 3. Eliminar la fuente de tráfico GeoJSON ---
  //   if (await _mapboxMapController!.style.styleSourceExists(
  //     'route-traffic-source',
  //   )) {
  //     await _mapboxMapController!.style.removeStyleSource(
  //       'route-traffic-source',
  //     );
  //     print('✅ Fuente de tráfico (route-traffic-source) eliminada.');
  //   }

  //   print('✅ _removePolyline: Polilíneas y capas eliminadas exitosamente.');
  // }

  //v3 gemini
  Future<void> _removePolyline() async {
    if (_mapboxMapController == null) return;

    print('🔴 _removePolyline: Iniciando eliminación de capas de ruta.');

    // Eliminar la capa y fuente de SEGMENTOS BASE (morado/naranja)
    if (await _mapboxMapController!.style.styleLayerExists(
      'route-base-segments-layer',
    )) {
      await _mapboxMapController!.style.removeStyleLayer(
        'route-base-segments-layer',
      );
      print('✅ Capa de segmentos base (route-base-segments-layer) eliminada.');
    }
    if (await _mapboxMapController!.style.styleSourceExists(
      'route-base-segments-source',
    )) {
      await _mapboxMapController!.style.removeStyleSource(
        'route-base-segments-source',
      );
      print(
        '✅ Fuente de segmentos base (route-base-segments-source) eliminada.',
      );
    }

    // Eliminar cualquier capa de tráfico si existía y también quieres limpiarla
    if (await _mapboxMapController!.style.styleLayerExists(
      'route-traffic-layer',
    )) {
      await _mapboxMapController!.style.removeStyleLayer('route-traffic-layer');
      print('✅ Capa de tráfico (route-traffic-layer) eliminada.');
    }
    if (await _mapboxMapController!.style.styleSourceExists(
      'route-traffic-source',
    )) {
      await _mapboxMapController!.style.removeStyleSource(
        'route-traffic-source',
      );
      print('✅ Fuente de tráfico (route-traffic-source) eliminada.');
    }

    // Eliminar cualquier PolylineAnnotation residual (como la línea azul anterior)
    // Asegurarse de que el manager está inicializado antes de intentar usarlo
    if (_polylineAnnotationManager != null) {
      if (_traversedPolyline != null) {
        try {
          await _polylineAnnotationManager!.delete(_traversedPolyline!);
          _traversedPolyline = null;
          print('✅ _traversedPolyline (línea azul anterior) eliminada.');
        } catch (e) {
          print('⚠️ Advertencia: Error al eliminar _traversedPolyline: $e');
        }
      }
      // Si _unTraversedPolyline existe (aunque ya no lo usamos en esta estrategia), también limpiarlo
      if (_unTraversedPolyline != null) {
        try {
          await _polylineAnnotationManager!.delete(_unTraversedPolyline!);
          _unTraversedPolyline = null;
          print('✅ _unTraversedPolyline (línea verde anterior) eliminada.');
        } catch (e) {
          print('⚠️ Advertencia: Error al eliminar _unTraversedPolyline: $e');
        }
      }
    }

    print('✅ _removePolyline: Limpieza de capas de ruta completada.');
  }

  // Métodos para manejar el zoom
  Future<void> _zoomIn() async {
    if (_mapboxMapController != null) {
      mapbox.CameraState cs = await _mapboxMapController!.getCameraState();
      mapbox.CameraOptions co = mapbox.CameraOptions(
        center: cs.center,
        zoom: cs.zoom + 1, // Aumenta el zoom en 1 nivel
        bearing: cs.bearing,
        pitch: cs.pitch,
      );
      _mapboxMapController!.easeTo(
        co,
        mapbox.MapAnimationOptions(duration: 200, startDelay: 0),
      );
    }
  }

  Future<void> _zoomOut() async {
    if (_mapboxMapController != null) {
      mapbox.CameraState cs = await _mapboxMapController!.getCameraState();
      // Asegúrate de no ir por debajo del zoom mínimo (generalmente 0)
      if (cs.zoom > 0) {
        mapbox.CameraOptions co = mapbox.CameraOptions(
          center: cs.center,
          zoom: cs.zoom - 1, // Disminuye el zoom en 1 nivel
          bearing: cs.bearing,
          pitch: cs.pitch,
        );
        _mapboxMapController!.easeTo(
          co,
          mapbox.MapAnimationOptions(duration: 200, startDelay: 0),
        );
      }
    }
  }

  // --- Funciones para la búsqueda ---

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _getPlaceSuggestions(_searchController.text);
      } else {
        setState(() {
          _suggestions = []; // Limpiar sugerencias si el campo está vacío
        });
      }
    });
  }

  Future<void> _getPlaceSuggestions(String pattern) async {
    print('🌟 get places');
    // if (pattern.isEmpty) {
    //   // if (_searchController.text.isEmpty) {
    //   return [];
    // }

    final String accessToken = widget.mapboxAccessToken;

    final url = Uri.parse(
      // 'https://api.mapbox.com/geocoding/v5/mapbox.places/$pattern.json?access_token=$accessToken&language=es&autocomplete=true',
      'https://api.mapbox.com/search/searchbox/v1/forward?q=$pattern&&proximity=${_currentPosition!.longitude},${_currentPosition!.latitude}&access_token=$accessToken',
      // 'https://api.mapbox.com/search/searchbox/v1/suggest?q=$pattern&proximity=${_currentPosition!.longitude},${_currentPosition!.latitude}&access_token=$accessToken',
    );

    print('💖 response $url');

    try {
      final response = await http.get(url);
      print('💖 response ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        // final properties = data['properties'];
        setState(() {
          _suggestions =
              features.map((feature) {
                return {
                  // 'name': feature['place_name'],
                  'name': feature['properties']['name'],
                  'coordinates':
                      feature['geometry']['coordinates'], // [longitude, latitude]
                };
              }).toList();
        });
      } else {
        print('Error en la API de Mapbox Geocoding: ${response.statusCode}');
        setState(() {
          _suggestions = [];
        });
        // return [];
      }
    } catch (e) {
      print('Error al obtener sugerencias de lugares: $e');
      setState(() {
        _suggestions = [];
      });
      // return [];
    }
  }

  void _onSuggestionSelected(Map<String, dynamic> suggestion) async {
    final String name = suggestion['name'];
    // [longitude, latitude]
    final List<dynamic> coords = suggestion['coordinates'];
    // Point.fromLngLat espera (longitude, latitude)
    final mapbox.Point point = mapbox.Point(
      coordinates: mapbox.Position(coords[0], coords[1]),
    );

    selectedPoints.add(
      mapbox.Point(
        coordinates: mapbox.Position(
          point.coordinates.lng,
          point.coordinates.lat,
        ),
      ),
    );

    // Agrega o actualiza un marcador en el mapa
    // createMarker ahora devuelve una lista
    final createdMarkers = await createMarker(
      assetPaTh: 'assets/red_marker.png',
      lat: point.coordinates.lat.toDouble(),
      lng: point.coordinates.lng.toDouble(),
      isUserMarker: false,
    );

    // createMarker añade el marcador a _destinationMarkers internamente.
    // Pero aquí necesitamos la referencia específica para este item en _addedLocations.
    mapbox.PointAnnotation? markerReference;
    if (createdMarkers.isNotEmpty) {
      // Si createMulti (dentro de createMarker) devolvió un solo marcador, tómalo.
      markerReference = createdMarkers.first;
    }

    setState(() {
      _addedLocations.add({
        'name': name,
        'point': point,
        //guarda la referencia del marcador
        'marker': markerReference,
      });
    });

    _searchController.text = name;

    // Mueve el mapa a la ubicación seleccionada
    _mapboxMapController?.setCamera(
      mapbox.CameraOptions(center: point, zoom: 14.0),
    );

    // _addOrUpdateSearchMarker(point, name);

    // Ocultar el teclado
    FocusScope.of(context).unfocus();
    //Limpiar el search controller
    _searchController.clear();
  }

  // speak steps
  // En _NavigationMapState
  // void _checkRouteProgress() async {
  //   if (!_isNavigating || _routeSteps.isEmpty || _currentPosition == null) {
  //     return;
  //   }

  //   // Si ya se recorrieron todos los pasos
  //   print('💜 current step index $_currentRouteStepIndex');
  //   print('💜 route step lengt ${_routeSteps.length}');
  //   if (_currentRouteStepIndex >= _routeSteps.length) {
  //     flutterTts.speak('Has llegado a tu destino.');
  //     _stopNavigation();
  //     return;
  //   }

  //   final currentStep = _routeSteps[_currentRouteStepIndex];
  //   final instruction = currentStep['maneuver']['instruction'];
  //   // final nextStep = _routeSteps[_currentRouteStepIndex + 1];

  //   //se resetea cuando ya se hayan visto todas las coordinates del step > geometry en curso
  //   //lo usaremos para reocorrer cada elemento de la lista de steps

  //   // Obtener el destino de la instrucción actual
  //   // Latitud del final del paso
  //   // print(
  //   //   '💛 lat ${currentStep['geometry']['coordinates'][_currentRouteStepIndex][1]}',
  //   // );
  //   // print(
  //   //   '💛 long ${currentStep['geometry']['coordinates'][_currentRouteStepIndex][0]}',
  //   // );

  //   print(
  //     '💚💛 current step lenght ${currentStep['geometry']['coordinates'].length} ',
  //   );
  //   print(
  //     '💚current step lat ${currentStep['geometry']['coordinates'][currentStep['geometry']['coordinates'].length - 1][1]} ',
  //   );
  //   print(
  //     '💚current step lng ${currentStep['geometry']['coordinates'][currentStep['geometry']['coordinates'].length - 1][0]} ',
  //   );
  //   // final double stepEndLat =
  //   //     currentStep['geometry']['coordinates'][currentStep['geometry']['coordinates']
  //   //             .length -
  //   //         1][1];
  //   // // Longitud del final del paso
  //   // final double stepEndLng =
  //   //     currentStep['geometry']['coordinates'][currentStep['geometry']['coordinates']
  //   //             .length -
  //   //         1][0];
  //   final double stepEndLat = currentStep['maneuver']['location'][1];
  //   // Longitud del final del paso
  //   final double stepEndLng = currentStep['maneuver']['location'][0];
  //   print('💚💚step end lat $stepEndLat ');
  //   print('💚💚step end lng $stepEndLng ');
  //   // Calcular la distancia del usuario al final del paso actual
  //   // final double distanceToStepEnd = await calculateDistance(
  //   //   lat1: _currentPosition!.latitude,
  //   //   lon1: _currentPosition!.longitude,
  //   //   lat2: stepEndLat,
  //   //   lon2: stepEndLng,
  //   // );
  //   final double distanceToStepEnd = geo.Geolocator.distanceBetween(
  //     _currentPosition!.latitude,
  //     _currentPosition!.longitude,
  //     stepEndLat,
  //     stepEndLng,
  //   );

  //   print(
  //     'Distancia al final del paso actual: $distanceToStepEnd metros. Instrucción: $instruction',
  //   );

  //   // Umbral para decir la instrucción (puedes ajustarlo)
  //   // Por ejemplo, 50 metros antes de llegar al punto de la maniobra
  //   if (distanceToStepEnd < 50 /*&& !_hasSpokenInstructionForCurrentStep*/ ) {
  //     print('🛂🛂🛂🛂🛂 distance step <50');
  //     // _hasSpokenInstructionForCurrentStep será una bandera
  //     flutterTts.speak(instruction);
  //     _hasSpokenInstructionForCurrentStep = true; // Para evitar que se repita
  //     // Puedes también avanzar al siguiente paso aquí o un poco más adelante,
  //     // dependiendo de cómo quieras que se sienta la navegación.

  //     //aplicacion de la eliminacion de las lineas recorridas
  //     // features.add(feature);
  //     // _segmentToFeatureIdMap[segmentId] = featureId; // Guarda el mapeo
  //     // _removePolylineSegment('segment_$_currentRouteStepIndex');
  //     // _removePolylineSegment('segment_$_currentRouteStepIndex');

  //     // Una alternativa es avanzar al siguiente paso cuando el usuario cruza el punto final del paso actual.
  //     _currentRouteStepIndex++;
  //     // // Resetear para la siguiente instrucción
  //     _hasSpokenInstructionForCurrentStep = false;
  //     // // <-- LLAMADA CLAVE para actualizar la línea
  //     // _updateRouteVisuals();
  //     _listMapLayers();
  //   }

  //   // Avanzar al siguiente paso una vez que el usuario ha pasado el punto de la maniobra
  //   // Un umbral un poco más grande para asegurar que "cruzó"
  //   // if (distanceToStepEnd < 10) {
  //   //   print('🛂🛂🛂🛂🛂 distance step <10');
  //   //   // Si el usuario está muy cerca o ya pasó el punto
  //   //   _currentRouteStepIndex++;
  //   //   // Resetear para la siguiente instrucción
  //   //   _hasSpokenInstructionForCurrentStep = false;
  //   //   // <-- LLAMADA CLAVE para actualizar la línea
  //   //   _updateRouteVisuals();
  //   // }
  // }

  //v2 gemini
  Future<void> _checkRouteProgress() async {
    if (!_isNavigating || _currentPosition == null) {
      return;
    }

    // Lógica para las instrucciones de voz (basada en _routeSteps)
    if (_currentRouteStepIndex < _routeSteps.length) {
      print('🔴🔴🔴 for _if currentroutestepindex');
      // final currentStep = _routeSteps[_currentRouteStepIndex];
      // final instruction = currentStep['maneuver']['instruction'];
      // final double maneuverLat = currentStep['maneuver']['location'][1];
      // final double maneuverLng = currentStep['maneuver']['location'][0];

      // Correctly access as Map<String, dynamic>
      final Map<String, dynamic> currentStep =
          _routeSteps[_currentRouteStepIndex]
              as Map<String, dynamic>; // <-- Corrected casting
      final instruction = currentStep['maneuver']['instruction'] as String;
      final double maneuverLat =
          (currentStep['maneuver']['location'][1] as num).toDouble();
      final double maneuverLng =
          (currentStep['maneuver']['location'][0] as num).toDouble();

      // final mapbox_model.Step currentStep =
      //     _routeSteps[_currentRouteStepIndex]
      //         as mapbox_model.Step; // <-- Castear
      // <-- Notación de punto
      // final instruction = currentStep.maneuver!.instruction!;
      // // <-- Notación de punto
      // final double maneuverLat = currentStep.maneuver!.location![1];
      // // <-- Notación de punto
      // final double maneuverLng = currentStep.maneuver!.location![0];

      final double distanceToManeuver = geo.Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        maneuverLat,
        maneuverLng,
      );
      print('✅ Distance to mauneaver $distanceToManeuver');

      // print('Distancia a maniobra (${currentStep['name']}): $distanceToManeuver m. Instrucción: $instruction');

      // Umbral para decir la instrucción (ej. 100 metros antes de la maniobra)
      if (distanceToManeuver < 100 && !_hasSpokenInstructionForCurrentStep) {
        print('🔊 Instrucción de voz: $instruction');
        flutterTts.speak(instruction);
        _hasSpokenInstructionForCurrentStep = true;
        // _currentRouteStepIndex++;
        // Reset para la próxima instrucción
        // _hasSpokenInstructionForCurrentStep = false;
      }

      // Umbral para avanzar al siguiente paso de la ruta (cuando el usuario ha CERCANO o PASADO la maniobra)
      // Esto debería ser un umbral menor que el de "decir la instrucción".
      // Por ejemplo, si está a menos de 10 metros del punto de la maniobra
      //todo unncomment
      if (distanceToManeuver < 15 && _hasSpokenInstructionForCurrentStep) {
        print('⏩ Avanzando al siguiente paso: ${currentStep['name']}');
        _currentRouteStepIndex++;
        // Reset para la próxima instrucción
        _hasSpokenInstructionForCurrentStep = false;

        // Si hay más pasos, podríamos pre-cargar la siguiente instrucción o sus detalles aquí.
      }
    } else {
      // Si ya no hay más pasos, se ha llegado al final de la ruta lógica
      if (_isNavigating) {
        // Solo si aún estamos navegando
        flutterTts.speak('Has llegado a tu destino.');
        _stopNavigation();
        return;
      }
    }

    // Lógica para actualizar la visualización de la ruta recorrida (basada en routeVisualSegments)
    // Iterar solo los segmentos que aún no han sido marcados como recorridos
    bool shouldUpdateVisuals = false;
    for (
      int i = _lastTraversedSegmentIndex + 1;
      i < routeVisualSegments.length;
      i++
    ) {
      print('🟡🟡🟡 for lastraversed');
      print('🟡🟡🟡 for i $i');
      print('🟡🟡🟡 for lasttraversedsegmentindex $_lastTraversedSegmentIndex');
      final segment = routeVisualSegments[i];
      // Consideramos que un segmento ha sido recorrido si la posición actual del usuario
      // está muy cerca o ha pasado el *punto final* de ese segmento.
      // Usaremos el último punto del segmento como referencia.
      // Asegurarse de que el segmento tenga al menos 2 puntos
      if (segment.coordinates.length < 2) continue;

      // Último punto del segmento
      final segmentEndCoord = segment.coordinates.last;

      final double distanceToSegmentEnd = geo.Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        segmentEndCoord.lat.toDouble(),
        segmentEndCoord.lng.toDouble(),
      );

      print('✅ distance segment to end $distanceToSegmentEnd');

      // Umbral de 20 metros para considerar que un segmento ha sido "cruzado"
      // Puedes ajustar este umbral.
      if (distanceToSegmentEnd < 100) {
        if (!segment.isTraversed) {
          // Solo si no ha sido marcado
          segment.isTraversed = true;
          segment.isHidden = true; // <-- Establecer a true para ocultar
          _lastTraversedSegmentIndex = i;
          shouldUpdateVisuals = true;
          print(
            '✅ Segmento ${segment.id} marcado como recorrido y oculto. Nuevo _lastTraversedSegmentIndex: $_lastTraversedSegmentIndex. Activando actualización visual.',
          );
          // await _updateRouteVisuals();
        }
        // segment.isTraversed = true;
        // // Actualiza el último segmento recorrido
        // _lastTraversedSegmentIndex = i;
        print(
          '✅ Segmento ${segment.id} marcado como recorrido y oculto. Nuevo _lastTraversedSegmentIndex: $_lastTraversedSegmentIndex. Activando actualización visual.',
        );
        // print(
        //   '✅ Segmento ${segment.id} marcado como recorrido. Nuevo _lastTraversedSegmentIndex: $_lastTraversedSegmentIndex',
        // );
        // Llamamos a la actualización visual si un segmento ha cambiado de estado
        // await _updateRouteVisuals();
      } else {
        print(
          'DEBUG: Segmento $i no alcanzado. Distancia: ${distanceToSegmentEnd.toStringAsFixed(2)}m',
        );
        // Si el usuario no ha alcanzado el final de este segmento, no hay necesidad de revisar los siguientes
        break;
      }
    }
    // Llama _updateRouteVisuals SOLO si hubo un cambio en los segmentos recorridos
    if (shouldUpdateVisuals) {
      print(
        'DEBUG: _checkRouteProgress: Un segmento fue recorrido, llamando a _updateRouteVisuals().',
      );
      await _updateRouteVisuals();
    } else {
      print(
        'DEBUG: _checkRouteProgress: No hay nuevos segmentos recorridos en esta actualización.',
      );
    }
  }

  // Función que se llama para actualizar la visualización de la ruta
  // Future<void> _updateRouteVisuals() async {
  //   if (_currentPosition == null || routeCoordinates.isEmpty) {
  //     return;
  //   }

  //   // Encontrar el punto más cercano en la ruta a la posición actual del usuario
  //   int closestPointIndex = 0;
  //   double minDistance = double.infinity;

  //   for (int i = 0; i < routeCoordinates.length; i++) {
  //     final routePoint = routeCoordinates[i];
  //     final distance = geo.Geolocator.distanceBetween(
  //       _currentPosition!.latitude,
  //       _currentPosition!.longitude,
  //       routePoint.lat.toDouble(),
  //       routePoint.lng.toDouble(),
  //     );
  //     if (distance < minDistance) {
  //       minDistance = distance;
  //       closestPointIndex = i;
  //     }
  //   }

  //   // Ahora, toma los puntos de la ruta desde el punto más cercano hasta el final
  //   List<mapbox.Position> remainingRoutePoints = [];
  //   if (closestPointIndex < routeCoordinates.length) {
  //     remainingRoutePoints = routeCoordinates.sublist(closestPointIndex);
  //   }

  //   // Actualizar la polyline existente o crear una nueva si no existe
  //   if (_polylineAnnotationManager != null) {
  //     if (_routePolyline != null) {
  //       // Si la polyline ya existe, actualiza sus coordenadas
  //       final updatedOptions = mapbox.PolylineAnnotation(
  //         id: _routePolyline!.id,
  //         geometry: mapbox.LineString(coordinates: remainingRoutePoints),
  //         lineWidth: 8.0,
  //         lineColor: Colors.blue.value, // Mantener el color
  //       );
  //       await _polylineAnnotationManager!.update(updatedOptions);
  //     } else {
  //       // Si no existe, créala
  //       final options = mapbox.PolylineAnnotationOptions(
  //         geometry: mapbox.LineString(coordinates: remainingRoutePoints),
  //         lineWidth: 8.0,
  //         lineColor: Colors.blue.value,
  //       );
  //       _routePolyline = await _polylineAnnotationManager!.create(options);
  //     }
  //   }
  // }

  // v2 gemini
  // Future<void> _updateRouteVisuals() async {
  //   if (_polylineAnnotationManager == null || routeCoordinates.isEmpty) {
  //     print('⚠️ _updateRouteVisuals: Manager no inicializado o ruta vacía.');
  //     return;
  //   }

  //   // 1. Construir la geometría de la parte recorrida de la ruta
  //   List<mapbox.Position> traversedRoutePoints = [];

  //   // Recolectar todas las coordenadas de los segmentos marcados como 'isTraversed'
  //   // Iteramos hasta el _lastTraversedSegmentIndex (inclusive)
  //   if (_lastTraversedSegmentIndex >= 0 &&
  //       _lastTraversedSegmentIndex < routeVisualSegments.length) {
  //     // Para asegurar la continuidad, añadimos todas las coordenadas
  //     // de los segmentos recorridos.
  //     // Iteramos sobre los segmentos hasta el último recorrido.
  //     for (int i = 0; i <= _lastTraversedSegmentIndex; i++) {
  //       traversedRoutePoints.addAll(routeVisualSegments[i].coordinates);
  //     }
  //   } else if (_lastTraversedSegmentIndex == -1 &&
  //       routeCoordinates.isNotEmpty) {
  //     // Si aún no se ha recorrido nada, pero el usuario está en el inicio,
  //     // podríamos dibujar el primer punto o un segmento muy pequeño.
  //     // Por ahora, lo dejamos vacío hasta que se recorra el primer segmento completo.
  //   }

  //   // Si no hay puntos recorridos, la línea recorrida debe ser vacía.
  //   if (traversedRoutePoints.isEmpty) {
  //     traversedRoutePoints = [];
  //   } else {
  //     // Opcional: Eliminar duplicados si los segmentos se solapan un poco para continuidad
  //     // (ya que cada segmento incluye el último punto del anterior).
  //     // mapbox.LineString constructor handles this well.
  //   }

  //   // 2. Actualizar la PolylineAnnotation de la ruta recorrida
  //   if (_traversedPolyline != null) {
  //     final updatedOptions = mapbox.PolylineAnnotation(
  //       id: _traversedPolyline!.id,
  //       geometry: mapbox.LineString(coordinates: traversedRoutePoints),
  //       lineColor: Colors.blue.toARGB32(), // Color de la ruta recorrida
  //       lineWidth: 5.0, // Mismo ancho que la línea base
  //     );
  //     await _polylineAnnotationManager!.update(updatedOptions);
  //     print(
  //       '✅ _traversedPolyline actualizada con ${traversedRoutePoints.length} puntos.',
  //     );
  //   } else {
  //     // Esto no debería suceder si _addRouteToMap() se llamó correctamente.
  //     print(
  //       '⚠️ _traversedPolyline es nulo, no se pudo actualizar. Posiblemente un error de inicialización.',
  //     );
  //   }
  //   setState(() {});
  // }

  //correcciones v2
  // Future<void> _updateRouteVisuals() async {
  //   print('DEBUG: Entrando a _updateRouteVisuals()');

  //   if (_polylineAnnotationManager == null) {
  //     print('⚠️ _updateRouteVisuals: _polylineAnnotationManager es NULO.');
  //     return;
  //   }
  //   if (routeCoordinates.isEmpty) {
  //     print('⚠️ _updateRouteVisuals: routeCoordinates está VACÍA.');
  //     return;
  //   }

  //   // 1. Construir la geometría de la parte recorrida de la ruta
  //   List<mapbox.Position> traversedRoutePoints = [];

  //   print('DEBUG: _lastTraversedSegmentIndex: $_lastTraversedSegmentIndex');
  //   print('DEBUG: routeVisualSegments.length: ${routeVisualSegments.length}');

  //   if (_lastTraversedSegmentIndex >= 0 &&
  //       _lastTraversedSegmentIndex < routeVisualSegments.length) {
  //     for (int i = 0; i <= _lastTraversedSegmentIndex; i++) {
  //       if (i < routeVisualSegments.length) {
  //         // Previene index out of bounds si algo sale mal
  //         traversedRoutePoints.addAll(routeVisualSegments[i].coordinates);
  //         print(
  //           'DEBUG: Añadiendo segmentos hasta el índice $i. Puntos acumulados: ${traversedRoutePoints.length}',
  //         );
  //       } else {
  //         print(
  //           'DEBUG: Índice $i fuera de rango para routeVisualSegments.length: ${routeVisualSegments.length}',
  //         );
  //       }
  //     }
  //   } else if (_lastTraversedSegmentIndex == -1 &&
  //       routeCoordinates.isNotEmpty) {
  //     print(
  //       'DEBUG: _lastTraversedSegmentIndex es -1. No hay segmentos recorridos aún.',
  //     );
  //   } else {
  //     print('DEBUG: Condición de _lastTraversedSegmentIndex no cumplida.');
  //   }

  //   print(
  //     'DEBUG: traversedRoutePoints final tiene ${traversedRoutePoints.length} puntos.',
  //   );

  //   // 2. Actualizar la PolylineAnnotation de la ruta recorrida
  //   if (_traversedPolyline != null) {
  //     print(
  //       'DEBUG: Intentando actualizar _traversedPolyline con ID: ${_traversedPolyline!.id}',
  //     );
  //     print(
  //       'DEBUG: Geometría a actualizar para _traversedPolyline: ${traversedRoutePoints.length} puntos.',
  //     );

  //     final updatedOptions = mapbox.PolylineAnnotation(
  //       id: _traversedPolyline!.id, // ¡Importante: el mismo ID!
  //       geometry: mapbox.LineString(coordinates: traversedRoutePoints),
  //       lineColor: Colors.blue.toARGB32(), // Color de la ruta recorrida
  //       lineWidth: 5.0, // Mismo ancho que la línea base
  //     );
  //     await _polylineAnnotationManager!.update(updatedOptions);
  //     print(
  //       '✅ _traversedPolyline actualizada con ${traversedRoutePoints.length} puntos.',
  //     );
  //   } else {
  //     print(
  //       '⚠️ _traversedPolyline es NULO. ¡Este es probablemente el problema principal!',
  //     );
  //     print(
  //       'DEBUG: Asegúrate de que _traversedPolyline se inicialice en _addRouteToMap() ANTES de que se llame a _updateRouteVisuals().',
  //     );
  //   }

  //   // El setState aquí asegura que Flutter reconstruya el widget tree,
  //   // lo cual puede ser necesario si el mapa no se refresca solo.
  //   if (mounted) {
  //     // Asegura que el widget esté montado antes de llamar a setState
  //     setState(() {});
  //   }
  //   print('DEBUG: Saliendo de _updateRouteVisuals()');
  // }

  //v3 gemini
  // Future<void> _updateRouteVisuals() async {
  //   print('DEBUG: === Entrando a _updateRouteVisuals() (SOLO BORRADO) ===');

  //   if (_mapboxMapController == null) {
  //     print('⚠️ _updateRouteVisuals: _mapboxMapController es NULO. Saliendo.');
  //     return;
  //   }
  //   if (routeVisualSegments.isEmpty) {
  //     print(
  //       '⚠️ _updateRouteVisuals: routeVisualSegments está VACÍA. Saliendo.',
  //     );
  //     return;
  //   }

  //   // Reconstruye el FeatureCollection completo con los estados actualizados
  //   List<mapbox.Feature> allUpdatedBaseSegmentFeatures = [];
  //   String sourceIdToUpdate = 'route-base-segments-source';
  //   String layerIdToUpdate = 'route-base-segments-layer';

  //   for (int i = 0; i < routeVisualSegments.length; i++) {
  //     final visualSegment = routeVisualSegments[i];
  //     allUpdatedBaseSegmentFeatures.add(
  //       mapbox.Feature(
  //         id: visualSegment.id,
  //         geometry: mapbox.LineString(coordinates: visualSegment.coordinates),
  //         properties: {
  //           'segment_number': visualSegment.segmentNumber,
  //           // Usa el flag `isTraversed` actualizado por _checkRouteProgress
  //           'is_traversed': visualSegment.isTraversed,
  //           'is_hidden': visualSegment.isHidden,
  //         },
  //       ),
  //     );
  //   }

  //   final updatedFeatureCollection = mapbox.FeatureCollection(
  //     features: allUpdatedBaseSegmentFeatures,
  //   );
  //   final updatedGeoJsonString = jsonEncode(updatedFeatureCollection.toJson());

  //   // *** AÑADE ESTE PRINT PARA INSPECCIONAR EL JSON ANTES DE ENVIARLO ***
  //   print('🆘 DEBUG: GeoJSON ENVIADO A MAPBOX para actualización:');
  //   print(
  //     '🆘 DEBUG check is hidden: ${updatedGeoJsonString.length > 500 ? updatedGeoJsonString.substring(0, 500) + '...' : updatedGeoJsonString}',
  //   );
  //   // O imprime una Feature específica si la ruta es muy larga:
  //   if (allUpdatedBaseSegmentFeatures.isNotEmpty) {
  //     print('DEBUG: Ejemplo de Feature actualizada (primer segmento):');
  //     print('DEBUG: ${jsonEncode(allUpdatedBaseSegmentFeatures[0].toJson())}');
  //     // O si sabes qué segmento debería estar oculto, imprime ese.
  //   }
  //   // *******************************************************************

  //   print(
  //     'DEBUG: _updateRouteVisuals: Generado GeoJSON para ${allUpdatedBaseSegmentFeatures.length} features. Contenido: ${updatedGeoJsonString.length > 200 ? updatedGeoJsonString.substring(0, 200) + '...' : updatedGeoJsonString}',
  //   );

  //   // Estrategia: Remover y Añadir de Nuevo la Fuente y la Capa para forzar la actualización
  //   try {
  //     bool layerExists = await _mapboxMapController!.style.styleLayerExists(
  //       layerIdToUpdate,
  //     );
  //     bool sourceExists = await _mapboxMapController!.style.styleSourceExists(
  //       sourceIdToUpdate,
  //     );
  //     print(
  //       'DEBUG: _updateRouteVisuals: Capa "$layerIdToUpdate" existe: $layerExists. Fuente "$sourceIdToUpdate" existe: $sourceExists.',
  //     );

  //     if (layerExists) {
  //       await _mapboxMapController!.style.removeStyleLayer(layerIdToUpdate);
  //       print('✅ Capa removida: $layerIdToUpdate');
  //     }
  //     if (sourceExists) {
  //       await _mapboxMapController!.style.removeStyleSource(sourceIdToUpdate);
  //       print('✅ Fuente removida: $sourceIdToUpdate');
  //     }

  //     // *** ¡AÑADIR UNA PEQUEÑA ESPERA AQUÍ! ***
  //     // Esto es crucial para dar tiempo al SDK nativo a procesar la remoción.
  //     await Future.delayed(
  //       Duration(milliseconds: 50),
  //     ); // Ajusta este valor si es necesario

  //     await _mapboxMapController!.style.addSource(
  //       mapbox.GeoJsonSource(id: sourceIdToUpdate, data: updatedGeoJsonString),
  //     );
  //     print('✅ Fuente añadida de nuevo: $sourceIdToUpdate');

  //     await _mapboxMapController!.style.addLayer(
  //       mapbox.LineLayer(
  //         id: layerIdToUpdate,
  //         sourceId: sourceIdToUpdate,
  //         lineWidth: 5.0,
  //         lineJoin: mapbox.LineJoin.ROUND,
  //         lineCap: mapbox.LineCap.ROUND,
  //         lineColorExpression: [
  //           'case',
  //           // Condición 1: Si el segmento está recorrido
  //           [
  //             '==',
  //             ['get', 'is_traversed'],
  //             true,
  //           ],
  //           _toHexColorString(
  //             Colors.transparent.toARGB32(),
  //           ), // Resultado: Transparente
  //           // Condición 2: Si el segmento es par
  //           [
  //             '==',
  //             [
  //               '%',
  //               ['get', 'segment_number'],
  //               2,
  //             ],
  //             0,
  //           ],
  //           _toHexColorString(Colors.purple.toARGB32()),

  //           // Fallback (último argumento): Si no es recorrido y no es par, entonces es impar
  //           _toHexColorString(Colors.orange.toARGB32()),
  //         ],
  //         // lineColorExpression: [
  //         //   'match',
  //         //   ['get', 'is_traversed'],
  //         //   true,
  //         //   _toHexColorString(
  //         //     Colors.transparent.toARGB32(),
  //         //   ), // Transparente si recorrido
  //         //   [
  //         //     '%',
  //         //     ['get', 'segment_number'],
  //         //     2,
  //         //   ],
  //         //   0,
  //         //   _toHexColorString(Colors.purple.toARGB32()),
  //         //   1,
  //         //   _toHexColorString(Colors.orange.toARGB32()),
  //         //   _toHexColorString(Colors.grey.toARGB32()), // Fallback
  //         // ],
  //       ),
  //     );
  //     print('✅ Capa añadida de nuevo: $layerIdToUpdate');
  //   } catch (e) {
  //     print(
  //       '❌ ERROR en _updateRouteVisuals al remover/añadir fuente o capa: $e',
  //     );
  //     print('Stacktrace: ${e.toString()}');
  //   }
  //   print('DEBUG: === Saliendo de _updateRouteVisuals() ===');
  // }

  // v4 gemini
  Future<void> _updateRouteVisuals() async {
    print(
      'DEBUG: === Entrando a _updateRouteVisuals() (BORRADO POR ELIMINACIÓN) ===',
    );

    if (_mapboxMapController == null) {
      print('⚠️ _updateRouteVisuals: _mapboxMapController es NULO. Saliendo.');
      return;
    }
    if (routeVisualSegments.isEmpty) {
      print(
        '⚠️ _updateRouteVisuals: routeVisualSegments está VACÍA. Saliendo.',
      );
      return;
    }

    // Paso 1: Construir la lista de FEATURES QUE DEBEN SEGUIR VISIBLES
    List<mapbox.Feature> remainingVisibleFeatures = [];
    String sourceIdToUpdate = 'route-base-segments-source';
    String layerIdToUpdate = 'route-base-segments-layer';

    for (int i = 0; i < routeVisualSegments.length; i++) {
      final visualSegment = routeVisualSegments[i];
      // ¡Solo añadimos la Feature si NO está oculta!
      if (!visualSegment.isHidden) {
        // <-- ¡LA CLAVE AQUÍ!
        remainingVisibleFeatures.add(
          mapbox.Feature(
            id: visualSegment.id,
            geometry: mapbox.LineString(coordinates: visualSegment.coordinates),
            properties: {
              'segment_number': visualSegment.segmentNumber,
              // Las propiedades 'is_traversed' y 'is_hidden' se mantendrían en tu modelo,
              // pero para esta Feature en el GeoJSON, ya no son tan críticas si no se usan en el filtro/expresión.
              // Las incluimos por completitud, pero lo importante es que el filtro ya no las evalúa.
              'is_traversed': visualSegment.isTraversed,
              'is_hidden': visualSegment.isHidden,
            },
          ),
        );
      }
    }

    final updatedFeatureCollection = mapbox.FeatureCollection(
      features: remainingVisibleFeatures,
    );
    final updatedGeoJsonString = jsonEncode(updatedFeatureCollection.toJson());

    print(
      'DEBUG: GeoJSON ENVIADO A MAPBOX para actualización (solo visibles):',
    );
    print(
      '🆘 DEBUG: ${updatedGeoJsonString.length > 500 ? updatedGeoJsonString.substring(0, 500) + '...' : updatedGeoJsonString}',
    );
    if (remainingVisibleFeatures.isNotEmpty) {
      print('🆘 DEBUG: Ejemplo de Feature *VISIBLE* (primer segmento):');
      print('🆘 DEBUG: ${jsonEncode(remainingVisibleFeatures[0].toJson())}');
    } else {
      print(
        '🆘 DEBUG: remainingVisibleFeatures está vacía. Toda la ruta debería haber desaparecido.',
      );
    }

    // Paso 2: Remover y Añadir la Fuente y la Capa (como antes)
    try {
      bool layerExists = await _mapboxMapController!.style.styleLayerExists(
        layerIdToUpdate,
      );
      bool sourceExists = await _mapboxMapController!.style.styleSourceExists(
        sourceIdToUpdate,
      );
      print(
        'DEBUG: _updateRouteVisuals: Capa "$layerIdToUpdate" existe: $layerExists. Fuente "$sourceIdToUpdate" existe: $sourceExists.',
      );

      if (layerExists) {
        await _mapboxMapController!.style.removeStyleLayer(layerIdToUpdate);
        print('✅ Capa removida: $layerIdToUpdate');
      }
      if (sourceExists) {
        await _mapboxMapController!.style.removeStyleSource(sourceIdToUpdate);
        print('✅ Fuente removida: $sourceIdToUpdate');
      }

      await Future.delayed(Duration(milliseconds: 50));

      await _mapboxMapController!.style.addSource(
        mapbox.GeoJsonSource(
          id: sourceIdToUpdate,
          data:
              updatedGeoJsonString, // <-- ¡Ahora solo contiene los segmentos visibles!
        ),
      );
      print('✅ Fuente añadida de nuevo: $sourceIdToUpdate');

      await _mapboxMapController!.style.addLayer(
        mapbox.LineLayer(
          id: layerIdToUpdate,
          sourceId: sourceIdToUpdate,
          lineWidth: 5.0,
          lineJoin: mapbox.LineJoin.ROUND,
          lineCap: mapbox.LineCap.ROUND,
          // La expresión de color ahora NO necesita el filtro, porque solo dibuja lo que está en la fuente.
          lineColorExpression: [
            'case',
            [
              '==',
              [
                '%',
                ['get', 'segment_number'],
                2,
              ],
              0,
            ],
            _toHexColorString(Colors.purple.toARGB32()),
            _toHexColorString(Colors.orange.toARGB32()),
          ],
          // *** ¡ELIMINA EL FILTRO DE AQUÍ! ***
          // filter: [
          //   '==',
          //   ['get', 'is_hidden'],
          //   false,
          // ],
        ),
      );
      print('✅ Capa añadida de nuevo: $layerIdToUpdate');
    } catch (e) {
      print(
        '❌ ERROR en _updateRouteVisuals al remover/añadir fuente o capa: $e',
      );
      print('Stacktrace: ${e.toString()}');
    }
    print('DEBUG: === Saliendo de _updateRouteVisuals() ===');
  }

  Future<double> calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) async {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 1000 * 12742 * asin(sqrt(a));
  }

  Future<void> _removeSingleDestinationMarker(
    mapbox.PointAnnotation markerToRemove,
    int index,
  ) async {
    if (pointAnnotationManager == null) {
      print(
        'ℹ️ _removeSingleDestinationMarker: pointAnnotationManager es nulo.',
      );
      return;
    }

    print(
      '🔴 _removeSingleDestinationMarker: Eliminando marcador de destino individual: ${markerToRemove.id}',
    );

    try {
      await pointAnnotationManager!.delete(markerToRemove); // Eliminar del mapa
      _destinationMarkers.remove(
        markerToRemove,
      ); // Eliminar de la lista global de marcadores

      // *** CAMBIO CLAVE AQUÍ: Remover de _addedLocations y selectedPoints ***
      // Usa el index para remover del mismo índice en _addedLocations y selectedPoints
      setState(() {
        _addedLocations.removeAt(index);
        selectedPoints.removeAt(index);
      });

      print(
        '✅ Marcador ${markerToRemove.id} y lugar asociado eliminados exitosamente.',
      );

      // Opcional: Si quieres redibujar la ruta después de eliminar un punto
      // await _getRoute(); // Esto recalculará la ruta con los puntos restantes
      // await _addPolyline(); // Y la redibujará
    } catch (e) {
      print('❌ Error al eliminar marcador individual: $e');
    }
  }
}

// Representa un segmento lógico de la ruta con su estado y sus coordenadas
// class RouteSegmentVisual {
//   final String
//   id; // Para identificarlo en el mapa (ej. sourceId o annotationId)
//   final List<mapbox.Position> coordinates;
//   bool isTraversed; // Estado de si ha sido recorrido o no

//   RouteSegmentVisual({
//     required this.id,
//     required this.coordinates,
//     this.isTraversed = false,
//   });
// }

// Definición de la clase RouteSegmentVisual (si no la tienes ya)
class RouteSegmentVisual {
  final String id;
  final List<mapbox.Position> coordinates;
  bool isTraversed;
  bool isHidden;
  int? stepIndex;
  final int
  segmentNumber; // <-- NUEVA PROPIEDAD: Para identificar el orden del segmento

  RouteSegmentVisual({
    required this.id,
    required this.coordinates,
    this.isHidden = false,
    this.isTraversed = false,
    this.stepIndex,
    required this.segmentNumber, // <-- REQUERIDO
  });
}

// Clase de ayuda para construir las características GeoJSON
class MapboxFeature {
  final Map<String, dynamic> geometry;
  final Map<String, dynamic> properties;

  MapboxFeature({required this.geometry, required this.properties});

  Map<String, dynamic> toJson() {
    return {'type': 'Feature', 'geometry': geometry, 'properties': properties};
  }
}
