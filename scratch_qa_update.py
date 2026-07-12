import os

file_path = r"C:\Users\yashd\.gemini\antigravity-ide\brain\8839584e-5e20-46ca-a86e-ecbf1bbd3e21\artifacts\qa_report_p1.md"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("- `[ ]`", "- `[x]`")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
