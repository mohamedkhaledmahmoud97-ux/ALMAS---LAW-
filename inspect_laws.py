import json
import os

# المسار الدقيق للملف بناءً على الصورة
file_path = os.path.join("docs", "data", "Egyptian_legal_laws.json")

if not os.path.exists(file_path):
    print(f"خطأ: لم يتم العثور على ملف القوانين في المسار: {file_path}")
else:
    print(f"تم العثور على الملف بنجاح! جاري فحص هيكل البيانات... يرجى الانتظار.")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            print("\n=== نتائج الفحص الهندسي ===")
            if isinstance(data, list):
                print(f"نوع البيانات الرئيسي: قائمة (List)")
                print(f"إجمالي عدد السجلات/القوانين في الملف: {len(data)}")
                if len(data) > 0:
                    print("\nمفاتيح السجل الأول (البنية الداخلية):")
                    for key in data[0].keys():
                        print(f"- {key}")
            elif isinstance(data, dict):
                print(f"نوع البيانات الرئيسي: قاموس (Dictionary)")
                print("المفاتيح الرئيسية المتاحة في الملف:")
                for key in data.keys():
                    print(f"- {key}")
    except Exception as e:
        print(f"حدث خطأ أثناء القراءة: {e}")