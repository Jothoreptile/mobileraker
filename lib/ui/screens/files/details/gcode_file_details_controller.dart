import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';

final gcodeProvider =
    Provider.autoDispose<GCodeFile>((ref) => throw UnimplementedError());

final canStartPrintProvider = Provider.autoDispose<bool>((ref) {
  var canPrint = ref.watch(printerSelectedProvider.select((value) => {
        PrintState.complete,
        PrintState.error,
        PrintState.standby
      }.contains(value.valueOrFullNull?.print.state)));

  var klippyCanReceiveCommands = ref.watch(klipperSelectedProvider.select(
      (value) => value.valueOrFullNull?.klippyCanReceiveCommands == true));

  return canPrint && klippyCanReceiveCommands;
});

final gcodeFileDetailsControllerProvider =
    StateNotifierProvider.autoDispose<GCodeFileDetailsController, void>(
        (ref) => GCodeFileDetailsController(ref));

class GCodeFileDetailsController extends StateNotifier<void> {
  GCodeFileDetailsController(this.ref)
      : _printerService = ref.watch(printerServiceSelectedProvider),
        _dialogService = ref.watch(dialogServiceProvider),
        _snackBarService = ref.watch(snackBarServiceProvider),
        super(null);
  final AutoDisposeRef ref;
  final PrinterService _printerService;
  final DialogService _dialogService;
  final SnackBarService _snackBarService;

  onStartPrintTap() {
    _printerService.startPrintFile(ref.read(gcodeProvider));
    ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
  }

  onPreHeatPrinterTap() {
    var gCodeFile = ref.read(gcodeProvider);
    var tempArgs = [
      '170',
      gCodeFile.firstLayerTempBed?.toStringAsFixed(0) ?? '60'
    ];
    _dialogService
        .showConfirm(
      title: 'pages.files.details.preheat_dialog.title'.tr(),
      body: tr('pages.files.details.preheat_dialog.body', args: tempArgs),
      confirmBtn: 'pages.files.details.preheat'.tr(),
    )
        .then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false) {
        _printerService.setTemperature('extruder', 170);
        _printerService.setTemperature(
            'heater_bed', (gCodeFile.firstLayerTempBed ?? 60.0).toInt());
        _snackBarService.show(SnackBarConfig(
            title: tr('pages.files.details.preheat_snackbar.title'),
            message: tr('pages.files.details.preheat_snackbar.body',
                args: tempArgs)));
      }
    });
  }
}
