import os
import re
import yaml

lib_dir = r'c:\Projects\famcare_app\lib'
pubspec_path = r'c:\Projects\famcare_app\pubspec.yaml'
output_path = r'C:\Users\yashd\.gemini\antigravity-ide\brain\a90b1459-1379-473e-96c8-fa741ced2841\reconnaissance_report_full.md'

def get_all_dart_files():
    dart_files = []
    for root, _, files in os.walk(lib_dir):
        for f in files:
            if f.endswith('.dart'):
                dart_files.append(os.path.join(root, f))
    return dart_files

dart_files = get_all_dart_files()

# PART A
part_a_lines = ["| File Path | Line Count | Purpose | Status |", "|---|---|---|---|"]
dead_files = [
    'family_hub_screen.dart', 'vault_screen.dart', 'family_alert_rule.dart',
    'family_task_comment.dart', 'medical_profile_provider.dart',
    'health_overview_provider.dart', 'health_dashboard_screen.dart',
    'prescription_screen.dart', 'slot_validation.dart'
]

for fp in dart_files:
    basename = os.path.basename(fp)
    with open(fp, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    line_count = len(lines)
    
    purpose = 'Utility/Model'
    for line in lines:
        if 'class ' in line:
            match = re.search(r'class\s+([a-zA-Z0-9_]+)', line)
            if match:
                purpose = f'Defines {match.group(1)}'
                break
    
    status = 'ACTIVE'
    if basename in dead_files:
        status = 'DEAD'
        if basename == 'vault_screen.dart':
            status = 'DUPLICATE'
        if basename == 'family_hub_screen.dart':
            status = 'DUPLICATE'
            
    rel_path = os.path.relpath(fp, lib_dir).replace(chr(92), '/')
    part_a_lines.append(f"| {rel_path} | {line_count} | {purpose} | {status} |")

part_a_md = '\n'.join(part_a_lines)

# PART B
with open(pubspec_path, 'r', encoding='utf-8') as f:
    pubspec = yaml.safe_load(f)

deps = pubspec.get('dependencies', {})
part_b_lines = ["| Package | Version | Purpose | Used? | Usage Files |", "|---|---|---|---|---|"]
for dep, version in deps.items():
    if dep in ['flutter', 'cupertino_icons', 'flutter_lints']: continue
    
    used_in = []
    for fp in dart_files:
        with open(fp, 'r', encoding='utf-8') as f:
            content = f.read()
            if f"package:{dep}/" in content or f"package:{dep}.dart" in content:
                rel = os.path.relpath(fp, lib_dir).replace(chr(92), '/')
                used_in.append(rel)
    
    status = 'YES' if used_in else 'NO (DEAD DEPENDENCY)'
    used_str = ', '.join(used_in[:5]) + ('...' if len(used_in)>5 else '')
    if not used_in: used_str = 'None'
    part_b_lines.append(f"| {dep} | {version} | Package | {status} | {used_str} |")

part_b_md = '\n'.join(part_b_lines)

# PART F
tables = {}
rpcs = set()
for fp in dart_files:
    with open(fp, 'r', encoding='utf-8') as f:
        content = f.read()
    rpc_matches = re.findall(r"\.rpc\(\s*'([^']+)'", content)
    for rpc in rpc_matches: rpcs.add(rpc)
    from_matches = re.findall(r"\.from\(\s*'([^']+)'", content)
    for table in from_matches:
        if table not in tables: tables[table] = set()
        tables[table].add(os.path.basename(fp))

part_f_lines = ["| Table Name | Referenced In |", "|---|---|"]
for t, fps in tables.items():
    part_f_lines.append(f"| {t} | {', '.join(fps)} |")
part_f_md = '\n'.join(part_f_lines)
part_f_md += "\n\n**RPCs called in code:**\n" + '\n'.join(f"- {r}" for r in rpcs)

# PART G
g_set_state = []
g_exists = []
g_select = []
g_limit = []
g_future_list = []

for fp in dart_files:
    basename = os.path.basename(fp)
    with open(fp, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    for i, line in enumerate(lines):
        line_num = i + 1
        if 'setState(' in line:
            g_set_state.append(f"- `{basename}:{line_num}`: {line.strip()}")
        if '.existsSync()' in line:
            g_exists.append(f"- `{basename}:{line_num}`: {line.strip()}")
        if '.select()' in line or ".select('*')" in line or '.select(\"*\")' in line:
            g_select.append(f"- `{basename}:{line_num}`: {line.strip()}")
        
    content = "".join(lines)
    if 'FutureBuilder' in content and ('ListView' in content or 'GridView' in content):
        g_future_list.append(f"- `{basename}` contains FutureBuilder inside a list/grid structure")

part_g_md = "**1. setState() calls:**\n" + '\n'.join(g_set_state) + \
            "\n\n**2. File().existsSync() in build:**\n" + '\n'.join(g_exists) + \
            "\n\n**3. Supabase SELECT * (no specific columns):**\n" + '\n'.join(g_select) + \
            "\n\n**5. FutureBuilder inside ListView/GridView:**\n" + '\n'.join(g_future_list)

with open(output_path, 'w', encoding='utf-8') as f:
    f.write(f"""# FamCare Project Reconnaissance Report - Exhaustive Version

## PART A — PROJECT STRUCTURE MAP
{part_a_md}

## PART B — PACKAGES AUDIT
{part_b_md}

## PART F — SUPABASE SCHEMA vs CODE MISMATCH
{part_f_md}

## PART G — PERFORMANCE BOTTLENECKS
{part_g_md}
""")
