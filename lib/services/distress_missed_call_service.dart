// import 'dart:async';
//
// import 'package:asan_evac_app/models/distress_signal_model.dart';
// import 'package:asan_evac_app/services/distress_signal_service.dart';
// import 'package:phone_state/phone_state.dart';
//
//
// /// Detects a missed call the same way a person would notice one: the
// /// phone rings (CALL_INCOMING) and then goes straight back to idle
// /// (CALL_ENDED) without ever passing through the "in a call" state — i.e.
// /// nobody picked up.
// ///
// /// Uses the `phone_state` package (Android + iOS call state, though the
// /// caller's number is Android-only — see package docs). Requires
// /// READ_PHONE_STATE and READ_CALL_LOG permissions in AndroidManifest.xml.
// /// READ_CALL_LOG in particular is a sensitive Play Store permission —
// /// make sure your Play Console data-safety form + permission declaration
// /// form justify it ("emergency distress detection") before shipping.
// ///
// /// Same ⚠️ ADJUST caveats as [DistressSmsListenerService]: phone-number
// /// matching against `profiles.phone_number` and "which drill is active"
// /// both need to be pointed at your real schema.
// class DistressMissedCallListenerService {
//   DistressMissedCallListenerService({DistressSignalService? service})
//       : _service = service ?? DistressSignalService();
//
//   final DistressSignalService _service;
//   StreamSubscription<PhoneState>? _subscription;
//
//   bool _wasRinging = false;
//   String? _ringingNumber;
//
//   void startListening() {
//     _subscription = PhoneState.stream.listen(_onPhoneStateChanged);
//   }
//
//   void _onPhoneStateChanged(PhoneState state) {
//     switch (state.status) {
//       case PhoneStateStatus.CALL_INCOMING:
//         _wasRinging = true;
//         _ringingNumber = state.number;
//         break;
//       case PhoneStateStatus.CALL_STARTED:
//       // Someone answered — not a missed call, clear the flag.
//         _wasRinging = false;
//         _ringingNumber = null;
//         break;
//       case PhoneStateStatus.CALL_OUTGOING:
//       // An outgoing call from this device — not an incoming distress
//       // call, so it should never be filed as a missed call.
//         _wasRinging = false;
//         _ringingNumber = null;
//         break;
//       case PhoneStateStatus.CALL_ENDED:
//         if (_wasRinging && _ringingNumber != null) {
//           _fileMissedCall(_ringingNumber!);
//         }
//         _wasRinging = false;
//         _ringingNumber = null;
//         break;
//       case PhoneStateStatus.NOTHING:
//         break;
//     }
//   }
//
//   Future<void> _fileMissedCall(String callerNumber) async {
//     final studentId = await _service.resolveStudentIdByPhone(callerNumber);
//     if (studentId == null) return;
//
//     final drillEventId = await _service.fetchActiveDrillEventId();
//     if (drillEventId == null) return;
//
//     await _service.createSignal(
//       drillEventId: drillEventId,
//       studentId: studentId,
//       channel: DistressChannel.missedCall,
//       message: 'Missed call — no answer',
//     );
//   }
//
//   void stopListening() {
//     _subscription?.cancel();
//     _subscription = null;
//   }
// }