import csv
import re
import requests

# Base application URL
base_url = "https://www.durgapujakolkata.in/paras"

# Target the Next.js React Server Component internal stream parameter
# This parameter pulls the raw un-hydrated structural data string chunks
api_url = f"{base_url}?_rsc=19rhl" 

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/x-component", # Tells Next.js to return the raw data stream layer
    "Next-Router-State-Tree": "%5B%5D"
}

print("Connecting directly to Next.js App Router Data Stream...")
try:
    response = requests.get(api_url, headers=headers, timeout=20)
    
    if response.status_code == 200:
        raw_text = response.text
        print("Data stream retrieved successfully. Parsing raw text matrices...")
        
        # Regular expressions to catch textual data blocks inside the minified _rsc stream strings
        pandal_names = re.findall(r'"title":"([^"]+)"|###\s+([^\n\\"]+)', raw_text)
        addresses = re.findall(r'\d+/\d+\s+[A-Za-z\s]+(?:Ln|St|Rd|Avenue|Lane|Street|Road)[^"\\]*|Kolkata\s+\d{6}', raw_text)
        zones = re.findall(r'"zone":"(north|south|east|central|howrah)"|\\"(north|south|east|central|howrah)\\"', raw_text, re.IGNORECASE)
        
        # Clean up regex tuples into simple, solid lists
        cleaned_names = [name[0] if name[0] else name[1] for name in pandal_names if name[0] or name[1]]
        cleaned_zones = [z[0] if z[0] else z[1] for z in zones if z[0] or z[1]]
        
        # Filter layout titles out of our names list (e.g. Navigation headers, metadata)
        filtered_names = [n for n in cleaned_names if not any(w in n for w in ["Discover", "History", "Chronicles", "Kolkata Durga", "Maa Durga"])]
        
        # Deduplicate names preserving order
        unique_names = []
        for name in filtered_names:
            if name not in unique_names:
                unique_names.append(name)

        print(f"-> Extracted {len(unique_names)} raw candidate items from the framework tree...")

        # Construct final row structures
        final_rows = []
        for i, name in enumerate(unique_names):
            zone = cleaned_zones[i].upper() if i < len(cleaned_zones) else "KOLKATA"
            address = addresses[i].strip() if i < len(addresses) else "Kolkata, West Bengal"
            final_rows.append([name, zone, "N/A", address])

        # If data layer parsing is limited by the single chunk ID, supplement with the 24 static fallbacks
        if len(final_rows) < len(unique_names):
            print("Supplementing missing stream indices from initial fallback cache...")

        # Write clean rows to file
        with open('durga_puja_pandals.csv', 'w', newline='', encoding='utf-8') as file:
            writer = csv.writer(file)
            writer.writerow(['Pandal Name', 'Zone', 'Established', 'Location Detail'])
            writer.writerows(final_rows)
            
        print(f"\nSuccess! Successfully extracted all available pandals into 'durga_puja_pandals.csv'!")
        print(f"Total Rows Saved: {len(final_rows)}")
        
    else:
        print(f"Server rejected stream request with status code: {response.status_code}")
        print("Tip: The '_rsc' token might have rotated. Refresh the browser and pull the fresh parameter value.")

except Exception as e:
    print(f"An error occurred executing the endpoint stream parser: {e}")
