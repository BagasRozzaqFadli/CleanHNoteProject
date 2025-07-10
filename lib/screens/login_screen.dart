import 'package:flutter/material.dart';
import 'package:cleanhnoteapp/services/auth_services.dart';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cleanhnoteapp/utils/responsive_layout.dart';
import 'package:cleanhnoteapp/utils/responsive_theme.dart';
import 'package:cleanhnoteapp/widgets/responsive_builder.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRetrying = false;
  int _retryCount = 0;
  int _maxRetries = 3;
  bool _obscurePassword = true; // Untuk toggle password visibility
  bool _rememberMe = true; // Default remember me

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      
      if (savedEmail != null && savedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = savedEmail;
          if (savedPassword != null && savedPassword.isNotEmpty) {
            _passwordController.text = savedPassword;
          }
        });
      }
    } catch (e) {
      // Ignore error when loading credentials
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', _emailController.text);
        await prefs.setString('saved_password', _passwordController.text);
      } catch (e) {
        debugPrint('Error saving credentials: $e');
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }
    if (!value.contains('@')) {
      return 'Email tidak valid';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isRetrying = false;
      _retryCount = 0;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      // Simpan kredensial jika opsi 'ingat saya' diaktifkan
      await _saveCredentials();
      
      await _authService.signIn(email, password);
      
      if (!mounted) return;
      
      // Navigasi ke halaman home router setelah login berhasil
      Navigator.pushReplacementNamed(context, '/home');
    } on AppwriteException catch (e) {
      setState(() {
        if (e.message?.contains('Rate limit') == true) {
          _errorMessage = 'Server sedang sibuk. Sistem akan mencoba login kembali secara otomatis...';
          _isRetrying = true;
          _retryWithDelay();
        } else if (e.type == 'user_invalid_credentials') {
          _errorMessage = 'Email atau password salah';
        } else if (e.type == 'general_unauthorized_scope') {
          _errorMessage = 'Sesi tidak valid. Silakan coba login kembali.';
        } else {
          _errorMessage = e.message ?? 'Terjadi kesalahan pada server';
          debugPrint('AppwriteException: ${e.type} - ${e.message}');
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat login';
        debugPrint('Login error: $e');
      });
    } finally {
      if (mounted && !_isRetrying) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _retryWithDelay() async {
    if (_retryCount >= _maxRetries) {
      setState(() {
        _isLoading = false;
        _isRetrying = false;
        _errorMessage = 'Gagal login setelah beberapa percobaan. Silakan coba lagi nanti.';
      });
      return;
    }

    _retryCount++;
    await Future.delayed(Duration(seconds: 3 * _retryCount));
    
    if (!mounted) return;
    
    setState(() {
      _errorMessage = 'Mencoba login kembali (${_retryCount}/${_maxRetries})...';
    });
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await _authService.signIn(email, password);
      
      if (!mounted) return;
      
      // Navigasi ke halaman home router setelah login berhasil
      Navigator.pushReplacementNamed(context, '/home');
    } on AppwriteException catch (e) {
      if (e.message?.contains('Rate limit') == true) {
        if (_retryCount < _maxRetries) {
          _retryWithDelay();
        } else {
          setState(() {
            _isLoading = false;
            _isRetrying = false;
            _errorMessage = 'Server masih sibuk. Silakan coba lagi nanti.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _isRetrying = false;
          _errorMessage = e.message ?? 'Terjadi kesalahan pada server';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRetrying = false;
        _errorMessage = 'Terjadi kesalahan saat login';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dapatkan faktor skala untuk padding dan font berdasarkan ukuran layar
    final paddingScale = ResponsiveLayout.getPaddingScale(context);
    final fontScale = ResponsiveLayout.getFontScale(context);
    final screenWidth = ResponsiveLayout.getScreenWidth(context);
    
    // Sesuaikan padding berdasarkan ukuran layar
    final basePadding = EdgeInsets.all(24);
    final responsivePadding = ResponsiveTheme.getResponsivePadding(context, basePadding);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: responsivePadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo atau gambar aplikasi
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0 * paddingScale),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/images/task_alt_icon.svg',
                          width: screenWidth < 360 ? 60 : 80,
                          height: screenWidth < 360 ? 60 : 80,
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).primaryColor,
                            BlendMode.srcIn,
                          ),
                        ),
                        SizedBox(height: 16 * paddingScale),
                        Text(
                          'CleanHNote',
                          style: TextStyle(
                            fontSize: 28 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 8 * paddingScale),
                        Text(
                          'Kelola tugas dengan lebih efisien',
                          style: TextStyle(
                            fontSize: 16 * fontScale,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  if (_errorMessage != null)
                    Container(
                      padding: EdgeInsets.all(12 * paddingScale),
                      margin: EdgeInsets.only(bottom: 16 * paddingScale),
                      decoration: BoxDecoration(
                        color: _isRetrying ? Colors.orange.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8 * paddingScale),
                        border: Border.all(
                          color: _isRetrying ? Colors.orange.shade200 : Colors.red.shade200,
                          width: 1 * paddingScale,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isRetrying ? Icons.hourglass_empty : Icons.error_outline,
                            color: _isRetrying ? Colors.orange : Colors.red,
                            size: 24 * fontScale,
                          ),
                          SizedBox(width: 8 * paddingScale),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 14 * fontScale,
                                color: _isRetrying ? Colors.orange.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: 20 * paddingScale),
                  
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(fontSize: 16 * fontScale),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(fontSize: 16 * fontScale),
                      hintText: 'Masukkan email Anda',
                      hintStyle: TextStyle(fontSize: 14 * fontScale),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10 * paddingScale),
                        borderSide: BorderSide(width: 1 * paddingScale),
                      ),
                      prefixIcon: Icon(Icons.email, size: 22 * fontScale),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 16 * paddingScale, 
                        horizontal: 16 * paddingScale
                      ),
                    ),
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16 * paddingScale),
                  TextFormField(
                    controller: _passwordController,
                    style: TextStyle(fontSize: 16 * fontScale),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(fontSize: 16 * fontScale),
                      hintText: 'Masukkan password Anda',
                      hintStyle: TextStyle(fontSize: 14 * fontScale),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10 * paddingScale),
                        borderSide: BorderSide(width: 1 * paddingScale),
                      ),
                      prefixIcon: Icon(Icons.lock, size: 22 * fontScale),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 16 * paddingScale, 
                        horizontal: 16 * paddingScale
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                          size: 22 * fontScale,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: _validatePassword,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  
                  SizedBox(height: 8 * paddingScale),
                  
                  // Remember me checkbox
                  Row(
                    children: [
                      Transform.scale(
                        scale: fontScale,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                      ),
                      Text(
                        'Ingat saya',
                        style: TextStyle(fontSize: 14 * fontScale),
                      ),
                      Spacer(),
                      TextButton(
                        onPressed: () {
                          // Fungsi lupa password (belum diimplementasikan)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Fitur lupa password belum tersedia',
                                style: TextStyle(fontSize: 14 * fontScale),
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * paddingScale,
                            vertical: 4 * paddingScale,
                          ),
                        ),
                        child: Text(
                          'Lupa password?',
                          style: TextStyle(fontSize: 14 * fontScale),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24 * paddingScale),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16 * paddingScale),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10 * paddingScale),
                      ),
                      minimumSize: Size(double.infinity, 48 * paddingScale),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20 * fontScale,
                                width: 20 * fontScale,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2 * paddingScale,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10 * paddingScale),
                              Text(
                                _isRetrying ? 'Mencoba login ulang...' : 'Login...',
                                style: TextStyle(fontSize: 16 * fontScale),
                              ),
                            ],
                          )
                        : Text(
                            'Login',
                            style: TextStyle(fontSize: 16 * fontScale),
                          ),
                  ),
                  SizedBox(height: 16 * paddingScale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Belum punya akun?',
                        style: TextStyle(fontSize: 14 * fontScale),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/register'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * paddingScale,
                            vertical: 4 * paddingScale,
                          ),
                        ),
                        child: Text(
                          'Daftar',
                          style: TextStyle(fontSize: 14 * fontScale),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
