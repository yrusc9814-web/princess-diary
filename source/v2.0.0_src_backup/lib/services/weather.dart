import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'settings.dart';

class Weather {
  final double temp, max, min, feels;
  final int code;
  final double wind; // km/h
  final int precip; // 降水概率 %
  final String city;
  final int updatedAt;
  final bool stale;
  Weather({
    required this.temp, required this.max, required this.min, required this.feels, required this.code, required this.wind,
    required this.precip, required this.city, required this.updatedAt, this.stale = false,
  });

  String get text => wmoText(code);
  bool get wet => code >= 51;
  IconData get icon => wmoIcon(code);
  String get windText {
    if (wind < 6) return '微风';
    if (wind < 20) return '有风';
    if (wind < 39) return '风较大';
    return '大风';
  }

  Map<String, dynamic> toJson() =>
      {'t': temp, 'mx': max, 'mn': min, 'f': feels, 'c': code, 'w': wind, 'p': precip, 'city': city, 'u': updatedAt};
  factory Weather.fromJson(Map<String, dynamic> j, {bool stale = false}) => Weather(
        temp: (j['t'] as num).toDouble(), max: (j['mx'] as num).toDouble(), min: (j['mn'] as num).toDouble(),
        feels: (j['f'] as num? ?? j['t'] as num).toDouble(), code: j['c'] as int, wind: (j['w'] as num).toDouble(),
        precip: (j['p'] as int?) ?? 0, city: (j['city'] as String?) ?? '', updatedAt: (j['u'] as int?) ?? 0, stale: stale,
      );
}

String wmoText(int c) {
  if (c == 0) return '晴';
  if (c <= 2) return '多云';
  if (c == 3) return '阴';
  if (c <= 48) return '雾';
  if (c <= 57) return '毛毛雨';
  if (c <= 65) return c >= 63 ? '中雨' : '小雨';
  if (c <= 67) return '冻雨';
  if (c <= 77) return '雪';
  if (c <= 82) return '阵雨';
  if (c <= 86) return '阵雪';
  return '雷阵雨';
}

IconData wmoIcon(int c) {
  if (c == 0) return Icons.wb_sunny;
  if (c <= 2) return Icons.wb_cloudy_outlined;
  if (c == 3) return Icons.cloud;
  if (c <= 48) return Icons.foggy;
  if (c <= 67 || (c >= 80 && c <= 82)) return Icons.water_drop;
  if (c <= 77 || c <= 86) return Icons.ac_unit;
  return Icons.thunderstorm;
}

/// 天气：Open-Meteo（免费、无需 Key），缓存 1 小时
class WeatherService {
  static final ValueNotifier<Weather?> current = ValueNotifier(null);

  static Future<({double lat, double lng})?> location() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('off');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw Exception('no permission');
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low))
          .timeout(const Duration(seconds: 10));
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return (lat: last.latitude, lng: last.longitude);
      } catch (_) {}
      if (Settings.lat != null) return (lat: Settings.lat!, lng: Settings.lng!);
      return null;
    }
  }

  static Future<String> _cityOf(double lat, double lng) async {
    try {
      final r = await http
          .get(Uri.parse('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=zh'))
          .timeout(const Duration(seconds: 8));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      var c = '${j['city'] ?? ''}';
      if (c.isEmpty) c = '${j['locality'] ?? ''}';
      if (c.isEmpty) c = '${j['principalSubdivision'] ?? ''}';
      return c.replaceAll('市', '');
    } catch (_) {
      return Settings.cityName;
    }
  }

  static Future<Weather?> load({bool force = false}) async {
    final sp = Settings.p;
    final cached = sp.getString('weather_cache2');
    final at = sp.getInt('weather_at2') ?? 0;
    if (!force && cached != null && DateTime.now().millisecondsSinceEpoch - at < 3600 * 1000) {
      return current.value = Weather.fromJson(jsonDecode(cached));
    }
    final loc = await location();
    if (loc == null) return current.value = cached == null ? null : Weather.fromJson(jsonDecode(cached), stale: true);
    try {
      final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${loc.lat}&longitude=${loc.lng}'
          '&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m'
          '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&forecast_days=1&timezone=auto');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final j = jsonDecode(res.body);
      final d = j['daily'];
      var city = await _cityOf(loc.lat, loc.lng);
      if (city.isEmpty) city = Settings.cityName;
      final w = Weather(
        temp: (j['current']['temperature_2m'] as num).toDouble(),
        feels: (j['current']['apparent_temperature'] as num).toDouble(),
        max: (d['temperature_2m_max'][0] as num).toDouble(),
        min: (d['temperature_2m_min'][0] as num).toDouble(),
        code: j['current']['weather_code'] as int,
        wind: (j['current']['wind_speed_10m'] as num).toDouble(),
        precip: ((d['precipitation_probability_max'][0] as num?) ?? 0).toInt(),
        city: city,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await sp.setString('weather_cache2', jsonEncode(w.toJson()));
      await sp.setInt('weather_at2', DateTime.now().millisecondsSinceEpoch);
      return current.value = w;
    } catch (_) {
      return current.value = cached == null ? null : Weather.fromJson(jsonDecode(cached), stale: true);
    }
  }

  /// 城市名转坐标（Open-Meteo 地理编码，免费）
  static Future<({String name, double lat, double lng})?> geocode(String city) async {
    final res = await http.get(Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1&language=zh'));
    final r = (jsonDecode(res.body)['results'] as List?) ?? [];
    if (r.isEmpty) return null;
    return (name: r[0]['name'] as String, lat: (r[0]['latitude'] as num).toDouble(), lng: (r[0]['longitude'] as num).toDouble());
  }
}
