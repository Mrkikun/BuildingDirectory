import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

const Color primaryBurgundy = Color(0xFF852040);
const Color darkBurgundy = Color(0xFF6A1A33);
const Color lightBurgundy = Color(0xFFA02B50);

const MaterialColor burgundySwatch = MaterialColor(
  0xFF852040,
  <int, Color>{
    50: Color(0xFFF9E4E8),
    100: Color(0xFFF0BCC7),
    200: Color(0xFFE690A3),
    300: Color(0xFFDB647F),
    400: Color(0xFFD44364),
    500: Color(0xFF852040),
    600: Color(0xFF7D1C3A),
    700: Color(0xFF721832),
    800: Color(0xFF68132A),
    900: Color(0xFF550B1C),
  },
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Строительный справочник',
      theme: ThemeData(
        primarySwatch: burgundySwatch,
        primaryColor: primaryBurgundy,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBurgundy,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBurgundy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryBurgundy,
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder(
            future: user.reload().then((_) => _auth.currentUser),
            builder: (context, AsyncSnapshot<User?> updatedSnapshot) {
              if (updatedSnapshot.connectionState != ConnectionState.done) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (updatedSnapshot.data != null &&
                  updatedSnapshot.data!.emailVerified) {
                return MainPage();
              } else {
                return LoginPage();
              }
            },
          );
        } else {
          return LoginPage();
        }
      },
    );
  }
}

void showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Ошибка", style: TextStyle(color: Colors.red)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text("ОК"),
        ),
      ],
    ),
  );
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signUp(String email, String password, BuildContext context) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.sendEmailVerification();
      Fluttertoast.showToast(msg: "Письмо подтверждения отправлено на $email");
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => LoginPage()));
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: _getErrorMessage(e));
      showErrorDialog(context, "${_getErrorMessage(e)}\nКод ошибки: ${e.code}");
    }
  }

  Future<void> signIn(String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await userCredential.user!.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser != null && refreshedUser.emailVerified) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => MainPage()));
      } else {
        await _auth.signOut();
        Fluttertoast.showToast(msg: "Подтвердите адрес электронной почты.");
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: _getErrorMessage(e));
      showErrorDialog(context, "${_getErrorMessage(e)}\nКод ошибки: ${e.code}");
    }
  }

  Future<void> signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => LoginPage()));
  }

  Future<void> resetPassword(String email, BuildContext context) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Fluttertoast.showToast(
          msg: "Ссылка для восстановления пароля отправлена на $email");
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: _getErrorMessage(e));
      showErrorDialog(context, "${_getErrorMessage(e)}\nКод ошибки: ${e.code}");
    }
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case "invalid-email":
        return "Неверный формат email.";
      case "user-not-found":
        return "Пользователь не найден.";
      case "wrong-password":
        return "Неверный пароль.";
      case "weak-password":
        return "Пароль слишком слабый.";
      case "email-already-in-use":
        return "Эта почта уже используется.";
      default:
        return "Произошла ошибка.";
    }
  }
}

class SystemFeaturesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Функционал системы"),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFeatureCard(
              title: "Аутентификация и управление пользователями",
              items: [
                "Регистрация новых пользователей с подтверждением email",
                "Авторизация зарегистрированных пользователей",
                "Восстановление пароля через email",
                "Выход из системы",
                "Проверка верификации email при входе",
                "Отображение профиля пользователя (email)"
              ],
            ),
            _buildFeatureCard(
              title: "Навигация и интерфейс",
              items: [
                "Главный экран с таб-баром (нижняя панель навигации)",
                "Четыре основных раздела:",
                "  • Об учреждении (статическая информация)",
                "  • Каталог дисциплин (основной контент)",
                "  • О системе (информация о разработке)",
                "  • Профиль пользователя",
                "Анимированные кнопки навигации с hover-эффектами",
                "Адаптивная цветовая схема (бордовые оттенки)"
              ],
            ),
            _buildFeatureCard(
              title: "Работа с учебными материалами",
              items: [
                "Загрузка дисциплин из Firebase Realtime Database",
                "Отображение дисциплин в виде раскрывающихся карточек",
                "Поиск по названию, описанию и подразделам дисциплин",
                "Навигация по подразделам дисциплин",
                "Динамическая генерация ID подразделов на основе названия"
              ],
            ),
            _buildFeatureCard(
              title: "Система контент-менеджмента",
              items: [
                "Отображение содержимого подразделов:",
                "  • Заголовки и текстовый контент",
                "  • Изображения с кэшированием",
                "  • Разделы с раскрывающимся содержимым",
                "Загрузка данных подразделов из Firebase",
                "Обработка структуры данных (заголовки, изображения, секции)"
              ],
            ),
            _buildFeatureCard(
              title: "Технические особенности",
              items: [
                "Интеграция с Firebase:",
                "  • Authentication (аутентификация)",
                "  • Realtime Database (хранение данных)",
                "  • Инициализация приложения",
                "Кэширование изображений через CachedNetworkImage",
                "Обработка ошибок:",
                "  • Валидация форм",
                "  • Firebase Auth Exception",
                "  • Проблемы загрузки данных",
                "Индикаторы загрузки",
                "Toast-уведомления",
                "Диалоговые окна для ошибок"
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                "Система предоставляет комплексное решение для изучения строительных дисциплин "
                    "с возможностью расширения контента через Firebase, обеспечивая безопасный доступ и удобный интерфейс.",
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({required String title, required List<String> items}) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryBurgundy,
              ),
            ),
            SizedBox(height: 10),
            ...items.map((item) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• ", style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(item, style: TextStyle(fontSize: 16))),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  void _signIn() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });
    if (_emailController.text.isEmpty) {
      if (mounted) {
        setState(() {
          _emailError = "Введите email";
          _isLoading = false;
        });
      }
      return;
    }
    if (_passwordController.text.isEmpty) {
      if (mounted) {
        setState(() {
          _passwordError = "Введите пароль";
          _isLoading = false;
        });
      }
      return;
    }
    try {
      await _authService.signIn(
        _emailController.text,
        _passwordController.text,
        context,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _emailError = e.message ?? "Ошибка";
          _passwordError = e.message ?? "Ошибка";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterPage()),
    );
  }

  void _navigateToResetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResetPasswordPage()),
    );
  }

  void _navigateToSystemFeatures() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SystemFeaturesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Вход")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Email",
                errorText: _emailError,
                errorStyle: TextStyle(color: Colors.red),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Пароль",
                errorText: _passwordError,
                errorStyle: TextStyle(color: Colors.red),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _signIn,
              icon: _isLoading
                  ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ))
                  : Icon(Icons.login),
              label: Text(_isLoading ? "" : "Войти"),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: _navigateToRegister,
              child: Text("Регистрация", style: TextStyle(color: primaryBurgundy)),
            ),
            TextButton(
              onPressed: _navigateToResetPassword,
              child: Text("Забыли пароль?", style: TextStyle(color: primaryBurgundy)),
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Center(
              child: Text(
                "Хотите узнать о возможностях системы?",
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            TextButton(
              onPressed: _navigateToSystemFeatures,
              child: Text(
                "Ознакомиться с функционалом",
                style: TextStyle(
                  color: primaryBurgundy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  final AuthService _authService = AuthService();

  void _register() async {
    if (!_agreedToTerms) {
      Fluttertoast.showToast(msg: "Вы должны принять условия использования");
      return;
    }

    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });
    if (_emailController.text.isEmpty) {
      if (mounted) {
        setState(() {
          _emailError = "Введите email";
          _isLoading = false;
        });
      }
      return;
    }
    if (_passwordController.text.length < 6) {
      if (mounted) {
        setState(() {
          _passwordError = "Пароль должен содержать минимум 6 символов";
          _isLoading = false;
        });
      }
      return;
    }
    try {
      await _authService.signUp(
        _emailController.text,
        _passwordController.text,
        context,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _emailError = e.message ?? "Ошибка";
          _passwordError = e.message ?? "Ошибка";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Условия использования"),
        content: SingleChildScrollView(
          child: Text(
            "1. Вы соглашаетесь с правилами использования сервиса\n\n"
                "2. Вы обязуетесь не нарушать авторские права\n\n"
                "3. Вы даете согласие на обработку персональных данных\n\n"
                "4. Сервис предоставляется 'как есть' без гарантий\n\n"
                "5. Администрация оставляет за собой право изменять условия",
            style: TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Закрыть"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Регистрация")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Email",
                errorText: _emailError,
                errorStyle: TextStyle(color: Colors.red),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Пароль (мин. 6 символов)",
                errorText: _passwordError,
                errorStyle: TextStyle(color: Colors.red),
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Checkbox(
                  value: _agreedToTerms,
                  onChanged: (value) {
                    setState(() {
                      _agreedToTerms = value ?? false;
                    });
                  },
                  activeColor: primaryBurgundy,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _showTermsDialog,
                    child: Text(
                      "Я принимаю условия использования",
                      style: TextStyle(
                        color: _agreedToTerms ? Colors.black : Colors.grey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: (_isLoading || !_agreedToTerms) ? null : _register,
              icon: _isLoading
                  ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ))
                  : Icon(Icons.person_add),
              label: Text(_isLoading ? "" : "Зарегистрироваться"),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  void _resetPassword() async {
    setState(() {
      _emailError = null;
      _isLoading = true;
    });
    if (_emailController.text.isEmpty) {
      if (mounted) {
        setState(() {
          _emailError = "Введите email";
          _isLoading = false;
        });
      }
      return;
    }
    try {
      await _authService.resetPassword(_emailController.text, context);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _emailError = e.message ?? "Ошибка";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Восстановление пароля")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Email",
                errorText: _emailError,
                errorStyle: TextStyle(color: Colors.red),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _resetPassword,
              icon: _isLoading
                  ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ))
                  : Icon(Icons.email),
              label: Text(_isLoading ? "" : "Отправить ссылку"),
            ),
          ],
        ),
      ),
    );
  }
}

class Discipline {
  final String name;
  final String description;
  final IconData icon;
  final List<String> subsections;

  Discipline({
    required this.name,
    required this.description,
    required this.icon,
    required this.subsections,
  });

  factory Discipline.fromJson(Map<String, dynamic> json) {
    dynamic iconData = json['icon'];
    int iconCode;
    if (iconData is String) {
      iconCode = int.parse(iconData);
    } else {
      iconCode = iconData as int;
    }
    List<String> subsections = [];
    if (json['subsections'] != null && json['subsections'] is List) {
      List<dynamic> subsectionList = json['subsections'] as List<dynamic>;
      subsections = subsectionList.map((item) => item.toString()).toList();
    }
    return Discipline(
      name: json['name'] as String,
      description: json['description'] as String,
      icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
      subsections: subsections,
    );
  }
}

class SubsectionPage extends StatefulWidget {
  final String subsectionId;
  final String subsectionName;

  const SubsectionPage({
    required this.subsectionId,
    required this.subsectionName,
    Key? key,
  }) : super(key: key);

  @override
  _SubsectionPageState createState() => _SubsectionPageState();
}

class _SubsectionPageState extends State<SubsectionPage> {
  Map<String, dynamic>? _subsectionData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubsectionData();
  }

  Future<void> _loadSubsectionData() async {
    try {
      final ref = FirebaseDatabase.instance.ref('subsections/${widget.subsectionId}');
      DatabaseEvent event = await ref.once();
      DataSnapshot snapshot = event.snapshot;

      if (!snapshot.exists) {
        setState(() {
          _isLoading = false;
          _error = 'Данные не найдены';
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        setState(() {
          _isLoading = false;
          _error = 'Данные пусты';
        });
        return;
      }

      setState(() {
        _subsectionData = Map<String, dynamic>.from(data.map((key, value) => MapEntry(key.toString(), value)));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка загрузки данных: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subsectionName,
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_subsectionData?['title'] != null)
            Text(
              _subsectionData!['title'],
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          SizedBox(height: 20),

          if (_subsectionData?['imageUrl'] != null && _subsectionData!['imageUrl'].toString().isNotEmpty)
            _buildImageWidget(_subsectionData!['imageUrl']),
          SizedBox(height: 20),

          if (_subsectionData?['content'] != null)
            Text(
              _subsectionData!['content'],
              style: Theme.of(context).textTheme.bodyLarge,
            ),

          SizedBox(height: 20),

          if (_subsectionData?['sections'] != null)
            ..._buildSections(_subsectionData!['sections'] as List),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 300,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => Icon(Icons.error_outline, size: 48, color: Colors.red),
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(List sections) {
    return sections.map((section) {
      final title = section['title'] ?? 'Без названия';
      final content = section['content'] ?? '';

      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.symmetric(vertical: 8),
        child: ExpansionTile(
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 1;
  int _hoverIndex = -1;
  final AuthService _authService = AuthService();

  final List<Widget> _pages = [
    Container(),
    CatalogPage(),
    AboutSystemPage(),
    ProfilePage(),
  ];

  final List<String> _titles = [
    'Об учреждении',
    'Каталог дисциплин',
    'О системе',
    'Профиль',
  ];

  final List<IconData> _icons = [
    Icons.business,
    Icons.menu_book,
    Icons.info,
    Icons.person,
  ];
  Future<void> _launchInstitutionUrl() async {
    const url = 'https://tsuab.ru/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Fluttertoast.showToast(msg: "Не удалось открыть сайт учреждения");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _authService.signOut(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            color: primaryBurgundy,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_icons.length, (index) {
                return MouseRegion(
                  onEnter: (_) => setState(() => _hoverIndex = index),
                  onExit: (_) => setState(() => _hoverIndex = -1),
                  child: GestureDetector(
                    onTap: () {
                      if (index == 0) {
                        _launchInstitutionUrl();
                      } else {
                        setState(() {
                          _currentIndex = index;
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: index == _currentIndex
                            ? Colors.white.withOpacity(0.2)
                            : _hoverIndex == index
                            ? Colors.white.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icons[index],
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            _titles[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: _pages[_currentIndex],
    );
  }
}

class AboutSystemPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 80, color: primaryBurgundy),
          SizedBox(height: 20),
          Text(
            'Строительный справочник',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Система разработана для обучения строительным дисциплинам',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 30),
          _buildFeatureCard(
            icon: Icons.verified_user,
            title: "Безопасность",
            description: "Доступ только для верифицированных пользователей",
          ),
          _buildFeatureCard(
            icon: Icons.search,
            title: "Поиск",
            description: "Быстрый поиск по всем учебным материалам",
          ),
          _buildFeatureCard(
            icon: Icons.storage,
            title: "Firebase",
            description: "Использование облачной базы данных для хранения контента",
          ),
          _buildFeatureCard(
            icon: Icons.book,
            title: "Учебные материалы",
            description: "Структурированные материалы с изображениями и текстом",
          ),
          SizedBox(height: 30),
          Text(
            "Система разработана для обучения строительным дисциплинам",
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SystemFeaturesPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBurgundy,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text("Подробный функционал системы"),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String description}) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: primaryBurgundy),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(description, style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: primaryBurgundy,
              radius: 50,
              child: Icon(Icons.person, size: 64, color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Email:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              user?.email ?? 'Неизвестен',
              style: TextStyle(fontSize: 18, color: primaryBurgundy),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogPage extends StatefulWidget {
  @override
  _CatalogPageState createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  List<Discipline> disciplines = [];
  List<Discipline> filteredDisciplines = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDisciplines();
    _searchController.addListener(() => _onSearchChanged(_searchController.text));
  }

  void _loadDisciplines() async {
    if (!mounted) return;
    setState(() {
      disciplines = [];
      filteredDisciplines = [];
    });
    try {
      final DatabaseReference ref = FirebaseDatabase.instance.ref('disciplines');
      DatabaseEvent event = await ref.once();
      DataSnapshot snapshot = event.snapshot;
      if (!mounted) return;
      if (snapshot.value == null) {
        print("⚠️ Данные пустые");
        if (mounted) {
          setState(() {
            disciplines = [];
            filteredDisciplines = [];
          });
        }
        return;
      }
      dynamic data = snapshot.value;
      print("Data type: ${data.runtimeType}");
      List<Discipline> newDisciplines = [];
      if (data is List) {
        print("Data is a list with length: ${data.length}");
        for (int i = 0; i < data.length; i++) {
          dynamic item = data[i];
          if (item != null && item is Map) {
            try {
              newDisciplines.add(Discipline.fromJson(Map<String, dynamic>.from(item)));
            } catch (e) {
              print("Error parsing item at index $i: $e");
            }
          }
        }
      } else if (data is Map) {
        print("Data is a map with keys: ${data.keys}");
        data.forEach((key, value) {
          if (value != null && value is Map) {
            try {
              newDisciplines.add(Discipline.fromJson(Map<String, dynamic>.from(value)));
            } catch (e) {
              print("Error parsing item with key $key: $e");
            }
          }
        });
      } else {
        print("Unknown data type: ${data.runtimeType}");
      }
      print("Loaded ${newDisciplines.length} disciplines");
      if (mounted) {
        setState(() {
          disciplines = newDisciplines;
          filteredDisciplines = List.from(disciplines);
        });
      }
    } catch (e) {
      print("❌ Ошибка загрузки данных: $e");
      if (mounted) {
        setState(() {
          disciplines = [];
          filteredDisciplines = [];
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (!mounted) return;
    setState(() {
      filteredDisciplines = disciplines
          .where((d) =>
      d.name.toLowerCase().contains(query.toLowerCase()) ||
          d.description.toLowerCase().contains(query.toLowerCase()) ||
          d.subsections.any((sub) => sub.toLowerCase().contains(query.toLowerCase())))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Поиск по дисциплинам',
              prefixIcon: Icon(Icons.search, color: primaryBurgundy),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryBurgundy),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryBurgundy, width: 2),
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredDisciplines.isEmpty
              ? Center(child: Text('Нет данных'))
              : ListView.builder(
            itemCount: filteredDisciplines.length,
            itemBuilder: (_, i) {
              final d = filteredDisciplines[i];
              return _buildDisciplineTile(d);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDisciplineTile(Discipline discipline) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: Icon(discipline.icon, color: primaryBurgundy),
        title: Text(discipline.name, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(discipline.description),
        children: discipline.subsections.map((subsection) {
          String subsectionId = '${discipline.name}_${subsection}'
              .toLowerCase()
              .replaceAll(' ', '_')
              .replaceAll('-', '_');

          return ListTile(
            title: Text(subsection),
            contentPadding: EdgeInsets.only(left: 32.0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubsectionPage(
                    subsectionId: subsectionId,
                    subsectionName: subsection,
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}