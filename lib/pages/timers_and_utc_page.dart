import 'dart:async';
import 'dart:convert';
import 'package:open_gate/manager/device_manager.dart';
import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';


class TimersUtcPage extends StatefulWidget {
  const TimersUtcPage({Key? key}) : super(key: key);




  @override
  State<TimersUtcPage> createState() => _TimersUtcPageState();
}

class _TimersUtcPageState extends State<TimersUtcPage> {

  bool isLoaded = false;
  ModelsRepository modelsRepository = ModelsRepository();
  late Device device;
  late DeviceManager deviceManager;
  late Timer timer;
  late Timer timerRedirect ;
  final _formKey = GlobalKey<FormState>();
  TextEditingController _deviceUTCController = TextEditingController();
  TextEditingController _deviceDayTimerController = TextEditingController();
  TextEditingController _deviceNightTimerController = TextEditingController();
  bool changed = true;

  @override
  void initState() {
    super.initState();
    timerRedirect = Timer.periodic(Duration(seconds:40), (timer) { });
    deviceManager = context.read<DeviceManager>();
    device = deviceManager.selectedDevice;

    refresh();
    timer = Timer.periodic(Duration(milliseconds:1), (timer) async  {
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
    if (device.connectionStatus != ConnectionStatus.disconnected) {
      device.deviceStatus = DeviceStatus.updating;
      Map <String, dynamic> map = {
        "t": "devices/" + device.mac.toUpperCase().substring(3),
        "a": "getutc",
      };
      deviceManager.send(jsonEncode(map), true);
      deviceManager.send(jsonEncode(map), false);
      await Future.delayed(Duration(microseconds: 500));
      device.deviceStatus = DeviceStatus.updating;
      map = {
        "t": "devices/" + device.mac.toUpperCase().substring(3),
        "a": "gettimers",
      };
      deviceManager.send(jsonEncode(map), true);
      deviceManager.send(jsonEncode(map), false);

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
    deviceManager = context.watch<DeviceManager>();

    device = deviceManager.selectedDevice;

    if(device.deviceStatus == DeviceStatus.updating) {
      isLoaded = false;
    }else{
      isLoaded = true;
    }
    if (changed) {

      _deviceUTCController..text = device.UTC.toString();
      _deviceDayTimerController..text = device.dayTimer.toString();
      _deviceNightTimerController..text = device.nightTimer.toString();
      changed = false;
    }
    return Scaffold(
        appBar: AppBar(
          title: Text("Configuración de UTC y timers"),
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
                      Expanded(child:Container()),
                      ElevatedButton(
                        child: Text(
                            "GUARDAR"
                        ),
                        onPressed: (device.deviceStatus != DeviceStatus.updated)? null :  () async {
                          if (_formKey.currentState!.validate()) {
                            changed = true;
                            device.UTC = int.parse(_deviceUTCController.text);
                            device.dayTimer = int.parse(_deviceDayTimerController.text);
                            device.nightTimer = int.parse(_deviceNightTimerController.text);
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
                leading: const Text(""),
                title: Text("UTC:"),
              ),

              Divider(),
              ListTile(
                leading: Icon(Icons.watch_later, size: 30,),

                title: TextFormField(
                    controller: _deviceUTCController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9--]'))],
                    validator: (val) {
                      if (val == null || val == "") {
                        return "Debe completar este campo.";
                      }
                      if (int.parse(val) > 6  || int.parse(val) < -6) {
                        return "El UTC debe ser menor a 6 y mayor a -6";
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "UTC*: ",
                      hintText: "coordinated universal time",
                    )
                ),
              ),
              ListTile(
                leading: const Text(""),
                title: Text("Timers para cerrado del porton (segundos):"),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.wb_sunny, size: 30,),

                title: TextFormField(
                    controller: _deviceDayTimerController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                    validator: (val) {
                      if (val == null || val == "") {
                        return "Debe completar este campo.";
                      }
                      if (int.parse(val) > 255 || int.parse(val) < 5) {
                        return "menores a 255 y mayores a 5";
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Espera de dia*: ",
                      hintText: "Espera para el cerrado del porton de dia (segundos)",
                    )
                ),
              ),
              ListTile(
                leading: Icon(Icons.bedtime, size: 30,),

                title: TextFormField(
                    controller: _deviceNightTimerController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                    validator: (val) {
                      if (val == null || val == "") {
                        return "Debe completar este campo.";
                      }
                      if (int.parse(val) > 255 || int.parse(val) < 5) {
                        return "menores a 255 y mayores a 5";
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Espera de noche*: ",
                      hintText: "Espera para el cerrado del porton de noche (segundos)",
                    )
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
      "a": "setutc",
      "d": {
        "u": device.UTC,
      }
    };
    deviceManager.send(jsonEncode(map), true);
    await Future.delayed(Duration(microseconds: 500));

    device.deviceStatus = DeviceStatus.updating;
    map = {
      "t": "devices/" + device.mac.toUpperCase().substring(3),
      "a": "settimers",
      "d": {
        "d": device.dayTimer,
        "n": device.nightTimer,
      }
    };
    deviceManager.send(jsonEncode(map), true);
    deviceManager.send(jsonEncode(map), false);
  }


}