import os
import glob
import json

notebooks = glob.glob('c:/My projects/Retail Demand Forecasting & Inventory Optimization/notebooks/*.ipynb')

replacements = {
    'â”€': '-',
    'ðŸ›’': '',
    'ðŸ“Š': '',
    'ðŸ“ˆ': '',
    'ðŸ”®': '',
    'ðŸ“¦': '',
    'âš ï¸': '',
    'ðŸ †': '',
    'Â·': '-',
    'â• ': '-',
    'ðŸ ª': '',
    'ðŸ—“ï¸ ': '',
    'ðŸŽ‰': '',
    'ðŸš¨': '',
    'ðŸ”„': '',
    'ðŸ”´': '',
    'ðŸŸ¡': '',
    'ðŸŸ¢': '',
    'âœ…': '',
    'ðŸ’¡': '',
    'ðŸ”¬': '',
    'Ã—': 'x',
    'Ïƒ': 'std',
    'âˆš': 'sqrt',
    '”': '"',
    '“': '"',
    '’': "'",
    '—': '-'
}

def clean_value(v):
    if isinstance(v, str):
        for bad, good in replacements.items():
            v = v.replace(bad, good)
        return v
    elif isinstance(v, list):
        return [clean_value(i) for i in v]
    elif isinstance(v, dict):
        return {k: clean_value(val) for k, val in v.items()}
    return v

for nb_file in notebooks:
    try:
        with open(nb_file, 'r', encoding='utf-8-sig') as f:
            data = json.load(f)
        
        # We also want to fix the raw file content in case the corruption was outside strings?
        # No, JSON parsing already handles that. The problem was emojis inside text or source.
        
        cleaned_data = clean_value(data)
        
        with open(nb_file, 'w', encoding='utf-8') as f:
            json.dump(cleaned_data, f, indent=1)
            
        print(f'Cleaned {os.path.basename(nb_file)}')
    except Exception as e:
        print(f'Error processing {os.path.basename(nb_file)}: {e}')
