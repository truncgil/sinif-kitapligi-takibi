#!/bin/bash

echo "🔧 Versiyon artırılıyor..."
dart bump_version.dart

echo "🚀 App Bundle oluşturuluyor..."
flutter build appbundle

echo "📂 Finder açılıyor..."
open build/app/outputs/bundle/release/
