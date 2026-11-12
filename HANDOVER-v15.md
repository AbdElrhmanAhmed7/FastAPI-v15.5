# تسليم NOVA — إصدار v15

**الريبو:** [`AbdElrhmanAhmed7/FastAPI-v15`](https://github.com/AbdElrhmanAhmed7/FastAPI-v15) · الأساس `5ee0295`
**الحالة:** الباك-إند مقفول ومتحقق منه بالكامل · **مشكلة الـCI اتصلحت** (كانت مش ظاهرة خالص)

> الملف ده **ليك انت**، مش جزء من الريبو. الريبو مستنداته إنجليزي بس وفيه بوابة
> (`test_english_content.py`) بتفحص كل ملف نصي — فأي ملف عربي جوه الريبو بيوقّع البوابة.
> **علشان كده: ارفع محتويات مجلد `Final/` بس، مش مجلد الـworkspace اللي حواليه.**

---

## 1. الخلاصة في سطرين

الكود وصل سليم زي كل مرة. **المشكلة كانت في مكان الملفات**: المشروع اترفع جوّه مجلد
`Final/`، فـGitHub **مشافش الـworkflow أصلاً** — مش فشل، لأ، *مفيش أي حاجة اشتغلت*.
اتصلح، واتولّد حزمة تسليم جديدة، واتجرّبت الطريقين فعلياً المرة دي.

---

## 2. اللي كان بايظ عند الوصول — بالأدلة

| # | الفحص | النتيجة على النسخة المرفوعة |
| --- | --- | --- |
| 1 | `bash tools/check_layout.sh` | ✗ `NOVA/backend is not at the git root` |
| 2 | `sha256sum -c SHA256SUMS.txt` | ✗ `nova-backend-final.zip: FAILED open or read` |
| 3 | `git am releases/nova-backend-final.patch` | ✗ `patch does not apply` |
| 4 | GitHub Actions | ✗ **0 workflows · 0 runs** |

**ليه؟** انت رفعت **مجلد الـworkspace** (اللي جوّاه الريبو)، مش الريبو نفسه. فالشجرة وصلت كده:

```
جذر الريبو/
├── Final/          ← المشروع كله، أعمق بمستوى (230 ملف)
├── .scratch/       ← سكريبتات مؤقتة من الجلسة اللي فاتت
└── HANDOVER.md     ← مذكرة التسليم
```

وملف الـworkflow بقى في `Final/.github/workflows/backend.yml` — وGitHub بيدوّر في
`<جذر الريبو>/.github/workflows` بس.

**المرة دي قِستها على GitHub نفسه، مش استنتاج:**

```
GET /repos/AbdElrhmanAhmed7/FastAPI-v15/actions/workflows → 0
GET /repos/AbdElrhmanAhmed7/FastAPI-v15/actions/runs      → 0
```

وللمقارنة (نفس ملف الـworkflow بالظبط، بس في المكان الصح) على الريبو السابق
`Final-v14.5`: **workflow واحد active + تشغيل ناجح 3/3**. ده يثبت إن الفرق هو
**مكان الملفات**، مش الملف نفسه.

> **دي سادس مرة تحصل** — بس بشكل جديد. المرات اللي فاتت كانت من بادئة `NOVA/` في
> الzip أو مجلد `repo/`. المرة دي من رفع مجلد الـworkspace كله.

---

## 3. اللي اتعمل

1. **إصلاح التخطيط** بـ`tools/restructure_repo.sh` — كل نقل بـ`git mv` فالاريخ بيمشي مع الملفات.
   الحارس بقى يقول `✓ layout ok`.
2. **تنضيف اللي اندس مع الرفع**: `.scratch/` اتشال، والمفيد منه بقى أداة حقيقية
   `tools/verify_delivery.sh`. والمذكرة العربية طلعت بره الريبو (بوابة اللغة).
3. **ضبط هوية git** — دي كانت السبب إن كوميت الجلسة اللي فاتت **فشل** بـ
   `Author identity unknown`، عشان كده حزمة v14.5 **ماتولّدتش أصلاً** ووصلت حزمة v14 القديمة.
4. **توليد الحزمة من جديد** فوق `5ee0295` (الأساس الموجود فعلاً على GitHub).
5. **إثبات إن الحزمة بتشتغل** — مش بس إن الـhashes سليمة (تحت).
6. **تحديث المستندات** لـ`FastAPI-v15` / `5ee0295` + دليل تحقق جديد.

### أداة جديدة: `tools/verify_delivery.sh`

`make_release.sh` بيثبت إن الملفات موجودة، و`sha256sum` بيثبت إنها سليمة —
**ولا واحد بيثبت إنها بتشتغل**. الأداة دي بتجرّب فعلياً على نسخ مؤقتة:

1. الـchecksums مطابقة للملفات الموجودة.
2. `git am` على clone نضيف من الأساس بينتج **نفس الشجرة ملف بملف**، والحارس بينجح بعده.
3. الzip لما يتفك ويترفع **محتوياته** → الحارس يقبله.
4. نفس الzip لما يترفع **كمجلد** → الحارس **يرفضه** (اختبار سلبي — حارس مبيفشلش أبداً مش حارس).

**نتيجة التشغيل الفعلي** (متسجّلة في `releases/delivery-roundtrip.log`):

```
nova-backend-final.patch: OK
nova-backend-final.zip: OK
-- layout as it arrived:   ✗ NOVA/backend is not at the git root
-- layout after the patch: ✓ layout ok
-- source files: patched clone 242 | delivery HEAD 242
-- only in delivery: none · only in clone: none · content mismatches: NONE
-- zip contents → ✓ layout ok      -- zip as folder → ✗ مرفوض
```

وكمان اتأكدت إن الحزمة **نقطة ثابتة**: إعادة توليدها بتطلع **نفس البايتات بالظبط**،
وإعادة تشغيل الفحص بتطلع **نفس اللوج بالظبط** — فمفيش دوّامة hashes بتكسر نفسها.

---

## 4. أرقام التحقق — تشغيل كامل من الصفر على الشجرة بعد الإصلاح

clone جديد + virtualenv جديد · Python 3.11.2 · FastAPI 0.162.5 · SQLAlchemy 2.0.57 · pytest 9.2.0

| البوابة | النتيجة |
| --- | --- |
| `check_layout.sh` | ✓ layout ok |
| `ruff check` + `ruff format` | ✅ All checks passed · 113 files |
| `mypy app scripts` | ✅ no issues in 82 source files |
| `validate_content.py --strict` | ✅ 15 missions / 95 actions · 0 errors |
| `audit_routes.py --check` | ✅ 0 errors · 67 operations · 15 guarded |
| `export_openapi.py --check` | ✅ contract up to date |
| `pytest --cov=app` | ✅ **451 passed** · coverage **94%** |
| `playthrough.py` | ✅ **15/15 missions** · 93 action · **0 mistakes** · readiness **100 (S)** |
| `audit_player_text.py` (in-process) | ✅ 996 response · 473 نص مميز · **67/67** · 0 violations |
| نفسه على socket حقيقي | ✅ 996 response · 476 نص مميز · 67/67 · 0 violations |
| `live_probes.py --no-live` | ✅ 12 probe · 0 failures |
| `live_probes.py` (NASA حقيقي) | ✅ **14 probe · 0 failures** · POWER `live` |
| `preview_smoke.py` | ✅ console 47,278 bytes · 0 external assets · الإصلاح قبل المحبس → **409** · الترتيب الصح بينجح · 27 event |
| `verify_delivery.sh` | ✅ الطريقين متجرّبين + الفخ مرفوض |

الدليل في `verification/2026-11-12-v15/` — كل ملف مخرجات أمر اتنفذ فعلاً.

---

## 5. الملفات الجاهزة للتسليم

جوّه `Final/releases/`:

| الملف | الحجم | SHA-256 |
| --- | --- | --- |
| `nova-backend-final.zip` | 765 KB (783,175 bytes) | `dd932c972636f3c5aaf28c0053495a9694f22a2f0c24925d3b57d733c4883056` |
| `nova-backend-final.patch` | 691 KB (707,786 bytes) | `fb4edca6b27a66b72d9bf83e0dfbc17b9f5830bb8a837b5ab50d43690e8f12e2` |
| `SHA256SUMS.txt` | — | فيه الـhashين اللي فوق |

- **الzip** = لقطة كاملة للشجرة (من غير `.venv` ولا الكاش ولا قاعدة البيانات المحلية).
- **الباتش** = دلتا الجلسة دي فوق `5ee0295`: إصلاح التخطيط + المستندات + الدليل + الأداة الجديدة.
- الzip **مش متخزّن في git** عن قصد (`releases/*.zip` في `.gitignore`) — بيتولّد بالأداة في ثانية.

---

## 6. الرفع على GitHub — الطريقة المضمونة

```bash
git clone https://github.com/AbdElrhmanAhmed7/FastAPI-v15 && cd FastAPI-v15
git am /path/to/nova-backend-final.patch   # بيصلّح التخطيط + المستندات + الدليل
bash tools/check_layout.sh                 # لازم: ✓ layout ok
git push origin main
```

بعد الرفع افتح تبويب **Actions**: لازم يظهر workflow اسمه `backend` ويشتغل (**3 jobs**).
لو التبويب فاضي → GitHub لسه مش شايف الـworkflow، شغّل الحارس.

---

## 7. لو هترفع من واجهة GitHub يدوي — اقرأ ده كويس

فيه **فخين** مش واحد:

1. الzip بيغلّف الشجرة في مجلد `NOVA/`.
2. مجلد الـworkspace بيحتوي على الريبو جوّه `Final/`.

```bash
unzip nova-backend-final.zip -d delivery   # → delivery/NOVA/…
cd delivery/NOVA                           # ← ادخل جوه
ls .github/workflows/backend.yml           # لازم يكون موجود هنا
```

**حدّد كل اللي جوه المجلد (Ctrl+A) وارفع المحتويات** — مش المجلد نفسه، ومش المجلد اللي برّه.

للتأكد بعد أي رفع:

```bash
bash tools/check_layout.sh    # ✓ layout ok
```

---

## 8. إزاي تتأكد بنفسك

```bash
cd releases && sha256sum -c SHA256SUMS.txt && cd ..   # OK للسطرين

bash tools/verify_delivery.sh --base 5ee0295          # الطريقين + الفخ

# لو عايز تولّد الحزمة بنفسك من نفس الشجرة:
bash tools/make_release.sh --base 5ee0295

# كل البوابات:
cd NOVA/backend && make install
cd ../.. && bash tools/verify.sh --live
```

اللقطة **byte-reproducible**: نفس الشجرة = نفس الـhash بالظبط، فـ`sha256sum -c`
بيفضل صالح حتى بعد ما تلتزم بالـhashes.

---

## 9. الكوميتات الجديدة (4 فوق `5ee0295`)

```
78cd32b evidence: record the delivery round trip
b6a0990 release: regenerate the delivery package above 5ee0295
af934fd Verify the v15 delivery and make the package prove itself
40f5878 chore: promote the project to the git root so GitHub can see the workflow
5ee0295 v15   ← الأساسي اللي على GitHub دلوقتي
```

**مهم:** الإصلاح موجود في النسخة اللي عندي هنا — لسه **مش مرفوع على GitHub**.
الريبو على GitHub لسه فيه المجلد الغلاف، فـActions لسه فاضي. لازم ترفع (قسم 6 أو 7).

---

## 10. اللي فاضل في المشروع

**الباك-إند خلص.** الفاضل هو **الفرونت-إند ثلاثي الأبعاد** (React Three Fiber + Rapier)،
وبيبدأ من عقد الـAPI الجاهز في `NOVA/backend/docs/openapi.json` (67 operation موثّق).
الخطة في `PROJECT_STATUS.md` §12.

السيرفر شغال على المنفذ **8000**: افتح `/` لـ**Mission Control** (كونسول بيلعب الـAPI
فعلاً من غير أي build)، و`/docs` لـSwagger UI.