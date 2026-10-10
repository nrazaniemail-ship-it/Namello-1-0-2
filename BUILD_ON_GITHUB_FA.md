# ساخت واقعی Namello 1.0.32 و APK در GitHub Actions

این بسته برای ساخت واقعی APK با GitHub Actions آماده شده است.

## پیش‌نیاز

محتویات پوشه `Namello-1.0.32-PWA` باید در **ریشه repository** قرار بگیرد؛ یعنی `.github`، `package.json`، `index.html`، `src` و `tests` مستقیماً در ریشه باشند.

## ساخت APK

1. کل محتویات این پوشه را در repository گیت‌هاب قرار دهید.
2. وارد **Actions** شوید.
3. workflow با نام **Namello Android APK Build** را انتخاب کنید.
4. روی **Run workflow** بزنید.
5. workflow به‌ترتیب Node.js، Java 21 و Android SDK را آماده می‌کند، dependencyها را نصب می‌کند، تست و TypeScript را اجرا می‌کند، Vite را build می‌کند، پروژه Android را با Capacitor ایجاد و sync می‌کند و در نهایت APK را می‌سازد.
6. در اجرای سبز، از بخش **Artifacts** فایل `Namello-1.0.33-Android-APK` را دریافت کنید.

## مشخصات APK

- App name: `Namello`
- Version name: `1.0.33`
- Version code: `34`
- Application ID: `com.namello.app`
- خروجی: `android/app/build/outputs/apk/debug/app-debug.apk`

## نکته

نسخه Backend مستقل است و `backend/package.json` عمداً روی `1.0.26` باقی می‌ماند؛ این موضوع مانع ساخت APK نیست.

همچنین manifestهای PWA نیز با نسخه نمایشی `Namello 1.0.32` یکدست شده‌اند.


## نوع خروجی
این workflow در حال حاضر APK نوع **debug** می‌سازد که برای نصب و آزمایش مناسب است. برای انتشار عمومی در فروشگاه‌ها، باید کلید امضای release را به‌صورت امن در GitHub Secrets تنظیم و workflow انتشار جداگانه‌ای تعریف کنید.


## نکته نسخه‌گذاری
نسخه و کد نسخه APK مستقیماً از `version.json` خوانده می‌شود.
