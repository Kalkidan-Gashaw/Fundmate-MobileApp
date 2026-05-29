import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'entrepreneur_screen.dart';
import 'mentor_screen.dart';
import 'investor_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/fundmate_app_bar.dart';
import 'widgets/fundmate_gradient_scaffold.dart';
import 'widgets/theme_toggle_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ThemeController.instance.load();
  runApp(const FundMateApp());
}

class FundMateApp extends StatelessWidget {
  const FundMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'FundMate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.mode,
          themeAnimationDuration: AppTheme.duration,
          themeAnimationCurve: AppTheme.curve,
          home: const AuthCheck(),
        );
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    // authStateChanges can fail to rebuild on Windows desktop; listen + setState fixes it.
    FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() => _checkingAuth = false);
    });
    FirebaseAuth.instance.userChanges().listen((_) {
      if (mounted) setState(() => _checkingAuth = false);
    });
    Future.microtask(() {
      if (mounted) setState(() => _checkingAuth = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth && FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (FirebaseAuth.instance.currentUser != null) {
      return const RoleRouter();
    }
    return const LoginPage();
  }
}

void _goToHomeAfterAuth(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RoleRouter()),
    (route) => false,
  );
}

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final role = snapshot.data!.get('role');
          if (role == 'entrepreneur') return const EntrepreneurScreen();
          if (role == 'investor') return const InvestorScreen();
          if (role == 'mentor') return const MentorScreen();
        }
        return const RoleSelectionPage();
      },
    );
  }
}

// ==================== LOGIN PAGE ====================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnackbar('Please fill all fields', Colors.red);
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return;
      _goToHomeAfterAuth(context);
      _showSnackbar('Login successful!', Colors.green);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found')
        message = 'No account found with this email';
      if (e.code == 'wrong-password') message = 'Wrong password';
      if (e.code == 'invalid-email') message = 'Invalid email format';
      _showSnackbar(message, Colors.red);
    } catch (e) {
      _showSnackbar('Something went wrong', Colors.red);
    }
    setState(() => isLoading = false);
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fm = context.fundMate;

    return FundMateGradientScaffold(
      child: Stack(
        children: [
          const Positioned(
            top: 4,
            right: 4,
            child: ThemeToggleButton(onGradientBackground: true),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: fm.shadow,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.business_center,
                      size: 45,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'FUNDMATE',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect with investors & mentors',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),
                  FundMateAuthCard(
                    child: Column(
                      children: [
                        FundMateAuthField(
                          child: TextField(
                            controller: emailController,
                            style: TextStyle(
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FundMateAuthField(
                          child: TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            style: TextStyle(
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                    () => obscurePassword = !obscurePassword),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : login,
                            child: isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Text('Login'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(color: fm.mutedText),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SignupPage()),
                                );
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SIGNUP PAGE ====================

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String selectedRole = 'entrepreneur';
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  Future<void> signup() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _showSnackbar('Please fill all fields', Colors.red);
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      _showSnackbar('Passwords do not match', Colors.red);
      return;
    }
    if (passwordController.text.length < 6) {
      _showSnackbar('Password must be at least 6 characters', Colors.red);
      return;
    }

    setState(() => isLoading = true);
    try {
      final userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'role': selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _goToHomeAfterAuth(context);
      _showSnackbar('Account created successfully!', Colors.green);
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      if (e.code == 'email-already-in-use') message = 'Email already in use';
      if (e.code == 'weak-password') message = 'Password is too weak';
      if (e.code == 'invalid-email') message = 'Invalid email format';
      _showSnackbar(message, Colors.red);
    } catch (e) {
      _showSnackbar('Something went wrong', Colors.red);
    }
    setState(() => isLoading = false);
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fm = context.fundMate;

    return FundMateGradientScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Spacer(),
                const ThemeToggleButton(onGradientBackground: true),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join the FundMate community',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            FundMateAuthCard(
              child: Column(
                children: [
                  FundMateAuthField(
                    child: TextField(
                      controller: nameController,
                      style: TextStyle(fontSize: 16, color: scheme.onSurface),
                      decoration: const InputDecoration(
                        hintText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FundMateAuthField(
                    child: TextField(
                      controller: emailController,
                      style: TextStyle(fontSize: 16, color: scheme.onSurface),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FundMateAuthField(
                    child: TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: TextStyle(fontSize: 16, color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                              () => obscurePassword = !obscurePassword),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FundMateAuthField(
                    child: TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      style: TextStyle(fontSize: 16, color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(() =>
                              obscureConfirmPassword =
                                  !obscureConfirmPassword),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'I am a...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildRoleChip('entrepreneur', '👨‍💼', 'Entrepreneur'),
                      const SizedBox(width: 8),
                      _buildRoleChip('investor', '💰', 'Investor'),
                      const SizedBox(width: 8),
                      _buildRoleChip('mentor', '🎓', 'Mentor'),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : signup,
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(color: fm.mutedText),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Login',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, String emoji, String label) {
    final isSelected = selectedRole == role;
    final fm = context.fundMate;
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? fm.chipSelected : fm.chipUnselected,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? fm.chipSelected : fm.chipBorder,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? (context.isDarkMode
                          ? const Color(0xFF0A0E18)
                          : Colors.white)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ROLE SELECTION PAGE ====================

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    Future<void> updateRole(String role) async {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'role': role},
        SetOptions(merge: true),
      );
      if (context.mounted) {
        _goToHomeAfterAuth(context);
      }
    }

    return FundMateGradientScaffold(
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: ThemeToggleButton(onGradientBackground: true),
          ),
          const SizedBox(height: 24),
          const Text(
            'Choose Your Role',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'How will you use FundMate?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildRoleCard(
                  context,
                  'Entrepreneur',
                  'Find funding and mentorship',
                  Icons.rocket_launch,
                  Colors.blue,
                  () => updateRole('entrepreneur'),
                ),
                const SizedBox(height: 12),
                _buildRoleCard(
                  context,
                  'Investor',
                  'Discover promising startups',
                  Icons.trending_up,
                  Colors.green,
                  () => updateRole('investor'),
                ),
                const SizedBox(height: 12),
                _buildRoleCard(
                  context,
                  'Mentor',
                  'Share expertise and guide founders',
                  Icons.school,
                  Colors.orange,
                  () => updateRole('mentor'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildRoleCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final fm = context.fundMate;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: fm.authCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fm.cardBorder.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: fm.shadow,
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PLACEHOLDER SCREEN ====================

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FundMateAppBar(
        title: title,
        subtitle: 'FundMate',
        leadingIcon: Icons.business_center_rounded,
        actions: [
          FundMateAppBar.actionButton(
            icon: Icons.logout_rounded,
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '$title Coming Soon',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is under development',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
