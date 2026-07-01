import subprocess
import sys
import os

# 1. Գտնում ենք այն թղթապանակը, որտեղ գտնվում է այս run_pipeline.py ֆայլը
current_folder = os.path.dirname(os.path.abspath(__file__))

def run_script(script_name):
    print(f"\n{'='*40}")
    print(f"🚀 ՍԿՍՎՈՒՄ Է: {script_name}")
    print(f"{'='*40}")
    
    # 2. Ճշգրիտ միացնում ենք թղթապանակի հասցեն և ֆայլի անունը
    script_path = os.path.join(current_folder, script_name)
    
    # Աշխատացնում ենք տրված python ֆայլը
    result = subprocess.run([sys.executable, script_path])
    
    if result.returncode != 0:
        print(f"\n❌ ԽՆԴԻՐ ԱՌԱՋԱՑԱՎ: {script_name}-ը չաշխատեց: Պրոցեսը կանգնեցվում է:")
        sys.exit(1)
        
    print(f"✅ ԱՎԱՐՏՎԵՑ: {script_name}")

if __name__ == "__main__":
    print("🌟 Սկսում ենք տվյալների թարմացման ամբողջական պրոցեսը...")
    
    # Հերթով կանչում ենք մեր ֆայլերը
    run_script("daily_refresh.py")
    run_script("clean_data.py")   #c<-- եթե մաքրման ֆայլն առանձին է, հանիր # նշանը
    run_script("upload_to_db.py")
    
    print("\n🎉 ՇՆՈՐՀԱՎՈՐՈՒՄ ԵՄ: Բոլոր քայլերը հաջողությամբ ավարտվեցին: Բազան թարմ է:")