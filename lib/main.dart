import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Message Board App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen();

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FirebaseAuth.instance.currentUser == null
              ? const LoginPage()
              : const HomePage(),
        ),
      );
    });

    return const Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.message, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text('Message Board', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage();
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: password, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 24),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: login, child: const Text("Login")),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
              child: const Text("Register here"),
            )
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage();
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  bool loading = false;

  Future<void> register() async {
    setState(() => loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'firstName': first.text.trim(),
        'lastName': last.text.trim(),
        'role': 'user',
        'registeredAt': Timestamp.now(),
      });
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(controller: first, decoration: const InputDecoration(labelText: "First Name")),
            TextField(controller: last, decoration: const InputDecoration(labelText: "Last Name")),
            TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: password, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 24),
            loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(onPressed: register, child: const Text("Register")),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage();

  final List<Map<String, dynamic>> boards = const [
    {'name': 'School', 'icon': Icons.school},
    {'name': 'Daily', 'icon': Icons.chat},
    {'name': 'Gaming', 'icon': Icons.videogame_asset},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Message Boards")),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text("Menu", style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(title: const Text("Boards"), onTap: () => Navigator.pop(context)),
            ListTile(title: const Text("Profile"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))),
            ListTile(title: const Text("Settings"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: boards.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            leading: Icon(boards[i]['icon']),
            title: Text(boards[i]['name']),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(boardName: boards[i]['name']))),
          ),
        ),
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  final String boardName;
  const ChatPage({required this.boardName});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('message_boards').doc(boardName).collection('messages').orderBy('datetime', descending: true);

    return Scaffold(
      appBar: AppBar(title: Text(boardName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: ref.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i];
                    return ListTile(
                      title: Text(m['message']),
                      subtitle: Text("${m['username']} • ${m['datetime'].toDate()}"),
                    );
                  },
                );
              },
            ),
          ),
          MessageInput(boardName: boardName),
        ],
      ),
    );
  }
}

class MessageInput extends StatefulWidget {
  final String boardName;
  const MessageInput({required this.boardName});
  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final controller = TextEditingController();

  Future<void> sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && controller.text.trim().isNotEmpty) {
      final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      await FirebaseFirestore.instance.collection('message_boards').doc(widget.boardName).collection('messages').add({
        'message': controller.text.trim(),
        'username': "${uDoc['firstName']} ${uDoc['lastName']}",
        'datetime': Timestamp.now(),
      });
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: "Type message..."))),
            IconButton(icon: const Icon(Icons.send), onPressed: sendMessage),
          ],
        ),
      ),
    );
  }
}

// Profile Page
class ProfilePage extends StatefulWidget {
  const ProfilePage();

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  Future<void> _loadData() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();
    _firstName.text = userDoc['firstName'] ?? '';
    _lastName.text = userDoc['lastName'] ?? '';
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated")));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _firstName, decoration: const InputDecoration(labelText: "First Name")),
            const SizedBox(height: 12),
            TextField(controller: _lastName, decoration: const InputDecoration(labelText: "Last Name")),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}

// Settings Page
class SettingsPage extends StatelessWidget {
  const SettingsPage();

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text("Logout"),
        ),
      ),
    );
  }
}
