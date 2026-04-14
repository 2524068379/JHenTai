import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/mixin/new_search_argument.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../model/search_config.dart';
import '../pages/search/mobile_v2/search_page_mobile_v2_logic.dart';
import '../routes/routes.dart';
import '../setting/preference_setting.dart';
import '../widget/eh_search_config_dialog.dart';

Future<void> newSearch({String? keyword, SearchConfig? rewriteSearchConfig, bool forceNewRoute = false}) async {
  assert(keyword != null || rewriteSearchConfig != null);

  if (SearchPageMobileV2Logic.current == null) {
    toRoute(
      Routes.mobileV2Search,
      arguments: NewSearchArgument(
        keyword: keyword,
        keywordSearchBehaviour: preferenceSetting.searchBehaviour.value,
        rewriteSearchConfig: rewriteSearchConfig,
      ),
    );
    return;
  }

  if (SearchPageMobileV2Logic.current!.state.loadingState == LoadingState.loading) {
    return;
  }

  if (isRouteAtTop(Routes.mobileV2Search) && !forceNewRoute) {
    await SearchPageMobileV2Logic.current!.state.searchConfigInitCompleter.future;
    if (rewriteSearchConfig != null) {
      SearchPageMobileV2Logic.current!.state.searchConfig = rewriteSearchConfig;
    } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.inheritAll) {
      SearchPageMobileV2Logic.current!.state.searchConfig.keyword = keyword;
    } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.inheritPartially) {
      SearchPageMobileV2Logic.current!.state.searchConfig.keyword = keyword;
      SearchPageMobileV2Logic.current!.state.searchConfig.tags?.clear();
      SearchPageMobileV2Logic.current!.state.searchConfig.language = null;
      SearchPageMobileV2Logic.current!.state.searchConfig.enableAllCategories();
    } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.none) {
      SearchPageMobileV2Logic.current!.state.searchConfig = SearchConfig(keyword: keyword);
    }
    SearchPageMobileV2Logic.current!.handleClearAndRefresh();
    return;
  }

  toRoute(
    Routes.mobileV2Search,
    arguments: NewSearchArgument(
      keyword: keyword,
      keywordSearchBehaviour: preferenceSetting.searchBehaviour.value,
      rewriteSearchConfig: rewriteSearchConfig,
    ),
    preventDuplicates: false,
  );
}

Future<void> handleAddQuickSearch() async {
  SearchConfig? originalConfig = SearchPageMobileV2Logic.current?.state.searchConfig;

  Map<String, dynamic>? result = await Get.dialog(
    EHSearchConfigDialog(quickSearchName: originalConfig?.computeFullKeywords(), searchConfig: originalConfig, type: EHSearchConfigDialogType.add),
  );

  if (result == null) {
    return;
  }

  String quickSearchName = result['quickSearchName'];
  SearchConfig searchConfig = result['searchConfig'];
  quickSearchService.addQuickSearch(quickSearchName, searchConfig);
}
