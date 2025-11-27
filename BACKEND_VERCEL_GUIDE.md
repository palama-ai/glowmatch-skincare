# 🚀 نشر Backend على Vercel

## ✅ الخطوات السريعة

### الخطوة 1: إنشاء Repository للـ Backend

يمكنك اختيار أحد الخيارين:

**الخيار A:** Repository منفصل (الأفضل)
```bash
cd backend
git init
git add .
git commit -m "Initial backend commit"
git remote add origin https://github.com/YOUR_USERNAME/glowmatch-backend.git
git push -u origin main
```

**الخيار B:** نفس Repository مع Monorepo
- البقاء في repository الحالي
- Vercel سيكتشف `backend/vercel.json`

---

### الخطوة 2: ربط Vercel بـ GitHub

#### للخيار A (Repository منفصل):

1. اذهب إلى: https://vercel.com/import
2. اختر: **GitHub**
3. ادخل بيانات اعتمادك
4. ابحث عن: `glowmatch-backend`
5. اختره وانقر **Import**

#### للخيار B (Monorepo):

1. اذهب إلى: https://vercel.com/dashboard
2. انقر **Add New Project**
3. اختر: `glowmatch-skincare`
4. في **Root Directory**: اختر `./backend`
5. اضغط **Deploy**

---

### الخطوة 3: إضافة Environment Variables

في Vercel Dashboard:

1. انقر على Project
2. اذهب إلى **Settings**
3. انقر **Environment Variables**
4. أضف التالي:

```
GLOWMATCH_JWT_SECRET = your_secret_key_here_min_32_chars
GLOWMATCH_ADMIN_EMAIL = admin@glowmatch.com
GLOWMATCH_ADMIN_PASSWORD = Adm1n!Glow2025#
GLOWMATCH_DB_PATH = /tmp/data.db
```

5. اضغط **Save**
6. انقر **Redeploy**

---

### الخطوة 4: اختبار الـ Backend

بعد النشر بنجاح:

```bash
# التحقق من الحالة
curl https://glowmatch-api.vercel.app

# يجب أن ترى:
# {"ok":true,"msg":"GlowMatch backend running"}

# اختبار Health Check
curl https://glowmatch-api.vercel.app/health
```

---

## ⚙️ التعديلات المهمة

### 1. تحديث Frontend للـ API URL

في `.env` الرئيسي:

```env
# للتطوير
VITE_BACKEND_URL=http://localhost:4000/api

# للإنتاج (يجب أن يُضبط تلقائياً عند البناء على Vercel)
```

أو في `vite.config.mjs`:

```javascript
export default defineConfig({
  define: {
    'import.meta.env.VITE_BACKEND_URL': JSON.stringify(
      process.env.VITE_BACKEND_URL || 'http://localhost:4000/api'
    )
  }
});
```

### 2. CORS في Backend

تأكد من أن `backend/index.js` يحتوي على:

```javascript
app.use(cors({
  origin: [
    'http://localhost:5173',
    'http://localhost:3000',
    'https://glowmatch.vercel.app',
    'https://*.vercel.app'
  ],
  credentials: true
}));
```

---

## 🔗 الروابط بعد النشر

- **API Base**: `https://glowmatch-api.vercel.app/api`
- **Health Check**: `https://glowmatch-api.vercel.app/health`
- **Routes**: `https://glowmatch-api.vercel.app/api/__routes`

---

## ⚠️ ملاحظات مهمة

### مشكلة: قاعدة البيانات

Vercel يحذف الملفات المؤقتة (`/tmp`) بعد كل deployment. **الحل:**

**الخيار 1:** استخدام قاعدة بيانات سحابية (موصى به)

```bash
# MongoDB Atlas (مجاني)
npm install mongodb

# PlanetScale (MySQL)
npm install mysql2

# Supabase (PostgreSQL)
npm install @supabase/supabase-js
```

**الخيار 2:** استخدام Vercel Postgres

1. في Vercel Dashboard
2. اذهب إلى **Storage**
3. انقر **Create**
4. اختر **Postgres**
5. اتبع التعليمات

---

## 📝 معالجة قاعدة البيانات

### للتطوير: استخدم SQLite
```bash
cd backend
npm run dev
```

### للإنتاج: استخدم قاعدة بيانات خارجية

**مثال مع MongoDB:**

```javascript
const { MongoClient } = require('mongodb');

const mongoClient = new MongoClient(process.env.MONGODB_URI);

async function init() {
  await mongoClient.connect();
  const db = mongoClient.db('glowmatch');
  return db;
}
```

---

## 🔧 استكشاف الأخطاء

### الخطأ: `Build failed`

```bash
# اختبر محلياً أولاً
cd backend
npm install
npm start

# يجب أن يعمل على http://localhost:4000
```

### الخطأ: `Cannot find module`

```bash
# في Vercel Logs، ابحث عن الرسالة
# الحل: تأكد من:
1. الحزم مثبتة في package.json
2. لا توجد import أخطاء
3. أعد النشر (Redeploy)
```

### الخطأ: `CORS error`

```bash
# تأكد من أن:
1. Backend يملك CORS مفعّل
2. Frontend يستخدم الـ URL الصحيح
3. تحديث Deployment بعد التغيير
```

---

## ✅ قائمة التحقق النهائية

- [x] `backend/vercel.json` موجود ومُحدّث
- [x] `backend/.gitignore` موجود
- [ ] Backend مرفوع على GitHub
- [ ] Vercel متصل مع GitHub
- [ ] Environment variables أُضيفت في Vercel
- [ ] Backend deployed بنجاح
- [ ] API accessible من الإنترنت
- [ ] Frontend متصل بـ API الصحيح

---

## 🚀 الخطوة التالية

بعد نجاح Backend:

1. **تحديث Frontend Environment URL**
2. **Redeploy Frontend على Vercel**
3. **اختبار التطبيق كاملاً**

---

**آخر تحديث:** 27 نوفمبر 2025 ✨

للمساعدة: راجع `VERCEL_DEPLOYMENT_GUIDE.md`
