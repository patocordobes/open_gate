import 'dart:async';
import 'dart:convert';
import 'package:open_gate/models/device_model.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:udp/udp.dart';
import 'package:wifi_configuration_2/wifi_configuration_2.dart';


enum ManagerStatus{
  started,
  starting,
  updating,
  updated,
  stopped
}
class MessageManager with ChangeNotifier {
  late MqttServerClient mqttClient;
  late UDP udpReceiver;
  late UDP udpReceiverForNew;
  late UDP udpSenderForNew;
  late UDP udpSender;
  ManagerStatus status = ManagerStatus.stopped;
  List<Device> devices = [];
  List<Device> scannedDevices = [];
  late Device selectedDevice;
  Device newDevice = Device(mac: "");
  WifiConfiguration wifiConfiguration = WifiConfiguration();

  Future<List<WifiNetwork>> getWifiList() async {
    wifiConfiguration = WifiConfiguration();

    List<WifiNetwork> list = await wifiConfiguration.getWifiList() as List<WifiNetwork>;
    List<WifiNetwork> wifiNetworkList = [];
    List macs = [];
    devices.forEach((device) {
      macs.add(device.mac);
    });
    list.forEach((wifiNetwork) {
      if (devices.isNotEmpty) {
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
    devices = await modelsRepository.getDevices();
    notifyListeners();
  }
  void update({required bool updateWifi}) async {
    if (status == ManagerStatus.started || status == ManagerStatus.updated) {
      status = ManagerStatus.updating ;

      notifyListeners();
      if (updateWifi) {
        scannedDevices = [];
        notifyListeners();
        List<WifiNetwork> wifiNetworkList = await getWifiList();


        wifiNetworkList.forEach((wifi){
          scannedDevices.add(Device(mac:wifi.bssid!,name: wifi.ssid!));
        });

      }
      if (mqttClient.connectionStatus!.state != MqttConnectionState.connected) {

        mqttClient = await connectToMQTT();
        if (mqttClient.connectionStatus!.state == MqttConnectionState.connected) {
          listenMqtt();
        }
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
      mqttClient = await connectToMQTT();
      ModelsRepository modelsRepository = ModelsRepository();
      devices = await modelsRepository.getDevices();
      try {
        listenMqtt();
      }catch (e){
      }
      listenUDP();
      List<WifiNetwork> wifiNetworkList = await getWifiList();

      scannedDevices = [];
      wifiNetworkList.forEach((wifi){
        scannedDevices.add(Device(mac:wifi.bssid!,name: wifi.ssid!));
      });

      updateDevicesConnection();
      status = ManagerStatus.started;
      notifyListeners();
    }

  }
  Future<void> stop() async {
    if (status != ManagerStatus.stopped || status == ManagerStatus.started) {
      udpSender.close();
      udpReceiver.close();
      mqttClient.disconnect();
      status = ManagerStatus.stopped;
    }
  }
  void addDevice(Device device){
    this.devices.add(device);
    notifyListeners();
  }
  void removerDevice(Device device){
    this.devices.remove(device);
    notifyListeners();
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
        bool local = true;
        if (await device.isConnectedLocally()) {

          this.send(jsonEncode(map), true);
        } else {

          local = false;
          try {
            this.send(jsonEncode(map), false);
          } catch (e) {

          }
        }
        try {
          if (device.updateDeviceConnection.isActive){
            device.updateDeviceConnection.cancel();
          }
        }catch (e){

        }

        device.updateDeviceConnection =
            Timer.periodic(Duration(seconds: 3), (timer) {
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
              device.updateDeviceConnection.cancel();
              device.deviceStatus = DeviceStatus.updated;


              status = ManagerStatus.updated;
              notifyListeners();
            });
      }
    }
    for (int i = 0;i < scannedDevices.length;i++) {

      Device device = scannedDevices[i];
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


        this.send(jsonEncode(map), true);

        try {
          if (device.updateDeviceConnection.isActive){
            device.updateDeviceConnection.cancel();
          }
        }catch (e){

        }

        device.updateDeviceConnection =
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
          device.updateDeviceConnection.cancel();
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
    return this.devices;
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

      udpSender = await UDP.bind(Endpoint.broadcast(port: Port(8888)));
      var dataLength = await udpSender.send(
          message.codeUnits, Endpoint.broadcast(port: Port(8888)));
      print("Message: ${message}");
      print("${dataLength} bytes sent.");
      udpSender.close();

    }else{
      if (mqttClient.connectionStatus!.state == MqttConnectionState.connected) {
        const pubTopic = 'control';
        final builder = MqttClientPayloadBuilder();
        builder.addString(message);
        print('EXAMPLE::Publishing our topic');
        mqttClient.publishMessage(
            pubTopic, MqttQos.exactlyOnce, builder.payload!);
      }
    }
    notifyListeners();
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
  if (client.connectionStatus!.state == MqttConnectionState.connected) {
    print('EXAMPLE::Mosquitto client connected');
    print('EXAMPLE::Subscribing to the controlporton/# topic');
    const topic = 'controlporton/#'; // Not a wildcard topic
    client.subscribe(topic, MqttQos.atMostOnce);
  } else {
    /// Use status here rather than state if you also want the broker return code.
    print(
        'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
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
