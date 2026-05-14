import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CachedTileProvider extends TileProvider {
  static final customCacheManager = CacheManager(
    Config(
      'mapboxTilesCache',
      stalePeriod: const Duration(days: 30), // El mapa de base cambia poco
      maxNrOfCacheObjects: 5000, // Aumentamos a 5000 tiles
      repo: JsonCacheInfoRepository(databaseName: 'mapboxTilesCache'),
    ),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);

    // EXTRAEMOS LA BASE SIN EL TOKEN
    // Esto convierte una URL larga con token en una llave simple como:
    // 'streets-v12/tiles/15/8000/12000'
    final String cleanKey = url.split('?').first.split('tiles/').last;

    return CachedNetworkImageProvider(
      url,
      cacheManager: customCacheManager,
      cacheKey: cleanKey, // USAMOS LA LLAVE LIMPIA
      headers: const {'User-Agent': 'com.vamosapp.vamosuser'},
    );
  }
}
