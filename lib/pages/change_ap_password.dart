import 'dart:async';
import 'dart:convert';
import 'package:open_gate/manager/device_manager.dart';
import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';


class ChangeAPPassword extends StatefulWidget {
  const ChangeAPPassword({Key? key}) : super(key: key);




  @override
  State<ChangeAPPassword> createState() => _ChangeAPPasswordState();
}

class _ChangeAPPasswordState extends State<ChangeAPPassword> {

  bool loading = false;
  ModelsRepository modelsRepository = ModelsRepository();
  late Device device;
  late DeviceManager deviceManager;
  late Timer timerGetting;
  late Timer timerRedirect ;
  bool _obscureText = false;
  final _formKey = GlobalKey<FormState>();
  TextEditingController _devicePasswordController = TextEditingController();

  void initTimer(){
    timerGetting = Timer.periodic(Duration(seconds:10), (timer) async  {
      if (device.connectionStatus != ConnectionStatus.disconnected) {
        if (device.connectionStatus == ConnectionStatus.local || device.connectionStatus == ConnectionStatus.updating) {

          device.deviceStatus = DeviceStatus.updating;
          Map <String, dynamic> map = {
            "t": "devices/" + device.mac.toUpperCase().substring(3),
            "a": "get",
          };
          deviceManager.send(jsonEncode(map), true);
          deviceManager.send(jsonEncode(map), false);
        }
      }
    });
  }
  @override
  void initState() {
    super.initState();
    deviceManager = context.read<DeviceManager>();

    device = deviceManager.selectedDevice;

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

    device = deviceManager.selectedDevice;

    if(device.deviceStatus == DeviceStatus.updating) {
      loading = true;
    }else{
      loading = false;
    }
    if (_devicePasswordController.text == "") {
      _devicePasswordController..text = device.passwordAP;
    }
    return Scaffold(
        appBar: AppBar(
          title: Text("Contraseña de la red del porton"),
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
              (loading)?LinearProgressIndicator():Container(),
              form(),
              Divider(thickness: 2,),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: EdgeInsets.only(right: 16,left: 16),
                  child: Row(
                    children: [
                      ElevatedButton(
                        child: Text(
                            "GUARDAR"
                        ),
                        onPressed: (loading)? null :  () async {
                          if (_formKey.currentState!.validate()) {
                            device.passwordAP = _devicePasswordController.text;
                            print(device.toDatabaseJson());
                            setDevice();
                            timerRedirect.cancel();
                            timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {
                              if (device.deviceStatus == DeviceStatus.updated){
                                timerRedirect.cancel();
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
                          labelText: "Contraseña de la red del porton*: ",
                          hintText: "Contraseña de la red del porton",
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
    deviceManager.send(jsonEncode(map), true);
  }


}