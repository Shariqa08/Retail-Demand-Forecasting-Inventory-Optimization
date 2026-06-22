import re

with open('c:/My projects/Retail Demand Forecasting & Inventory Optimization/dashboard/app.py', 'rb') as f:
    raw = f.read()

try:
    text = raw.decode('utf-8')
except Exception:
    text = raw.decode('latin1')

# Remove the syntax error line starting with @{os.getenv
lines = text.split('\n')
lines = [l for l in lines if not l.startswith('@{os.getenv')]
text = '\n'.join(lines)

# Remove all emojis and corrupted strings
text = text.replace('â”€', '-')
text = text.replace('ðŸ›’', '')
text = text.replace('ðŸ“Š', '')
text = text.replace('ðŸ“ˆ', '')
text = text.replace('ðŸ”®', '')
text = text.replace('ðŸ“¦', '')
text = text.replace('âš ï¸', '')
text = text.replace('ðŸ †', '')
text = text.replace('Â·', '-')
text = text.replace('â• ', '-')
text = text.replace('ðŸ ª', '')
text = text.replace('ðŸ—“ï¸ ', '')
text = text.replace('ðŸŽ‰', '')
text = text.replace('ðŸš¨', '')
text = text.replace('ðŸ”„', '')
text = text.replace('ðŸ”´', '')
text = text.replace('ðŸŸ¡', '')
text = text.replace('ðŸŸ¢', '')
text = text.replace('âœ…', '')

# Also remove the actual emojis in case they are parsed as utf-8
text = text.replace('🛒', '')
text = text.replace('📊', '')
text = text.replace('📈', '')
text = text.replace('🔮', '')
text = text.replace('📦', '')
text = text.replace('⚠️', '')
text = text.replace('🏆', '')
text = text.replace('🏪', '')
text = text.replace('📅', '')
text = text.replace('🗓️', '')
text = text.replace('🎉', '')
text = text.replace('🚨', '')
text = text.replace('🔄', '')
text = text.replace('🔴', '')
text = text.replace('🟡', '')
text = text.replace('🟢', '')
text = text.replace('✅', '')
text = text.replace('·', '-')
text = text.replace('═', '-')
text = text.replace('─', '-')

with open('c:/My projects/Retail Demand Forecasting & Inventory Optimization/dashboard/app.py', 'w', encoding='utf-8') as f:
    f.write(text)

print('Cleaned dashboard/app.py')
