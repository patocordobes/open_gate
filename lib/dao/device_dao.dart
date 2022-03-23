import 'package:open_gate/database/database.dart';
import 'package:open_gate/models/models.dart';

import 'package:sqflite/sqflite.dart';

class DeviceDao {
  final dbProvider = DatabaseProvider.dbProvider;

  Future<int> createDevice(Device device) async {
    final db = await dbProvider.database;

    var result = db.insert(deviceTable, device.toCreateDatabaseJson(),conflictAlgorithm: ConflictAlgorithm.replace);
    return result;
  }
  Future<int> updateDevice(Device device) async {
    final db = await dbProvider.database;

    var result = db.insert(deviceTable, device.toDatabaseJson(),conflictAlgorithm: ConflictAlgorithm.replace);
    return result;
  }

  Future<int> deleteDevice(Device device) async {
    final db = await dbProvider.database;
    var result = await db
        .delete(deviceTable, where: "id = ?", whereArgs: [device.id]);
    return result;
  }

  Future<List<Map<String,dynamic>>> selectDevices() async {
    final db = await dbProvider.database;
    try {
      List<Map<String,dynamic>> devices = await db
          .query(deviceTable);
      

      return devices;
    } catch (error) {
      print(error);
      throw Exception("Error selecting devices.");

    }
  }
}
