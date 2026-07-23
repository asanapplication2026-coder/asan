import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth/auth_controller.dart';
import '../../controllers/message_controller.dart';

const _primaryRed = Color(0xFF7B1113);
const _iosBackground = Color(0xFFF2F2F7);

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.sectionId, this.drillEventId, super.key});

  final String sectionId;
  final String? drillEventId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final MessageController controller;
  final _authController = Get.find<AuthController>();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      MessageController(
        sectionId: widget.sectionId,
        drillEventId: widget.drillEventId,
      ),
      tag: widget.sectionId,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomIfNeeded() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final local = dt.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  static const List<Color> _avatarPalette = [
    Color(0xFFE57373),
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFF4DB6AC),
    Color(0xFFF06292),
    Color(0xFF9575CD),
    Color(0xFFA1887F),
    Color(0xFF7986CB),
  ];

  Color _colorForSender(String senderId) {
    final hash = senderId.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return _avatarPalette[hash % _avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    // Component drops directly inside the pre-configured nested IndexedStack infrastructure.
    return ColoredBox(
      color: _iosBackground,
      child: Column(
        children: [
          // 1. CHAT TIMELINE INTERFACE
          Expanded(
            child: Obx(() {
              final messages = controller.messages;

              if (messages.length != _lastMessageCount) {
                _lastMessageCount = messages.length;
                _scrollToBottomIfNeeded();
              }

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.chat_bubble_2, size: 44, color: CupertinoColors.systemGrey3),
                      const SizedBox(height: 12),
                      Text(
                        'No transmission history yet.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), // Spaced safely above absolute dock positions
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  // Standard mapping strategy inverted via builder parameters
                  final actualIndex = messages.length - 1 - index;
                  final msg = messages[actualIndex];
                  final isMine = msg.senderId == controller.currentUserId;
                  final senderName = controller.senderNames[msg.senderId] ?? 'Unknown User';

                  // Group messages: examine next chronologically newer index entry (previous list builder order item)
                  bool isFirstInGroup = true;
                  if (actualIndex > 0) {
                    final nextMsg = messages[actualIndex - 1];
                    if (nextMsg.senderId == msg.senderId) {
                      isFirstInGroup = false;
                    }
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                      top: isFirstInGroup ? 10 : 2,
                      bottom: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        // Left-side avatar rendered only on group transitions for inbound bubbles
                        if (!isMine) ...[
                          SizedBox(
                            width: 32,
                            child: isFirstInGroup
                                ? Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _colorForSender(msg.senderId),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _initials(senderName),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 8),
                        ],

                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // Sender name line injected above incoming bubble start coordinates
                              if (!isMine && isFirstInGroup)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6, bottom: 4),
                                  child: Text(
                                    senderName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _colorForSender(msg.senderId),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),

                              // Main content block bubble
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMine ? _primaryRed : Colors.white,
                                  border: isMine
                                      ? null
                                      : Border.all(color: CupertinoColors.systemGrey5, width: 0.5),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMine ? 18 : (isFirstInGroup ? 4 : 18)),
                                    bottomRight: Radius.circular(isMine ? (isFirstInGroup ? 4 : 18) : 18),
                                  ),
                                  boxShadow: isMine
                                      ? []
                                      : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Text(
                                  msg.content,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isMine ? Colors.white : CupertinoColors.label,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                              ),

                              // Micro timestamp text line
                              Padding(
                                padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
                                child: Text(
                                  _formatRelativeTime(msg.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: CupertinoColors.secondaryLabel,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),

          // 2. BROADCAST DATA DOCK WITH GLASSMORPHIC ENTRY LAYERS
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  border: const Border(
                    top: BorderSide(color: CupertinoColors.separator, width: 0.5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Typing metrics layout track
                      Obx(() {
                        final typingIds = controller.typingUserIds;
                        if (typingIds.isEmpty) return const SizedBox.shrink();

                        final names = typingIds.map((id) => controller.senderNames[id] ?? 'Someone').toList();
                        final typingLabel = names.length == 1 ? '${names.first} is typing' : '${names.length} people typing';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Text(
                                typingLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.secondaryLabel,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const _TypingDots(),
                            ],
                          ),
                        );
                      }),

                      // Network dynamic error reports
                      Obx(() {
                        final error = controller.sendError.value;
                        if (error == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.systemRed, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  error,
                                  style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Message Form Control Field Box
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey6,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: TextField(
                                  controller: _textController,
                                  onChanged: (_) => controller.notifyTyping(),
                                  maxLines: 4,
                                  minLines: 1,
                                  textCapitalization: TextCapitalization.sentences,
                                  style: const TextStyle(fontSize: 15, color: CupertinoColors.label),
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(color: CupertinoColors.placeholderText),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Obx(() {
                              final sending = controller.isSending.value;

                              return GestureDetector(
                                onTap: sending
                                    ? null
                                    : () {
                                  final txt = _textController.text.trim();
                                  if (txt.isNotEmpty) {
                                    controller.sendMessage(txt);
                                    _textController.clear();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: sending ? CupertinoColors.systemGrey4 : _primaryRed,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: sending
                                      ? const CupertinoActivityIndicator(radius: 9, color: Colors.white)
                                      : const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 18),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value + i / 3) % 1.0;
            final offset = -4.0 * (1 - (2 * t - 1).abs());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.secondaryLabel,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}