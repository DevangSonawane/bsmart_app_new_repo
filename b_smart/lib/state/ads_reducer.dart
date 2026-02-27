import 'package:redux/redux.dart';
import 'ads_state.dart';
import 'ads_actions.dart';

final adsReducer = combineReducers<AdsState>([
  TypedReducer<AdsState, SetAds>(_setAds),
  TypedReducer<AdsState, ClearAds>(_clearAds),
]);

AdsState _setAds(AdsState state, SetAds action) {
  return state.copyWith(ads: action.ads);
}

AdsState _clearAds(AdsState state, ClearAds action) {
  return AdsState.initial();
}

