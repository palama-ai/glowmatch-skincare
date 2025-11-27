# 🔥 رفع Backend على Vercel - خطوات سريعة

## 3️⃣ خطوات فقط

### 1️⃣ دفع Backend إلى GitHub

```powershell
cd backend
& "C:\Program Files\Git\bin\git.exe" add .
& "C:\Program Files\Git\bin\git.exe" commit -m "Backend ready for Vercel"
& "C:\Program Files\Git\bin\git.exe" push origin main
```

### 2️⃣ ربط مع Vercel

**اختر واحد من الخيارين:**

**الخيار A:** استخدام نفس Project (الأسهل)
1. اذهب: https://vercel.com/dashboard
2. اختر `glowmatch-skincare`
3. انقر **Settings** → **Environment Override**
4. اختر: **Backend** في **Root Directory**
5. اضغط **Deploy**

**الخيار B:** Project منفصل (الأفضل)
1. اذهب: https://vercel.com/import
2. اختر `glowmatch-skincare` (أو `glowmatch-backend` إذا أنشأت repository منفصل)
3. في **Root Directory**: اختر `backend`
4. اضغط **Deploy**

### 3️⃣ إضافة البيانات السرية

في Vercel Dashboard:
1. Project → Settings → Environment Variables
2. أضف:
   - `GLOWMATCH_JWT_SECRET` = `your_secret_key`
   - `GLOWMATCH_ADMIN_EMAIL` = `admin@glowmatch.com`
   - `GLOWMATCH_ADMIN_PASSWORD` = `password_here`
3. اضغط **Save & Redeploy**

---

## ✅ الآن Backend يعمل!

- API: `https://glowmatch-api.vercel.app/api`
- Status: `https://glowmatch-api.vercel.app`
- Routes: `https://glowmatch-api.vercel.app/api/__routes`

---

## 📝 تحديث Frontend للـ API الجديد

في `.env`:
```env
VITE_BACKEND_URL=https://glowmatch-api.vercel.app/api
```

ثم:
```bash
git add .env
git commit -m "Update Backend URL for production"
git push origin main
```

---

**تم!** ✨ Frontend و Backend الآن على Vercel!
