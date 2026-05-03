# Deploy Firestore indexes using Firebase CLI
# Usage: Ensure `firebase` CLI is installed and you're logged in and in the correct project directory.
# Run in PowerShell:
#   .\scripts\deploy_indexes.ps1

$ErrorActionPreference = 'Stop'
Write-Host "Deploying Firestore indexes from firestore.indexes.json..."
firebase deploy --only firestore:indexes
if ($LASTEXITCODE -ne 0) {
  Write-Error "firebase deploy exited with code $LASTEXITCODE"
  exit $LASTEXITCODE
}
Write-Host "Indexes deployed successfully." 
