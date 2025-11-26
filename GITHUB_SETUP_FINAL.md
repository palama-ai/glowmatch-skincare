# 📤 تعليمات الرفع إلى GitHub - خطوة بخطوة

## ✅ قائمة المتطلبات

- [x] `.gitignore` محدث ✓
- [x] `.gitattributes` جاهز ✓
- [x] README.md محدث ✓
- [x] LICENSE موجود ✓
- [x] CONTRIBUTING.md جاهز ✓
- [ ] Git مثبت على الجهاز
- [ ] حساب GitHub نشط
- [ ] Repository أنشئ على GitHub

---

## 📥 تثبيت Git

### على Windows:

1. اذهب إلى: https://git-scm.com/download/win
2. حمّل الإصدار الأخير
3. شغّل ملف التثبيت (.exe)
4. اتبع التعليمات (اختر الخيارات الافتراضية)
5. أعد تشغيل PowerShell بعد التثبيت

**التحقق من التثبيت:**
```powershell
git --version
```

---

## 🆔 تكوين Git محلياً

شغّل هذه الأوامر **مرة واحدة فقط**:

```powershell
git config --global user.name "Your Full Name"
git config --global user.email "your.email@gmail.com"
git config --global core.autocrlf true
```

**التحقق:**
```powershell
git config --global --list
```

---

## 🔑 إعداد GitHub SSH (اختياري لكن موصى به)

```powershell
# توليد مفتاح SSH
ssh-keygen -t ed25519 -C "your.email@gmail.com"

# اضغط Enter 3 مرات (استخدم كلمة مرور فارغة)
```

ثم:
1. اذهب إلى: https://github.com/settings/keys
2. انقر "New SSH key"
3. اسمه: "My Computer"
4. والصق المفتاح من: `C:\Users\YourUsername\.ssh\id_ed25519.pub`

---

## 📝 إنشاء Repository على GitHub

1. اذهب إلى: https://github.com/new
2. **Repository name**: `glowmatch-skincare`
3. **Description**: `AI-powered skincare analysis platform`
4. اختر **Public** (علني)
5. ❌ **لا تحدد** "Initialize this repository"
6. انقر **Create repository**

---

## 🚀 الخطوات النهائية للرفع

افتح PowerShell واذهب للمجلد:

```powershell
cd "d:\disk part 1\aicha projects\MVP\skin care V2 beta"
```

### الأمر الكامل (نسخ والصق):

```powershell
# تهيئة git
git init

# إضافة جميع الملفات
git add .

# إنشاء أول commit
git commit -m "Initial commit: GlowMatch AI Skincare Analysis App

- Interactive skincare quiz
- Image analysis capabilities
- Admin dashboard
- Blog management with image uploads
- User notifications and referral system
- SQLite database with JWT authentication"

# إضافة remote repository
git remote add origin https://github.com/YOUR_USERNAME/glowmatch-skincare.git

# إعادة تسمية branch الرئيسي
git branch -M main

# رفع المشروع
git push -u origin main
```

### ⚠️ أهم نقطة:

استبدل `YOUR_USERNAME` باسم المستخدم الفعلي لديك على GitHub!

مثال:
```powershell
git remote add origin https://github.com/ali123/glowmatch-skincare.git
```

---

## ✅ التحقق من النجاح

بعد الأمر الأخير:

1. اذهب إلى: https://github.com/YOUR_USERNAME/glowmatch-skincare
2. يجب أن ترى:
   - ✅ جميع الملفات والمجلدات
   - ✅ README محدث
   - ✅ تاريخ آخر commit
   - ✅ `node_modules` و `.env` **غير موجودة**

---

## 🔄 التحديثات المستقبلية

بعد الرفع الأولي، أي تغييرات جديدة:

```powershell
cd "d:\disk part 1\aicha projects\MVP\skin care V2 beta"

# عرض الملفات المعدلة
git status

# إضافة التغييرات
git add .

# إنشاء commit
git commit -m "وصف التغيير بالعربية أو الإنجليزية"

# دفع التحديثات
git push origin main
```

---

## 🆘 حل المشاكل الشائعة

### ❌ خطأ: `fatal: not a git repository`
**الحل:** تأكد من أنك في المجلد الصحيح
```powershell
cd "d:\disk part 1\aicha projects\MVP\skin care V2 beta"
git init
```

### ❌ خطأ: `permission denied`
**الحل:** استخدم SSH key بدلاً من HTTP
```powershell
git remote remove origin
git remote add origin git@github.com:YOUR_USERNAME/glowmatch-skincare.git
git push -u origin main
```

### ❌ خطأ: `nothing added to commit`
**الحل:** تأكد من وجود ملفات لم تُضف:
```powershell
git status  # عرض الملفات
git add .   # إضافة الكل
```

### ❌ خطأ: `.env` أو `node_modules` مرفوعة
**الحل:** احذفها من GitHub:
```powershell
git rm -r --cached .env node_modules
git commit -m "Remove sensitive files"
git push origin main
```

---

## 📊 إحصائيات المشروع

بعد الرفع، يمكنك رؤية:

- **Insights** → عرض النشاط والمساهمات
- **Settings** → إدارة Repository
- **Actions** → CI/CD (للمستقبل)
- **Issues** → تتبع المشاكل
- **Pull Requests** → طلبات الدمج

---

## 🎯 خطوات إضافية موصى بها

### 1. إضافة GitHub Actions (CI/CD)
أنشئ: `.github/workflows/test.yml`

### 2. إضافة Code of Conduct
ملف: `CODE_OF_CONDUCT.md`

### 3. إضافة Security Policy
ملف: `SECURITY.md`

### 4. تفعيل GitHub Pages (للتوثيق)
في Settings → Pages

### 5. إضافة Badges
في README:
```markdown
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
```

---

## 🎉 تم!

مبروك! 🎊 مشروعك الآن على GitHub!

### الخطوة التالية:

1. شارك الرابط: `https://github.com/YOUR_USERNAME/glowmatch-skincare`
2. أضفه إلى بيانات الملف الشخصي
3. ادعُ الآخرين للمساهمة
4. استمر في التطوير! 🚀

---

**آخر تحديث:** 27 نوفمبر 2025

لأي أسئلة، راجع:
- GitHub Help: https://help.github.com
- Git Documentation: https://git-scm.com/doc
