import urllib.request
import json

def test_inference(url, model, max_tokens):
    print(f"Testing URL: {url} with model: {model} and max_tokens: {max_tokens}")
    data = {
        "model": model,
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
            "Authorization": "Bearer ***REMOVED***"
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
                    
                    print(f"\n[Response Preview]: {content[:100]}... [length: {len(content)}]")
                    print(f"[Finish Reason]: {finish_reason}")
                    print(f"[Usage]: {json.dumps(usage)}")
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

# Test 1: User's exact prompt parameters (to show why it might fail due to HTML or model mismatch)
test_inference("https://my-freellmapi-server.onrender.com/v1/chat/completions", "auto", 250)

# Test 2: 800 Tokens verification
test_inference("https://my-freellmapi-server.onrender.com/v1/chat/completions", "auto", 800)

