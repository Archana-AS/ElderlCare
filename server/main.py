import firebase_admin
from firebase_admin import credentials
from firebase_admin import db


"""
uvicorn server:app --reload


cloudflared tunnel --url http://localhost:8000  


python main.py (after updating url)

"""
URL_TO_SAVE = 'https://concentration-competition-electron-immediately.trycloudflare.com' # NOTE: HERE UPDATE



# --- 1. CONFIGURATION (Replace these) ---
SERVICE_ACCOUNT_FILE = 'serviceAccountKey.json' 
DATABASE_URL = 'https://urlstore-cfd61-default-rtdb.firebaseio.com/' 
DB_PATH = '/latest_url' 
# ----------------------------------------

try:
    cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
    firebase_admin.initialize_app(cred, {
        'databaseURL': DATABASE_URL
    })
except ValueError:
    print("Firebase app already initialized.")
ref = db.reference(DB_PATH)
try:
    ref.set(URL_TO_SAVE)
    print(f"✅ Successfully uploaded URL to Firebase at {DB_PATH}: {URL_TO_SAVE}")
except Exception as e:
    print(f"❌ Error uploading URL: {e}")
