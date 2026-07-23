import 'dart:async';

import 'package:asan_evac_app/controllers/auth/auth_controller.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/message.dart';
import '../../services/message_service.dart';

/// One instance per section — put with `tag: sectionId` (see ChatScreen)
/// so switching between sections doesn't mix up messages or leak
/// subscriptions from a previously viewed section.
class MessageController extends GetxController {
  MessageController({required this.sectionId, this.drillEventId});

  final String sectionId;
  final String? drillEventId;

  final _messageService = MessageService();
  final _authController = Get.find<AuthController>();

  final RxList<Message> messages = <Message>[].obs;
  final RxBool isSending = false.obs;
  final RxnString sendError = RxnString();

  /// senderId -> full_name. Populated lazily as new sender IDs show up
  /// in the message stream — see fetchSenderNames() in MessageService
  /// for why this is a local cache rather than a per-message join.
  final RxMap<String, String> senderNames = <String, String>{}.obs;

  /// User IDs (other than yourself) currently typing in this section,
  /// per the ephemeral broadcast channel below. Not persisted anywhere
  /// — purely live presence, cleared automatically if no follow-up
  /// "still typing" broadcast arrives within a few seconds.
  final RxSet<String> typingUserIds = <String>{}.obs;

  StreamSubscription<List<Message>>? _messagesSubscription;
  RealtimeChannel? _typingChannel;
  final Map<String, Timer> _typingClearTimers = {};
  DateTime? _lastTypingSentAt;

  String? get currentUserId => _authController.currentUser.value?.id;

  @override
  void onInit() {
    super.onInit();
    _messagesSubscription =
        _messageService.streamSectionMessages(sectionId).listen((rows) {
          messages.assignAll(rows);
          _loadMissingSenderNames(rows);
        }, onError: (e) {
          sendError.value = 'Failed to load messages: $e';
        });
    _subscribeTypingChannel();
  }

  Future<void> _loadMissingSenderNames(List<Message> rows) async {
    final missing = rows
        .map((m) => m.senderId)
        .toSet()
        .difference(senderNames.keys.toSet());
    if (missing.isEmpty) return;

    try {
      final fetched = await _messageService.fetchSenderNames(missing.toList());
      senderNames.addAll(fetched);
      // If we asked for names and got fewer back than we asked for, the
      // most likely cause is an RLS policy on `profiles` that only lets
      // a user select their own row (e.g. `auth.uid() = id`), which
      // silently drops classmates' rows from the query result instead
      // of throwing. That shows up here as "Unknown" senders in the UI.
      final stillMissing = missing.difference(fetched.keys.toSet());
      if (stillMissing.isNotEmpty) {
        // ignore: avoid_print
        print(
          'MessageController: profiles lookup returned no row for '
              '${stillMissing.length} sender(s): $stillMissing. '
              'Check the SELECT policy on public.profiles.',
        );
      }
    } catch (e) {
      // Best-effort — a name lookup failure shouldn't break the chat
      // itself. The view falls back to a placeholder label per sender.
      // ignore: avoid_print
      print('MessageController: fetchSenderNames failed: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    final senderId = currentUserId;
    if (trimmed.isEmpty || senderId == null) return;

    isSending.value = true;
    sendError.value = null;
    try {
      await _messageService.sendMessage(
        sectionId: sectionId,
        drillEventId: drillEventId,
        senderId: senderId,
        content: trimmed,
      );
    } catch (e) {
      sendError.value = 'Failed to send message: $e';
    } finally {
      isSending.value = false;
    }
  }

  // --- Typing indicator (ephemeral broadcast, not stored in the DB) ---

  void _subscribeTypingChannel() {
    try {
      _typingChannel = Supabase.instance.client
          .channel('typing:$sectionId')
          .onBroadcast(
        event: 'typing',
        callback: (payload) {
          final userId = payload['user_id'] as String?;
          if (userId == null || userId == currentUserId) return;

          typingUserIds.add(userId);
          // Reset the auto-clear window each time this user's
          // typing event arrives, so a burst of keystrokes keeps
          // the indicator alive continuously instead of flickering.
          _typingClearTimers[userId]?.cancel();
          _typingClearTimers[userId] = Timer(
            const Duration(seconds: 3),
                () => typingUserIds.remove(userId),
          );
        },
      )
          .subscribe();
    } catch (_) {
      // Non-fatal — chat still works without the typing indicator.
    }
  }

  /// Call on every keystroke in the composer. Internally throttled so
  /// it only actually sends a broadcast at most once every 2 seconds,
  /// regardless of how often the view calls this.
  void notifyTyping() {
    final userId = currentUserId;
    if (userId == null || _typingChannel == null) return;

    final now = DateTime.now();
    if (_lastTypingSentAt != null &&
        now.difference(_lastTypingSentAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastTypingSentAt = now;

    _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': userId},
    );
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    _typingChannel?.unsubscribe();
    for (final timer in _typingClearTimers.values) {
      timer.cancel();
    }
    super.onClose();
  }
}