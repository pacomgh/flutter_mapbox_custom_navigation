// To parse this JSON data, do
//
//     final mapboxModel = mapboxModelFromJson(jsonString);

import 'dart:convert';

MapboxModel mapboxModelFromJson(String str) =>
    MapboxModel.fromJson(json.decode(str));

String mapboxModelToJson(MapboxModel data) => json.encode(data.toJson());

class MapboxModel {
  List<Route>? routes;
  List<Waypoint>? waypoints;
  String? code;
  String? uuid;

  MapboxModel({this.routes, this.waypoints, this.code, this.uuid});

  factory MapboxModel.fromJson(Map<String, dynamic> json) => MapboxModel(
    routes: List<Route>.from(json["routes"].map((x) => Route.fromJson(x))),
    waypoints: List<Waypoint>.from(
      json["waypoints"].map((x) => Waypoint.fromJson(x)),
    ),
    code: json["code"],
    uuid: json["uuid"],
  );

  Map<String, dynamic> toJson() => {
    "routes": List<dynamic>.from(routes!.map((x) => x.toJson())),
    "waypoints": List<dynamic>.from(waypoints!.map((x) => x.toJson())),
    "code": code,
    "uuid": uuid,
  };
}

class Route {
  double? weightTypical;
  double? durationTypical;
  String? weightName;
  double? weight;
  double? duration;
  double? distance;
  List<Leg>? legs;
  Geometry? geometry;

  Route({
    this.weightTypical,
    this.durationTypical,
    this.weightName,
    this.weight,
    this.duration,
    this.distance,
    this.legs,
    this.geometry,
  });

  factory Route.fromJson(Map<String, dynamic> json) => Route(
    weightTypical: json["weight_typical"]?.toDouble(),
    durationTypical: json["duration_typical"]?.toDouble(),
    weightName: json["weight_name"],
    weight: json["weight"]?.toDouble(),
    duration: json["duration"]?.toDouble(),
    distance: json["distance"]?.toDouble(),
    legs: List<Leg>.from(json["legs"].map((x) => Leg.fromJson(x))),
    geometry: Geometry.fromJson(json["geometry"]),
  );

  Map<String, dynamic> toJson() => {
    "weight_typical": weightTypical,
    "duration_typical": durationTypical,
    "weight_name": weightName,
    "weight": weight,
    "duration": duration,
    "distance": distance,
    "legs": List<dynamic>.from(legs!.map((x) => x.toJson())),
    "geometry": geometry!.toJson(),
  };
}

class Geometry {
  List<List<double>>? coordinates;
  Type? type;

  Geometry({this.coordinates, this.type});

  factory Geometry.fromJson(Map<String, dynamic> json) => Geometry(
    coordinates: List<List<double>>.from(
      json["coordinates"].map(
        (x) => List<double>.from(x.map((x) => x?.toDouble())),
      ),
    ),
    type: typeValues.map[json["type"]]!,
  );

  Map<String, dynamic> toJson() => {
    "coordinates": List<dynamic>.from(
      coordinates!.map((x) => List<dynamic>.from(x.map((x) => x))),
    ),
    "type": typeValues.reverse[type],
  };
}

enum Type { LINE_STRING }

final typeValues = EnumValues({"LineString": Type.LINE_STRING});

class Leg {
  List<dynamic>? viaWaypoints;
  List<Admin>? admins;
  Annotation? annotation;
  double? weightTypical;
  double? durationTypical;
  double? weight;
  double? duration;
  List<Step>? steps;
  double? distance;
  String? summary;

  Leg({
    this.viaWaypoints,
    this.admins,
    this.annotation,
    this.weightTypical,
    this.durationTypical,
    this.weight,
    this.duration,
    this.steps,
    this.distance,
    this.summary,
  });

  factory Leg.fromJson(Map<String, dynamic> json) => Leg(
    viaWaypoints: List<dynamic>.from(json["via_waypoints"].map((x) => x)),
    admins: List<Admin>.from(json["admins"].map((x) => Admin.fromJson(x))),
    annotation:
        json["annotation"] != null
            ? Annotation.fromJson(json["annotation"])
            : null,
    weightTypical: json["weight_typical"]?.toDouble(),
    durationTypical: json["duration_typical"]?.toDouble(),
    weight: json["weight"]?.toDouble(),
    duration: json["duration"]?.toDouble(),
    steps: List<Step>.from(json["steps"].map((x) => Step.fromJson(x))),
    distance: json["distance"]?.toDouble(),
    summary: json["summary"],
  );

  Map<String, dynamic> toJson() => {
    "via_waypoints": List<dynamic>.from(viaWaypoints!.map((x) => x)),
    "admins": List<dynamic>.from(admins!.map((x) => x.toJson())),
    "annotation": annotation?.toJson(),
    "weight_typical": weightTypical,
    "duration_typical": durationTypical,
    "weight": weight,
    "duration": duration,
    "steps": List<dynamic>.from(steps!.map((x) => x.toJson())),
    "distance": distance,
    "summary": summary,
  };
}

class Admin {
  String? iso31661Alpha3;
  String? iso31661;

  Admin({this.iso31661Alpha3, this.iso31661});

  factory Admin.fromJson(Map<String, dynamic> json) => Admin(
    iso31661Alpha3: json["iso_3166_1_alpha3"],
    iso31661: json["iso_3166_1"],
  );

  Map<String, dynamic> toJson() => {
    "iso_3166_1_alpha3": iso31661Alpha3,
    "iso_3166_1": iso31661,
  };
}

class Annotation {
  List<Congestion>? congestion;

  Annotation({this.congestion});

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
    congestion: List<Congestion>.from(
      json["congestion"].map((x) => congestionValues.map[x]!),
    ),
  );

  Map<String, dynamic> toJson() => {
    "congestion": List<dynamic>.from(
      congestion!.map((x) => congestionValues.reverse[x]),
    ),
  };
}

enum Congestion { LOW, UNKNOWN, MODERATE, SEVERE, HEAVY }

final congestionValues = EnumValues({
  "low": Congestion.LOW,
  "unknown": Congestion.UNKNOWN,
  "moderate": Congestion.MODERATE,
  "severe": Congestion.SEVERE,
  "heavy": Congestion.HEAVY,
});

class Step {
  List<Intersection>? intersections;
  Maneuver? maneuver;
  String? name;
  double? weightTypical;
  double? durationTypical;
  double? duration;
  double? distance;
  DrivingSide? drivingSide;
  double? weight;
  Mode? mode;
  Geometry? geometry;
  String? destinations;

  Step({
    this.intersections,
    this.maneuver,
    this.name,
    this.weightTypical,
    this.durationTypical,
    this.duration,
    this.distance,
    this.drivingSide,
    this.weight,
    this.mode,
    this.geometry,
    this.destinations,
  });

  factory Step.fromJson(Map<String, dynamic> json) => Step(
    intersections: List<Intersection>.from(
      json["intersections"].map((x) => Intersection.fromJson(x)),
    ),
    maneuver: Maneuver.fromJson(json["maneuver"]),
    name: json["name"],
    weightTypical: json["weight_typical"]?.toDouble(),
    durationTypical: json["duration_typical"]?.toDouble(),
    duration: json["duration"]?.toDouble(),
    distance: json["distance"]?.toDouble(),
    drivingSide: drivingSideValues.map[json["driving_side"]]!,
    weight: json["weight"]?.toDouble(),
    mode: modeValues.map[json["mode"]]!,
    geometry: Geometry.fromJson(json["geometry"]),
    destinations: json["destinations"],
  );

  Map<String, dynamic> toJson() => {
    "intersections": List<dynamic>.from(intersections!.map((x) => x.toJson())),
    "maneuver": maneuver!.toJson(),
    "name": name,
    "weight_typical": weightTypical,
    "duration_typical": durationTypical,
    "duration": duration,
    "distance": distance,
    "driving_side": drivingSideValues.reverse[drivingSide],
    "weight": weight,
    "mode": modeValues.reverse[mode],
    "geometry": geometry!.toJson(),
    "destinations": destinations,
  };
}

enum DrivingSide { LEFT, RIGHT, STRAIGHT }

final drivingSideValues = EnumValues({
  "left": DrivingSide.LEFT,
  "right": DrivingSide.RIGHT,
  "straight": DrivingSide.STRAIGHT,
});

class Intersection {
  List<bool>? entry;
  List<int>? bearings;
  double? duration;
  MapboxStreetsV8? mapboxStreetsV8;
  bool? isUrban;
  int? adminIndex;
  int? out;
  double? weight;
  int? geometryIndex;
  List<double>? location;
  int? intersectionIn;
  double? turnWeight;
  double? turnDuration;
  bool? trafficSignal;
  List<Lane>? lanes;

  Intersection({
    this.entry,
    this.bearings,
    this.duration,
    this.mapboxStreetsV8,
    this.isUrban,
    this.adminIndex,
    this.out,
    this.weight,
    this.geometryIndex,
    this.location,
    this.intersectionIn,
    this.turnWeight,
    this.turnDuration,
    this.trafficSignal,
    this.lanes,
  });

  factory Intersection.fromJson(Map<String, dynamic> json) => Intersection(
    entry: List<bool>.from(json["entry"].map((x) => x)),
    bearings: List<int>.from(json["bearings"].map((x) => x)),
    duration: json["duration"]?.toDouble(),
    mapboxStreetsV8:
        json["mapbox_streets_v8"] == null
            ? null
            : MapboxStreetsV8.fromJson(json["mapbox_streets_v8"]),
    isUrban: json["is_urban"],
    adminIndex: json["admin_index"],
    out: json["out"],
    weight: json["weight"]?.toDouble(),
    geometryIndex: json["geometry_index"],
    location: List<double>.from(json["location"].map((x) => x?.toDouble())),
    intersectionIn: json["in"],
    turnWeight: json["turn_weight"]?.toDouble(),
    turnDuration: json["turn_duration"]?.toDouble(),
    trafficSignal: json["traffic_signal"],
    lanes:
        json["lanes"] == null
            ? []
            : List<Lane>.from(json["lanes"]!.map((x) => Lane.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "entry": List<dynamic>.from(entry!.map((x) => x)),
    "bearings": List<dynamic>.from(bearings!.map((x) => x)),
    "duration": duration,
    "mapbox_streets_v8": mapboxStreetsV8?.toJson(),
    "is_urban": isUrban,
    "admin_index": adminIndex,
    "out": out,
    "weight": weight,
    "geometry_index": geometryIndex,
    "location": List<dynamic>.from(location!.map((x) => x)),
    "in": intersectionIn,
    "turn_weight": turnWeight,
    "turn_duration": turnDuration,
    "traffic_signal": trafficSignal,
    "lanes":
        lanes == null ? [] : List<dynamic>.from(lanes!.map((x) => x.toJson())),
  };
}

class Lane {
  List<DrivingSide>? indications;
  DrivingSide? validIndication;
  bool? valid;
  bool? active;

  Lane({this.indications, this.validIndication, this.valid, this.active});

  factory Lane.fromJson(Map<String, dynamic> json) => Lane(
    indications:
        json["indications"] != null
            ? List<DrivingSide>.from(
              json["indications"].map((x) => drivingSideValues.map[x]!),
            )
            : [],
    validIndication:
        json["valid_indication"] != null
            ? drivingSideValues.map[json["valid_indication"]]!
            : null,
    valid: json["valid"],
    active: json["active"],
  );

  Map<String, dynamic> toJson() => {
    "indications": List<dynamic>.from(
      indications!.map((x) => drivingSideValues.reverse[x]),
    ),
    "valid_indication": drivingSideValues.reverse[validIndication],
    "valid": valid,
    "active": active,
  };
}

class MapboxStreetsV8 {
  Class mapboxStreetsV8Class;

  MapboxStreetsV8({required this.mapboxStreetsV8Class});

  factory MapboxStreetsV8.fromJson(Map<String, dynamic> json) =>
      MapboxStreetsV8(mapboxStreetsV8Class: classValues.map[json["class"]]!);

  Map<String, dynamic> toJson() => {
    "class": classValues.reverse[mapboxStreetsV8Class],
  };
}

enum Class {
  PRIMARY,
  PRIMARY_LINK,
  SECONDARY,
  SECONDARY_LINK,
  SERVICE,
  STREET,
  TERTIARY,
  TERTIARY_LINK,
}

final classValues = EnumValues({
  "primary": Class.PRIMARY,
  "primary_link": Class.PRIMARY_LINK,
  "secondary": Class.SECONDARY,
  "secondary_link": Class.SECONDARY_LINK,
  "service": Class.SERVICE,
  "street": Class.STREET,
  "tertiary": Class.TERTIARY,
  "tertiary_link": Class.TERTIARY_LINK,
});

class Maneuver {
  String? type;
  String? instruction;
  int? bearingAfter;
  int? bearingBefore;
  List<double>? location;
  Modifier? modifier;
  int? exit;

  Maneuver({
    required this.type,
    required this.instruction,
    required this.bearingAfter,
    required this.bearingBefore,
    required this.location,
    this.modifier,
    this.exit,
  });

  factory Maneuver.fromJson(Map<String, dynamic> json) => Maneuver(
    type: json["type"],
    instruction: json["instruction"],
    bearingAfter: json["bearing_after"],
    bearingBefore: json["bearing_before"],
    location: List<double>.from(json["location"].map((x) => x?.toDouble())),
    modifier:
        json["modifier"] != null ? modifierValues.map[json["modifier"]] : null,
    exit: json["exit"],
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "instruction": instruction,
    "bearing_after": bearingAfter,
    "bearing_before": bearingBefore,
    "location": List<dynamic>.from(location!.map((x) => x)),
    "modifier": modifierValues.reverse[modifier],
    "exit": exit,
  };
}

enum Modifier { LEFT, RIGHT, SLIGHT_LEFT, SLIGHT_RIGHT, UTURN }

final modifierValues = EnumValues({
  "left": Modifier.LEFT,
  "right": Modifier.RIGHT,
  "slight left": Modifier.SLIGHT_LEFT,
  "slight right": Modifier.SLIGHT_RIGHT,
  "uturn": Modifier.UTURN,
});

enum Mode { DRIVING }

final modeValues = EnumValues({"driving": Mode.DRIVING});

class Waypoint {
  TimeZone? timeZone;
  double? distance;
  String? name;
  List<double>? location;

  Waypoint({this.timeZone, this.distance, this.name, this.location});

  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
    timeZone:
        json["time_zone"] != null ? TimeZone.fromJson(json["time_zone"]) : null,
    distance: json["distance"]?.toDouble(),
    name: json["name"],
    location:
        json["location"] != null
            ? List<double>.from(json["location"].map((x) => x?.toDouble()))
            : null,
  );

  Map<String, dynamic> toJson() => {
    "time_zone": timeZone?.toJson(),
    "distance": distance,
    "name": name,
    "location": List<dynamic>.from(location!.map((x) => x)),
  };
}

class TimeZone {
  String abbreviation;
  String identifier;
  String offset;

  TimeZone({
    required this.abbreviation,
    required this.identifier,
    required this.offset,
  });

  factory TimeZone.fromJson(Map<String, dynamic> json) => TimeZone(
    abbreviation: json["abbreviation"],
    identifier: json["identifier"],
    offset: json["offset"],
  );

  Map<String, dynamic> toJson() => {
    "abbreviation": abbreviation,
    "identifier": identifier,
    "offset": offset,
  };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
