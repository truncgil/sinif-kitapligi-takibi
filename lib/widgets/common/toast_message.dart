import 'dart:async';
import 'package:flutter/material.dart';

// Aktif toast'u takip etmek için global değişkenler
OverlayEntry? _currentToast;
Timer? _toastTimer;

/// Toast mesaj gösterme fonksiyonu
///
/// [message] Gösterilecek mesaj
/// [isSuccess] Başarılı mı başarısız mı durumu (Renk değişimi için)
void showToastMessage(
  BuildContext context, {
  required String message,
  bool isSuccess = true,
}) {
  // Varsa eski toast'u hemen kaldır
  _removeCurrentToast();

  final overlay = Overlay.of(context);

  _currentToast = OverlayEntry(
    builder: (context) => Positioned(
      // Ekranın üst kısmında göster (SafeArea'yı dikkate alarak)
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: _ToastWidget(
          message: message,
          isSuccess: isSuccess,
          onDismiss: _removeCurrentToast,
        ),
      ),
    ),
  );

  overlay.insert(_currentToast!);

  // 1.5 saniye sonra otomatik kaldır
  _toastTimer = Timer(const Duration(milliseconds: 1500), () {
    _removeCurrentToast();
  });
}

void _removeCurrentToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _currentToast?.remove();
  _currentToast = null;
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.isSuccess,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _offset = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSuccess
                ? const Color(0xFF04BF61)
                : Colors.red.shade700,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSuccess ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.onDismiss,
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
