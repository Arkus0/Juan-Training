# CI-style check script for local use
# Usage: ./scripts/ci_check.ps1 [-Build]
param(
  [switch]$Build
)

$report = "ci_report.txt"
"CI check started at $(Get-Date -Format o)" | Out-File $report -Encoding utf8

function run-cmd($commandLine) {
  # Append the command line to the report, then execute and capture output
  $commandLine | Out-File $report -Append -Encoding utf8
  try {
    $output = Invoke-Expression $commandLine 2>&1
    if ($output) { $output | Out-File $report -Append -Encoding utf8 }
    return 0
  } catch {
    $_ | Out-File $report -Append -Encoding utf8
    return 1
  }
}

# 1) Ensure dependencies
"--- flutter pub get ---" | Out-File $report -Append -Encoding utf8
run-cmd "flutter pub get"

# 2) Static analysis
"--- flutter analyze ---" | Out-File $report -Append -Encoding utf8
run-cmd "flutter analyze --fatal-infos"

# 3) Unit/widget tests
"--- flutter test ---" | Out-File $report -Append -Encoding utf8
run-cmd "flutter test"

# 4) Run the asset checker (Dart script)
"--- dart asset check ---" | Out-File $report -Append -Encoding utf8
if (Test-Path "bin/ci_asset_check.dart") {
  run-cmd "dart run bin/ci_asset_check.dart"
  if (Test-Path "ci_report_assets.json") {
    "Asset report (summary):" | Out-File $report -Append -Encoding utf8
    Get-Content ci_report_assets.json | Out-File $report -Append -Encoding utf8
  }
} else {
  "bin/ci_asset_check.dart not found" | Out-File $report -Append -Encoding utf8
}

# 5) Optionally build an APK (debug) to catch build-time asset issues
if ($Build) {
  "--- flutter build apk (debug) ---" | Out-File $report -Append -Encoding utf8
  run-cmd "flutter build apk --debug --no-shrink"
}

"CI check finished at $(Get-Date -Format o)" | Out-File $report -Append -Encoding utf8
Write-Output "CI check complete. See $report and ci_report_assets.json for details."