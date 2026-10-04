import urllib.request
import json

url = "https://my-freellmapi-server.onrender.com/v1/chat/completions"
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer ***REMOVED***"
}
payload = {
    "model": "auto",
    "messages": [
        {
            "role": "system",
            "content": "You are AI Sathi for PujoRoute (Kolkata Durga Puja 2026). Ground truth: Green Line runs Howrah Maidan -> Howrah -> Mahakaran -> Esplanade. Blue Line northbound to Sovabazar Sutanuti is via Esplanade interchange. Keep replies concise and emit [ACTION:...] tags when asked for circuits."
        },
        {
            "role": "user",
            "content": "How do I reach Sovabazar Rajbari from Howrah Maidan via Metro, and build me a 6-stop North Kolkata circuit starting there?"
        }
    ],
    "max_tokens": 1500,
    "temperature": 0.1
}

req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
try:
    with urllib.request.urlopen(req, timeout=60) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        print("STATUS:", resp.status)
        print("RESPONSE:")
        print(res["choices"][0]["message"]["content"])
except Exception as e:
    print("ERROR:", e)
