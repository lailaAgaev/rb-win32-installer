; NOTES:
; 1) Compiling this requires ZipDLL plugin!
;    Not currently a default plugin for the NSIS compiler.
; 2) This is currently NOT a silent install due to use of distutil install
;    packages: PyCrypto and PIL, among other things
; 3) Currently we install only python bindings for the database/source control systems.


;---------------------------------------------------------------------------
; Includes
;---------------------------------------------------------------------------
!include "MUI2.nsh"
!include "ZipDLL.nsh"
!include "Sections.nsh"

;---------------------------------------------------------------------------
; MUI Settings
;---------------------------------------------------------------------------

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"

;---------------------------------------------------------------------------
; Installer definitions
;---------------------------------------------------------------------------

; Installer defines
!define PRODUCT_NAME          "ReviewBoard"
!define PRODUCT_VERSION       "1.0.1" ;TODO update version?
!define PRODUCT_NORM_VERSION  "1.0.1"
!define PRODUCT_PUBLISHER     "The Review Board Project"
!define PRODUCT_WEB_SITE      "http://www.review-board.org/"

; Versions of software
!define PYTHON_VERSION "2.6" ;TODO is python version correct?
!define PATCH_VERSION "2.5.9"
!define MYSQL_VERSION "5.1.31" ;TODO deal with MySQL

;---------------------------------------------------------------------------
; Installer Information
;---------------------------------------------------------------------------
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "ReviewBoard-${PRODUCT_NORM_VERSION}-win32.exe"
InstallDir "$PROGRAMFILES\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${RB_REG_KEY}" "InstallPath"
ShowInstDetails show

;---------------------------------------------------------------------------
; Misc. Definitions
;---------------------------------------------------------------------------

;src for compilation: need COPYING file to be here, for example.
!define REVIEWBOARD_SRC "C:\Laila\Reviewboard\reviewboard" ;TODO where we get our src from

; Filenames we will download
!define PYTHON_MSI_FILE "python-${PYTHON_VERSION}.msi"
!define SETUPTOOLS_FILE "setuptools-0.6c11.win32-py${PYTHON_VERSION}.exe"
!define PYCRYPTO_FILE "pycrypto-2.1.0.win32-py${PYTHON_VERSION}"
!define MEMCACHED_FILE "memcached-1.2.6-win32-bin.zip"
!define PIL_FILE "PIL-1.1.7.win32-py${PYTHON_VERSION}.exe"
!define PATCH_FILE "patch-${PATCH_VERSION}-7-setup.exe"
!define MYSQL_MSI_FILE "mysql-essential-${MYSQL_VERSION}-win32.msi"

; Registry Keys
; This key is used to edit the PATH variable
!define ENVIRONMENT_REG_KEY "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
!define PYTHON_REG_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\AppPaths\Python.exe"

; Download locations
!define PYTHON_DOWNLOAD_LOC "http://python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_MSI_FILE}"
!define SETUPTOOLS_DOWNLOAD_LOC "http://pypi.python.org/packages/${PYTHON_VERSION}/s/setuptools/${SETUPTOOLS_FILE}"
!define PATCH_DOWNLOAD_LOC "http://gnuwin32.sourceforge.net/downlinks/patch.php"
!define PYCRYPTO_DOWNLOAD_LOC "http://www.voidspace.org.uk/downloads/${PYCRYPTO_FILE}.zip"
!define PIL_DOWNLOAD_LOC "http://effbot.org/media/downloads/${PIL_FILE}"
!define MEMCACHED_DOWNLOAD_LOC "http://code.jellycan.com/files/memcached-1.2.6-win32-bin.zip"
!define MYSQL_DOWNLOAD_LOC "http://dev.mysql.com/get/Downloads/MySQL-5.1/${MYSQL_MSI_FILE}/from/http://mysql.he.net/"

;TODO install CVS, Git, Mercurial, Perforce, Subversion
;TODO install database: MySQL, PostgreSQL, Apache
;TODO Do I need to uninstall old versions of python? how old?

;---------------------------------------------------------------------------
; Global Variables
;---------------------------------------------------------------------------

;Variables containing the directory into which we will install
Var gPythonInstDir
Var gPatchInstDir
var gMemcachedInstDir
var gEIInstDir ;directory where Easy_Install was found on the path... not used!

!define PYTHON_INST_DIR $gPythonInstDir
!define PATCH_INST_DIR $gPatchInstDir
!define MEMCACHED_INST_DIR $gMemcachedInstDir

;Variables containing "true" if the product was found already and "false" otherwise
var gPythonInstalled
var gPatchInstalled
var gEIInstalled

;used to output results of installation.
var output
;---------------------------------------------------------------------------
; Installation Pages
;---------------------------------------------------------------------------

; Initial Welcome page
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${REVIEWBOARD_SRC}\COPYING"

; Component selection page
!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_COMPONENTS

; Python installation directory page
!define MUI_PAGE_CUSTOMFUNCTION_PRE pythonPre
!define MUI_DIRECTORYPAGE_VARIABLE ${PYTHON_INST_DIR}
!define MUI_PAGE_HEADER_TEXT "Python installation location."
!define MUI_PAGE_HEADER_SUBTEXT "This installer will install Python ${PYTHON_VERSION}."
!define MUI_DIRECTORYPAGE_TEXT_TOP "Please select the folder where Python should be installed."
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Python Folder"
!insertmacro MUI_PAGE_DIRECTORY

; Patch installation directory page
!define MUI_PAGE_CUSTOMFUNCTION_PRE patchPre
!define MUI_DIRECTORYPAGE_VARIABLE ${PATCH_INST_DIR}
!define MUI_PAGE_HEADER_TEXT "Patch installation location."
!define MUI_PAGE_HEADER_SUBTEXT "This installer will install GnuWin32 Patch version ${PATCH_VERSION}"
!define MUI_DIRECTORYPAGE_TEXT_TOP "Please select the folder where GNU Patch should be installed."
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Patch Folder"
!insertmacro MUI_PAGE_DIRECTORY

; Memcached installation directory page
!define MUI_PAGE_CUSTOMFUNCTION_PRE memcachedPre
!define MUI_DIRECTORYPAGE_VARIABLE ${MEMCACHED_INST_DIR}
!define MUI_PAGE_HEADER_TEXT "Memcached installation location."
!define MUI_PAGE_HEADER_SUBTEXT ""
!define MUI_DIRECTORYPAGE_TEXT_TOP "Please select the folder where Memcached should be installed."
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Memcached Folder"
!insertmacro MUI_PAGE_DIRECTORY

; Install Files page
!insertmacro MUI_PAGE_INSTFILES

; Finished page
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_FINISHPAGE_LINK "Visit the Review Board Website to complete setup."
!define MUI_FINISHPAGE_LINK_LOCATION ${PRODUCT_WEB_SITE}
!insertmacro MUI_PAGE_FINISH

; Set our list of languages
!insertmacro MUI_LANGUAGE "English"

;---------------------------------------------------------------------------
; Installation Page
;---------------------------------------------------------------------------

;Section of required components.
SectionGroup "Core Components" SEC_Core

; Installs Python unless it's already installed.
Section "Python" SEC_Python
SectionIn RO
	StrCmp $gPythonInstalled "true" donePython 0
	       NSISdl::download "${PYTHON_DOWNLOAD_LOC}" ${PYTHON_MSI_FILE}

	       Pop $R0 ; Get the return value
	       Strcmp $R0 "success" +3
                      MessageBox MB_OK "Download failed: $R0"
                      Quit

	       ExecWait 'msiexec /i ${PYTHON_MSI_FILE} /qb! TARGETDIR=${PYTHON_INST_DIR}' $output
	       StrCmp $output 0 sat 0
	       DetailPrint $output
	       StrCpy $output ""
	       sat:
               delete ${PYTHON_MSI_FILE}
               ReadRegStr $0 HKLM "${ENVIRONMENT_REG_KEY}" "path"
	       WriteRegStr HKLM "${ENVIRONMENT_REG_KEY}" "path" "$0;$gPythonInstDir"
	       goto PythonInst
        donePython: DetailPrint "A Python installation was detected at \n $gPythonInstDir and will be used to install Reviewboard."
        PythonInst:
SectionEnd

; Installs Python Setup Tools unless Easy_install is detected on the PATH.
Section "Python Setup Tools" SEC_PST
SectionIn RO
        ;installing setup tools
	StrCmp $gEIInstalled "true" doneEI 0
        NSISdl::download "${SETUPTOOLS_DOWNLOAD_LOC}" ${SETUPTOOLS_FILE}

	       Pop $R0 ; Get the return value
	       Strcmp $R0 "success" +3
                      MessageBox MB_OK "Download failed: $R0"
                      Quit

	       ExecWait '${SETUPTOOLS_FILE}' $output
               StrCmp $output 0 sat 0
	       DetailPrint $output
	       StrCpy $output ""
	       sat:
	       delete ${SETUPTOOLS_FILE}
               ReadRegStr $0 HKLM "${ENVIRONMENT_REG_KEY}" "path"
	       WriteRegStr HKLM "${ENVIRONMENT_REG_KEY}" "path" "$0;$gPythonInstDir\Scripts"
	       goto EIinst
               doneEI: DetailPrint "Easy_Install detected on the path:\n Python Setup Tools installation aborted."
               EIinst:
SectionEnd

; Installs Patch unless Patch.exe is detected on the PATH (even if it's not ours!)
Section "WinGNU Patch" SEC_Patch
SectionIn RO
	StrCmp $gPatchInstalled "" 0 donePatch
	       NSISdl::download "${PATCH_DOWNLOAD_LOC}" ${PATCH_FILE}

               Pop $R0 ; Get the return value
               Strcmp $R0 "success" +3
                      MessageBox MB_OK "Download failed: $R0"
                      Quit

               ExecWait '${PATCH_FILE} /SP- /SILENT /DIR="$gPatchInstDir"' $output
               StrCmp $output 0 sat 0
               DetailPrint $output
	       StrCpy $output ""
	       sat:
               delete ${PATCH_FILE}

               ;Call GetPatchInstDir
               ReadRegStr $0 HKLM "${ENVIRONMENT_REG_KEY}" "path"
               WriteRegStr HKLM "${ENVIRONMENT_REG_KEY}" "path" "$0;$gPatchInstDir\bin"
               goto patchInst
	donePatch: DetailPrint "$gPatchInstDir was detected on the PATH. GNU Patch install \n \
        was aborted. Please make certain that \n GNU Patch.exe is first on the PATH."
	patchInst:
SectionEnd

; Installs PIL using a distutil installer-- meaning no silent option.
; Does NOT check if PIL was installed.
Section "Python Imaging Library" SEC_PIL
SectionIn RO
	NSISdl::download "${PIL_DOWNLOAD_LOC}" "${PIL_FILE}"

        Pop $R0 ; Get the return value
        Strcmp $R0 "success" +3
             MessageBox MB_OK "Download failed: $R0"
             Quit
        ExecWait '${PIL_FILE}'
        delete ${PIL_FILE}
SectionEnd

; Installs PyCrypto using a distutil installer-- meaning no silent option.
; Does NOT check if PyCrypto was installed.
Section "PyCrypto" SEC_Pycrypto
SectionIn RO
          NSISdl::download "${PYCRYPTO_DOWNLOAD_LOC}" "${PYCRYPTO_FILE}.zip"
          Pop $R0 ; Get the return value
          Strcmp $R0 "success" +3
          	MessageBox MB_OK "Download failed: $R0"
          	Quit

          ZipDLL::extractall '${PYCRYPTO_FILE}.zip' $EXEDIR
          ExecWait "${PYCRYPTO_FILE}.exe" $output
          StrCmp $output 0 sat 0
          DetailPrint $output
          StrCpy $output ""
          sat:
          delete "${PYCRYPTO_FILE}.exe"
          delete "${PYCRYPTO_FILE}.zip"
SectionEnd

; Installs Reviewboard and all Easy_Install dependencies.
; Although we've added Easy_Install to the PATH, the
; changes don't take effect until the process is closed, therefore
; we have to provide the full PATH.
Section "Reviewboard" SEC_Reviewboard
SectionIn RO
        ;installing reviewboard + dependencies
        ExecWait '$gPythonInstDir\Scripts\easy_install pytz'
        ExecWait '$gPythonInstDir\Scripts\easy_install python-dateutil'
        ExecWait '$gPythonInstDir\Scripts\easy_install reviewboard'
        ExecWait '$gPythonInstDir\Scripts\easy_install python-memcached'
SectionEnd
SectionGroupEnd

; Installs Memcached
Section "Memcached" SEC_Memcached
        StrCmp $gMemcachedInstDir "" noDir 0
	NSISdl::download "${MEMCACHED_DOWNLOAD_LOC}" ${MEMCACHED_FILE}
	
         	Pop $R0 ; Get the return value
          	Strcmp $R0 "success" +3
           		MessageBox MB_OK "Download failed: $R0"
             		Quit
             		
               ZipDLL::extractall ${MEMCACHED_FILE} $gMemcachedInstDir
               ExecWait '$gMemcachedInstDir\memcached.exe' $output
               StrCmp $output "0" sat 0
	       DetailPrint $output
	       StrCpy $output ""
               sat:
               delete $gMemcachedInstDir\${MEMCACHED_FILE}
               ExecWait '$gMemcachedInstDir\memcached.exe -d -install'
               ExecWait '$gPythonInstDir\Scripts\easy_install python-memcached'
               goto doneM
        noDir: MessageBox MB_OK "Memcached: No installation directory selected, Memcached install skipped."
        doneM:
SectionEnd

; Installs Amazon S3
Section "Amazon S3" SEC_Amazon
	ExecWait '$gPythonInstDir\Scripts\easy_install django-storages'
SectionEnd

SectionGroup "Database Bindings" SEC_Database
	Section /o "MySQL" SEC_MySQL
		ExecWait '$gPythonInstDir\Scripts\easy_install mysql-python'
	SectionEnd
	Section /o "PostgreSQL" SEC_POSTGRE
		ExecWait '$gPythonInstDir\Scripts\easy_install psycopg2'
	SectionEnd
	;Section /o "Apache" SEC_APACHE
	;SectionEnd
SectionGroupEnd

SectionGroup "Source Control Systems" SEC_SC
	Section /o "CVS" SEC_CVS
	SectionEnd
	Section /o "Git" SEC_GIT
	SectionEnd
	Section /o "Mercurial" SEC_MERC
	SectionEnd
	Section /o "Perforce" SEC_PER
	SectionEnd
	Section /o "Subversion" SEC_SVN
		ExecWait 'easy_install pysvn' ;TODO
	SectionEnd
SectionGroupEnd

;---------------------------------------------------------------------------
;  Descriptions for each Section.
;---------------------------------------------------------------------------
LangString DESC_Section1 ${LANG_ENGLISH} "Required components of Reviewboard."
LangString DESC_Section12 ${LANG_ENGLISH} "Installs Python ${PYTHON_VERSION} and adds it to the PATH."
LangString DESC_Section13 ${LANG_ENGLISH} "Installs Python Setup Tools, a Python library for installing modules."
LangString DESC_Section14 ${LANG_ENGLISH} "Installs WinGNU Patch, used to create Reviewboard diff files."
LangString DESC_Section15 ${LANG_ENGLISH} "Installs Pycrypto."
LangString DESC_Section16 ${LANG_ENGLISH} "Installs Python Imaging Library."
LangString DESC_Section17 ${LANG_ENGLISH} "Installs Reviewboard, Django, and other dependencies."
LangString DESC_Section2 ${LANG_ENGLISH} "Depending on the database you intend to use, we must install the appropriate python bindings."
LangString DESC_Section3 ${LANG_ENGLISH} "Allows uploading screenshots."
LangString DESC_Section4 ${LANG_ENGLISH} "Installs MySQL Python bindings. Allows reviewboard to work with a MySQL database."
LangString DESC_Section5 ${LANG_ENGLISH} "Installs PostgreSQL Python bindings. Allows reviewboard to work with a PostgreSQL database."
LangString DESC_Section6 ${LANG_ENGLISH} "Installs Apache Python bindings. Allows reviewboard to work with an Apache database."
LangString DESC_Section7 ${LANG_ENGLISH} "Speeds up performance."
LangString DESC_Section8 ${LANG_ENGLISH} "Reviewboard can work with several Source Control components, please choose those which you would like installed."
LangString DESC_Section9 ${LANG_ENGLISH} "Installs CVS and adds cvs.exe to the PATH variable."
LangString DESC_Section10 ${LANG_ENGLISH} "Installs Git."
LangString DESC_Section11 ${LANG_ENGLISH} "Installs Mercurial."
LangString DESC_Section18 ${LANG_ENGLISH} "Installs Perforce and P4Python."
LangString DESC_Section19 ${LANG_ENGLISH} "Installs Subversion and PySVN."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Python} $(DESC_Section12)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_PST} $(DESC_Section13)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Patch} $(DESC_Section14)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Pycrypto} $(DESC_Section15)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_PIL} $(DESC_Section16)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Reviewboard} $(DESC_Section17)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Database} $(DESC_Section2) 
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Amazon} $(DESC_Section3)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_MySQL} $(DESC_Section4)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_POSTGRE} $(DESC_Section5)
;  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_APACHE} $(DESC_Section6)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Memcached} $(DESC_Section7)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_SC} $(DESC_Section8)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CVS} $(DESC_Section9)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_GIT} $(DESC_Section10)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Merc} $(DESC_Section11)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Per} $(DESC_Section18)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_SVN} $(DESC_Section19)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;---------------------------------------------------------------------------
; Pre-show handler macro for Python Install Location page
;---------------------------------------------------------------------------

; Pre-show function that decides whether we show the python install
; directory page based on whether Python is installed.
Function pythonPre
  strcmp $gPythonInstalled "true" 0 Done
  Abort
  Done:
FunctionEnd

; Pre-show function that decides whether we show the Patch install
; directory page.
Function patchPre
  strcmp $gPatchInstalled "true" 0 Done
  Abort
  Done:
FunctionEnd

; Pre-show function that decides whether we show the Memcached install
; directory page.
Function memcachedPre
	!insertmacro SectionFlagIsSet ${SEC_Memcached} ${SF_SELECTED} Show Abr
	Abr:
        Abort
	Show:
FunctionEnd

;---------------------------------------------------------------------------
; Initialization Handler
;---------------------------------------------------------------------------
Function .onInit
         Call GetPythonInstDir
         Call GetPatchInstDir
         Call GetEasyInstallDir
	;Call GetPycryptoInstDir
	;TODO program files location programmatically
        StrCpy $gMemcachedInstDir "C:\Program Files\Memcached"
FunctionEnd

;Check to see if Python is installed, and where...
Function GetPythonInstDir
        ReadRegStr $gPythonInstDir HKLM "Software\Microsoft\Windows\CurrentVersion\App Paths\Python.exe" ""
	StrCmp $gPythonInstDir "" donePython 0
        ;python is installed
	StrCpy $gPythonInstalled "true"
	StrCpy $gPythonInstDir "$gPythonInstDir" -12
        donePython:
	;python is not installed
	StrCpy $gPythonInstDir 'C:\python26'
FunctionEnd

; Checks if Easy_Install is already on the PATH
Function GetEasyInstallDir
         SearchPath $gEIInstDir 'Easy_Install'
         StrCmp $gEIInstDir "" doneEI 0
         ;easy-install is on the path
         StrCpy $gEIInstalled "true"
         StrCpy $gEIInstalled $gEIInstalled -14
         doneEI:
         ;EI is not installed
         StrCpy $gEIInstalled ""
FunctionEnd

; Searches the PATH for patch.exe. If found, shows a message
; To the user that they need to manually install GNU Patch if it's not
; what's already on the PATH.
Function GetPatchInstDir
         SearchPath $gPatchInstDir 'patch.exe'
         StrCmp $gPatchInstDir "" donePatch 0
         ;patch is installed
         StrCpy $gPatchInstalled "true"
         MessageBox MB_OK '$gPatchInstDir was found on your PATH. Reviewboard requires \
          that GNU Patch.exe is available on the PATH. Please make certain the correct Patch version is installed.'
         StrCpy $gPatchInstDir $gPatchInstDir -14
         DonePatch:
         ;patch is not installed
         StrCpy $gPatchInstDir 'C:\GnuWin32'
         ;TODO Does this contain 'gnuwin'?
FunctionEnd
