import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/announcement/announcement_entry.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';

final announcementServiceProvider = Provider.autoDispose
    .family<AnnouncementService, String>((ref, machineUUID) {
  ref.keepAlive();

  return AnnouncementService(ref, machineUUID);
});

final announcementProvider = StreamProvider.autoDispose
    .family<List<AnnouncementEntry>, String>((ref, machineUUID) {
  ref.keepAlive();
  return ref
      .watch(announcementServiceProvider(machineUUID))
      .announcementNotificationStream;
});

/// The AnnouncementService handles different notifications/announcements from feed api.
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#announcement-apis
class AnnouncementService {
  AnnouncementService(AutoDisposeRef ref, String machineUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(machineUUID)) {
    ref.onDispose(dispose);
    _jRpcClient.addMethodListener(
        _onNotifyAnnouncementUpdate, "notify_announcement_update");
    _jRpcClient.addMethodListener(
        _onNotifyAnnouncementDismissed, "notify_announcement_dismissed");
    _jRpcClient.addMethodListener(
        _onNotifyAnnouncementWake, "notify_announcement_wake");
  }

  final StreamController<List<AnnouncementEntry>> _announcementsStreamCtrler =
      StreamController();

  Stream<List<AnnouncementEntry>> get announcementNotificationStream =>
      _announcementsStreamCtrler.stream;

  final JsonRpcClient _jRpcClient;

  Future<List<AnnouncementEntry>> listAnnouncements(
      [bool includeDismissed = false]) async {
    logger.i('List Announcements request...');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
          'server.announcements.list',
          params: {'include_dismissed': includeDismissed});

      List<Map<String, dynamic>> entries =
          rpcResponse.response['result']['entries'];

      return _parseAnnouncementsList(entries);
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to fetch announcement list: $e');
    }
  }

  Future<String> dismissAnnouncement(String entryId, [int? wakeTime]) async {
    logger.i('Trying to dismiss announcement `$entryId`');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
          'server.announcements.list',
          params: {'entry_id': entryId, 'wake_time': wakeTime});

      String respEntryId = rpcResponse.response['result']['entry_id'];
      return respEntryId;
    } on JRpcError catch (e) {
      throw MobilerakerException(
          'Unable to dismiss announcement $entryId. Err: $e');
    }
  }

  _onNotifyAnnouncementUpdate(Map<String, dynamic> rawMessage) {
    List<Map<String, dynamic>> rawEntries = rawMessage['params'];
    List<AnnouncementEntry> entries = _parseAnnouncementsList(rawEntries);
    _announcementsStreamCtrler.add(entries);
  }

  _onNotifyAnnouncementDismissed(Map<String, dynamic> rawMessage) {
    logger.i('Announcement dismissed event!!!');
    listAnnouncements().then(_announcementsStreamCtrler.add);
  }

  _onNotifyAnnouncementWake(Map<String, dynamic> rawMessage) {
    logger.i('Announcement wake event!!!');
    listAnnouncements().then(_announcementsStreamCtrler.add);
  }

  List<AnnouncementEntry> _parseAnnouncementsList(
      List<Map<String, dynamic>> entries) {
    return entries.map((e) => AnnouncementEntry.parse(e)).toList();
  }

  dispose() {
    _announcementsStreamCtrler.close();
  }
}
