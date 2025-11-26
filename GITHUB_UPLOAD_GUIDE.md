# 🚀 دليل رفع المشروع إلى GitHub

## الخطوات الأساسية

### ✅ الخطوة 1: تثبيت Git

1. اذهب إلى: https://git-scm.com/download/win
2. حمّل وثبّت Git
3. أعد تشغيل PowerShell بعد التثبيت

### ✅ الخطوة 2: إنشاء Repository على GitHub

1. اذهب إلى: https://github.com/new
2. املأ البيانات:
   - **Repository name**: `glowmatch-skincare` (أو اسم يفضله)
   - **Description**: "GlowMatch - AI Skincare Analysis App"
   - **Public** (علني) أو **Private** (خاص)
   - ✅ تأكد من **عدم** تحديد "Initialize this repository with:"
3. اضغط **Create repository**

### ✅ الخطوة 3: تكوين Git محلياً

افتح PowerShell أو Command Prompt وشغّل:

```powershell
cd "d:\disk part 1\aicha projects\MVP\skin care V2 beta"

# تكوين بيانات Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# تهيئة repository
git init

# إضافة جميع الملفات
git add .

# إنشاء أول commit
git commit -m "Initial commit: GlowMatch AI Skincare Analysis App"

# إضافة remote repository
git remote add origin https://github.com/YOUR_USERNAME/glowmatch-skincare.git

# رفع المشروع
git branch -M main
git push -u origin main
```

---

## ⚠️ ملفات يجب تجاهلها

الملف `.gitignore` موجود بالفعل ويحتوي على:
```
node_modules/
.env
build/
dist/
```

تأكد من أن ملفات التالية **لا تُرفع**:
- ✅ `node_modules/` - حزم npm
- ✅ `.env` - مفاتيح سرية
- ✅ `backend/data.db` - قاعدة البيانات المحلية

---

## 📋 تعديلات سريعة قبل الرفع

### تحديث README.md

```markdown
# 🌟 GlowMatch - AI Skincare Analysis

AI-powered skincare analysis and personalized beauty recommendations.

## ⚡ الميزات

- 🎯 Quiz تحليل البشرة الذكي
- 📸 تحليل الصور بـ AI
- 📊 تاريخ المحاولات والنتائج
- 💬 نظام الإخطارات
- 🎁 نظام الإحالات
- 📝 مدونة متكاملة مع رفع الصور

## 🛠️ التقنيات

- **Frontend**: React + Vite + Tailwind CSS
- **Backend**: Node.js + Express + SQLite
- **Authentication**: JWT
- **AI**: Integration ready

## 🚀 البدء السريع

\`\`\`bash
# تثبيت الحزم
npm install

# تشغيل الـ Development
npm run dev

# بناء الإنتاج
npm run build
\`\`\`

## 📁 البنية

\`\`\`
├── src/              # React Components
├── backend/          # Express Server
├── public/           # Static Files
└── supabase/         # Database Migrations
\`\`\`

## 📄 الترخيص

MIT License
```

---

## 🔐 حماية البيانات الحساسة

تأكد من أن ملف `.env` **لا يُرفع** ويحتوي على:

```env
# .env (محلي فقط)
VITE_BACKEND_URL=http://localhost:4000/api
GLOWMATCH_JWT_SECRET=your_secret_key_here
GLOWMATCH_ADMIN_EMAIL=admin@glowmatch.com
GLOWMATCH_ADMIN_PASSWORD=your_password_here
```

---

## 🔄 التحديثات اللاحقة

بعد الرفع الأولي، أي تغييرات جديدة:

```powershell
# في المشروع
cd "d:\disk part 1\aicha projects\MVP\skin care V2 beta"

# الخطوة 1: إضافة التغييرات
git add .

# الخطوة 2: إنشاء commit
git commit -m "وصف التغييرات هنا"

# الخطوة 3: دفع التحديثات
git push origin main
```

---

## 📞 الدعم والمساعدة

### مشاكل شائعة:

**المشكلة**: `fatal: not a git repository`
- **الحل**: تأكد من أنك في المجلد الصحيح وشغّل `git init`

**المشكلة**: `permission denied` عند الدفع
- **الحل**: استخدم SSH key أو Personal Access Token

**المشكلة**: خطأ في `.env`
- **الحل**: تأكد من وجود `.env` في `.gitignore`

---

## ✅ القائمة النهائية قبل الرفع

- [ ] Git مثبت ومكون
- [ ] Repository أنشئ على GitHub
- [ ] `.env` موجود في `.gitignore`
- [ ] `node_modules/` موجود في `.gitignore`
- [ ] README.md محدث
- [ ] أول commit جاهز
- [ ] Remote URL صحيح

---

**تم التحديث**: 27 نوفمبر 2025 ✨
