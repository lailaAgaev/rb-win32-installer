;---------------------------------------------------------------------------
; Installer definitions
;---------------------------------------------------------------------------

; Installer defines
!define PRODUCT_NAME          "Review Board"
!define PRODUCT_VERSION       "1.0.1"
!define PRODUCT_NORM_VERSION  "1.0.1"
!define PRODUCT_PUBLISHER     "The Review Board Project"
!define PRODUCT_WEB_SITE      "http://www.review-board.org/"

; Versions
!define PYTHON_VERSION "2.5.3"
!define MYSQL_VERSION "5.1.31"

; Filenames
!define PYTHON_MSI_FILE "python-${PYTHON_VERSION}.msi"
!define MYSQL_MSI_FILE "mysql-essential-${MYSQL_VERSION}-win32.msi"

; Registry Keys
!define ENVIRONMENT_REG_KEY "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
!define RB_REG_KEY "Software\Review Board\Review Board"
!define PYTHON_PATH_REG_KEY "Software\Python\PythonCore\2.5\InstallPath"

; TODO: http://www.osuch.org/python-ldap-2.3.5.win32-py2.5.msi
;http://pypi.python.org/packages/2.5/s/setuptools/setuptools-0.6c9.win32-py2.5.exe


;---------------------------------------------------------------------------
; Global Variables
;---------------------------------------------------------------------------
Var gPythonInstDir

!define PYTHON_INST_DIR $gPythonInstDir


;---------------------------------------------------------------------------
; MUI Settings
;---------------------------------------------------------------------------
!include "MUI2.nsh"
!include "Sections.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"


;---------------------------------------------------------------------------
; Installer Information
;---------------------------------------------------------------------------
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "ReviewBoard-${PRODUCT_NORM_VERSION}-win32.exe"
InstallDir "$PROGRAMFILES\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${RB_REG_KEY}" "InstallPath"
ShowInstDetails show


;---------------------------------------------------------------------------
; Pre-show handler macro for Python Install Location page
;---------------------------------------------------------------------------
!macro PAGE_SHOW_IF_SECTION sectionvar
	Function onShow${sectionvar}
		SectionGetFlags "${sectionvar}" $R0
		MessageBox MB_OK "$R0"
		!insertmacro SectionFlagIsSet ${sectionvar} ${SF_SELECTED} done +1
		MessageBox MB_OK "Abort."
		Abort
done:
	FunctionEnd
	!define MUI_PAGE_CUSTOMFUNCTION_PRE onShow${sectionvar}
!macroend


;---------------------------------------------------------------------------
; Installation Pages
;---------------------------------------------------------------------------

; Initial Welcome page
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\COPYING"

; Component selection page
!insertmacro MUI_PAGE_COMPONENTS

; Review Board installation directory page
!define MUI_DIRECTORYPAGE_VARIABLE $INSTDIR
!define MUI_PAGE_HEADER_TEXT "Review Board installation location."
!define MUI_PAGE_HEADER_SUBTEXT ""
!define MUI_DIRECTORYPAGE_TEXT_TOP "Please select the folder where Review Board should be installed."
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Review Board Folder"
!insertmacro MUI_PAGE_DIRECTORY

; Python installation directory page
;!define MUI_DIRECTORYPAGE_VARIABLE ${PYTHON_INST_DIR}
;!define MUI_PAGE_HEADER_TEXT "Python installation location."
;!define MUI_PAGE_HEADER_SUBTEXT ""
;!define MUI_DIRECTORYPAGE_TEXT_TOP "Please select the folder where Python should be installed."
;!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Python Folder"
;;!define MUI_PAGE_CUSTOMFUNCTION_PRE onPythonDirPagePre
;;Function onShow
;;	!insertmacro SectionFlagIsSet SEC_Python ${SF_SELECTED} checkMore done
;;checkMore:
;;	!insertmacro SectionFlagIsSet SEC_Python ${SF_SELECTED} done notSel
;;notSel:
;;	Abort
;;done:
;;	Abort
;;FunctionEnd
;;!define MUI_PAGE_CUSTOMFUNCTION_PRE onShow
;!insertmacro PAGE_SHOW_IF_SECTION "SEC_Python"
;!insertmacro MUI_PAGE_DIRECTORY

; Install Files page
!insertmacro MUI_PAGE_INSTFILES

; Finished page
!define MUI_FINISHPAGE_LINK "Visit the Review Board website"
!define MUI_FINISHPAGE_LINK_LOCATION ${PRODUCT_WEB_SITE}
!insertmacro MUI_PAGE_FINISH

; Set our list of languages
!insertmacro MUI_LANGUAGE "English"

;---------------------------------------------------------------------------
; Uninstallation Pages
;---------------------------------------------------------------------------

;!insertmacro MUI_UNPAGE_CONFIRM
;!insertmacro MUI_UNPAGE_INSTFILES


Section -SETTINGS SEC01
	SetOutPath "$INSTDIR"
	SetOverwrite ifnewer
SectionEnd

SectionGroup /e "Core"
	Section -Python SEC_Python
		StrCmp $gPythonInstDir "" 0 done
		NSISdl::download "http://python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_MSI_FILE}" ${PYTHON_MSI_FILE}

		Pop $R0 ; Get the return value
		Strcmp $R0 "success" +3
			MessageBox MB_OK "Download failed: $R0"
			Quit

		ExecWait 'msiexec /package ${PYTHON_MSI_FILE} TARGETDIR=${PYTHON_INST_DIR}'
		delete ${PYTHON_MSI_FILE}

		Call GetPythonInstDir
		ReadRegStr $0 HKLM "${ENVIRONMENT_REG_KEY}" "path"
		WriteRegStr HKLM "${ENVIRONMENT_REG_KEY}" "path" "$0;$gPythonInstDir"
done:
	SectionEnd
SectionGroupEnd

SectionGroup /e "Database"
	Section "MySQL" MySQLSection
		NSIsdl::download "http://dev.mysql.com/get/Downloads/MySQL-5.1/${MYSQL_MSI_FILE}/from/http://mysql.he.net/" ${MYSQL_MSI_FILE}

		Pop $R0 ; Get the return value
		Strcmp $R0 "success" +3
			MessageBox MB_OK "Download failed: $R0"
			Quit

		ExecWait 'msiexec /package ${MYSQL_MSI_FILE}'
		delete ${MYSQL_MSI_FILE}
	SectionEnd
SectionGroupEnd

;Section "MySQL Python Bindings" SEC03
;	ExecWait 'msiexec /package "$INSTDIR\pkgs\mysql-essential-${MYSQL_VERSION}-win32.msi" /quiet'
;SectionEnd

;Section "PyWin32" SEC04
;	; this is not a "quiet" install
;	ExecWait '$INSTDIR\pkgs\pywin32-208.win32-py2.5.exe'
;SectionEnd
;
;Section "Mysqld-python" SEC05
;	; this is not a "quiet" install
;	ExecWait '$INSTDIR\pkgs\MySQL-python.exe-1.2.0.win32-py2.5.exe'
;SectionEnd
;


;---------------------------------------------------------------------------
; Initialization Handler
;---------------------------------------------------------------------------
Function .onInit
	ReadRegStr $0 HKCU "${RB_REG_KEY}" "InstallPath"
	Strcmp $0 "" +2 0
		StrCpy $INSTDIR $0

	Call GetPythonInstDir
FunctionEnd

Function GetPythonInstDir
	ReadRegStr $gPythonInstDir HKCU "${PYTHON_PATH_REG_KEY}" ""
	StrCmp $gPythonInstDir "" 0 +2
		StrCpy $gPythonInstDir "C:\Python25"
FunctionEnd
