# Space Grotesk Font

Этот шрифт используется для Solana-элементов в редизайне приложения.

## Установка

1. Скачайте шрифт Space Grotesk с официального сайта:
   - https://www.fontshare.com/fonts/space-grotesk
   - Или с Google Fonts: https://fonts.google.com/specimen/Space+Grotesk

2. Распакуйте архив и скопируйте файлы шрифтов в папку `assets/fonts/`:
   ```
   assets/fonts/SpaceGrotesk-Regular.ttf
   assets/fonts/SpaceGrotesk-Medium.ttf
   assets/fonts/SpaceGrotesk-Bold.ttf
   ```

3. Шрифт уже добавлен в `pubspec.yaml`:
   ```yaml
   fonts:
     - family: SpaceGrotesk
       fonts:
         - asset: assets/fonts/SpaceGrotesk-Regular.ttf
         - asset: assets/fonts/SpaceGrotesk-Medium.ttf
           weight: 500
         - asset: assets/fonts/SpaceGrotesk-Bold.ttf
           weight: 700
   ```

4. Запустите `flutter pub get` для обновления зависимостей

5. Запустите `flutter clean` и `flutter pub get` для очистки кэша

## Использование

Шрифт Space Grotesk используется в следующих местах:

- Адреса кошельков Solana
- Заголовки секций с Solana акцентом
- Технические элементы интерфейса

Пример использования:

```dart
Text(
  '8xK...3m2P',
  style: AppTextStyles.walletAddress, // Использует Space Grotesk
)
```

## Лицензия

Space Grotesk распространяется под лицензией SIL Open Font License 1.1.
Пожалуйста, ознакомьтесь с лицензией на официальном сайте.
