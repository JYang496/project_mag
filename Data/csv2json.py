import csv
import json
import argparse

# Define the argument parser
parser = argparse.ArgumentParser(description="Convert CSV file to JSON file.")
parser.add_argument('input_csv', type=str, help="Input CSV file path")
parser.add_argument('output_json', type=str, help="Output JSON file path")

args = parser.parse_args()

# Function to remove BOM if present
def remove_bom(file):
    first_char = file.read(1)
    if first_char != '\ufeff':
        file.seek(0)  # BOM not present, reset to the beginning of the file
    else:
        print("BOM detected and removed.")

# Read the CSV and convert it to a dictionary with 'uid' as the key
data = {}
with open(args.input_csv, mode='r', encoding='utf-8-sig', newline='') as csv_file:
    remove_bom(csv_file)  # Call the function to check and remove BOM
    csv_reader = csv.DictReader(csv_file)
    for row in csv_reader:
        print(row)
        uid = row.pop('uid')  # Remove 'uid' from row and save it as the key
        if uid:  # Check if uid is not null or empty
            data[uid] = row

# Write the dictionary to a JSON file
with open(args.output_json, mode='w', encoding='utf-8') as json_file:
    json.dump(data, json_file, indent=4)

print(f"CSV data has been successfully converted to JSON and saved to {args.output_json}")
