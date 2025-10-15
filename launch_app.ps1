# Script de Lancement Muslim App
# Utilisez ce script pour tester l'application sur l'émulateur Android

Write-Host "🕌 Lancement de Muslim App sur émulateur Android" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Vérification des prérequis
Write-Host "`n📱 Vérification de l'émulateur..." -ForegroundColor Yellow

$devices = flutter devices
if ($devices -match "emulator-5554") {
    Write-Host "✅ Émulateur Android détecté" -ForegroundColor Green
    
    Write-Host "`n🔨 Compilation et lancement..." -ForegroundColor Yellow
    Write-Host "Cela peut prendre 2-5 minutes pour la première fois..." -ForegroundColor Gray
    
    # Lancement de l'application
    flutter run -d emulator-5554
    
} else {
    Write-Host "❌ Émulateur non détecté. Veuillez démarrer votre émulateur Android d'abord." -ForegroundColor Red
    Write-Host "Appareils disponibles :" -ForegroundColor Gray
    flutter devices
    
    Write-Host "`n💡 Pour démarrer un émulateur :" -ForegroundColor Yellow
    Write-Host "1. Ouvrez Android Studio" -ForegroundColor White
    Write-Host "2. Allez dans AVD Manager" -ForegroundColor White  
    Write-Host "3. Démarrez un appareil virtuel" -ForegroundColor White
    Write-Host "4. Relancez ce script" -ForegroundColor White
}

Write-Host "`n📋 Commandes utiles pendant le développement :" -ForegroundColor Cyan
Write-Host "r - Hot reload (recharger l'app)" -ForegroundColor White
Write-Host "R - Hot restart (redémarrer l'app)" -ForegroundColor White
Write-Host "q - Quitter l'application" -ForegroundColor White