import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import '../../../core/network/api_client.dart';
// ignore: unused_import
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomeService {
  final ApiClient _api = ApiClient();
  PusherChannelsClient? _client;
  final Map<String, PrivateChannel> _activeTripChannels = {};
  Future<Map<String, dynamic>?> getActiveTrip() async {
    try {
      final response = await _api.dio.get('/viajes/activo');
      if (response.data != null && response.data['status'] == 'success') {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- FUNCIÓN DE GUARDADO (Corregida) ---
  Future<Map<String, dynamic>?> saveQuickAddress({
    required String type,
    required String address,
    required double lat,
    required double lng,
  }) async {
    try {
      // CAMBIO: Usamos '_api' que es como se llama tu variable arriba
      final response = await _api.dio.post(
        '/user/favoritos',
        data: {'tipo': type, 'address': address, 'lat': lat, 'lng': lng},
      );
      if (response.statusCode == 200) {
        return response.data['user'];
      }
      return null;
    } catch (e) {
      debugPrint("Error guardando favorito desde HomeService: $e");
      return null;
    }
  }

  void initUserSocket({
    required String userId,
    required String token,
    required Function(String event, Map<String, dynamic> data) onEvent,
  }) {
    // Configuración del cliente Pusher
    _client = PusherChannelsClient.websocket(
      options: PusherChannelsOptions.fromHost(
        scheme: 'wss',
        host: 'api.vamosapp.com.co',
        port: 443,
        key: '06exymiubefjjglwmvqe',
      ),
      connectionErrorHandler: (exception, trace, client) {
        debugPrint("🚨 Error de Socket: $exception");
      },
    );

    // Función auxiliar para unificar el manejo de eventos y evitar duplicidad
    void handleEvent(String eventName, dynamic e) {
      if (e.data != null) {
        try {
          onEvent(eventName, json.decode(e.data!));
        } catch (ex) {
          debugPrint("❌ Error al decodificar evento $eventName: $ex");
        }
      }
    }

    _client!.eventStream.listen((event) {
      if (event.name == 'pusher:connection_established') {
        debugPrint("✅ Conexión establecida con el servidor de VAMOS");

        final channel = _client!.privateChannel(
          'private-usuario.$userId',
          authorizationDelegate: UserPusherAuth(token: token),
        );
        channel.subscribe();

        // --- Binds unificados ---

        channel
            .bind('ViajeAceptado')
            .listen((e) => handleEvent('ViajeAceptado', e));

        // 2. Cancelación
        channel
            .bind('ViajeCancelado')
            .listen((e) => handleEvent('ViajeCancelado', e));
        channel
            .bind('.ViajeCancelado')
            .listen((e) => handleEvent('ViajeCancelado', e));
        channel
            .bind('App\\Events\\ViajeCanceladoEvent')
            .listen((e) => handleEvent('ViajeCancelado', e));

        // 3. Estado
        channel
            .bind('ViajeEstado')
            .listen((e) => handleEvent('ViajeEstado', e));
        channel
            .bind('.ViajeEstado')
            .listen((e) => handleEvent('ViajeEstado', e));
        channel
            .bind('App\\Events\\ViajeEstadoEvent')
            .listen((e) => handleEvent('ViajeEstado', e));

        debugPrint("✅ Canales de usuario suscritos correctamente.");
      }
    });

    _client!.connect();
  }

  void unsubscribeFromTrip(String tripId) {
    final channelName = 'private-viaje.$tripId';

    // Buscamos el canal en nuestro mapa
    if (_activeTripChannels.containsKey(channelName)) {
      _activeTripChannels[channelName]!.unsubscribe(); // Cortamos la conexión
      _activeTripChannels.remove(channelName); // Limpiamos el mapa
      debugPrint("🛑 Tracking detenido para el viaje: $tripId");
    }
  }

  // Escuchar el GPS específico del viaje
  void subscribeToTripTracking(
    String tripId,
    String token,
    Function(double lat, double lng) onLocation,
  ) {
    final channelName = 'private-viaje.$tripId';

    // Creamos el canal
    final tripChannel = _client!.privateChannel(
      channelName,
      authorizationDelegate: UserPusherAuth(token: token),
    );

    // LO GUARDAMOS EN EL MAPA PARA PODER USARLO EN unsubscribeFromTrip
    _activeTripChannels[channelName] = tripChannel;

    tripChannel.subscribe();
    tripChannel.bind('PuntoTracking').listen((e) {
      if (e.data != null) {
        final data = json.decode(e.data!);
        onLocation(
          double.parse(data['lat'].toString()),
          double.parse(data['lng'].toString()),
        );
      }
    });
  }

  void dispose() {
    _client?.disconnect();
  }
}

class UserPusherAuth
    implements
        EndpointAuthorizableChannelAuthorizationDelegate<
          PrivateChannelAuthorizationData
        > {
  final String token;
  UserPusherAuth({required this.token});

  @override
  EndpointAuthFailedCallback? get onAuthFailed =>
      (exception, trace) => debugPrint("Auth Error: $exception");

  @override
  Future<PrivateChannelAuthorizationData> authorizationData(
    String socketId,
    String channelName,
  ) async {
    // IMPORTANTE: Asegúrate de que el ApiClient incluya el Token en los headers
    final dio = ApiClient().dio;

    try {
      final response = await dio.post(
        '/broadcasting/auth', // Tu endpoint de Laravel
        data: {'socket_id': socketId, 'channel_name': channelName},
      );

      return PrivateChannelAuthorizationData(
        authKey: response.data['auth'] ?? '',
      );
    } catch (e) {
      debugPrint("🚨 Error en el POST de /broadcasting/auth: $e");
      rethrow;
    }
  }
}
