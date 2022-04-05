import 'dart:convert';
import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:wifi_configuration_2/wifi_configuration_2.dart';
import 'dart:async';

enum ConnectionStatus {
  local,
  mqtt,
  updating,
  connecting,
  disconnected
}
enum DeviceStatus{
  updating,
  updated
}
enum SoftwareStatus{
  upgrading,
  upgraded,
  outdated,
  overUpgraded
}
enum WifiStatus{
  connected,
  connecting,
  disconnecting,
  disconnected,
  scanning,
  getting
}


class Device {
  int? id;

  String version = "1.1.1";

  String name = "";

  bool connectedToWiFi = false;
  String ssid = "";
  String address;
  String mac;
  bool locked1 = true;
  bool locked2 = true;
  String passwordAP;
  int UTC;
  int dayTimer ;
  int nightTimer;
  bool gateType;

  bool serverConnected = false;
  ModelsRepository modelsRepository = ModelsRepository();
  SoftwareStatus softwareStatus = SoftwareStatus.upgraded;
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  DeviceStatus deviceStatus = DeviceStatus.updated;
  WifiStatus wifiStatus = WifiStatus.disconnected;

  late Timer timerUpdateDeviceConnection;
  int numberOfDisconnections = 3;
  WifiNetwork? currentWifiNetwork;
  List<WifiNetwork> wifiNetworkList = [];


  String temps = "";



  Device({
    this.id,
    this.version = "1.1.1",
    required this.mac,
    this.address = "",
    this.name = "",
    this.connectedToWiFi = false,
    this.ssid = "",
    this.passwordAP = "",
    this.UTC = 0,
    this.dayTimer = 40,
    this.nightTimer = 30,
    this.gateType = false,

  }){
    if (version != "1.14.0") {
      softwareStatus = SoftwareStatus.outdated;
    }else {
      softwareStatus = SoftwareStatus.upgraded;
    }
    if (connectedToWiFi){
      wifiStatus =WifiStatus.connected;
    }else{
      wifiStatus =WifiStatus.disconnected;
    }

  }

  Future<bool> isSameNetwork() async {
    bool connected = false;
    WifiConfiguration wifiConfiguration = WifiConfiguration();
    bool selfConnected = await wifiConfiguration.isConnectedToWifi("Gate_${this.mac.substring(3).toUpperCase()}");
    if (!selfConnected) {
      if (this.ssid != "") {
        bool localConnected = await wifiConfiguration.isConnectedToWifi(this.ssid);
        if (localConnected) {
          connected = true;
        }
      }
    } else {
      connected = true;
    }
    return connected;
  }

  void listen(String message, {String address= "",required bool local}) async {

    try {
      Map <String, dynamic> map = json.decode(message);
      if (map["t"] == "devices/${mac.toUpperCase().substring(3)}") {
        deviceStatus = DeviceStatus.updated;
        print("json: $map");
        switch (map["a"]) {
          case "connectwifi":
            if (map["status"] != "error"){
              print("no se conecto");
            }
            break;
          case "getip":
            print("Ip: ${map["d"]["ip"]}");
            this.address = map["d"]["ip"] ;
            break;
          case "getmqtt":
            print("Mqtt: ${map["d"]["m"]}");
            serverConnected = (map["d"]["m"] == 1)? true : false;
            break;
          case "getv":
            print("Version: ${map["d"]["v"]}");
            this.version = map["d"]["v"];
            if (version != "1.14.0") {
              softwareStatus = SoftwareStatus.outdated;
            }else {
              softwareStatus = SoftwareStatus.upgraded;
            }
            break;
          case "gettype":
            this.gateType = (map["d"]["t"] == 1) ? true : false;
            print(this.gateType);
            break;
          case "setota":
            softwareStatus = SoftwareStatus.upgrading;
            break;
          case "getfc":
            fromArduinoJson(map);
            break;
          case "set":
            fromArduinoJsonName(map);
            break;
          case "get":
            fromArduinoJsonName(map);
            break;
          case "setutc":
            this.UTC = map["d"]["u"];
            break;
          case "getutc":
            this.UTC = map["d"]["u"];
            break;
          case "settimers":
            this.dayTimer = map["d"]["d"];
            this.nightTimer = map["d"]["n"];
            break;
          case "gettimers":
            this.dayTimer = map["d"]["d"];
            this.nightTimer = map["d"]["n"];
            break;
          case "getcw":
            if (map["d"]["s"] != "") {
              int dBm = int.parse(map["d"]["r"].toString());
              double quality = 0;
              if (dBm <= -100)
                quality = 0;
              else if (dBm >= -50)
                quality = 100;
              else
                quality = 2 * (dBm + 100);
              quality = quality * 4 / 100;
              currentWifiNetwork = WifiNetwork(
                  signalLevel: quality.toInt().toString(),
                  ssid: map["d"]["s"].toString());
              connectedToWiFi = true;
              ssid = currentWifiNetwork!.ssid!;
              wifiStatus = WifiStatus.connected;
            } else {
              currentWifiNetwork = null;
              connectedToWiFi = false;
              wifiStatus = WifiStatus.disconnected;
            }
            break;
          case "deletew":
            ssid = "";
            connectedToWiFi = false;
            currentWifiNetwork = null;
            wifiStatus = WifiStatus.disconnected;
            break;
          default:
            break;
        }


        if (connectionStatus == ConnectionStatus.updating || connectionStatus == ConnectionStatus.connecting) {
          if (!local) {
            connectionStatus = ConnectionStatus.mqtt;
          } else {
            connectionStatus = ConnectionStatus.local;
          }
        }
        if (!local){
          serverConnected = true;
        }
        if (this.id != null){
          modelsRepository.updateDevice(device:this);
        }

      }
    } catch (e) {
    }

    try {
      Map <String, dynamic> map = json.decode(message);
      List<dynamic> listWiFi = map["d"] as List<dynamic>;
      wifiNetworkList = [];
      deviceStatus = DeviceStatus.updated;
      print(map);
      listWiFi.forEach((wifi) {
        Map<String, dynamic> wifiMap = wifi;
        try{
          int dBm = int.parse(wifiMap["r"].toString());
          double quality = 0;
          if (dBm <= -100)
            quality = 0;
          else if (dBm >= -50)
            quality = 100;
          else
            quality = 2 * (dBm + 100);
          quality = quality * 4 / 100;
          wifiNetworkList.add(WifiNetwork(

              signalLevel: quality.toInt().toString(),
              ssid: wifiMap["s"].toString(),
              security: wifiMap["e"].toString()));
        }catch (e){

        }
      });
      if (connectedToWiFi){
        wifiStatus = WifiStatus.connected;
      }else{
        wifiStatus = WifiStatus.disconnected;
      }
      deviceStatus = DeviceStatus.updated;
      if (connectionStatus == ConnectionStatus.updating || connectionStatus == ConnectionStatus.connecting) {
        if (!local) {
          connectionStatus = ConnectionStatus.mqtt;
        } else {
          connectionStatus = ConnectionStatus.local;
        }
      }
      if (!local){
        serverConnected = true;
      }


      if (this.id != null){
        modelsRepository.updateDevice(device:this);
      }
    } catch (e) {

    }
  }

  factory Device.fromDatabaseJson(Map<String, dynamic> json) {
    return Device(
      id: json["id"],
      version: json["version"],
      mac: json["mac"],
      address: json["address"],
      name: json["name"],
      connectedToWiFi: (json["connected_wifi"] == 1) ? true : false,
      ssid: json["ssid"],
      passwordAP: json["passwordAP"],
      UTC: json["UTC"],
      dayTimer: json["dayTimer"],
      nightTimer: json["nightTimer"],
      gateType: (json["gateType"] == 1) ? true : false,
    );
  }
  factory Device.fromQRCode(Map<String, dynamic> json) {
    return Device(
      version: json["version"],
      mac: json["mac"],
      address: json["address"],
      name: json["name"],
      connectedToWiFi: (json["connected_wifi"] == 1) ? true : false,
      ssid: json["ssid"],
      passwordAP: json["passwordAP"],
      UTC: json["UTC"],
      dayTimer: json["dayTimer"],
      nightTimer: json["nightTimer"],
      gateType: (json["gateType"] == 1) ? true : false,
    );
  }

  Map <String, dynamic> toDatabaseJson() =>
      {
        "id": this.id,
        "version": this.version,
        "mac": this.mac,
        "address": this.address,
        "name": this.name,
        "connected_wifi": (this.connectedToWiFi) ? 1 : 0,
        "ssid": this.ssid,
        "passwordAP": this.passwordAP,
        "UTC": this.UTC,
        "dayTimer": this.dayTimer,
        "nightTimer": this.nightTimer,
        "gateType": (this.gateType) ? 1 : 0,
      };

  Map <String, dynamic> toCreateDatabaseJson() =>
      {
        "version": this.version,
        "mac": this.mac,
        "address": this.address,
        "name": this.name,
        "connected_wifi": (this.connectedToWiFi) ? 1 : 0,
        "ssid": this.ssid,
        "passwordAP": this.passwordAP,
        "UTC": this.UTC,
        "dayTimer": this.dayTimer,
        "nightTimer": this.nightTimer,
        "gateType": (this.gateType) ? 1 : 0,
      };

  /*Map <String, dynamic> toArduinoJson() =>
      {
        "p0": (this.prog0) ? 1 : 0,
        "t0": this.temp0,
        "p1": (this.prog1) ? 1 : 0,
        "t1": this.temp1,
        "h1": this.time1,
        "p2": (this.prog2) ? 1 : 0,
        "t2": this.temp2,
        "h2": this.time2,
        "p3": (this.prog3) ? 1 : 0,
        "t3": this.temp3,
        "h3": this.time3
      };*/

  Map <String, dynamic> toArduinoSetJson() =>
      {
        "n": this.name,
        "p": this.passwordAP,
      };
  void fromArduinoJsonName(Map<String, dynamic> json) {
    try {
      this.name = json["d"]["n"];
      this.passwordAP = json["d"]["p"];
    } catch (e) {
      print(e);
    }
  }
  void fromArduinoJson(Map<String, dynamic> json) {
    try {

      this.locked1 = ( json["d"]["fc1"] == 1)? true : false;
      this.locked2 = ( json["d"]["fc2"] == 1)? true : false;
    } catch (e) {

      print(e);
    }
  }


}
