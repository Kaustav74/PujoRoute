import os
import urllib.request
req = urllib.request.Request(
    "https://my-freellmapi-server.onrender.com/v1/models",
    headers={"Origin": "http://localhost:8080", "Authorization": f"Bearer {os.environ.get('FREELLMAPI_API_KEY', '')}"}
)
try:
    with urllib.request.urlopen(req) as response:
        print("Status", response.getcode())
        print("CORS Origin", response.getheader("Access-Control-Allow-Origin"))
except Exception as e:
    print(e)
