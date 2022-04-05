import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:open_gate/models/device_model.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:udp/udp.dart';
import 'package:wifi_configuration_2/wifi_configuration_2.dart';
import 'package:http/http.dart' as http;

enum ManagerStatus{
  started,
  starting,
  updating,
  updated,
  stopped
}
class DeviceManager with ChangeNotifier {
  late MqttServerClient mqttClient;
  late UDP udpReceiver;
  late UDP _udpReceiverForNew;
  late UDP _udpSenderForNew;
  late UDP _udpSender;
  ManagerStatus status = ManagerStatus.stopped;
  List<Device> _devices = [];
  List<Device> scannedDevices = [];
  late Device selectedDevice;
  Device newDevice = Device(mac: "");
  WifiConfiguration wifiConfiguration = WifiConfiguration();

  Future<List<WifiNetwork>> getWifiList() async {
    wifiConfiguration = WifiConfiguration();

    List<WifiNetwork> list = await wifiConfiguration.getWifiList() as List<WifiNetwork>;
    List<WifiNetwork> wifiNetworkList = [];
    List macs = [];
    _devices.forEach((device) {
      macs.add(device.mac);
    });
    list.forEach((wifiNetwork) {
      if (_devices.isNotEmpty) {
        if (!macs.contains(wifiNetwork.bssid)) {
          if (wifiNetwork.ssid == "Dinamico${wifiNetwork.bssid!.toUpperCase().substring(3)}" || wifiNetwork.ssid == "Gate_${wifiNetwork.bssid!.toUpperCase().substring(3)}") {
            wifiNetworkList.add(wifiNetwork);
          }
        }
      }else{
        if (wifiNetwork.ssid == "Dinamico${wifiNetwork.bssid!.toUpperCase().substring(3)}" || wifiNetwork.ssid == "Gate_${wifiNetwork.bssid!.toUpperCase().substring(3)}") {
          wifiNetworkList.add(wifiNetwork);
        }
      }
    });
    return wifiNetworkList;
  }

  Future<void> updateDevices() async {
    ModelsRepository modelsRepository = ModelsRepository();
    _devices = await modelsRepository.getDevices();
    notifyListeners();
  }
  void update({required bool updateWifi}) async {
    if (status == ManagerStatus.started || status == ManagerStatus.updated) {
      status = ManagerStatus.updating ;

      notifyListeners();
      if (updateWifi) {
        scannedDevices = [];

        List<WifiNetwork> wifiNetworkList = await getWifiList();


        wifiNetworkList.forEach((wifi){
          scannedDevices.add(Device(mac:wifi.bssid!,name: wifi.ssid!));
        });
        notifyListeners();
      }
      try {
        if (mqttClient.connectionStatus!.state != MqttConnectionState.connected) {

          mqttClient = await connectToMQTT();
          if (mqttClient.connectionStatus!.state ==
              MqttConnectionState.connected) {
            _devices.forEach((device) {

              String topic = 'controlgates/devices/' + device.mac.toUpperCase().substring(3); // Not a wildcard topic
              mqttClient.subscribe(topic, MqttQos.atMostOnce);
            });
            listenMqtt();
          }

        }
      }catch (e){
        mqttClient = await connectToMQTT();
      }
      if (udpReceiver.closed) {

        listenUDP();
        print("udp inited");
      }

      status = ManagerStatus.updated;
      notifyListeners();
    }
  }
  void start() async {

    if (status == ManagerStatus.stopped) {

      status = ManagerStatus.starting;
      udpReceiver = await UDP.bind(Endpoint.any(port: Port(8890)));
      ModelsRepository modelsRepository = ModelsRepository();
      _devices = await modelsRepository.getDevices();
      notifyListeners();

      try {
        if (mqttClient.connectionStatus!.state != MqttConnectionState.connected) {

          mqttClient = await connectToMQTT();
          if (mqttClient.connectionStatus!.state ==
              MqttConnectionState.connected) {
            _devices.forEach((device) {

              String topic = 'controlgates/devices/' + device.mac.toUpperCase().substring(3); // Not a wildcard topic
              mqttClient.subscribe(topic, MqttQos.atMostOnce);
            });
            listenMqtt();
          }

        }
      }catch (e){
        mqttClient = await connectToMQTT();
      }

      listenUDP();
      updateDevicesConnection();
      status = ManagerStatus.started;
      notifyListeners();
    }

  }
  Future<void> stop() async {
    if (status != ManagerStatus.stopped || status == ManagerStatus.started) {
      _udpSender.close();
      udpReceiver.close();
      mqttClient.disconnect();
      status = ManagerStatus.stopped;
    }
  }

  void disconnectDevice(Device device){
    device.connectionStatus = ConnectionStatus.disconnected;
    device.numberOfDisconnections = 3;
    notifyListeners();
  }
  Future<void> updateNewDeviceConnection() async {
    newDevice.connectionStatus = ConnectionStatus.connecting;
    notifyListeners();
  }
  Future<void> updateDeviceConnection(Device device) async {
    device.connectionStatus = ConnectionStatus.connecting;
    updateDevicesConnection();
  }
  Future<void> updateDevicesConnection() async {
    status = ManagerStatus.updating;
    for (int i = 0;i < getDevices.length;i++) {

      Device device = getDevices[i];
      if (device.connectionStatus != ConnectionStatus.disconnected) {
        if (device.connectionStatus != ConnectionStatus.connecting) {
          device.connectionStatus = ConnectionStatus.updating;
        }
        device.deviceStatus = DeviceStatus.updating;

        notifyListeners();
        Map <String, dynamic> map = {
          "t": "devices/" + device.mac.toUpperCase().substring(3),
          "a": "getv"
        };
        bool local = false;
        if (await device.isSameNetwork()) {

          this.send(jsonEncode(map), true);
          local = true;
        } else {
          try {
            this.send(jsonEncode(map), false);
          } catch (e) {
          }
        }
        try {
          if (device.timerUpdateDeviceConnection.isActive){
            device.timerUpdateDeviceConnection.cancel();
          }
        }catch (e){

        }

        device.timerUpdateDeviceConnection = Timer.periodic(Duration(seconds: 2), (timer) {
            if (device.connectionStatus == ConnectionStatus.updating){
              device.numberOfDisconnections ++;
            }else if (device.connectionStatus == ConnectionStatus.connecting || device.connectionStatus == ConnectionStatus.disconnected){
              device.numberOfDisconnections = 3;
              device.connectionStatus = ConnectionStatus.disconnected;
            }else{
              if (local){
                device.connectionStatus = ConnectionStatus.local;
              }else{
                device.connectionStatus = ConnectionStatus.mqtt;
              }
              device.numberOfDisconnections = 0;
            }

            if (device.numberOfDisconnections >= 3){
              device.numberOfDisconnections = 3;
              device.connectionStatus = ConnectionStatus.disconnected;
            }
            device.timerUpdateDeviceConnection.cancel();
            device.deviceStatus = DeviceStatus.updated;


            status = ManagerStatus.updated;
            notifyListeners();
          }
        );
      }
    }
    for (int i = 0;i < scannedDevices.length;i++) {

      Device device = scannedDevices[i];
      if (device.connectionStatus != ConnectionStatus.disconnected) {
        print("hola fe la coneccion");

        if (device.connectionStatus != ConnectionStatus.connecting) {
          device.connectionStatus = ConnectionStatus.updating;
        }
        device.deviceStatus = DeviceStatus.updating;
        notifyListeners();
        Map <String, dynamic> map = {
          "t": "devices/" + device.mac.toUpperCase().substring(3),
          "a": "getv"
        };


        this.send(jsonEncode(map), true);

        try {
          if (device.timerUpdateDeviceConnection.isActive){
            device.timerUpdateDeviceConnection.cancel();
          }
        }catch (e){

        }

        device.timerUpdateDeviceConnection =
        Timer.periodic(Duration(seconds: 3), (timer) {
          if (device.connectionStatus == ConnectionStatus.updating){
            device.numberOfDisconnections ++;

          }else if (device.connectionStatus == ConnectionStatus.connecting || device.connectionStatus == ConnectionStatus.disconnected){

            device.numberOfDisconnections = 3;
            device.connectionStatus = ConnectionStatus.disconnected;
          }else{

            device.connectionStatus = ConnectionStatus.local;

            device.numberOfDisconnections = 0;
          }

          if (device.numberOfDisconnections >= 2){
            device.numberOfDisconnections = 3;
            device.connectionStatus = ConnectionStatus.disconnected;
          }
          device.timerUpdateDeviceConnection.cancel();
          device.deviceStatus = DeviceStatus.updated;
          status = ManagerStatus.updated;
          notifyListeners();
        });
      }
    }
    await Future.delayed(Duration(seconds: 3));
    status = ManagerStatus.updated;
    notifyListeners();
  }
  List<Device> get getDevices{
    return this._devices;
  }
  void listenMqtt(){
    mqttClient.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print(
          'EXAMPLE::Change notification:: topic is <${c[0]
              .topic}>, payload is <-- $pt -->');
      getDevices.forEach((device) {
        device.listen(pt,local:false);
      });

      notifyListeners();
    });
  }
  void listenUDP() async  {
    udpReceiver = await UDP.bind(Endpoint.any(port: Port(8890)));
    udpReceiver.asStream(timeout: Duration(hours: 1)).listen((datagram) {
      var str = String.fromCharCodes(datagram!.data);
      getDevices.forEach((device){
        device.listen(str,address: datagram.address.address,local:true);
      });
      scannedDevices.forEach((device){
        device.listen(str,address: datagram.address.address,local:true);
      });
      notifyListeners();
    });

  }
  void send(String message,bool local) async {
    if (local) {

      http.get(Uri.parse("http://172.217.28.1/settings?message=$message")).then((response)  {


        if (response.statusCode == 200) {
          print(response.body);
          getDevices.forEach((device){
            device.listen(response.body,local:true);
          });
          scannedDevices.forEach((device){
            device.listen(response.body,local:true);
          });
          notifyListeners();

        }else{
          print(response.body);
          print("no se envio nadaasdklñfjasñldkfjasñ");
        }
      },onError: (e){

          print(e);
      });
      _udpSender = await UDP.bind(Endpoint.broadcast(port: Port(8888)));
      var dataLength = await _udpSender.send(
          message.codeUnits, Endpoint.broadcast(port: Port(8888)));
      print("Message: ${message}");
      print("${dataLength} bytes sent.");
      _udpSender.close();



    }else{
      Map <String, dynamic> map = jsonDecode(message);
      if (mqttClient.connectionStatus!.state == MqttConnectionState.connected) {
        String pubTopic = 'control' + "/" + map["t"];
        final builder = MqttClientPayloadBuilder();
        builder.addString(message);
        mqttClient.publishMessage(pubTopic, MqttQos.exactlyOnce, builder.payload!);
      }
    }
  }

  void selectDevice(Device device) {
    selectedDevice = device;
    notifyListeners();
  }
  void selectNewDevice(Device device) {
    newDevice = device;
    notifyListeners();
  }


}

Future<MqttServerClient> connectToMQTT() async {

  MqttServerClient client = MqttServerClient.withPort('appdinamico3.com', 'psironi', 1883);
  client.logging(on: true);
  client.onConnected = onConnected;
  client.onDisconnected = onDisconnected;
  client.onUnsubscribed = onUnsubscribed;
  client.onSubscribed = onSubscribed;
  client.onSubscribeFail = onSubscribeFail;
  client.pongCallback = pong;
  client.keepAlivePeriod = 6000;
  final connMessage = MqttConnectMessage()
      .authenticateAs('psironi', 'Queiveephai6')

      .withWillTopic('willtopic')
      .withWillMessage('Will message')
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);
  client.connectionMessage = connMessage;
  try {
    await client.connect();
  } catch (e) {
    print('Exception: $e');
    client.disconnect();
  }
  if (client.connectionStatus!.state != MqttConnectionState.connected) {
    client.disconnect();
  }
  return client;
}

void onConnected() {
  print('Connected');
}

// unconnected
void onDisconnected() {
  print('Disconnected');
}

// subscribe to topic succeeded
void onSubscribed(String topic) {
  print('Subscribed topic: $topic');
}

// subscribe to topic failed
void onSubscribeFail(String topic) {
  print('Failed to subscribe $topic');
}

// unsubscribe succeeded
void onUnsubscribed(String? topic) {
  print('Unsubscribed topic: $topic');
}
// PING response received
void pong() {
  print('Ping response client callback invoked');
}
