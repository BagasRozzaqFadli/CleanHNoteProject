import 'package:flutter/material.dart';
import 'package:cleanhnoteapp/services/auth_services.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cleanhnoteapp/utils/responsive_layout.dart';
import 'package:cleanhnoteapp/utils/responsive_theme.dart';
import 'package:cleanhnoteapp/widgets/responsive_builder.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
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
    if (value.length < 8) {
      return 'Password minimal 8 karakter';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama tidak boleh kosong';
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();
      
      final user = await _authService.signUp(email, password, name);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registrasi berhasil! Silakan login.'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pushReplacementNamed(context, '/login');
    } on AppwriteException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat registrasi';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menghitung skala responsif berdasarkan ukuran layar
    final paddingScale = ResponsiveLayout.getPaddingScale(context);
    final fontScale = ResponsiveLayout.getFontScale(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = ResponsiveTheme.getResponsivePadding(context, EdgeInsets.all(16));
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24 * paddingScale),
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
                          width: screenWidth * 0.2, // Responsif berdasarkan lebar layar
                          height: screenWidth * 0.2, // Responsif berdasarkan lebar layar
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
                          'Buat akun baru untuk memulai',
                          style: TextStyle(
                            fontSize: 16 * fontScale,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (_errorMessage != null)
                    Container(
                      padding: EdgeInsets.all(12 * paddingScale),
                      margin: EdgeInsets.only(bottom: 16 * paddingScale),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8 * paddingScale),
                        border: Border.all(
                          color: Colors.red.shade200,
                          width: 1 * paddingScale,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 24 * fontScale,
                          ),
                          SizedBox(width: 8 * paddingScale),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 14 * fontScale,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      labelStyle: TextStyle(fontSize: 16 * fontScale),
                      hintText: 'Masukkan nama lengkap Anda',
                      hintStyle: TextStyle(fontSize: 14 * fontScale),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10 * paddingScale),
                        borderSide: BorderSide(width: 1 * paddingScale),
                      ),
                      prefixIcon: Icon(
                        Icons.person,
                        size: 24 * fontScale,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 16 * paddingScale, 
                        horizontal: 16 * paddingScale
                      ),
                    ),
                    style: TextStyle(fontSize: 16 * fontScale),
                    validator: _validateName,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16 * paddingScale),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(fontSize: 16 * fontScale),
                      hintText: 'Masukkan email Anda',
                      hintStyle: TextStyle(fontSize: 14 * fontScale),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10 * paddingScale),
                        borderSide: BorderSide(width: 1 * paddingScale),
                      ),
                      prefixIcon: Icon(
                        Icons.email,
                        size: 24 * fontScale,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 16 * paddingScale, 
                        horizontal: 16 * paddingScale
                      ),
                    ),
                    style: TextStyle(fontSize: 16 * fontScale),
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16 * paddingScale),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(fontSize: 16 * fontScale),
                      hintText: 'Masukkan password Anda',
                      hintStyle: TextStyle(fontSize: 14 * fontScale),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10 * paddingScale),
                        borderSide: BorderSide(width: 1 * paddingScale),
                      ),
                      prefixIcon: Icon(
                        Icons.lock,
                        size: 24 * fontScale,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 16 * paddingScale, 
                        horizontal: 16 * paddingScale
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                          size: 24 * fontScale,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    style: TextStyle(fontSize: 16 * fontScale),
                    validator: _validatePassword,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                  ),
                  SizedBox(height: 24 * paddingScale),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                                'Mendaftar...',
                                style: TextStyle(fontSize: 16 * fontScale),
                              ),
                            ],
                          )
                        : Text(
                            'Daftar',
                            style: TextStyle(fontSize: 16 * fontScale),
                          ),
                  ),
                  SizedBox(height: 16 * paddingScale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sudah punya akun?',
                        style: TextStyle(fontSize: 14 * fontScale),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * paddingScale,
                            vertical: 4 * paddingScale,
                          ),
                        ),
                        child: Text(
                          'Login',
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
