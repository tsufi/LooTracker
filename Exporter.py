import re
import csv
import os  # Import os to handle directory operations

def parse_lua_file(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # Use regex to find the LooTrackerDB table
    match = re.search(r'LooTrackerDB\s*=\s*(.*?);', content, re.DOTALL)
    if match:
        lua_data = match.group(1)
        return eval(lua_data)  # Be careful with eval; ensure input is safe
    else:
        raise ValueError("LooTrackerDB not found in the file.")

def extract_roll_data(lua_data):
    roll_data = []
    # Adjust this key based on your actual structure
    for entry in lua_data.get('rolls', []):  
        roll_entry = {
            'item': entry.get('item'),
            'rarity': entry.get('rarity'),
            'rolled_by': entry.get('rolled_by'),
            'roll_value': entry.get('roll_value'),  # Assuming you store roll values
            'timestamp': entry.get('timestamp'),
        }
        roll_data.append(roll_entry)
    return roll_data

def export_to_csv(roll_data, output_file):
    # Ensure the output directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    with open(output_file, 'w', newline='') as csvfile:
        fieldnames = roll_data[0].keys() if roll_data else []
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        writer.writeheader()
        for data in roll_data:
            writer.writerow(data)

if __name__ == "__main__":
    # Adjust the path to where your LooTracker.lua file is located
    lua_file_path = r'client\WTF\Account\<Your account>\SavedVariables\LooTracker.lua'
    output_csv_path = 'output/roll_data.csv'

    lua_data = parse_lua_file(lua_file_path)
    roll_data = extract_roll_data(lua_data)
    export_to_csv(roll_data, output_csv_path)

    print(f"Roll data exported to {output_csv_path}")