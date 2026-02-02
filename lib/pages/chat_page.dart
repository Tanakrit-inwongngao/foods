import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../widgets/message_bubble.dart';

class ChatPage extends StatefulWidget {
  final String userId;
  const ChatPage({super.key, required this.userId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late IO.Socket socket;
  final TextEditingController messageCtrl = TextEditingController();
  final List<Map<String, dynamic>> messages = [];

  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    initSocket();
  }

  void initSocket() {
    socket = IO.io(
      "http://192.168.2.40:5000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setTimeout(5000)          // ⬅ ลดปัญหาโหลดนาน
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      setState(() => isConnected = true);
      socket.emit("join_room", widget.userId);
    });

    socket.onDisconnect((_) {
      setState(() => isConnected = false);
    });

    socket.onConnectError((data) {
      debugPrint("❌ Socket Connect Error: $data");
    });

    socket.onError((data) {
      debugPrint("❌ Socket Error: $data");
    });

    socket.on("receive_message", (data) {
      setState(() {
        messages.add(data);
      });
    });
  }

  void sendMessage() {
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ")),
      );
      return;
    }

    if (messageCtrl.text.trim().isEmpty) return;

    final msg = {
      "sender": widget.userId,
      "message": messageCtrl.text.trim(),
      "time": DateTime.now().toString(),
    };

    socket.emit("send_message", msg);

    setState(() {
      messages.add(msg);
    });

    messageCtrl.clear();
  }

  @override
  void dispose() {
    socket.dispose();   // ⬅ ปิด socket กันค้าง
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(
                isConnected ? Icons.circle : Icons.circle_outlined,
                color: isConnected ? Colors.green : Colors.red,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? "ออนไลน์" : "ออฟไลน์",
                style: TextStyle(
                  color: isConnected ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: messages
                .map(
                  (m) => MessageBubble(
                message: m["message"],
                isMe: m["sender"] == widget.userId,
              ),
            )
                .toList(),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageCtrl,
                decoration:
                const InputDecoration(hintText: "พิมพ์ข้อความ..."),
              ),
            ),
            IconButton(
              onPressed: sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}
