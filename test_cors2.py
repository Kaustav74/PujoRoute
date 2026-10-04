import urllib.request

req = urllib.request.Request(
    "https://api.allorigins.win/raw?url=https://my-freellmapi-server.onrender.com/v1/models",
    headers={"Origin": "http://localhost:8080"}
)
try:
    with urllib.request.urlopen(req) as response:
        print(response.getcode())
except Exception as e:
    print(e)
