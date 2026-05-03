# Deploy Firestore Rules and Indexes
# This script deploys both security rules and indexes to Firebase

Write-Host "Deploying Firestore Rules and Indexes..." -ForegroundColor Cyan

# Check if firebase-tools is installed
try {
    $firebaseVersion = firebase --version 2>&1
    Write-Host "Firebase CLI found: $firebaseVersion" -ForegroundColor Green
}
catch {
    Write-Host "Firebase CLI not found. Installing..." -ForegroundColor Yellow
    npm install -g firebase-tools
}

# Deploy Firestore rules
Write-Host ""
Write-Host "Deploying Firestore Security Rules..." -ForegroundColor Cyan
firebase deploy --only firestore:rules

if ($LASTEXITCODE -eq 0) {
    Write-Host "Firestore rules deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "Failed to deploy Firestore rules" -ForegroundColor Red
    exit 1
}

# Deploy Firestore indexes
Write-Host ""
Write-Host "Deploying Firestore Indexes..." -ForegroundColor Cyan
firebase deploy --only firestore:indexes

if ($LASTEXITCODE -eq 0) {
    Write-Host "Firestore indexes deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Index creation can take several minutes. Monitor progress at:" -ForegroundColor Yellow
    Write-Host "https://console.firebase.google.com/project/_/firestore/indexes" -ForegroundColor Cyan
} else {
    Write-Host "Failed to deploy Firestore indexes" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "Your announcements and document requests should now work properly." -ForegroundColor Green