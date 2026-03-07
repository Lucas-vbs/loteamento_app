import csv
import os

# Paths
lotes_csv = 'assets/data/lotes.csv'
lotes_cart_csv = 'assets/data/lotes_cart.csv'
output_csv = 'assets/data/lotes_merged.csv'

def migrate():
    # 1. Load correct coordinates from lotes.csv
    # We use matricula as the primary key for matching
    coords_map = {}
    if os.path.exists(lotes_csv):
        with open(lotes_csv, mode='r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                # Store coordinates using matricula as key
                m = row.get('matricula', '').strip()
                if m:
                    coords_map[m] = {
                        'x': row.get('x', '').strip(),
                        'y': row.get('y', '').strip()
                    }
        print(f"Loaded {len(coords_map)} coordinate pairs from {lotes_csv}")

    # 2. Process lotes_cart.csv and update coordinates
    if not os.path.exists(lotes_cart_csv):
        print(f"Error: {lotes_cart_csv} not found.")
        return

    updated_rows = []
    fieldnames = []
    with open(lotes_cart_csv, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            m = row.get('matricula', '').strip()
            if m in coords_map:
                row['x'] = coords_map[m]['x']
                row['y'] = coords_map[m]['y']
            updated_rows.append(row)

    # 3. Write merged data
    with open(output_csv, mode='w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(updated_rows)

    print(f"Merged data saved to {output_csv}")

    # 4. Swap files
    # Backup original lotes.csv just in case
    # os.replace(lotes_csv, lotes_csv + '.bak')
    os.replace(output_csv, lotes_csv)
    print(f"Successfully replaced {lotes_csv} with merged data.")

if __name__ == "__main__":
    migrate()
