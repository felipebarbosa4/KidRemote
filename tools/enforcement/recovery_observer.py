"""Parse only technical binding metadata; callers must not retain raw OS dumps."""
import re


def binding(bound_section, component_dump, app):
    pid = re.search(r'app=ProcessRecord\{[^}]* ([0-9]+):' + re.escape(app) + r'/', component_dump)
    label = 'Service[label=KidRemote Child Local,' in bound_section
    system = (all(v in component_dump for v in ('hasBound=true', 'received=true'))
              and re.search(r'\b[0-9]+:system/1000\b', component_dump) is not None)
    return {'bound': bool(label and system and pid), 'boundLabel': label,
            'systemBinding': system, 'servicePid': int(pid.group(1)) if pid else None}
