import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://kozhczffkulvhxzbwsfl.supabase.co';
const supabaseAnonKey = 'sb_publishable__wqs-rPYa-lfNwDj0E5y4g_FKwWsA8F';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MiAhorroApp());
}

final supabase = Supabase.instance.client;

class MiAhorroApp extends StatelessWidget {
  const MiAhorroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi Ahorro',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff22c55e), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xff0d1322),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        return session == null ? const LoginPage() : const HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  Future<void> auth({required bool register}) async {
    setState(() => loading = true);
    try {
      if (register) {
        await supabase.auth.signUp(email: email.text.trim(), password: password.text.trim());
        if (mounted) _msg('Cuenta creada. Revisá tu mail si pide confirmación.');
      } else {
        await supabase.auth.signInWithPassword(email: email.text.trim(), password: password.text.trim());
      }
    } catch (e) {
      if (mounted) _msg('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.attach_money_rounded, size: 76, color: Color(0xff22c55e)),
                const SizedBox(height: 16),
                const Text('Mi Ahorro', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Tu app nativa para controlar gastos, metas y progreso.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.7))),
                const SizedBox(height: 28),
                _field(email, 'Email', Icons.mail_outline),
                const SizedBox(height: 12),
                _field(password, 'Contraseña', Icons.lock_outline, obscure: true),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: loading ? null : () => auth(register: false), icon: const Icon(Icons.login), label: Text(loading ? 'Cargando...' : 'Ingresar')),
                TextButton(onPressed: loading ? null : () => auth(register: true), child: const Text('Crear cuenta nueva')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _field(TextEditingController c, String label, IconData icon, {bool obscure = false, TextInputType? type}) {
  return TextField(
    controller: c,
    obscureText: obscure,
    keyboardType: type,
    decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18))),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  int year = DateTime.now().year;
  int month = DateTime.now().month;
  bool loading = true;

  final incomeUsd = TextEditingController(text: '0');
  final exchangeRate = TextEditingController(text: '1428.01');
  final realSavingUsd = TextEditingController(text: '0');
  final goalName = TextEditingController(text: 'Comprar moto');
  final goalAmount = TextEditingController(text: '0');
  final notes = TextEditingController();

  List<Map<String, dynamic>> fixed = [
    {'icon': '🏠', 'name': 'Alquiler', 'amount': 0.0, 'paid': false},
    {'icon': '💡', 'name': 'Luz', 'amount': 0.0, 'paid': false},
    {'icon': '🎓', 'name': 'Academia Avi', 'amount': 0.0, 'paid': false},
    {'icon': '🍽️', 'name': 'Menú', 'amount': 0.0, 'paid': false},
    {'icon': '🏋️', 'name': 'Gimnasio', 'amount': 0.0, 'paid': false},
    {'icon': '🤖', 'name': 'ChatGPT', 'amount': 0.0, 'paid': false},
  ];

  final List<String> monthNames = const ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

  double get usd => double.tryParse(incomeUsd.text.replaceAll(',', '.')) ?? 0.0;
  double get rate => double.tryParse(exchangeRate.text.replaceAll(',', '.')) ?? 0.0;
  double get incomeArs => usd * rate;
  double get fixedTotal => fixed.fold(0.0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0));
  double get paidTotal => fixed.where((e) => e['paid'] == true).fold(0.0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0));
  double get available => incomeArs - fixedTotal;

  @override
  void initState() {
    super.initState();
    loadMonth();
  }

  Future<void> loadMonth() async {
    setState(() => loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final row = await supabase.from('finance_months').select().eq('user_id', userId).eq('year', year).eq('month', month).maybeSingle();
      if (row != null) {
        incomeUsd.text = '${row['income_usd'] ?? row['income'] ?? 0}';
        exchangeRate.text = '${row['exchange_rate'] ?? 1428.01}';
        realSavingUsd.text = '${row['real_saving_usd'] ?? row['actual_savings'] ?? 0}';
        notes.text = '${row['notes'] ?? ''}';
        final rawFixed = row['fixed_expenses'];
        if (rawFixed is List) {
          fixed = rawFixed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveMonth() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('finance_months').upsert({
        'user_id': userId,
        'year': year,
        'month': month,
        'currency': 'ARS',
        'exchange_rate': rate,
        'income_usd': usd,
        'real_saving_usd': double.tryParse(realSavingUsd.text.replaceAll(',', '.')) ?? 0.0,
        'notes': notes.text,
        'fixed_expenses': fixed,
      }, onConflict: 'user_id,year,month');
      if (mounted) _msg('Guardado ✅');
    } catch (e) {
      if (mounted) _msg('No se pudo guardar: $e');
    }
  }

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final screens = [inicio(), mes(), gastos(), semana(), metas()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Ahorro'),
        actions: [
          IconButton(onPressed: saveMonth, icon: const Icon(Icons.save_rounded)),
          IconButton(onPressed: () => supabase.auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : screens[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Mes'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Gastos'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Semana'),
          NavigationDestination(icon: Icon(Icons.flag), label: 'Metas'),
        ],
      ),
    );
  }

  Widget base(Widget child) => RefreshIndicator(onRefresh: loadMonth, child: ListView(padding: const EdgeInsets.all(18), children: [child]));

  Widget inicio() {
    final double progress = fixedTotal == 0.0 ? 0.0 : (paidTotal / fixedTotal).clamp(0.0, 1.0).toDouble();
    return base(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      monthSelector(),
      const SizedBox(height: 16),
      card('Disponible estimado', money(available), Icons.account_balance_wallet, const Color(0xff22c55e)),
      const SizedBox(height: 12),
      card('Gastos fijos', money(fixedTotal), Icons.home_work_outlined, const Color(0xfff97316)),
      const SizedBox(height: 12),
      card('Pagado', money(paidTotal), Icons.check_circle_outline, const Color(0xff60a5fa)),
      const SizedBox(height: 18),
      LinearProgressIndicator(value: progress),
      const SizedBox(height: 8),
      Text('Pagaste ${(progress * 100).toStringAsFixed(0)}% de tus gastos fijos'),
    ]));
  }

  Widget mes() => base(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    monthSelector(),
    const SizedBox(height: 12),
    _field(incomeUsd, 'Ingreso del mes en USD', Icons.attach_money, type: TextInputType.number),
    const SizedBox(height: 12),
    _field(exchangeRate, 'Tipo de cambio', Icons.currency_exchange, type: TextInputType.number),
    const SizedBox(height: 12),
    _field(realSavingUsd, 'Ahorro real USD', Icons.savings_outlined, type: TextInputType.number),
    const SizedBox(height: 12),
    _field(notes, 'Notas rápidas', Icons.note_alt_outlined),
    const SizedBox(height: 18),
    FilledButton.icon(onPressed: () => setState(() {}), icon: const Icon(Icons.calculate), label: const Text('Recalcular')),
    const SizedBox(height: 8),
    FilledButton.icon(onPressed: saveMonth, icon: const Icon(Icons.save), label: const Text('Guardar ahora')),
  ]));

  Widget gastos() => base(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Gastos fijos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    ...fixed.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      final c = TextEditingController(text: '${item['amount']}');
      return Card(
        child: ListTile(
          leading: Text('${item['icon']}', style: const TextStyle(fontSize: 24)),
          title: Text('${item['name']}'),
          subtitle: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monto'),
            onChanged: (v) => fixed[i]['amount'] = double.tryParse(v.replaceAll(',', '.')) ?? 0.0,
          ),
          trailing: Checkbox(value: item['paid'] == true, onChanged: (v) => setState(() => fixed[i]['paid'] = v ?? false)),
        ),
      );
    }),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: () => setState(() => fixed.add({'icon': '🧾', 'name': 'Nuevo gasto', 'amount': 0.0, 'paid': false})), icon: const Icon(Icons.add), label: const Text('Agregar gasto')),
  ]));

  Widget semana() {
    final int days = DateUtils.getDaysInMonth(year, month);
    final double daily = days == 0 ? 0.0 : available / days;
    final double weekly = daily * 7.0;
    return base(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Resumen semanal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      card('Presupuesto diario sugerido', money(daily), Icons.today, const Color(0xffa78bfa)),
      const SizedBox(height: 12),
      card('Presupuesto semanal estimado', money(weekly), Icons.view_week, const Color(0xff22c55e)),
      const SizedBox(height: 16),
      ...List.generate(5, (i) {
        final int start = i * 7 + 1;
        final int end = (start + 6).clamp(1, days).toInt();
        final double weekBudget = daily * (end - start + 1).toDouble();
        return Card(child: ListTile(title: Text('Semana ${i + 1}: día $start al $end'), subtitle: Text('Tope estimado: ${money(weekBudget)}')));
      }),
    ]));
  }

  Widget metas() => base(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Metas de ahorro', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    _field(goalName, 'Nombre de la meta', Icons.flag_outlined),
    const SizedBox(height: 12),
    _field(goalAmount, 'Monto objetivo USD', Icons.savings, type: TextInputType.number),
    const SizedBox(height: 14),
    card(goalName.text.isEmpty ? 'Meta' : goalName.text, 'Objetivo: USD ${goalAmount.text}', Icons.emoji_events_outlined, const Color(0xfffacc15)),
  ]));

  Widget monthSelector() => Row(children: [
    Expanded(child: DropdownButtonFormField<int>(value: month, decoration: const InputDecoration(labelText: 'Mes'), items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(monthNames[i]))), onChanged: (v) { if (v != null) { setState(() => month = v); loadMonth(); } })),
    const SizedBox(width: 12),
    Expanded(child: DropdownButtonFormField<int>(value: year, decoration: const InputDecoration(labelText: 'Año'), items: List.generate(6, (i) => DropdownMenuItem(value: DateTime.now().year + i, child: Text('${DateTime.now().year + i}'))), onChanged: (v) { if (v != null) { setState(() => year = v); loadMonth(); } })),
  ]);

  Widget card(String title, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(.35))),
    child: Row(children: [Icon(icon, color: color, size: 34), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.white.withOpacity(.7))), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]))]),
  );

  String money(double n) => NumberFormat.currency(locale: 'es_AR', symbol: 'ARS ', decimalDigits: 0).format(n);
}
