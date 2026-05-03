part of '../../app/app.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showForgotPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validate all fields simultaneously by triggering validation without stopping
    final isValid = _formKey.currentState!.validate();
    
    if (isValid) {
      if (mounted) setState(() => _isLoading = true);

      try {
        // Try to login directly; Firebase will report if email/password is invalid.
        bool success = await AuthService.login(_emailController.text.trim(), _passwordController.text);

        // If the widget was unmounted while waiting (e.g. navigation on auth change), exit.
        if (!mounted) return;

        setState(() => _isLoading = false);

        if (success) {
          // Login succeeded; the StreamBuilder in BarangayApp will handle navigation.
          return;
        }
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        String title;
        String message;
        String? actionText;
        VoidCallback? actionCallback;

        if (e.code == 'user-not-found') {
          title = 'Account Not Found';
          message = 'No account exists for this email address. Would you like to create a new account?';
          actionText = 'Register';
          actionCallback = () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.register);
          };
          setState(() => _showForgotPassword = true);
        } else if (e.code == 'wrong-password') {
          title = 'Incorrect Password';
          message = 'The password you entered is incorrect. Please try again or reset your password.';
          actionText = 'Reset Password';
          actionCallback = () {
            Navigator.pop(context);
            _showForgotPasswordDialog();
          };
          setState(() => _showForgotPassword = true);
        } else if (e.code == 'account-pending-approval') {
          title = 'Account Pending Approval';
          message = 'Your account registration is currently under review by the barangay officials. You will receive a notification once your account has been approved. Please try logging in again later.';
        } else if (e.code == 'account-rejected') {
          title = 'Account Rejected';
          message = 'Your account registration has been rejected by the barangay officials. Please contact your barangay office for more information.';
        } else if (e.code == 'no-officials-found') {
          title = 'No Barangay Officials';
          message = e.message ?? 'There are no registered officials in your barangay yet.';
        } else if (e.code == 'invalid-email') {
          title = 'Invalid Email';
          message = 'Please enter a valid email address.';
        } else if (e.code == 'profile-not-found') {
          title = 'Profile Not Found';
          message = e.message ?? 'Your account profile could not be loaded. Please contact support.';
        } else if (e.code == 'user-disabled') {
          title = 'Account Disabled';
          message = 'This account has been disabled. Please contact support.';
        } else if (e.code == 'too-many-requests') {
          title = 'Too Many Attempts';
          message = 'You\'ve tried to login too many times. Please try again later.';
        } else if (e.code == 'invalid-credential') {
          title = 'Login Failed';
          message = 'Invalid email or password. Please check and try again.';
          setState(() => _showForgotPassword = true);
        } else {
          title = 'Login Error';
          message = 'An error occurred: ${e.message}';
        }

        if (mounted) {
          _showErrorDialog(title, message, actionText, actionCallback);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog('Error', 'An unexpected error occurred: ${e.toString()}', null, null);
        }
      }
    }
  }

  void _showErrorDialog(String title, String message, String? actionText, VoidCallback? actionCallback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (actionText != null && actionCallback != null)
            ElevatedButton(
              onPressed: actionCallback,
              child: Text(actionText),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email address and we\'ll send you a password reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                if (mounted) {
                  Navigator.pop(context);
                  _showErrorDialog('Invalid Email', 'Please enter a valid email address.', null, null);
                }
                return;
              }
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Email Sent'),
                      content: const Text('A password reset link has been sent to your email. Please check your inbox.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showErrorDialog('Error', 'Could not send reset email: ${e.message}', null, null);
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Unfocus all text fields when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // BAG-O Logo - Enlarged
                    Image.asset('assets/images/FINAL_LOGO_NAT_-removebg-preview.png', width: 220, height: 220, fit: BoxFit.contain),
                    const SizedBox(height: 24),
                    const Text('BAG-O', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF228B22))),
                    const Text('Barangay Automated Governance and Operation', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF228B22), width: 2),
                        ),
                      ),
                      validator: (val) => val!.isEmpty || !val.contains('@') ? 'Enter valid email' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF228B22), width: 2),
                        ),
                      ),
                      validator: (val) => val!.isEmpty ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 24),

                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('LOGIN', style: TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                          child: const Text("Don't have an account? Register", style: TextStyle(color: Color(0xFF228B22))),
                        ),
                        if (_showForgotPassword)
                          TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF228B22))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== REGISTRATION PAGE ====================


