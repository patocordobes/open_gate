import 'dart:async';
import 'dart:convert';
import 'package:open_gate/models/message_manager_model.dart';
import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';


class DeviceSettingsPage extends StatefulWidget {
  const DeviceSettingsPage({Key? key,  this.create = true}) : super(key: key);

  final bool create;


  @override
  State<DeviceSettingsPage> createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {

  bool isLoaded = false;
  ModelsRepository modelsRepository = ModelsRepository();
  late Device device;
  late MessageManager messageManager;
  late Timer timer;
  late Timer timerRedirect ;
  bool _obscureText = false;
  final _formKey = GlobalKey<FormState>();
  TextEditingController _deviceNameController = TextEditingController();
  TextEditingController _devicePasswordController = TextEditingController();
  bool changed = true;

  @override
  void initState() {
    super.initState();
    timerRedirect = Timer.periodic(Duration(seconds:40), (timer) { });
    messageManager = context.read<MessageManager>();
    if (widget.create){
      device = messageManager.newDevice;
    }else {
      device = messageManager.selectedDevice;
    }
    refresh();
    timer = Timer.periodic(Duration(milliseconds:1), (timer) async  {
      if (device.connectionStatus != ConnectionStatus.disconnected) {
        if (device.connectionStatus != ConnectionStatus.local && device.connectionStatus != ConnectionStatus.updating) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Solo puedes editar esto en local'),backgroundColor:Theme.of(context).errorColor),
          );
          Navigator.of(context).pop();
        }
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Se ha perdido la conexión con el dispositivo!'),backgroundColor:Theme.of(context).errorColor),
        );
        Navigator.of(context).pop();
      }
    });
  }
  void refresh() async {
    if (device.connectionStatus != ConnectionStatus.disconnected) {
      if (device.connectionStatus != ConnectionStatus.local && device.connectionStatus != ConnectionStatus.updating) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Solo puedes editar esto en local'),backgroundColor:Theme.of(context).errorColor),
        );
        Navigator.of(context).pop();
      }else{
        device.deviceStatus = DeviceStatus.updating;
        Map <String, dynamic> map = {
          "t": "devices/" + device.mac.toUpperCase().substring(3),
          "a": "get",
        };
        messageManager.send(jsonEncode(map), true);
      }
    }else{
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Se ha perdido la conexión con el porton!'),backgroundColor:Theme.of(context).errorColor),
      );
      Navigator.of(context).pop();
    }
  }
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }
  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    messageManager = context.watch<MessageManager>();
    if (widget.create){
      device = messageManager.newDevice;
    }else {
      device = messageManager.selectedDevice;
    }
    if(device.deviceStatus == DeviceStatus.updating) {
      isLoaded = false;
    }else{
      isLoaded = true;
    }
    if (changed) {
      _deviceNameController..text = device.name;
      _devicePasswordController..text = device.passwordAP;
      changed = false;
    }
    return Scaffold(
        appBar: AppBar(
          title: Text("Configuración del porton"),
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
                            child: Text((widget.create)?"Paso 2 de 2":""),
                          )
                      ) : Expanded(child:Container()),
                      ElevatedButton(
                        child: Text(
                            "GUARDAR porton"
                        ),
                        onPressed: (device.deviceStatus != DeviceStatus.updated)? null :  () async {
                          if (_formKey.currentState!.validate()) {
                            changed = true;
                            device.name = _deviceNameController.text;
                            device.passwordAP = _devicePasswordController.text;
                            print(device.toDatabaseJson());
                            setDevice();

                            timerRedirect.cancel();
                            timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {
                              if (device.deviceStatus == DeviceStatus.updated){
                                timerRedirect.cancel();
                                if (widget.create) {
                                  modelsRepository.createDevice(
                                      device: device).then((value) {
                                    messageManager.updateDevices();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(content: Text(
                                          'Porton guardado exitosamente'),
                                          backgroundColor: Colors.green),
                                    );

                                    messageManager.udpReceiver.close();
                                    messageManager.update(updateWifi: true);
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
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
                leading: const Text(""),
                title: Text("Porton:"),
              ),

              Divider(),
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
              ListTile(
                leading: const Text(""),
                title: Text("WiFi:"),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.lock, size: 30,),

                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                        controller: _devicePasswordController,
                        maxLength: 20,
                        obscureText: !_obscureText,
                        validator: (val) {
                          if (val == null || val == "") {
                            return "Debe completar este campo.";
                          }
                          if (val.length < 8){
                            return "La contraseña debe contenera almenos 8 caracteres";
                          }
                        },
                        decoration: InputDecoration(
                          labelText: "Contraseña del WiFi del porton*: ",
                          hintText: "Contraseña del WiFi del porton",
                        )
                    ),
                    GestureDetector(
                      onTap: (){
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                      child: Row(
                        children: [
                          Checkbox(value: _obscureText, onChanged: (value){
                            setState(() {
                              _obscureText = value!;
                            });

                          }),
                          Text("Mostrar contraseña")

                        ],),
                    ),
                  ],
                ),

              ),
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
    messageManager.send(jsonEncode(map), true);
  }


}