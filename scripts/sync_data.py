import csv
import json
import os

# Paths relative to project root
csv_file = 'assets/data/lotes.csv'
json_file = 'assets/data/lotes.json'

def sync():
    if not os.path.exists(csv_file):
        print(f"Error: {csv_file} not found.")
        return

    results = []
    try:
        with open(csv_file, mode='r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                if not any(row.values()): continue # Skip empty rows
                
                clean_row = {}
                for k, v in row.items():
                    if k is None: continue
                    clean_row[k.strip().lower()] = v.strip() if v else ""
                
                results.append(clean_row)

        with open(json_file, mode='w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        
        print(f"SYNC SUCCESS: Converted {len(results)} rows from CSV to JSON.")
    except Exception as e:
        print(f"SYNC ERROR: {e}")

if __name__ == "__main__":
    sync()
