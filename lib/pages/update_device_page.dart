import 'dart:async';
import 'dart:convert';

import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

class UpdateDevicePage extends StatefulWidget {
  const UpdateDevicePage({Key? key}) : super(key: key);
  @override
  State<UpdateDevicePage> createState() => _UpdateDevicePageState();
}

class _UpdateDevicePageState extends State<UpdateDevicePage> {

  bool isLoaded = false;
  ModelsRepository modelsRepository = ModelsRepository();
  User user = User();
  bool magnifier = false;
  double magnifierSize = 100;
  late Timer timerOta ;
  late MessageManager messageManager;
  late Device device;
  
  @override
  void initState() {
    
    super.initState();
    timerOta = Timer.periodic(Duration(milliseconds:1), (timer) {
    });
    refresh();
  }
  void refresh() async {

    await Future.delayed(Duration(seconds:2));
    device.deviceStatus = DeviceStatus.updating;
    Map <String, dynamic> map = {
      "t":"devices/" + device.mac.toUpperCase().substring(3),
      "a":"getv",
    };
    messageManager.send(jsonEncode(map),true);
    await Future.delayed(Duration(milliseconds:200));
    device.deviceStatus = DeviceStatus.updating;
    map = {
      "t": "devices/" + device.mac.toUpperCase().substring(3),
      "a": "getip",
    };
    if (await device.isConnectedLocally()) {
      messageManager.send(jsonEncode(map), true);
    }else{
      messageManager.send(jsonEncode(map), false);
    }
  }
  @override
  void setState(fn) {
    if(mounted) {
      super.setState(fn);
    }
  }
  @override
  void dispose(){
    timerOta.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    messageManager = context.watch<MessageManager>();
    device = messageManager.selectedDevice;

    if(device.deviceStatus == DeviceStatus.updating) {
      isLoaded = false;
    }else{
      isLoaded = true;
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('Actualización "${device.name}"'),
        actions: [
          IconButton(icon: Icon(Icons.settings), onPressed: (){
            Navigator.of(context).pushNamed("/settings");
          }),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            (isLoaded)?Container():LinearProgressIndicator(),
            ListTile(
              leading:(device.softwareStatus == SoftwareStatus.upgrading)? Container(
                height: 50,
                width: 50,
                child: CircularProgressIndicator()
              ): Icon(Icons.new_releases, size: 50),
              title: Text((device.softwareStatus == SoftwareStatus.upgraded)?"El porton está actualizado":(device.softwareStatus == SoftwareStatus.upgrading)?"Actualizando porton...":"Actualizacion disponible",style:Theme.of(context).textTheme.headline4)
            ),
            ListTile(
              subtitle: Column(

                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Version del sofware: ${device.version}\n"),
                  Text("Última version: 1.5\n"),
                ]
              ),
            ),
            Divider(),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only( right:10),
                    child: (device.softwareStatus == SoftwareStatus.outdated || device.softwareStatus == SoftwareStatus.upgraded)?OutlinedButton(
                        child: Text("COMPROBAR ACTUALIZACIONES"),
                        onPressed:  () {
                          refresh();
                        }
                    ): null
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                      child: Text("ACTUALIZAR"),
                      onPressed: (device.softwareStatus == SoftwareStatus.outdated)? () {

                        device.deviceStatus = DeviceStatus.updating;
                        device.connectionStatus = ConnectionStatus.updating;
                        Map <String, dynamic> map = {
                          "t": "devices/" + device.mac.toUpperCase()
                              .substring(3),
                          "a": "setota",
                        };
                        messageManager.send(jsonEncode(map), true);
                        timerOta.cancel();
                        timerOta = Timer.periodic(Duration(milliseconds:1), (timer) async {
                          if (device.softwareStatus == SoftwareStatus.upgrading) {
                            timerOta.cancel();
                            await Future.delayed(Duration(milliseconds:5000));
                            FormData formData = new FormData.fromMap({
                            "file": await MultipartFile.fromBytes(
                            (await rootBundle.load('assets/files/control_porton-v1.9_${device.gateType? "2":"1"}.ino.generic.bin')).buffer.asInt8List(),
                            filename: "control_porton-v1.9_${device.gateType? "2":"1"}.ino.generic.bin"),
                            });
                            var dio = Dio(); // with default Options

                            dio.options.baseUrl = "http://${device.address}:8080/webota";

                            var response = await dio.post(
                                "",
                                data: formData);
                            if (response.statusCode == 200) {
                              device.softwareStatus != SoftwareStatus.upgraded;
                              Navigator.of(context).pop();
                              messageManager.disconnectDevice(device);
                              showDialog(context: context, builder: (_) {
                                return AlertDialog(
                                  title: Text("Software actualizado correctamente"),
                                  content: Text("Para terminar presiona aceptar. El porton tardara unos minutos en volver a responder, luego podra volver a conectarlo apretando en conectar. "),
                                  actions: [
                                    TextButton(
                                      child: Text("ACEPTAR"),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    )
                                  ],

                                );
                              });
                            }
                          }
                        });
                        Future.delayed(Duration(milliseconds:4000),(){
                          timerOta.cancel();
                          if (device.softwareStatus != SoftwareStatus.upgrading){

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('No se pudo actualizar'),backgroundColor: Theme.of(context).errorColor),
                            );
                            messageManager.disconnectDevice(device);
                            Navigator.of(context).pop();
                          }
                        });

                      }: null

                  ),
                ),
              ],
            ),
            (device.softwareStatus == SoftwareStatus.upgrading)?Text("Por favor espere a que el porton se actualice correctamente, esto aveces puede fallar"):Container()


          ],
        ),
      ),
    );
  }
}
