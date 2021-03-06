import 'dart:async';
import 'dart:convert';
import 'package:animations/animations.dart';
import 'package:open_gate/models/user_model.dart';
import 'package:open_gate/manager/device_manager.dart';
import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({Key? key}) : super(key: key);
  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  late Device device;
  bool isLoaded = false;

  ModelsRepository modelsRepository = ModelsRepository();
  late DeviceManager deviceManager;

  User user = User();

  late Timer timerAll;
  late Timer timer;


  
  @override
  void initState() {
    super.initState();

    modelsRepository.getUser.then((user) {
      setState(() {
        this.user = user;
      });
    });

    refresh();

    timerAll = Timer.periodic(Duration(seconds:10), (timer) {

        Map <String, dynamic> map = {
          "t":"devices/" + device.mac.toUpperCase().substring(3),
          "a":"getfc",
        };
        if (device.connectionStatus == ConnectionStatus.local) {
          deviceManager.send(jsonEncode(map),true);
        }else{
          deviceManager.send(jsonEncode(map),false);
        }

    });

    timer = Timer.periodic(Duration(seconds:1), (timer) async  {
      if (device.connectionStatus == ConnectionStatus.disconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Se ha perdido la conexión con el porton!'),backgroundColor:Theme.of(context).errorColor),
        );
        Navigator.of(context).pop();
      }
    });
  }
  void refresh() async {

    await Future.delayed(Duration(microseconds:100));

    Map map = {
      "t":"devices/" + device.mac.toUpperCase().substring(3),
      "a":"getfc",
    };
    if (device.connectionStatus == ConnectionStatus.local) {
      deviceManager.send(jsonEncode(map),true);
    }else{
      deviceManager.send(jsonEncode(map),false);
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

    timerAll.cancel();
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${device.name }'),
        actions: [

          IconButton(icon: Icon(Icons.settings), onPressed: (){
            Navigator.of(context).pushNamed("/settings");
          }),
        ],
      ),
      body:  SingleChildScrollView(
        child: Column(
          children: [

            SafeArea(
              child: Row(
                children:getButtons(),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,

                children: getRequests(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  List<Widget> getRequests(){
    List<Widget> list = [];
    device.requests.forEach((request) {
      list.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("${(request.received)?"Recibido ":(request.timeElapsed)? "No se envio ": "Enviando... "}",style: TextStyle(fontSize: 20)),
            (request.received)?
            Icon(Icons.check, color: Colors.green,):
              (request.timeElapsed)?
            Icon(Icons.error, color: Colors.red): Container(child: CircularProgressIndicator(),height:16,width: 16),
          ],
        )
      );
      list.add(
        Divider()
      );
    });
    return list ;
  }
  List<Widget> getButtons(){
    List<Widget> buttons = [];
    buttons.add(Expanded(
      child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Icon(device.locked1? Icons.lock: Icons.lock_open, size: 100,color: device.locked1? Colors.green: Colors.red),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.width/2,
            width: MediaQuery.of(context).size.width/2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: (){
                  Map map = {
                    "t":"devices/" + device.mac.toUpperCase().substring(3),
                    "a":"set1",
                  };
                  Request request = device.addRequest(jsonEncode(map));
                  Future.delayed(Duration(seconds: 3),(){
                    setState(() {
                      request.timeElapsed = true;
                    });
                  });
                  Future.delayed(Duration(seconds: 5),(){
                    setState(() {
                      device.requests.remove(request);
                    });
                  });
                  if (device.connectionStatus == ConnectionStatus.local) {
                    deviceManager.send(jsonEncode(map),true);
                  }else{
                    deviceManager.send(jsonEncode(map),false);
                  }
                },
                child: Text("Porton 1",style: TextStyle(fontSize: 20),),
              ),
            ),
          ),
        ],
      ),
    )
    );
    if (device.gateType){
      buttons.add(Expanded(
        child:Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Icon(device.locked2? Icons.lock: Icons.lock_open, size: 100, color: device.locked2? Colors.green: Colors.red),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.width/2,
              width: MediaQuery.of(context).size.width/2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton(
                  onPressed: (){
                    Map map = {
                      "t":"devices/" + device.mac.toUpperCase().substring(3),
                      "a":"set2",
                    };
                    Request request = device.addRequest(jsonEncode(map));
                    Future.delayed(Duration(seconds: 3),(){
                      setState(() {
                        request.timeElapsed = true;
                      });
                    });
                    Future.delayed(Duration(seconds: 5),(){
                      setState(() {
                        device.requests.remove(request);
                      });
                    });
                    if (device.connectionStatus == ConnectionStatus.local) {
                      deviceManager.send(jsonEncode(map),true);
                    }else{
                      deviceManager.send(jsonEncode(map),false);
                    }
                  },
                  child: Text("Porton 2",style: TextStyle(fontSize: 20),),
                ),
              ),
            ),
          ],
        ),
      )
      );
    }

    return buttons;
  }

  void updateDevice(Map <String, dynamic> data) async {
    device.deviceStatus = DeviceStatus.updating;
    Map <String, dynamic> map = {
      "t":"devices/" + device.mac.toUpperCase().substring(3),
      "a":"set",
      "d": data
    };
    if (device.connectionStatus == ConnectionStatus.local) {
      deviceManager.send(jsonEncode(map),true);
    }else{
      deviceManager.send(jsonEncode(map),false);
    }
  }
}

class CircularButton extends StatelessWidget {
  final String text;
  final Function onPressed;
  const CircularButton({
    Key? key,
    required this.text,
    required this.onPressed,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8),
      child: Container(

        child: ClipRRect( // Crea un rectangulo con bordes circulares dentro del cual puede ir el boton
          child: ElevatedButton(
            onPressed: () {onPressed();},
            child: Text(
              text,
            ),
          ),
        ),
      ),
    );
  }
}