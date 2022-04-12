import 'dart:async';
import 'dart:convert';
import 'package:open_gate/manager/device_manager.dart';
import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';


class ChangeNamePage extends StatefulWidget {
  const ChangeNamePage({Key? key,  this.create = true}) : super(key: key);

  final bool create;


  @override
  State<ChangeNamePage> createState() => _ChangeNamePageState();
}

class _ChangeNamePageState extends State<ChangeNamePage> {
  ModelsRepository modelsRepository = ModelsRepository();
  late Device device;
  late DeviceManager deviceManager;
  late Timer timerGetting;
  late Timer timerRedirect ;
  final _formKey = GlobalKey<FormState>();
  TextEditingController _deviceNameController = TextEditingController();
  bool isLoaded = false;

  void initTimer(){
    timerGetting = Timer.periodic(Duration(seconds:10), (timer) async  {
      if (device.connectionStatus != ConnectionStatus.disconnected) {
        device.deviceStatus = DeviceStatus.updating;
        Map <String, dynamic> map = {
          "t": "devices/" + device.mac.toUpperCase().substring(3),
          "a": "get",
        };
        deviceManager.send(jsonEncode(map), true);
        deviceManager.send(jsonEncode(map), false);
      }
    });
  }

  @override
  void initState() {
    _deviceNameController..text = "Nombre";
    super.initState();
    deviceManager = context.read<DeviceManager>();
    if (widget.create){
      device = deviceManager.newDevice;
    }else {
      device = deviceManager.selectedDevice;
    }
    initTimer();
    timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) async  {
      if (device.connectionStatus == ConnectionStatus.disconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Se ha perdido la conexión con el dispositivo!'),backgroundColor:Theme.of(context).errorColor),
        );
        Navigator.of(context).pop();
      }
    });
  }
  void refresh() async {
    timerGetting.cancel();
    initTimer();
  }
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }
  @override
  void dispose() {
    timerGetting.cancel();
    timerRedirect.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    deviceManager = context.watch<DeviceManager>();
    if (widget.create){
      device = deviceManager.newDevice;
    }else {
      device = deviceManager.selectedDevice;
    }
    if(device.deviceStatus == DeviceStatus.updating) {
      isLoaded = false;
    }else{
      isLoaded = true;
    }
    if (_deviceNameController.text == "Nombre" ) {

      _deviceNameController..text = device.name;
    }
    return Scaffold(
        appBar: AppBar(
          title: Text("Nombre del Porton"),
          actions: [
            IconButton(icon: Icon(Icons.settings), onPressed: () {
              Navigator.of(context).pushNamed("/settings");
            }),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  color:Theme.of(context).primaryColor,
                  child: ListTile(
                    leading: Icon(
                      IconData(59653, fontFamily: 'signal_wifi'), size: 30,),
                    title: Text('${device.name}'),
                    subtitle: Text(
                        (device.connectionStatus == ConnectionStatus.connecting)
                            ? "Conectando..."
                            : (device.connectionStatus ==
                            ConnectionStatus.disconnected)
                            ? "Desconectado"
                            : (device.connectionStatus == ConnectionStatus.local)
                            ? "Conectado localmente"
                            : (device.connectionStatus == ConnectionStatus.updating)?"Sincronizando...":"Conectado a traves del servidor"),
                  )
              ),
              (!isLoaded)?LinearProgressIndicator():Container(),
              form(),
              Divider(thickness: 2,),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: EdgeInsets.only(right: 16,left: 16),
                  child: Row(
                    children: [
                      (widget.create)?
                      Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Paso 3 de 3"),
                          )
                      ) : Expanded(child:Container()),
                      ElevatedButton(
                        child: Text(
                            "GUARDAR"
                        ),
                        onPressed: (device.deviceStatus != DeviceStatus.updated)? null :  () async {
                          if (_formKey.currentState!.validate()) {
                            device.name = _deviceNameController.text;
                            print(device.toDatabaseJson());
                            setDevice();

                            timerRedirect.cancel();
                            timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {
                              if (device.deviceStatus == DeviceStatus.updated){
                                timerRedirect.cancel();
                                if (widget.create) {
                                  modelsRepository.createDevice(
                                      device: device).then((value) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(content: Text(
                                          'Porton guardado exitosamente'),
                                          backgroundColor: Colors.green),
                                    );


                                    deviceManager.update(updateWifi: true);
                                    Navigator.of(context).pushNamedAndRemoveUntil("/devices", (route) => false);
                                    
                                  });
                                } else {
                                  modelsRepository.updateDevice(
                                      device: device).then((value) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(content: Text(
                                          'Porton editado exitosamente'),
                                          backgroundColor: Colors.green),
                                    );
                                    Navigator.of(context).pop();
                                  });
                                }
                              }
                            });
                            await Future.delayed(Duration(milliseconds: 3000),(){
                              timerRedirect.cancel();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        )

    );
  }


  Widget form() {
    return Form(
        key: _formKey,
        child: Column(
            children: [


              ListTile(
                leading: Icon(
                  IconData(59653, fontFamily: 'signal_wifi'), size: 30,),

                title: TextFormField(
                    controller: _deviceNameController,
                    maxLength: 20,
                    validator: (val) {
                      if (val == null || val == "") {
                        return "Debe completar este campo.";
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Nombre del porton*: ",
                      hintText: "Nombre del porton",
                    )
                ),
              ),
              Divider(),
              ListTile(
                leading:Icon(Icons.info_outline),
                subtitle: Text('Este sera el nombre que aparecera en la primera pantalla\n')
              )
            ]
        )
    );
  }

  void setDevice() async {
    device.deviceStatus = DeviceStatus.updating;
    Map <String, dynamic> map = {
      "t": "devices/" + device.mac.toUpperCase().substring(3),
      "a": "set",
      "d": device.toArduinoSetJson()
    };
    deviceManager.send(jsonEncode(map), true);
    deviceManager.send(jsonEncode(map), false);
  }


}