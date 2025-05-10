# Kitap Takibi Kütüphanesi

Flutter ile geliştirilmiş offline çalışan kitap takibi yönetim uygulaması.

## Uygulama İkonunu Değiştirme

Uygulama ikonunu değiştirmek için aşağıdaki adımları izleyebilirsiniz:

1. Paylaştığınız resmi bilgisayarınıza kaydedin
2. Projedeki `assets/icons/` klasörüne `icon.png` adıyla kopyalayın
3. Aşağıdaki komutu çalıştırarak uygulama ikonlarını güncelleyin:

```bash
flutter pub run flutter_launcher_icons
```

4. Uygulama ikonunuzun tüm platformlar için güncellenmiş olması gerekir

## Proje Yapısı

- `lib/models/`: Veri modelleri
- `lib/screens/`: Uygulama ekranları
- `lib/services/`: Veritabanı ve barkod tarayıcı servisleri
- `lib/widgets/`: Yeniden kullanılabilir widget'lar
