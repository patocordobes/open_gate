import 'dart:async';

import 'package:open_gate/models/models.dart';
import 'package:open_gate/pages/pages.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  ModelsRepository modelsRepository = ModelsRepository();
  List<Device> devicesConnected = [];
  List<Device> devicesDisconnected = [];
  bool isLoaded = false;
  late MessageManager messageManager;
  late Timer updateDevicesConnection;
  late Timer updateMqtt;
  late Timer timerRedirect;


  @override
  void initState(){
    super.initState();
    timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {
    });
    messageManager = context.read<MessageManager>();
    messageManager.start();
    refresh();
    updateDevicesConnection = Timer.periodic(Duration(seconds: 40), (t) {
      messageManager.updateDevicesConnection();
    });
    updateMqtt = Timer.periodic(Duration(seconds:5),(t){

      messageManager.update(updateWifi: false);

    });
  }
  void refresh(){
    messageManager.updateDevicesConnection();
  }
  @override
  void dispose() {
    super.dispose();
    updateMqtt.cancel();
    updateDevicesConnection.cancel();
    messageManager.stop();
  }
  @override
  Widget build(BuildContext context) {

    messageManager = context.watch<MessageManager>();
    if(messageManager.status == ManagerStatus.starting || messageManager.status == ManagerStatus.updating) {
      isLoaded = false;
    }else{
      isLoaded = true;
    }
    devicesConnected = [];
    devicesDisconnected = [];
    messageManager.getDevices.forEach((device){
      if (device.connectionStatus != ConnectionStatus.disconnected && device.connectionStatus != ConnectionStatus.connecting){
        devicesConnected.add(device);
      }else{
        devicesDisconnected.add(device);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: (){
                Navigator.of(context).pushNamed("/settings");
              }
          ),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: (){
                refresh();
              }
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(

          mainAxisSize: MainAxisSize.min,
          children: getList(),
        ),
      ),
    );
  }
  List<Widget> getList(){
    List<Widget> list = [];
    if (!isLoaded){
      list.add(LinearProgressIndicator());
    }
    if (devicesConnected.isNotEmpty){
      list.add(
          ListTile(
            leading: Text(""),
            title: Text('Conectados Actualmente',style: TextStyle(color: Theme.of(context).primaryColor),),
          )
      );
    }
    devicesConnected.forEach((device){
      list.add(
        OpenContainer(
          openBuilder: (_, closeContainer) => DevicePage(),
          tappable: false,
          closedColor: Theme.of(context).dialogBackgroundColor,
          openColor: Colors.transparent,
          closedBuilder: (_, openContainer) => DeviceWidget(device: device,messageManager: messageManager, openContainer: openContainer,onTap: (){
            openContainer();
            messageManager.selectDevice(device);
          }),
        ),
      );
    });
    if (devicesDisconnected.isNotEmpty){

      list.add(
        ListTile(
          leading:Text(""),
          title: Text('Portones conectados previamente',style: TextStyle(color: Theme.of(context).primaryColor),)
        )
      );
    }
    devicesDisconnected.forEach((device){
      list.add(
        OpenContainer(
          openBuilder: (_, closeContainer) => DevicePage(),

          closedColor: Theme.of(context).dialogBackgroundColor,
          openColor: Colors.transparent,
          closedBuilder: (_, openContainer) => DeviceWidget(device: device,messageManager: messageManager, openContainer: openContainer,onTap: () async {
            messageManager.selectDevice(device);
            messageManager.updateDeviceConnection(device);
            timerRedirect.cancel();
            timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {
              if (device.connectionStatus == ConnectionStatus.local || device.connectionStatus == ConnectionStatus.mqtt){
                timerRedirect.cancel();
                openContainer();
              }
            });
            await Future.delayed(Duration(milliseconds:3000),(){
              timerRedirect.cancel();
            });
          }),
        ),
      );
    });
    if (devicesDisconnected.isNotEmpty || devicesConnected.isNotEmpty) {
      list.add(Divider());
    }
    list.add(
        ListTile(
          leading: Icon(Icons.add,size: 30),
          title: Text('Sincronizar porton nuevo'),
          onTap: (){
            Navigator.of(context).pushNamed("/search_devices");
          },
        )
    );
    list.add(Divider());
    list.add(
        ListTile(
            leading:Icon(Icons.info_outline),
            subtitle: Text('Toca un porton para conectarte\n')
        )
    );
    return list;
  }

}
class DeviceWidget extends StatelessWidget {
  DeviceWidget({required this.device, required this.messageManager, required this.openContainer, required this.onTap});
  final Device device;
  final MessageManager messageManager;
  final VoidCallback openContainer;
  final void Function() onTap;
  @override
  Widget build(BuildContext context){
    return Row(
        children: [
          Expanded(
            child: ListTile(
              enabled: (device.connectionStatus == ConnectionStatus.connecting)? false:true,
              leading: (device.softwareStatus == SoftwareStatus.outdated)? Icon(Icons.new_releases,size: 30):(device.softwareStatus == SoftwareStatus.overUpgraded)? Icon(Icons.warning,size: 30): Icon(
                IconData(59653, fontFamily: 'signal_wifi'),size: 30,),
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

              onTap: onTap,
            ),
          ),
          Container(color: Theme.of(context).dividerColor, height: 40, width: 2,),
          IconButton(
              color: Theme.of(context).accentColor,
              icon: Icon(Icons.edit),
              onPressed: (){
                messageManager.selectDevice(device);
                Navigator.of(context).pushNamed("/edit_device");
              }
          )
        ]
    );
  }
}