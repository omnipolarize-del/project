Write-Host "Creating C:\src..."
New-Item -ItemType Directory -Force -Path "C:\src" > $null

# Delete old fragmented file
If (Test-Path "$env:TEMP\flutter.zip") {
    Remove-Item "$env:TEMP\flutter.zip" -Force
}

Write-Host "Downloading Flutter SDK using curl... This will take a few minutes."
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.41.6-stable.zip"
curl.exe -L -o "$env:TEMP\flutter.zip" $url

Write-Host "Extracting to C:\src\flutter..."
Expand-Archive -Path "$env:TEMP\flutter.zip" -DestinationPath "C:\src" -Force

Write-Host "Updating PATH..."
$oldPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($oldPath -notmatch "C:\\src\\flutter\\bin") {
    $newPath = $oldPath + ";C:\src\flutter\bin"
    [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
}
Write-Host "Install Done!"
