# create-lecture-html.ps1
# Windows PowerShell 5.1 compatible
# Reads outline.txt and creates section folders + lecture HTML files

$ErrorActionPreference = "Stop"

$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$outlinePath = Join-Path $root "outline.txt"

if (-not (Test-Path $outlinePath)) {
  Write-Host "ERROR: Missing outline.txt at: $outlinePath" -ForegroundColor Red
  exit 1
}

function Sanitize-Name([string]$s) {
  if ($null -eq $s) { return "" }

  # Remove emojis and other non-basic chars (safe for filenames)
  $s = ($s -replace "[^\u0000-\u007F]+", " ")

  # Remove invalid Windows filename chars: \ / : * ? " < > |
  $s = ($s -replace '[\\/:*?"<>|]', " ")

  # Remove apostrophes/backticks to avoid quoting surprises
  $s = $s -replace "[`'’]", ""

  # Replace multiple spaces with single space
  $s = ($s -replace "\s+", " ").Trim()

  # Avoid trailing dots/spaces (Windows limitation)
  $s = $s.TrimEnd(".", " ")

  return $s
}

function New-LectureHtml([string]$sectionLabel, [string]$lectureLabel) {
@"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>$lectureLabel</title>
  <style>
    body { font-family: Arial, Helvetica, sans-serif; margin: 24px; line-height: 1.5; color: #111; }
    h1 { font-size: 22px; margin: 0 0 6px; }
    .meta { color: #555; margin: 0 0 18px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #ddd; padding: 10px; vertical-align: top; }
    th { background: #f5f5f5; text-align: left; }
  </style>
</head>
<body>
  <h1>$lectureLabel</h1>
  <p class="meta">$sectionLabel</p>

  <table>
    <thead>
      <tr>
        <th>Key Points</th>
        <th>Notes</th>
        <th>Code Snippets</th>
        <th>Questions</th>
        <th>Links</th>
      </tr>
    </thead>
    <tbody>
      <tr><td></td><td></td><td></td><td></td><td></td></tr>
      <tr><td></td><td></td><td></td><td></td><td></td></tr>
      <tr><td></td><td></td><td></td><td></td><td></td></tr>
      <tr><td></td><td></td><td></td><td></td><td></td></tr>
      <tr><td></td><td></td><td></td><td></td><td></td></tr>
      <tr><td></td><td></td><td></td><td></td><td></td></tr>
      <tr><td></td><td></td><td></td><td></td><td></td></tr>
      <tr><td></td><td></td><td></td><td></td><td></td></tr>
    </tbody>
  </table>
</body>
</html>
"@
}

$lines = Get-Content -Path $outlinePath -Encoding UTF8

$currentSectionNo = $null
$currentSectionTitle = $null
$currentSectionDir = $null
$lectureIndex = 0

$createdFiles = 0
$createdFolders = 0

foreach ($raw in $lines) {
  if ($null -eq $raw) { continue }
  $t = ($raw.Trim())
  if ($t -eq "") { continue }

  # Ignore noise lines
  if ($t -match "^(Play|Start|Role Play|Preview|Lecture|Quiz)$") { continue }
  if ($t -match "^\d+\s*(min|mins|hr|hrs)$") { continue }
  if ($t -match "^(➡️\s*)?Play$") { continue }
  if ($t -match "^(➡️\s*)?Start$") { continue }

  # SECTION line: "01 - Something"
  if ($t -match "^(?<sec>\d{2})\s*-\s*(?<title>.+)$") {
    $currentSectionNo = $Matches["sec"]
    $currentSectionTitle = Sanitize-Name $Matches["title"]

    # Try to find existing folder that starts with "01 -"
    $existing = Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -match ("^" + [regex]::Escape($currentSectionNo) + "\s*-\s*") } | Select-Object -First 1

    if ($existing) {
      $currentSectionDir = $existing.FullName
    } else {
      $folderName = "{0} - {1}" -f $currentSectionNo, $currentSectionTitle
      $currentSectionDir = Join-Path $root $folderName
      if (-not (Test-Path $currentSectionDir)) {
        New-Item -ItemType Directory -Path $currentSectionDir | Out-Null
        $createdFolders++
      }
    }

    $lectureIndex = 0
    continue
  }

  if (-not $currentSectionDir) {
    # skip lines until we see first section
    continue
  }

  # LECTURE line patterns:
  # "➡️32. Section Overview"
  # "32. Section Overview"
  # "Role Play 1: Help Isabelle to Plan an App" (special case)
  $globalNo = $null
  $title = $null

  if ($t -match "^(?:➡️\s*)?(?<no>\d+)\.\s*(?<ttl>.+)$") {
    $globalNo = $Matches["no"]
    $title = $Matches["ttl"]
  }
  elseif ($t -match "^(?<no>\d+)\s+(?<ttl>.+)$" -and $t -match "^\d+\s") {
    # fallback (rare): "32 Section Overview"
    $globalNo = $Matches["no"]
    $title = $Matches["ttl"]
  }
  elseif ($t -match "^Role\s*Play\s*(?<rp>\d+)\s*:\s*(?<ttl>.+)$") {
    $globalNo = $Matches["rp"]
    $title = "Role Play " + $globalNo + " - " + $Matches["ttl"]
  }

  if ($null -eq $title) { continue }

  $title = Sanitize-Name $title
  if ($title -eq "") { continue }

  $lectureIndex++

  $safeFileTitle = $title
  $fileName = "{0}. {1}.html" -f $lectureIndex, $safeFileTitle
  $outFile = Join-Path $currentSectionDir $fileName

  $sectionLabel = ("Section {0} - {1}" -f $currentSectionNo, $currentSectionTitle)
  $lectureLabel = ("{0}. {1}" -f $lectureIndex, $safeFileTitle)

  $html = New-LectureHtml $sectionLabel $lectureLabel
  Set-Content -Path $outFile -Value $html -Encoding UTF8

  $createdFiles++
}

Write-Host ""
Write-Host "DONE" -ForegroundColor Green
Write-Host ("Root: {0}" -f $root)
Write-Host ("Folders created: {0}" -f $createdFolders)
Write-Host ("HTML files created: {0}" -f $createdFiles)
