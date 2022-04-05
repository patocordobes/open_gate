import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:system_settings/system_settings.dart';
import 'package:wifi_configuration_2/wifi_configuration_2.dart';
import '../models/models.dart';



class StepOnePage extends StatelessWidget {
  late WifiConfiguration wifiConfiguration;
  late WifiConnectionObject wifi;
  void getWiFi() async {
    wifiConfiguration = WifiConfiguration();
    try{
      print(wifi.ssid);
    }catch (e) {
      wifi = await wifiConfiguration.connectedToWifi();
    }


  }
  @override
  Widget build(BuildContext context) {
    getWiFi();
    return Scaffold(
        appBar: AppBar(
          title: Text("Paso 1"),
          actions: [
            IconButton(icon: Icon(Icons.settings), onPressed: (){
              Navigator.of(context).pushNamed("/settings");
            }),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
              children: [
                ListTile(
                  leading: Text("1."),

                  title: Text("Conenctate a la red Gate_${context.watch<DeviceManager>().newDevice.mac.toUpperCase().substring(3)}"),
                  subtitle: Text("Contraseña: OpenGate1234, Si no es posible debe ser porque alguien la cambio (puedes cambiarla solo reseteando el dispositivo)")
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                        onPressed: (){
                          SystemSettings.wifi();
                        },
                        icon: Icon(Icons.network_wifi),
                        label: Text("Ir a redes"),
                    ),
                    OutlinedButton.icon(
                      onPressed: (){
                        Clipboard.setData(ClipboardData(text: "OpenGate1234"));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Contraseña copiada al portapapeles")));
                      },
                      icon: Icon(Icons.copy),
                      label: Text("Password"),
                    )
                  ],
                ),
                Divider(),
                ListTile(
                  leading: Text("2."),
                  title: Text("Presiona en el mensaje que te aparece en las notificaciones 'Ingresar a esta red'"),
                  subtitle: Text("Esto te dirigira a una pagina externa en donde debes completar informacion."),
                ),
                Divider(),
                ListTile(
                  leading: Text("3."),
                  title: Text("Aqui encontraras un lugar para conectar la red del porton a una red de tu preferencia."),
                  subtitle: Text("Conectate a una en la que ya estes conectado en tu dispositivo celular"),
                ),
                Divider(),
                ListTile(
                  leading: Text("4."),
                  title: Text("Cuando completes todos los pasos apreta en 'SIGUIENTE'"),
                ),
                Divider(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: EdgeInsets.only(right: 16,left: 16),
                    child: Row(
                      children: [
                        Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text("Paso 1 de 3"),
                            )
                        ),
                        ElevatedButton(
                            child: Text(
                                "SIGUIENTE"
                            ),
                            onPressed: () async {

                              wifiConfiguration = WifiConfiguration();
                              await wifiConfiguration.connectToWifi("${wifi.ssid}", "", "");
                              Navigator.of(context).pushNamed("/step_two");
                            }
                        ),
                      ],
                    ),
                  ),
                )

              ]
          ),
        )
    );
  }
}