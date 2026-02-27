import 'package:redux/redux.dart';
import 'reels_state.dart';
import 'reels_actions.dart';

final reelsReducer = combineReducers<ReelsState>([
  TypedReducer<ReelsState, SetReels>(_setReels),
  TypedReducer<ReelsState, ClearReels>(_clearReels),
]);

ReelsState _setReels(ReelsState state, SetReels action) {
  return state.copyWith(reels: action.reels);
}

ReelsState _clearReels(ReelsState state, ClearReels action) {
  return ReelsState.initial();
}

