; Script de Inno Setup para Sistema TFG
; Genera un instalador .exe para Windows

#define MyAppName "Sistema TFG"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "CIFP"
#define MyAppURL "https://github.com/elmosca/proyecto_flutter_supabase/wiki"
#define MyAppExeName "sistema_tfg.exe"
#define MyAppId "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D"

[Setup]
; Información básica de la aplicación
AppId={{{#MyAppId}}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=
InfoBeforeFile=
InfoAfterFile=
OutputDir=..\build\installer
OutputBaseFilename=SistemaTFG_Installer_v{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64

; Configuración de compresión y tamaño
DiskSpanning=no

; Configuración de desinstalación
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Ejecutable principal
Source: "..\build\windows\x64\runner\Release\sistema_tfg.exe"; DestDir: "{app}"; Flags: ignoreversion

; DLLs necesarios
Source: "..\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\app_links_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\permission_handler_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\printing_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\pdfium.dll"; DestDir: "{app}"; Flags: ignoreversion

; Carpeta data completa con todos los recursos
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Icono en el menú de inicio
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; Icono en el escritorio (opcional)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; Icono en la barra de inicio rápido (solo Windows XP y anteriores)
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; Opción para ejecutar la aplicación después de la instalación
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Función para verificar si .NET Framework está instalado (si es necesario)
function InitializeSetup(): Boolean;
begin
  Result := True;
  // Aquí puedes agregar verificaciones adicionales si es necesario
end;

// Función para actualizar los enlaces en el registro después de la instalación
procedure CurStepChanged(CurStep: TSetupStep);
var
  UninstallKey: String;
begin
  if CurStep = ssPostInstall then
  begin
    // Actualizar los enlaces en el registro del desinstalador
    UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + ExpandConstant('{#MyAppId}') + '_is1';
    
    // Forzar la actualización de los enlaces
    RegWriteStringValue(HKEY_LOCAL_MACHINE, UninstallKey, 'PublisherURL', ExpandConstant('{#MyAppURL}'));
    RegWriteStringValue(HKEY_LOCAL_MACHINE, UninstallKey, 'HelpLink', ExpandConstant('{#MyAppURL}'));
    RegWriteStringValue(HKEY_LOCAL_MACHINE, UninstallKey, 'URLUpdateInfo', ExpandConstant('{#MyAppURL}'));
    RegWriteStringValue(HKEY_LOCAL_MACHINE, UninstallKey, 'URLInfoAbout', ExpandConstant('{#MyAppURL}'));
  end;
end;

