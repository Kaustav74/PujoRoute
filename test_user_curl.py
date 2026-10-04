import urllib.request
import json

def run_exact_user_curl(max_tokens):
    url = "https://my-freellmapi-server.onrender.com/chat/completions"
    print(f"Testing URL: {url} with max_tokens: {max_tokens}")
    data = {
        "model": "qwen/qwen3.8-27b",
        "messages": [
            {"role": "system", "content": "You are AI Sathi for PujoRoute (Kolkata Durga Puja 2026). Keep transit accurate and include action tags."},
            {"role": "user", "content": "Ami Howrah Maidan theke ashchi on Maha Ashtami morning. How do I reach Sovabazar Rajbari using Metro, what is the exact Sandhi Puja timing according to Belur Math panjika, and can you plan a 6-stop North Kolkata circuit starting from there?"}
        ],
        "max_tokens": max_tokens,
        "temperature": 0.1
    }
    
    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode('utf-8'),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer freellmapi-60361c293a499d1f5786eb8f96d950e842d171c84d32576b"
        }
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            body = response.read().decode('utf-8')
            if response.getheader('Content-Type').startswith('application/json'):
                parsed = json.loads(body)
                if 'choices' in parsed and len(parsed['choices']) > 0:
                    choice = parsed['choices'][0]
                    content = choice.get('message', {}).get('content', '')
                    finish_reason = choice.get('finish_reason', 'unknown')
                    usage = parsed.get('usage', {})
                    
                    print(f"\n[Finish Reason]: {finish_reason}")
                    print(f"[Usage]: {json.dumps(usage)}")
                    print(f"[Content snippet]: {content[:200]}...")
                else:
                    print("JSON response did not contain choices.")
            else:
                print(f"Received non-JSON content. Content-Type: {response.getheader('Content-Type')}")
                print(body[:200])
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode('utf-8')}")
    except Exception as e:
        print(f"Error: {e}")
    print("-" * 50)

run_exact_user_curl(250)
run_exact_user_curl(800)
