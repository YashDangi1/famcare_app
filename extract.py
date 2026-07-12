import os
import re

lib_dir = r'c:\Projects\famcare_app\lib'
dart_files = []
for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            dart_files.append(os.path.join(root, f))

tables = {}
rpcs = set()

for fp in dart_files:
    with open(fp, 'r', encoding='utf-8') as f:
        content = f.read()
    
    rpc_matches = re.findall(r"\.rpc\(\s*'([^']+)'", content)
    for rpc in rpc_matches:
        rpcs.add(rpc)
        
    from_matches = re.findall(r"\.from\(\s*'([^']+)'", content)
    for table in from_matches:
        if table not in tables:
            tables[table] = {'written': set(), 'read': set()}

print('RPCs called in code:', rpcs)
print('Tables referenced in code:', list(tables.keys()))
