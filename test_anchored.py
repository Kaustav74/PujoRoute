import urllib.request
import json

data = {
    "model": "auto",
    "messages": [
        {
            "role": "system", 
            "content": "You are AI Sathi for PujoRoute. Ground Truth: Green Line runs Howrah Maidan -> Howrah -> Mahakaran -> Esplanade. Blue Line goes to Sovabazar Sutanuti via Esplanade interchange. Do not debate names. Output the answer directly."
        },
        {
            "role": "user", 
            "content": "Ami Howrah Maidan theke ashchi on Maha Ashtami morning. How do I reach Sovabazar Rajbari using Metro, what is the exact Sandhi Puja timing according to Belur Math panjika, and can you plan a 6-stop North Kolkata circuit starting from there?"
        }
    ],
    "max_tokens": 1000,
    "temperature": 0.1
}

req = urllib.request.Request(
    "https://my-freellmapi-server.onrender.com/v1/chat/completions",
    data=json.dumps(data).encode("utf-8"),
    headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer freellmapi-60361c293a499d1f5786eb8f96d950e842d171c84d32576b"
    }
)

with urllib.request.urlopen(req) as response:
    result = json.loads(response.read().decode("utf-8"))
    choice = result["choices"][0]
    print(f"Finish Reason: {choice['finish_reason']}")
    print(f"Reasoning Tokens: {result.get('usage', {}).get('completion_tokens_details', {}).get('reasoning_tokens', 0)}")
    print(f"Content: {choice['message']['content'][:500]}")
