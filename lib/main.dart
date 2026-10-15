import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CampusEaseApp());
}

class TaskItem {
  String id;
  String title;
  String subject;
  String dueDate;
  bool completed;

  TaskItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'dueDate': dueDate,
    'completed': completed,
  };

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'],
      title: json['title'],
      subject: json['subject'] ?? '',
      dueDate: json['dueDate'] ?? '',
      completed: json['completed'] ?? false,
    );
  }
}

class ClassItem {
  String id;
  String subject;
  String instructor;
  String room;
  String day;
  String time;

  ClassItem({
    required this.id,
    required this.subject,
    required this.instructor,
    required this.room,
    required this.day,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'instructor': instructor,
    'room': room,
    'day': day,
    'time': time,
  };

  factory ClassItem.fromJson(Map<String, dynamic> json) {
    return ClassItem(
      id: json['id'],
      subject: json['subject'],
      instructor: json['instructor'] ?? '',
      room: json['room'] ?? '',
      day: json['day'],
      time: json['time'],
    );
  }
}

class CampusEaseApp extends StatelessWidget {
  const CampusEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Ease',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457C5)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FC),
          foregroundColor: Color(0xFF172554),
          centerTitle: false,
        ),
      ),
      home: const CampusHome(),
    );
  }
}

class CampusHome extends StatefulWidget {
  const CampusHome({super.key});

  @override
  State<CampusHome> createState() => _CampusHomeState();
}

class _CampusHomeState extends State<CampusHome> {
  int selectedIndex = 0;
  bool loading = true;
  List<TaskItem> tasks = [];
  List<ClassItem> classes = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      tasks = (jsonDecode(prefs.getString('campus_tasks') ?? '[]') as List)
          .map((item) => TaskItem.fromJson(item))
          .toList();

      classes = (jsonDecode(prefs.getString('campus_classes') ?? '[]') as List)
          .map((item) => ClassItem.fromJson(item))
          .toList();
    } catch (_) {
      tasks = [];
      classes = [];
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'campus_tasks',
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
  }

  Future<void> saveClasses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'campus_classes',
      jsonEncode(classes.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> addTask({TaskItem? existing}) async {
    final result = await showDialog<TaskItem>(
      context: context,
      builder: (_) => TaskDialog(existing: existing),
    );

    if (result == null) return;

    setState(() {
      if (existing == null) {
        tasks.add(result);
      } else {
        final index = tasks.indexWhere((t) => t.id == existing.id);
        if (index != -1) tasks[index] = result;
      }
    });

    await saveTasks();
  }

  Future<void> addClass() async {
    final result = await showDialog<ClassItem>(
      context: context,
      builder: (_) => const ClassDialog(),
    );

    if (result == null) return;

    setState(() => classes.add(result));
    await saveClasses();
  }

  Future<bool> confirmDelete(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        tasks: tasks,
        classes: classes,
        onNavigate: (index) => setState(() => selectedIndex = index),
      ),
      TasksPage(
        tasks: tasks,
        onAdd: () => addTask(),
        onEdit: (task) => addTask(existing: task),
        onToggle: (task, value) async {
          setState(() => task.completed = value ?? false);
          await saveTasks();
        },
        onDelete: (task) async {
          if (await confirmDelete(task.title)) {
            setState(() => tasks.removeWhere((t) => t.id == task.id));
            await saveTasks();
            if (mounted) showMessage('Assignment deleted.');
          }
        },
      ),
      SchedulePage(
        classes: classes,
        onAdd: addClass,
        onDelete: (item) async {
          if (await confirmDelete(item.subject)) {
            setState(() => classes.removeWhere((c) => c.id == item.id));
            await saveClasses();
            if (mounted) showMessage('Class deleted.');
          }
        },
      ),
      const WeatherPage(),
      const AnnouncementsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: Color(0xFF2457C5)),
            SizedBox(width: 10),
            Text('Campus Ease', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Tasks'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            label: 'Weather',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            label: 'News',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final List<TaskItem> tasks;
  final List<ClassItem> classes;
  final ValueChanged<int> onNavigate;

  const DashboardPage({
    super.key,
    required this.tasks,
    required this.classes,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.completed).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2457C5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.waving_hand, color: Colors.white, size: 32),
              SizedBox(height: 16),
              Text(
                'Welcome to Campus Ease!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Organize your classes. Manage your tasks. Make every school day count.',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Your Overview',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Assignments',
                value: '${tasks.length}',
                icon: Icons.assignment_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'Completed',
                value: '$completed',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SummaryCard(
          title: 'Scheduled Classes',
          value: '${classes.length}',
          icon: Icons.calendar_month,
        ),
        const SizedBox(height: 24),
        const Text(
          'Quick Access',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        QuickButton(
          icon: Icons.task_alt,
          title: 'Manage Assignments',
          subtitle: 'Add and track your schoolwork',
          onTap: () => onNavigate(1),
        ),
        QuickButton(
          icon: Icons.calendar_month,
          title: 'Class Schedule',
          subtitle: 'Keep your classes organized',
          onTap: () => onNavigate(2),
        ),
        QuickButton(
          icon: Icons.cloud_outlined,
          title: 'Campus Weather',
          subtitle: 'Check live weather information',
          onTap: () => onNavigate(3),
        ),
        const SizedBox(height: 20),
        const Text(
          'Upcoming Tasks',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            message: 'No assignments yet. Add your first task!',
          )
        else
          ...tasks
              .where((t) => !t.completed)
              .take(3)
              .map(
                (task) => ListTile(
                  leading: const Icon(
                    Icons.circle_outlined,
                    color: Color(0xFF2457C5),
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                    task.dueDate.isEmpty
                        ? task.subject
                        : '${task.subject} • Due ${task.dueDate}',
                  ),
                ),
              ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2457C5), size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          Text(title, style: const TextStyle(color: Colors.blueGrey)),
        ],
      ),
    );
  }
}

class QuickButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const QuickButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8EEFF),
          child: Icon(icon, color: const Color(0xFF2457C5)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}

class TasksPage extends StatefulWidget {
  final List<TaskItem> tasks;
  final VoidCallback onAdd;
  final ValueChanged<TaskItem> onEdit;
  final void Function(TaskItem, bool?) onToggle;
  final ValueChanged<TaskItem> onDelete;

  const TasksPage({
    super.key,
    required this.tasks,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.tasks.where((task) {
      return task.title.toLowerCase().contains(search.toLowerCase()) ||
          task.subject.toLowerCase().contains(search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Assignments',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text('Keep track of your schoolwork and deadlines.'),
          const SizedBox(height: 18),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search assignments...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => search = value),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              message: 'No assignments found. Add a new task to get started.',
            ),
          ListView.builder(
            itemCount: filtered.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final task = filtered[index];

              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Checkbox(
                    value: task.completed,
                    onChanged: (value) => widget.onToggle(task, value),
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${task.subject.isEmpty ? 'General' : task.subject}'
                    '${task.dueDate.isEmpty ? '' : '\nDue: ${task.dueDate}'}',
                  ),
                  isThreeLine: task.dueDate.isNotEmpty,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') widget.onEdit(task);
                      if (value == 'delete') widget.onDelete(task);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class SchedulePage extends StatelessWidget {
  final List<ClassItem> classes;
  final VoidCallback onAdd;
  final ValueChanged<ClassItem> onDelete;

  const SchedulePage({
    super.key,
    required this.classes,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Class Schedule',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text('Organize your subjects, rooms, and class times.'),
          const SizedBox(height: 20),
          if (classes.isEmpty)
            const EmptyState(
              icon: Icons.calendar_month,
              message: 'No classes yet. Add your first class schedule.',
            ),
          ListView.builder(
            itemCount: classes.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final item = classes[index];

              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8EEFF),
                    child: Icon(Icons.menu_book, color: Color(0xFF2457C5)),
                  ),
                  title: Text(
                    item.subject,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item.day} • ${item.time}\n'
                    'Room: ${item.room.isEmpty ? 'Not specified' : item.room}\n'
                    'Instructor: ${item.instructor.isEmpty ? 'Not specified' : item.instructor}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Delete class',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => onDelete(item),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  bool loading = false;
  String? error;
  Map<String, dynamic>? weather;

  Future<void> fetchWeather() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=10.07&longitude=124.03'
        '&current=temperature_2m,relative_humidity_2m,'
        'apparent_temperature,weather_code,wind_speed_10m'
        '&timezone=Asia%2FManila',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Weather service returned an error.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        weather = data['current'] as Map<String, dynamic>;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not load weather. Check your internet and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String weatherDescription(dynamic code) {
    final value = (code as num?)?.toInt() ?? -1;

    if (value == 0) return 'Clear sky';
    if ([1, 2, 3].contains(value)) return 'Partly cloudy';
    if ([45, 48].contains(value)) return 'Foggy';
    if ([51, 53, 55, 56, 57].contains(value)) return 'Drizzle';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(value)) {
      return 'Rainy';
    }
    if ([71, 73, 75, 77, 85, 86].contains(value)) return 'Snow';
    if ([95, 96, 99].contains(value)) return 'Thunderstorm';

    return 'Weather information';
  }

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Campus Weather',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text('Live weather for Tubigon, Bohol.'),
        const SizedBox(height: 24),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          ),
        if (error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, size: 45),
                  const SizedBox(height: 12),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: fetchWeather,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        if (weather != null) ...[
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: const Color(0xFF2457C5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(Icons.cloud_outlined, color: Colors.white, size: 65),
                const SizedBox(height: 12),
                Text(
                  '${(weather!['temperature_2m'] as num).round()}°C',
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  weatherDescription(weather!['weather_code']),
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tubigon, Bohol',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SummaryCard(
            title: 'Feels Like',
            value: '${weather!['apparent_temperature']}°C',
            icon: Icons.thermostat,
          ),
          const SizedBox(height: 12),
          SummaryCard(
            title: 'Humidity',
            value: '${weather!['relative_humidity_2m']}%',
            icon: Icons.water_drop_outlined,
          ),
          const SizedBox(height: 12),
          SummaryCard(
            title: 'Wind Speed',
            value: '${weather!['wind_speed_10m']} km/h',
            icon: Icons.air,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: fetchWeather,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Weather'),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Weather data provided by Open-Meteo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey),
        ),
      ],
    );
  }
}

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final announcements = [
      {
        'title': 'Welcome to Campus Ease',
        'content': 'Keep your class schedule and assignments organized.',
        'date': 'Campus Ease',
      },
      {
        'title': 'Manage Your Deadlines',
        'content': 'Add your assignments and check their due dates regularly.',
        'date': 'Study Reminder',
      },
      {
        'title': 'Stay Updated',
        'content': 'Check official school channels for verified announcements.',
        'date': 'Campus Reminder',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Announcements',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text('Important reminders for your campus life.'),
        const SizedBox(height: 18),
        ListView.builder(
          itemCount: announcements.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = announcements[index];

            return Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.campaign,
                      color: Color(0xFF2457C5),
                      size: 30,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['title']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item['content']!),
                    const SizedBox(height: 10),
                    Text(
                      item['date']!,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class TaskDialog extends StatefulWidget {
  final TaskItem? existing;

  const TaskDialog({super.key, this.existing});

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController titleController;
  late TextEditingController subjectController;
  late TextEditingController dateController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.existing?.title ?? '');
    subjectController = TextEditingController(
      text: widget.existing?.subject ?? '',
    );
    dateController = TextEditingController(
      text: widget.existing?.dueDate ?? '',
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    subjectController.dispose();
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Assignment' : 'Edit Assignment',
      ),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Assignment title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an assignment title.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Due date (YYYY-MM-DD)',
                  hintText: '2026-10-20',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.trim())) {
                    return 'Use YYYY-MM-DD format.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;

            Navigator.pop(
              context,
              TaskItem(
                id:
                    widget.existing?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                subject: subjectController.text.trim(),
                dueDate: dateController.text.trim(),
                completed: widget.existing?.completed ?? false,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class ClassDialog extends StatefulWidget {
  const ClassDialog({super.key});

  @override
  State<ClassDialog> createState() => _ClassDialogState();
}

class _ClassDialogState extends State<ClassDialog> {
  final formKey = GlobalKey<FormState>();
  final subjectController = TextEditingController();
  final instructorController = TextEditingController();
  final roomController = TextEditingController();
  final timeController = TextEditingController();

  String day = 'Monday';

  @override
  void dispose() {
    subjectController.dispose();
    instructorController.dispose();
    roomController.dispose();
    timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Class'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a subject.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: instructorController,
                decoration: const InputDecoration(
                  labelText: 'Instructor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: roomController,
                decoration: const InputDecoration(
                  labelText: 'Room',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: day,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  border: OutlineInputBorder(),
                ),
                items:
                    const [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ].map((value) {
                      return DropdownMenuItem(value: value, child: Text(value));
                    }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => day = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  hintText: '8:00 AM - 9:30 AM',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the class time.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;

            Navigator.pop(
              context,
              ClassItem(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                subject: subjectController.text.trim(),
                instructor: instructorController.text.trim(),
                room: roomController.text.trim(),
                day: day,
                time: timeController.text.trim(),
              ),
            );
          },
          child: const Text('Save Class'),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 15),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}
