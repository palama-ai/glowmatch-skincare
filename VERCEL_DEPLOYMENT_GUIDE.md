# 🚀 نشر GlowMatch على Vercel

## 📋 الخطوات السريعة

### أولاً: تحضير الملفات

#### 1. Frontend (React + Vite)

**إنشاء ملف `vercel.json` في الجذر:**

```json
{
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "env": {
    "VITE_BACKEND_URL": "@backend_url"
  }
}
```

#### 2. Backend (Express)

**إنشاء ملف `vercel.json` في `backend/`:**

```json
{
  "version": 2,
  "builds": [
    {
      "src": "index.js",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "index.js"
    }
  ],
  "env": {
    "GLOWMATCH_JWT_SECRET": "@glowmatch_jwt_secret",
    "GLOWMATCH_ADMIN_EMAIL": "@glowmatch_admin_email",
    "GLOWMATCH_ADMIN_PASSWORD": "@glowmatch_admin_password",
    "GLOWMATCH_DB_PATH": "/tmp/data.db"
  }
}
```

---

## 🔧 تعديلات Backend للإنتاج

### 1. تحديث `backend/index.js`:

```javascript
const express = require('express');
const cors = require('cors');
const { db, init } = require('./db');

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Initialize database
init();

// Routes
const authRoutes = require('./routes/auth');
const adminRoutes = require('./routes/admin');
const blogsRoutes = require('./routes/blogs');
const contactRoutes = require('./routes/contact');
const notificationsRoutes = require('./routes/notifications');
const profileRoutes = require('./routes/profile');
const quizRoutes = require('./routes/quiz');
const referralsRoutes = require('./routes/referrals');
const subscriptionRoutes = require('./routes/subscription');
const analysisRoutes = require('./routes/analysis');
const reportRoutes = require('./routes/report');
const eventsRoutes = require('./routes/events');

app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/blogs', blogsRoutes);
app.use('/api/contact', contactRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/quiz', quizRoutes);
app.use('/api/referrals', referralsRoutes);
app.use('/api/subscription', subscriptionRoutes);
app.use('/api/analysis', analysisRoutes);
app.use('/api/report', reportRoutes);
app.use('/api/events', eventsRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
if (require.main === module) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[backend] Server running on port ${PORT}`);
  });
}

module.exports = app;
```

### 2. تحديث `backend/db.js`:

```javascript
// أضف في بداية الملف بعد require
const os = require('os');

// تغيير قيمة DB_PATH
const DB_PATH = process.env.GLOWMATCH_DB_PATH || path.join(
  process.env.NODE_ENV === 'production' ? '/tmp' : __dirname,
  'data.db'
);

console.log('[backend/db] Using database at:', DB_PATH);

// تأكد من إمكانية الكتابة في المجلد
if (!fs.existsSync(path.dirname(DB_PATH))) {
  fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
}
```

---

## 📝 تحديث `backend/package.json`

```json
{
  "name": "glowmatch-backend",
  "version": "0.1.0",
  "main": "index.js",
  "type": "commonjs",
  "engines": {
    "node": "18.x"
  },
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "bcrypt": "^6.0.0",
    "better-sqlite3": "^12.4.1",
    "cors": "^2.8.5",
    "dotenv": "^17.2.3",
    "express": "^5.1.0",
    "jimp": "^0.16.1",
    "jsonwebtoken": "^9.0.2",
    "uuid": "^13.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.1.10"
  }
}
```

---

## 🌐 نشر على Vercel

### الطريقة 1: Frontend فقط (الأفضل)

#### الخطوة 1: رفع المشروع على GitHub (إذا لم تفعل)

```bash
git push origin main
```

#### الخطوة 2: ربط مع Vercel

1. اذهب إلى: https://vercel.com
2. اضغط **Import Project**
3. اختر Repository من GitHub
4. اختر `glowmatch-skincare`
5. اضغط **Import**

#### الخطوة 3: إعدادات التكوين

**Build Settings:**
- Framework: Vite
- Build Command: `npm run build`
- Output Directory: `dist`
- Install Command: `npm install`

**Environment Variables:**
```
VITE_BACKEND_URL = https://glowmatch-api.vercel.app/api
```

اضغط **Deploy**

---

### الطريقة 2: Backend على Vercel

#### الخطوة 1: Repository جديد للـ Backend

```bash
# أنشئ repository جديد على GitHub يسمى: glowmatch-backend

git init
cd backend
git remote add origin https://github.com/YOUR_USERNAME/glowmatch-backend.git
git add .
git commit -m "Initial backend commit"
git push -u origin main
```

#### الخطوة 2: ربط Backend مع Vercel

1. اذهب إلى: https://vercel.com/import
2. اختر Repository: `glowmatch-backend`
3. تخطّى خطوة Framework
4. اضغط **Deploy**

#### الخطوة 3: إضافة Environment Variables

في Vercel Dashboard:
1. اذهب إلى Project Settings
2. Environment Variables
3. أضف:

```
GLOWMATCH_JWT_SECRET = your_secret_key_here
GLOWMATCH_ADMIN_EMAIL = admin@glowmatch.com
GLOWMATCH_ADMIN_PASSWORD = your_password_here
GLOWMATCH_DB_PATH = /tmp/data.db
```

4. اضغط **Save & Redeploy**

---

## ⚙️ تحديثات إضافية

### 1. تحديث Frontend للـ Production API

**في `src/lib/api.js` أو حيث تستخدم API:**

```javascript
const API_BASE = import.meta.env.VITE_BACKEND_URL || 
  (import.meta.env.PROD ? 'https://glowmatch-api.vercel.app/api' : 'http://localhost:4000/api');

export const fetchAPI = async (endpoint, options = {}) => {
  const response = await fetch(`${API_BASE}${endpoint}`, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    },
    ...options
  });
  
  if (!response.ok) {
    throw new Error(`API Error: ${response.status}`);
  }
  
  return response.json();
};
```

### 2. CORS على Backend

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

## 🔗 الروابط النهائية

بعد النشر:

- **Frontend**: `https://glowmatch.vercel.app`
- **Backend**: `https://glowmatch-api.vercel.app`
- **API Health**: `https://glowmatch-api.vercel.app/api/health`

---

## ⚠️ ملاحظات مهمة

### قاعدة البيانات

- Vercel يحذف الملفات المؤقتة بعد كل deployment
- استخدم قاعدة بيانات خارجية للإنتاج:
  - **MongoDB Atlas** (مجاني)
  - **PlanetScale** (MySQL)
  - **Supabase** (PostgreSQL)

### الحل: استخدام Supabase

```javascript
// استبدل SQLite بـ Supabase
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_KEY
);

// استخدم Supabase بدلاً من SQLite
```

---

## 📊 المراحل

### المرحلة 1: Frontend (سريع)
- ⏱️ 5-10 دقائق
- ✅ Automatic deployments من GitHub

### المرحلة 2: Backend (متوسط)
- ⏱️ 10-15 دقيقة
- ⚠️ يحتاج قاعدة بيانات خارجية

### المرحلة 3: قاعدة بيانات (اختياري)
- ⏱️ 15-20 دقيقة
- ✅ استخدم Supabase

---

## ✅ Checklist قبل النشر

- [ ] جميع الأوامر API تعمل محلياً
- [ ] Environment variables محدثة
- [ ] `.gitignore` يتجاهل `.env`
- [ ] `node_modules` لا يُرفع
- [ ] `vercel.json` موجود في الجذر و backend
- [ ] Frontend يتصل بـ Backend الصحيح
- [ ] CORS مفعّل على Backend

---

**آخر تحديث:** 27 نوفمبر 2025 ✨
