import urllib.request
req = urllib.request.Request(
    "https://my-freellmapi-server.onrender.com/v1/models",
    headers={"Origin": "http://localhost:8080"}
)
try:
    with urllib.request.urlopen(req) as response:
        print("Status", response.getcode())
        print("CORS", response.getheader("Access-Control-Allow-Origin"))
except Exception as e:
    print(e)
