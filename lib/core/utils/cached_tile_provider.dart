import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CachedTileProvider extends TileProvider {
  static final customCacheManager = CacheManager(
    Config(
      'mapboxTilesCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 5000,
    ),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);

    // EXPLICACIÓN: Cortamos la URL antes del '?' para que el token no sea parte de la llave.
    // Esto hace que si la imagen ya existe, no la vuelva a pedir a Mapbox.
    final String staticCacheKey = url.split('?').first;

    return CachedNetworkImageProvider(
      url,
      cacheManager: customCacheManager,
      cacheKey: staticCacheKey, // USAMOS LA LLAVE ESTÁTICA
      headers: const {'User-Agent': 'com.vamosapp.vamosuser'},
    );
  }
}
