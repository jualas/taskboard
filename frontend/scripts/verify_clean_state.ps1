# Script de verificación de estado limpio del proyecto Flutter
# Ejecutar: .\scripts\verify_clean_state.ps1

Write-Host "🧹 Verificando estado limpio del proyecto Flutter..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Función para mostrar resultado
function Show-Result {
    param($Success, $Message)
    if ($Success) {
        Write-Host "✅ $Message" -ForegroundColor Green
    } else {
        Write-Host "❌ $Message" -ForegroundColor Red
    }
}

# 1. Verificar Flutter Doctor
Write-Host "`n1. Verificando Flutter Doctor..." -ForegroundColor Yellow
$flutterDoctor = flutter doctor 2>&1
if ($LASTEXITCODE -eq 0) {
    Show-Result $true "Flutter Doctor: OK"
} else {
    Show-Result $false "Flutter Doctor: ERROR"
    Write-Host $flutterDoctor -ForegroundColor Red
}

# 2. Verificar Análisis de Código
Write-Host "`n2. Verificando análisis de código..." -ForegroundColor Yellow
$flutterAnalyze = flutter analyze 2>&1
if ($LASTEXITCODE -eq 0) {
    Show-Result $true "Análisis de código: Sin problemas"
} else {
    Show-Result $false "Análisis de código: Problemas encontrados"
    Write-Host $flutterAnalyze -ForegroundColor Red
}

# 3. Verificar Tests
Write-Host "`n3. Verificando tests..." -ForegroundColor Yellow
$flutterTest = flutter test 2>&1
if ($LASTEXITCODE -eq 0) {
    Show-Result $true "Tests: Todos pasando"
} else {
    Show-Result $false "Tests: Fallos encontrados"
    Write-Host $flutterTest -ForegroundColor Red
}

# 4. Verificar Build de Android
Write-Host "`n4. Verificando build de Android..." -ForegroundColor Yellow
$flutterBuild = flutter build apk --debug --no-tree-shake-icons 2>&1
if ($LASTEXITCODE -eq 0) {
    Show-Result $true "Build Android: Exitoso"
} else {
    Show-Result $false "Build Android: Falló"
    Write-Host $flutterBuild -ForegroundColor Red
}

# 5. Verificar Dependencias
Write-Host "`n5. Verificando dependencias..." -ForegroundColor Yellow
$flutterPubGet = flutter pub get 2>&1
if ($LASTEXITCODE -eq 0) {
    Show-Result $true "Dependencias: Actualizadas"
} else {
    Show-Result $false "Dependencias: Problemas"
    Write-Host $flutterPubGet -ForegroundColor Red
}

# 6. Verificar archivos problemáticos
Write-Host "`n6. Verificando archivos problemáticos..." -ForegroundColor Yellow
$problematicFiles = @(
    "lib/test_connection.dart",
    "lib/debug.dart",
    "lib/temp.dart"
)

$foundProblems = $false
foreach ($file in $problematicFiles) {
    if (Test-Path $file) {
        Show-Result $false "Archivo problemático encontrado: $file"
        $foundProblems = $true
    }
}

if (-not $foundProblems) {
    Show-Result $true "No se encontraron archivos problemáticos"
}

# 7. Verificar print statements
Write-Host "`n7. Verificando print statements..." -ForegroundColor Yellow
$printStatements = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | 
    Select-String -Pattern "print\(" -AllMatches | 
    Where-Object { $_.Line -notmatch "debugPrint" -and $_.Line -notmatch "kDebugMode" }

if ($printStatements) {
    Show-Result $false "Print statements encontrados:"
    $printStatements | ForEach-Object {
        Write-Host "  - $($_.Filename):$($_.LineNumber) - $($_.Line.Trim())" -ForegroundColor Red
    }
} else {
    Show-Result $true "No se encontraron print statements problemáticos"
}

# Resumen final
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "📊 RESUMEN DE VERIFICACIÓN" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$allChecks = @(
    ($LASTEXITCODE -eq 0), # Flutter Doctor
    ($flutterAnalyze -notmatch "issues found"), # Análisis
    ($flutterTest -notmatch "FAILED"), # Tests
    ($flutterBuild -notmatch "FAILED"), # Build
    ($flutterPubGet -notmatch "FAILED"), # Dependencias
    (-not $foundProblems), # Archivos problemáticos
    (-not $printStatements) # Print statements
)

$passedChecks = ($allChecks | Where-Object { $_ }).Count
$totalChecks = $allChecks.Count

Write-Host "Checks pasados: $passedChecks/$totalChecks" -ForegroundColor White

if ($passedChecks -eq $totalChecks) {
    Write-Host "🎉 ¡PROYECTO EN ESTADO LIMPIO!" -ForegroundColor Green
    Write-Host "✅ Listo para desarrollo" -ForegroundColor Green
} else {
    Write-Host "⚠️  Se encontraron problemas que requieren atención" -ForegroundColor Yellow
    Write-Host "🔧 Revisa los errores anteriores" -ForegroundColor Yellow
}

Write-Host "`n💡 Comando para ejecutar: flutter run -d chrome" -ForegroundColor Blue
