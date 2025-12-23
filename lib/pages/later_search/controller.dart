import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/later/data.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/common/search/common_search_controller.dart';
import 'package:PiliPlus/pages/later/controller.dart' show BaseLaterController;
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:get/get.dart';

class LaterSearchController
    extends CommonSearchController<LaterData, LaterItemModel>
    with
        CommonMultiSelectMixin<LaterItemModel>,
        DeleteItemMixin,
        BaseLaterController {
  dynamic mid = Get.arguments['mid'];
  dynamic count = Get.arguments['count'];

  @override
  Future<LoadingState<LaterData>> customGetData() => UserHttp.seeYouLater(
    page: page,
    keyword: editController.value.text,
  );

  @override
  List<LaterItemModel>? getDataList(LaterData response) {
    final list = response.list;
    // 检查每个视频是否有离线缓存
    if (list != null && Get.isRegistered<DownloadService>()) {
      final downloadService = Get.find<DownloadService>();
      for (var item in list) {
        if (item.cid != null) {
          item.hasOfflineCache = downloadService.downloadList.any(
            (e) => e.cid == item.cid,
          );
        }
      }
    }
    return list;
  }
}
