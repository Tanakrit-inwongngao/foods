import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late IO.Socket socket;
  final List<String> userRooms = [];

  @override
  void initState() {
    super.initState();

    socket = IO.io("http://192.168.2.40:5000",
        IO.OptionBuilder().setTransports(['websocket']).build());

    socket.onConnect((_) {
      socket.emit("admin_join");
    });

    socket.on("user_list", (data) {
      setState(() => userRooms.clear());
      setState(() => userRooms.addAll(List<String>.from(data)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel")),
      body: ListView.builder(
        itemCount: userRooms.length,
        itemBuilder: (_, i) {
          return ListTile(
            title: Text("User: ${userRooms[i]}"),
            trailing: const Icon(Icons.chat),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatWithUserPage(userId: userRooms[i])),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatWithUserPage extends StatelessWidget {
  final String userId;
  const ChatWithUserPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("แชทกับ $userId")),
      body: Center(child: Text("หน้าแชท Admin ↔ $userId (ทำต่อได้)")),
    );
  }
}
