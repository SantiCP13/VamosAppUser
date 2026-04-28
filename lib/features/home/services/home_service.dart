import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import '../../../core/network/api_client.dart';
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
    _client = PusherChannelsClient.websocket(
      options: PusherChannelsOptions.fromHost(
        scheme: dotenv.env['REVERB_SCHEME'] ?? 'wss',
        host: dotenv.env['REVERB_HOST'] ?? 'api.vamosapp.com.co',
        port: int.parse(dotenv.env['REVERB_PORT'] ?? '443'),
        key: dotenv.env['REVERB_KEY'] ?? '06exymiubefjjglwmvqe',
      ),
      connectionErrorHandler: (exception, trace, client) {
        debugPrint("🚨 Error de Socket en Producción: $exception");
      },
    );

    _client!.eventStream.listen((event) {
      if (event.name == 'pusher:connection_established') {
        final channel = _client!.privateChannel(
          'private-usuario.$userId',
          authorizationDelegate: UserPusherAuth(token: token),
        );
        channel.subscribe();

        // Escuchamos cuando un conductor ACEPTA
        channel.bind('ViajeAceptado').listen((e) {
          if (e.data != null) onEvent('ViajeAceptado', json.decode(e.data!));
        });

        // 🔥 NUEVO: Escuchamos cuando el sistema CANCELA (falta de conductores)
        channel.bind('ViajeCancelado').listen((e) {
          if (e.data != null) onEvent('ViajeCancelado', json.decode(e.data!));
        });
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
    final dio = ApiClient().dio;

    // Usamos el baseUrl que ya tiene configurado el ApiClient (https://api.vamosapp.com.co/api)
    final response = await dio.post(
      '/broadcasting/auth', // Al poner solo esto, Dio usa automáticamente la URL del .env
      data: {'socket_id': socketId, 'channel_name': channelName},
    );

    return PrivateChannelAuthorizationData(
      authKey: response.data['auth'] ?? '',
    );
  }
}
