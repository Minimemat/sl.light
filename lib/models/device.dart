class Device {
  final String id;
  final String name;
  final String ipAddress;
  final String mqttClientId;
  final String mqttUsername;
  final String mqttPassword;
  final List<String> allowedUsers;
  final bool isOnline;
  final bool isPoweredOn;
  final int brightness;
  final String? color;
  final List<List<int>> colors; // RGB for up to 3 colors
  final int effect;
  final int palette;
  final int speed;
  final int intensity;
  final Map<String, bool> options;
  final Map<String, int> customs;

  Device({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.mqttClientId,
    required this.mqttUsername,
    required this.mqttPassword,
    required this.allowedUsers,
    this.isOnline = false,
    this.isPoweredOn = false,
    this.brightness = 0,
    this.color,
    this.colors = const [[255,255,255],[255,255,255],[0,0,0]],
    this.effect = 0,
    this.palette = 0,
    this.speed = 128,
    this.intensity = 128,
    this.options = const {'o1': false, 'o2': false, 'o3': false},
    this.customs = const {'c1': 128, 'c2': 128, 'c3': 16},
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      ipAddress: json['ip_address'] ?? '',
      mqttClientId: json['mqtt_client_id'] ?? '',
      mqttUsername: json['mqtt_username'] ?? '',
      mqttPassword: json['mqtt_password'] ?? '',
      allowedUsers: (json['allowed_users'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isOnline: json['isOnline'] ?? false,
      isPoweredOn: json['isPoweredOn'] ?? false,
      brightness: json['brightness'] ?? 0,
      color: json['color'],
      colors: (json['colors'] as List?)?.map((e) => List<int>.from(e)).toList() ?? [[255,255,255],[255,255,255],[0,0,0]],
      effect: json['effect'] ?? 0,
      palette: json['palette'] ?? 0,
      speed: json['speed'] ?? 128,
      intensity: json['intensity'] ?? 128,
      options: (json['options'] as Map?)?.map((k,v) => MapEntry(k as String, v as bool)) ?? {'o1': false, 'o2': false, 'o3': false},
      customs: (json['customs'] as Map?)?.map((k,v) => MapEntry(k as String, v as int)) ?? {'c1': 128, 'c2': 128, 'c3': 16},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip_address': ipAddress,
      'mqtt_client_id': mqttClientId,
      'mqtt_username': mqttUsername,
      'mqtt_password': mqttPassword,
      'allowed_users': allowedUsers,
      'isOnline': isOnline,
      'isPoweredOn': isPoweredOn,
      'brightness': brightness,
      'color': color,
      'colors': colors,
      'effect': effect,
      'palette': palette,
      'speed': speed,
      'intensity': intensity,
      'options': options,
      'customs': customs,
    };
  }

  Device copyWith({
    String? id,
    String? name,
    String? ipAddress,
    String? mqttClientId,
    String? mqttUsername,
    String? mqttPassword,
    List<String>? allowedUsers,
    bool? isOnline,
    bool? isPoweredOn,
    int? brightness,
    String? color,
    List<List<int>>? colors,
    int? effect,
    int? palette,
    int? speed,
    int? intensity,
    Map<String, bool>? options,
    Map<String, int>? customs,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      mqttClientId: mqttClientId ?? this.mqttClientId,
      mqttUsername: mqttUsername ?? this.mqttUsername,
      mqttPassword: mqttPassword ?? this.mqttPassword,
      allowedUsers: allowedUsers ?? this.allowedUsers,
      isOnline: isOnline ?? this.isOnline,
      isPoweredOn: isPoweredOn ?? this.isPoweredOn,
      brightness: brightness ?? this.brightness,
      color: color ?? this.color,
      colors: colors ?? this.colors,
      effect: effect ?? this.effect,
      palette: palette ?? this.palette,
      speed: speed ?? this.speed,
      intensity: intensity ?? this.intensity,
      options: options ?? this.options,
      customs: customs ?? this.customs,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Device) return false;
    final a = this;
    final b = other;
    final aColors = a.colors;
    final bColors = b.colors;
    bool colorsEqual =
        aColors.length == bColors.length &&
        List.generate(aColors.length, (i) =>
          aColors[i].length == bColors[i].length &&
          List.generate(aColors[i].length, (j) => aColors[i][j] == bColors[i][j]).every((x) => x)
        ).every((x) => x);
    final bool optionsEqual =
        (a.options['o1'] ?? false) == (b.options['o1'] ?? false) &&
        (a.options['o2'] ?? false) == (b.options['o2'] ?? false) &&
        (a.options['o3'] ?? false) == (b.options['o3'] ?? false);
    final bool customsEqual =
        (a.customs['c1'] ?? 128) == (b.customs['c1'] ?? 128) &&
        (a.customs['c2'] ?? 128) == (b.customs['c2'] ?? 128) &&
        (a.customs['c3'] ?? 16) == (b.customs['c3'] ?? 16);
    return a.id == b.id &&
        a.isPoweredOn == b.isPoweredOn &&
        a.brightness == b.brightness &&
        a.effect == b.effect &&
        a.palette == b.palette &&
        a.speed == b.speed &&
        a.intensity == b.intensity &&
        colorsEqual &&
        optionsEqual &&
        customsEqual;
  }

  @override
  int get hashCode {
    final flatColors = colors.expand((c) => c).toList(growable: false);
    final o1 = options['o1'] ?? false;
    final o2 = options['o2'] ?? false;
    final o3 = options['o3'] ?? false;
    final c1 = customs['c1'] ?? 128;
    final c2 = customs['c2'] ?? 128;
    final c3 = customs['c3'] ?? 16;
    return Object.hashAll([
      id,
      isPoweredOn,
      brightness,
      effect,
      palette,
      speed,
      intensity,
      ...flatColors,
      o1,
      o2,
      o3,
      c1,
      c2,
      c3,
    ]);
  }

  @override
  String toString() {
    return 'Device(id: $id, name: $name, ipAddress: $ipAddress)';
  }
}
