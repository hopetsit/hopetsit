import sys, subprocess

REPO = '/sessions/relaxed-jolly-pasteur/mnt/HopeTSIT_FINAL_FIXED/HopeTSIT_FINAL'

# Always read from HEAD to avoid stale/truncated working copies
def head(path):
    return subprocess.check_output(
        ['git', 'show', f'HEAD:{path}'], cwd=REPO, encoding='utf-8'
    )

# ============ 1. walker_model.dart — add countryCode field ============
wm_path = 'frontend/lib/models/walker_model.dart'
wm = head(wm_path)

# Add field declaration
old1 = "  final String mobile;\n  final String language;"
new1 = "  final String mobile;\n  /// Country dial code, e.g. \"+34\", \"+33\". Kept separate from `mobile` so the\n  /// edit-profile screen's CountryCodePicker stays in sync with the stored value.\n  final String countryCode;\n  final String language;"
if old1 not in wm:
    sys.exit('walker_model field decl pattern not found')
wm = wm.replace(old1, new1, 1)

# Add to constructor
old2 = "    required this.mobile,\n    required this.language,"
new2 = "    required this.mobile,\n    this.countryCode = '',\n    required this.language,"
if old2 not in wm:
    sys.exit('walker_model ctor pattern not found')
wm = wm.replace(old2, new2, 1)

# Add to fromJson
old3 = "      mobile: json['mobile'] as String? ?? '',\n      language: json['language'] as String? ?? '',"
new3 = "      mobile: json['mobile'] as String? ?? '',\n      countryCode: json['countryCode'] as String? ?? '',\n      language: json['language'] as String? ?? '',"
if old3 not in wm:
    sys.exit('walker_model fromJson pattern not found')
wm = wm.replace(old3, new3, 1)

with open(f'{REPO}/{wm_path}', 'w') as f:
    f.write(wm)
print('walker_model.dart: OK (countryCode added)')

# ============ 2. edit_walker_profile_controller.dart — trust backend countryCode ============
ec_path = 'frontend/lib/controllers/edit_walker_profile_controller.dart'
ec = head(ec_path)

old4 = """      // Extract country code prefix from the stored mobile (e.g. "+33 6 12 …"
      // → "+33"). Best effort: we match the leading +<digits>.
      final mobileMatch = RegExp(r'^\\+(\\d+)').firstMatch(walker.mobile);
      if (mobileMatch != null) {
        selectedCountryCode.value = '+${mobileMatch.group(1)}';
      }"""

new4 = """      // Session v16.3 — trust the backend's stored countryCode first. Previously
      // we regex-extracted it from the mobile string, which caused the picker
      // to desync when the stored number format changed (e.g. flag showing
      // Afghanistan while the number started with +34). Regex stays as a
      // fallback for old accounts that don't have countryCode persisted.
      if (walker.countryCode.isNotEmpty) {
        selectedCountryCode.value = walker.countryCode;
      } else {
        final mobileMatch = RegExp(r'^\\+(\\d+)').firstMatch(walker.mobile);
        if (mobileMatch != null) {
          selectedCountryCode.value = '+${mobileMatch.group(1)}';
        }
      }"""

if old4 not in ec:
    sys.exit('edit_walker_profile_controller regex pattern not found')
ec = ec.replace(old4, new4, 1)

with open(f'{REPO}/{ec_path}', 'w') as f:
    f.write(ec)
print('edit_walker_profile_controller.dart: OK (trust backend countryCode)')

# Verify no truncation on disk
for p in [wm_path, ec_path]:
    with open(f'{REPO}/{p}', 'r') as f:
        content = f.read()
    if len(content) < 1000:
        sys.exit(f'{p} looks too short ({len(content)} bytes)')
    print(f'  {p}: {len(content)} bytes on disk')

print('\nALL PHONE BUG EDITS APPLIED')
