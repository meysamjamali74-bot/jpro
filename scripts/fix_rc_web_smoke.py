from pathlib import Path
p=Path('.github/workflows/rc-enterprise-gate.yml')
s=p.read_text(encoding='utf-8')
old="""          curl -fsS http://127.0.0.1:8080/ >/tmp/home.html
          grep -q 'ترازپاد' /tmp/home.html
          grep -q 'phase15-ui.js' /tmp/home.html
          grep -q 'phase16-ui.js' /tmp/home.html
          grep -q 'phase17-ui.js' /tmp/home.html
"""
new="""          curl -fsS http://127.0.0.1:8080/ >/tmp/home.html
          curl -fsS http://127.0.0.1:8080/fa-overlay.js >/tmp/fa-overlay.js
          grep -q 'ترازپاد' /tmp/home.html
          grep -q 'fa-overlay.js' /tmp/home.html
          grep -q 'phase15-ui.js' /tmp/fa-overlay.js
          grep -q 'phase16-ui.js' /tmp/fa-overlay.js
          grep -q 'phase17-ui.js' /tmp/fa-overlay.js
"""
if old not in s:
    raise SystemExit('RC web smoke block not found; inspect workflow before changing it')
p.write_text(s.replace(old,new,1),encoding='utf-8')
print('RC web smoke corrected')
