import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roamly/features/admin/screens/admin_dashboard.dart';
import 'package:roamly/features/home/screens/home_screen.dart';
import 'package:roamly/models/user_profile_model.dart';

// ──────────────────────────────────────────────
// Navy‑blue themed Login Screen for Roamly
// Three‑screen flow: Welcome → Sign In → Sign Up
// ──────────────────────────────────────────────

enum _ScreenState { welcome, signIn, signUp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── State ──
  _ScreenState _screen = _ScreenState.welcome;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  // ── Login form ──
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  // ── Sign‑up form ──
  final _signupFormKey = GlobalKey<FormState>();
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  final _signupConfirmPasswordCtrl = TextEditingController();

  // ── Colors ──
  static const _navyDark = Color(0xFF1A237E);
  static const _navyLight = Color(0xFF3949AB);

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPhoneCtrl.dispose();
    _signupPasswordCtrl.dispose();
    _signupConfirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ───────────────────── Auth logic (unchanged) ─────────────────────

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPasswordCtrl.text,
      );

      if (!mounted) return;

      final email = credential.user?.email;
      final isAdmin =
          email != null && email.trim().toLowerCase() == 'admin@roamly.com';

      if (!mounted) return;
      debugPrint('LOGIN SUCCESS: $email (Admin: $isAdmin)');

      if (isAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Authentication failed'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _signupEmailCtrl.text.trim(),
        password: _signupPasswordCtrl.text,
      );

      if (!mounted) return;

      final userProfile = UserProfile(
        uid: credential.user!.uid,
        email: _signupEmailCtrl.text.trim(),
        name: _signupNameCtrl.text.trim(),
        phoneNumber: _signupPhoneCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set(userProfile.toMap());

      if (!mounted) return;
      debugPrint('SIGNUP SUCCESS: ${credential.user?.email}');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = e.message ?? 'Registration failed';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered. Please login instead.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────── Navigation helpers ─────────────────────

  void _goTo(_ScreenState s) => setState(() => _screen = s);

  // ───────────────────── BUILD ─────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Navy gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_navyDark, _navyLight],
              ),
            ),
          ),

          // Topographic pattern overlay
          Positioned.fill(
            child: CustomPaint(painter: _TopographicPainter()),
          ),

          // Screen content
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.15, 0),
                  end: Offset.zero,
                ).animate(animation);
                return SlideTransition(
                  position: slide,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _buildCurrentScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_screen) {
      case _ScreenState.welcome:
        return _WelcomeContent(
          key: const ValueKey('welcome'),
          onGetStarted: () => _goTo(_ScreenState.signUp),
          onSignIn: () => _goTo(_ScreenState.signIn),
        );
      case _ScreenState.signIn:
        return _SignInContent(
          key: const ValueKey('signIn'),
          formKey: _loginFormKey,
          emailCtrl: _loginEmailCtrl,
          passwordCtrl: _loginPasswordCtrl,
          obscurePassword: _obscurePassword,
          isLoading: _isLoading,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onLogin: _handleLogin,
          onBack: () => _goTo(_ScreenState.welcome),
          onGoToSignUp: () => _goTo(_ScreenState.signUp),
        );
      case _ScreenState.signUp:
        return _SignUpContent(
          key: const ValueKey('signUp'),
          formKey: _signupFormKey,
          nameCtrl: _signupNameCtrl,
          emailCtrl: _signupEmailCtrl,
          phoneCtrl: _signupPhoneCtrl,
          passwordCtrl: _signupPasswordCtrl,
          confirmPasswordCtrl: _signupConfirmPasswordCtrl,
          obscurePassword: _obscurePassword,
          obscureConfirmPassword: _obscureConfirmPassword,
          agreedToTerms: _agreedToTerms,
          isLoading: _isLoading,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onToggleConfirmPassword: () =>
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          onToggleTerms: (v) => setState(() => _agreedToTerms = v ?? false),
          onSignUp: _handleSignup,
          onBack: () => _goTo(_ScreenState.welcome),
          onGoToSignIn: () => _goTo(_ScreenState.signIn),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  WELCOME SCREEN
// ═══════════════════════════════════════════════════════════════

class _WelcomeContent extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const _WelcomeContent({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Logo / icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),

          // Heading
          Text(
            'Welcome to\nRoamly',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            'Plan your rides, discover new trails,\nand share the adventure.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
              height: 1.5,
            ),
          ),

          const Spacer(flex: 3),

          // Get Started button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A237E),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Get Started'),
            ),
          ),
          const SizedBox(height: 14),

          // Sign In button (outlined)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: onSignIn,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Sign In'),
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SIGN‑IN SCREEN
// ═══════════════════════════════════════════════════════════════

class _SignInContent extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onBack;
  final VoidCallback onGoToSignUp;

  const _SignInContent({
    super.key,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onBack,
    required this.onGoToSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back arrow
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: onBack,
          ),
          const SizedBox(height: 16),

          // Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign In',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome back, rider!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Email
                  _label('Email'),
                  const SizedBox(height: 8),
                  _styledField(
                    controller: emailCtrl,
                    hint: 'you@example.com',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    action: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password
                  _label('Password'),
                  const SizedBox(height: 8),
                  _styledField(
                    controller: passwordCtrl,
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscure: obscurePassword,
                    action: TextInputAction.done,
                    onSubmit: (_) => onLogin(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'Min 6 characters';
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: onTogglePassword,
                    ),
                  ),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF1A237E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sign In button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF1A237E).withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Switch to Sign Up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                      GestureDetector(
                        onTap: onGoToSignUp,
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A237E),
                          ),
                        ),
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════
//  SIGN‑UP SCREEN
// ═══════════════════════════════════════════════════════════════

class _SignUpContent extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool agreedToTerms;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final ValueChanged<bool?> onToggleTerms;
  final VoidCallback onSignUp;
  final VoidCallback onBack;
  final VoidCallback onGoToSignIn;

  const _SignUpContent({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.confirmPasswordCtrl,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.agreedToTerms,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onToggleTerms,
    required this.onSignUp,
    required this.onBack,
    required this.onGoToSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back arrow
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: onBack,
          ),
          const SizedBox(height: 8),

          // Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Account',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join the ride. Start your journey.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Full Name
                  _label('Full Name'),
                  const SizedBox(height: 8),
                  _styledField(
                    controller: nameCtrl,
                    hint: 'John Doe',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                    action: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 18),

                  // Email
                  _label('Email'),
                  const SizedBox(height: 8),
                  _styledField(
                    controller: emailCtrl,
                    hint: 'you@example.com',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    action: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Phone
                  _label('Phone Number'),
                  const SizedBox(height: 8),
                  _styledField(
                    controller: phoneCtrl,
                    hint: '+1 234 567 8900',
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    action: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 10) return 'Invalid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password
                  _label('Password'),
                  const SizedBox(height: 8),
                  _styledField(
                    controller: passwordCtrl,
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscure: obscurePassword,
                    action: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'Min 6 characters';
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: onTogglePassword,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Confirm Password
                  _label('Confirm Password'),
                  const SizedBox(height: 8),
                  _styledField(
                    controller: confirmPasswordCtrl,
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscure: obscureConfirmPassword,
                    action: TextInputAction.done,
                    onSubmit: (_) => onSignUp(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v != passwordCtrl.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: onToggleConfirmPassword,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Terms checkbox
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: agreedToTerms,
                          onChanged: onToggleTerms,
                          activeColor: const Color(0xFF1A237E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            children: [
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A237E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Sign Up button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF1A237E).withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Switch to Sign In
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                      GestureDetector(
                        onTap: onGoToSignIn,
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A237E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED HELPERS
// ═══════════════════════════════════════════════════════════════

Widget _label(String text) {
  return Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF2D2D2D),
    ),
  );
}

Widget _styledField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  bool obscure = false,
  TextInputType? keyboard,
  TextInputAction? action,
  TextCapitalization capitalization = TextCapitalization.none,
  String? Function(String?)? validator,
  ValueChanged<String>? onSubmit,
  Widget? suffixIcon,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboard,
    textInputAction: action,
    textCapitalization: capitalization,
    onFieldSubmitted: onSubmit,
    validator: validator,
    style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D2D2D)),
    cursorColor: const Color(0xFF1A237E),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A237E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  TOPOGRAPHIC PATTERN PAINTER
// ═══════════════════════════════════════════════════════════════

class _TopographicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw organic topographic-style curves
    for (int i = 0; i < 12; i++) {
      final path = Path();
      final yOffset = size.height * (i / 12.0) - 20;
      path.moveTo(-20, yOffset + 60);

      // Create flowing curves that look like contour lines
      for (double x = -20; x <= size.width + 20; x += 80) {
        final y = yOffset +
            60 * _topoWave(x / size.width, i) +
            30 * _topoWave(x / size.width * 2.5, i + 3);
        if (x == -20) {
          path.moveTo(x, y);
        } else {
          path.quadraticBezierTo(
            x - 40,
            y + 20 * _topoWave((x - 40) / size.width, i + 1),
            x,
            y,
          );
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  double _topoWave(double x, int seed) {
    // Simple deterministic wave based on seed
    final a = (seed * 7 + 3) % 11 / 11.0;
    final b = (seed * 13 + 5) % 7 / 7.0;
    return (a * _sin(x * 3.14159 * 2 + b * 6.28)) +
        (1 - a) * _sin(x * 3.14159 * 4 + b * 3.14);
  }

  double _sin(double x) {
    // Approximate sine without dart:math import in painting context
    x = x % 6.28318;
    if (x > 3.14159) x -= 6.28318;
    // Taylor series approximation
    final x2 = x * x;
    final x3 = x2 * x;
    final x5 = x3 * x2;
    final x7 = x5 * x2;
    return x - x3 / 6 + x5 / 120 - x7 / 5040;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
