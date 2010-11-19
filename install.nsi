; NOTES:
; 1) Compiling this requires ZipDLL plugin!
;    Not currently a default plugin for the NSIS compiler.
; 2) This is currently NOT a silent install due to use of distutil install
;    packages: PyCrypto, PIL, etc...
; 3) Currently we install only python bindings for the database/source control systems.
;    We expect that the system itself (as well as Apache) is already there.
; 4) By default we install Python 2.5. We are able to use 2.6 if we find it,
;    however since mod_python is a mess on Windows with Python 2.6, 2.5 is the default
; 5) To work with Apache, patch.exe may need to be added to the Apache bin-- not
;    every Apache installation sees it on the system PATH.

;---------------------------------------------------------------------------
; Includes
;---------------------------------------------------------------------------
!include "MUI2.nsh"
!include "ZipDLL.nsh"
!include "Sections.nsh"
!include "InstallOptions.nsh"
!include "LogicLib.nsh"

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
!define PATCH_VERSION "2.5.9"
!define MYSQL_VERSION "5.0"
!define PG_VERSION "9.X"
!define PYTHON_VERSION_DEF "2.5"
#default SVN version we install for is in the InstallOptionsFile.ini file

;We try to search for it
Var pythonVersion
!define PYTHON_VERSION $pythonVersion
;---------------------------------------------------------------------------
; Installer Information
;---------------------------------------------------------------------------
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "ReviewBoard-${PRODUCT_NORM_VERSION}-win32.exe"
InstallDir "$PROGRAMFILES\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${RB_REG_KEY}" "InstallPath"
ShowInstDetails show
;---------------------------------------------------------------------------
; Global Variables
;---------------------------------------------------------------------------

;Variables containing the directory into which we will install
Var gPythonInstDir
Var gPatchInstDir
var gMemcachedInstDir

!define PYTHON_INST_DIR $gPythonInstDir
!define PATCH_INST_DIR $gPatchInstDir
!define MEMCACHED_INST_DIR $gMemcachedInstDir

;Variables containing "true" if the product was found already and "false" otherwise
var gPythonInstalled
var gPatchInstalled

;used to output results of installation.
var output

; Outputs details of an ExecWait that takes $output as its final argument
; label - unique id for labels
; name  - user-friendly name to print
; abrt  - if 'true', aborts on failure.
!macro OUTPUTDETAILS label name abrt

       ${If} $output == 0
             DetailPrint "Successfully installed ${name}"
       ${Else}
              DetailPrint "${name} installation result: $output"
              ${If} ${abrt} == 'true'
                    Abort "An essential part of Reviewboard failed to install. Aborting installation."
              ${EndIf}
       ${EndIf}

!macroend

; Checks whether a python module is installed by trying to import the package.
; package - what package should we try to import?
; name    - user-friendly name to print
!macro ISPYTHONPACKAGEINSTALLED package name

       nsExec::ExecToStack /OEM '"Python" -c "import ${package}"'
       pop $0
       ${If} $0 == 0
             DetailPrint "${name} module is installed."
       ${Else}
             DetailPrint "${name} module is not installed."
       ${EndIf}

!macroend

; Silent execution of easy_install.
; abrt    - is set to 'true', causes Abort on failure.
; name    - user-friendly name to print
; package - unique name for labels
; what    - full command to execute(ex: "easy_install packageXYZ")
!macro EXEC_OUT package what name abrt

       nsExec::ExecToStack /OEM ${what}
       pop $0
       ${If} $0 == "0"
             DetailPrint "${name} module installed successfully."
       ${Else}
              DetailPrint "${name} failed to install: $0"
             ${If} ${abrt} == "true"
                  abort "An essential part of the installation, ${name}, failed to install. Aborting installation."
             ${EndIf}
       ${EndIf}

!macroend

;Adds 'pathAdd' to the PATH enviroment variable and prints a message about it.
!macro ADD_TO_PATH pathAdd

       DetailPrint "Adding ${pathAdd} to the system PATH."
       ReadRegStr $0 HKLM "${ENVIRONMENT_REG_KEY}" "path"
       WriteRegStr HKLM "${ENVIRONMENT_REG_KEY}" "path" "$0;${pathAdd}"
       
       ; "Export" our change
       SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

!macroend
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
!define MYSQLP_FILE "MySQL-python-1.2.2.win32-py${PYTHON_VERSION}.exe"
!define PYSVN_FILE "pysvn-svn161-1.7.0-1177.exe"
!define POSTGRE_FILE "psycopg2-2.2.2.win32-py${PYTHON_VERSION}-pg9.0.1-release.exe"
!define P4PYTHON_FILE "p4python.exe"

; Registry Keys
; This key is used to edit the PATH variable
!define ENVIRONMENT_REG_KEY "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
!define PYTHON6_INSTALL_KEY "SOFTWARE\Python\PythonCore\2.6\InstallPath"
!define PYTHON5_INSTALL_KEY "SOFTWARE\Python\PythonCore\2.5\InstallPath"

;Default installation directories:
!define DEFAULT_PATCH_DIR     "C:\GnuWin32"
!define DEFAULT_PYTHON_DIR    "C:\Python25"

; Download locations
!define PYTHON_DOWNLOAD_LOC "http://python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_MSI_FILE}"
!define SETUPTOOLS_DOWNLOAD_LOC "http://pypi.python.org/packages/${PYTHON_VERSION}/s/setuptools/${SETUPTOOLS_FILE}"
!define PATCH_DOWNLOAD_LOC "http://gnuwin32.sourceforge.net/downlinks/patch.php"
!define PYCRYPTO_DOWNLOAD_LOC "http://www.voidspace.org.uk/downloads/${PYCRYPTO_FILE}.zip"
!define PIL_DOWNLOAD_LOC "http://effbot.org/media/downloads/${PIL_FILE}"
!define MEMCACHED_DOWNLOAD_LOC "http://code.jellycan.com/files/memcached-1.2.6-win32-bin.zip"
!define P4PYTHON_2.5_DOWNLOAD_LOC "ftp://ftp.perforce.com/perforce/r08.2/bin.ntx86/p4python25.exe"
!define P4PYTHON_2.6_DOWNLOAD_LOC "ftp://ftp.perforce.com/perforce/r10.1/bin.ntx86/p4python26.exe"

; The newest MySQL python bindings haven't been compiled on sourceforge.net yet...
!define MYSQLP_DOWNLOAD_LOC "http://www.technicalbard.com/files/MySQL-python-1.2.2.win32-py2.6.exe"
!define MYSQLP2_DOWNLOAD_LOC "http://qa.debian.org/watch/sf.php/mysql-python/MySQL-python-1.2.2.win32-py2.5.exe"
!define POSTGRE_DOWNLOAD_LOC "http://www.stickpeople.com/projects/python/win-psycopg/psycopg2-2.2.2.win32-py${PYTHON_VERSION}-pg9.0.1-release.exe"
!define PYSVN_DOWNLOAD_LOC "http://pysvn.tigris.org/files/documents/1233/45661/py25-pysvn-svn161-1.7.0-1177.exe"
!define PYSVN2_DOWNLOAD_LOC "http://pysvn.tigris.org/files/documents/1233/45666/py26-pysvn-svn161-1.7.0-1177.exe"

;---------------------------------------------------------------------------
; Installation Pages
;---------------------------------------------------------------------------

; Initial Welcome page
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${REVIEWBOARD_SRC}\COPYING"

; Component selection page
!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_PAGE_CUSTOMFUNCTION_SHOW ForceHackyRO
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
!define MUI_PAGE_HEADER_TEXT "Patch installation location"
!define MUI_PAGE_HEADER_SUBTEXT "This installer will install GnuWin32 Patch version ${PATCH_VERSION}"
!define MUI_DIRECTORYPAGE_TEXT_TOP "Please select the folder where GNU Patch should be installed."
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Patch Folder"
!insertmacro MUI_PAGE_DIRECTORY

; Memcached installation directory page
!define MUI_PAGE_CUSTOMFUNCTION_PRE memcachedPre
!define MUI_DIRECTORYPAGE_VARIABLE ${MEMCACHED_INST_DIR}
!define MUI_PAGE_HEADER_TEXT "Memcached installation location"
!define MUI_PAGE_HEADER_SUBTEXT "The location to which Memcached will be installed."
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
	${If} $gPythonInstalled == "true"
              DetailPrint "A Python installation was detected at $gPythonInstDir and will be"
              DetailPrint "used to install Reviewboard."
        ${Else}
	       NSISdl::download "${PYTHON_DOWNLOAD_LOC}" ${PYTHON_MSI_FILE}

	       Pop $R0 ; Get the return value
	       Strcmp $R0 "success" +3
                      MessageBox MB_OK "Download failed: $R0"
                      Quit

	       ExecWait 'msiexec /i ${PYTHON_MSI_FILE} /qb TARGETDIR=${PYTHON_INST_DIR} ALLUSERS=1' $output
               !insertmacro OUTPUTDETAILS "pthn" "Python ${PYTHON_VERSION}" "true"
	       delete ${PYTHON_MSI_FILE}
               !insertmacro ADD_TO_PATH $gPythonInstDir
        ${EndIf}
SectionEnd

; Installs Python Setup Tools unless Easy_install is detected on the PATH.
Section "Python Setup Tools" SEC_PST
SectionIn RO
        !insertmacro ISPYTHONPACKAGEINSTALLED "pkg_resources" "Python Setuptools"
        ${If} $0 != 0
              NSISdl::download "${SETUPTOOLS_DOWNLOAD_LOC}" ${SETUPTOOLS_FILE}
              
              Pop $R0 ; Get the return value
              ${If} $R0 != "success"
                      MessageBox MB_OK "Download failed: $R0"
                      Quit
              ${EndIf}

	       ExecWait '${SETUPTOOLS_FILE}' $output
	       !insertmacro OUTPUTDETAILS "EI" "Python Setup Tools" "true"
	       
	       delete ${SETUPTOOLS_FILE}
               !insertmacro ADD_TO_PATH '$gPythonInstDir\Scripts'
        ${EndIf}
SectionEnd

; Installs Patch unless Patch.exe is detected on the PATH (even if it's not ours!)
Section "WinGNU Patch" SEC_Patch
SectionIn RO
	${If} $gPatchInstalled == ""
	       NSISdl::download "${PATCH_DOWNLOAD_LOC}" ${PATCH_FILE}

               Pop $R0 ; Get the return value
               ${If} $R0 != "success"
                      MessageBox MB_OK "Download failed: $R0"
                      Quit
               ${EndIf}
               
               ExecWait '"${PATCH_FILE}" /SP- /SILENT /DIR="$gPatchInstDir"' $output
               !insertmacro OUTPUTDETAILS "ptch" "GNU Patch" "true"
               delete ${PATCH_FILE}

               !insertmacro ADD_TO_PATH '$gPatchInstDir\bin'
	${Else}
                DetailPrint "$gPatchInstDir was detected on the PATH. GNU Patch install"
                DetailPrint "was aborted. Please make certain that GNU"
                DetailPrint "Patch.exe is first on the PATH."
        ${EndIf}
SectionEnd

; Installs PIL using a distutil installer-- meaning no silent option.
; Aborts if PIL was installed
Section "Python Imaging Library" SEC_PIL
SectionIn RO
        !insertmacro ISPYTHONPACKAGEINSTALLED "Image" "Python Imaging Library"

        ${If} $0 != "0"
              NSISdl::download "${PIL_DOWNLOAD_LOC}" "${PIL_FILE}"

              Pop $R0 ; Get the return value
              ${If} $R0 != "success"
                    MessageBox MB_OK "Download failed: $R0"
                    Quit
              ${EndIf}

              ExecWait '${PIL_FILE}' $output
              !insertmacro OUTPUTDETAILS "pil" "Python Imaging Library" "true"
              delete ${PIL_FILE}
       ${EndIf}
SectionEnd

; Installs PyCrypto using a distutil installer-- meaning no silent option.
; Aborts if PyCrypto was installed
Section "PyCrypto" SEC_Pycrypto
SectionIn RO
        !insertmacro ISPYTHONPACKAGEINSTALLED "Crypto" "PyCrypto"
        ${If} $0 != "0"
          NSISdl::download "${PYCRYPTO_DOWNLOAD_LOC}" "${PYCRYPTO_FILE}.zip"
          Pop $R0 ; Get the return value
          ${If} $R0 != "success"
          	MessageBox MB_OK "Download failed: $R0"
          	Quit
          ${EndIf}

          ZipDLL::extractall '${PYCRYPTO_FILE}.zip' $EXEDIR

          ExecWait "${PYCRYPTO_FILE}.exe" $output
          !insertmacro OUTPUTDETAILS "Pycrypto" "Pycrypto" "true"
          
          delete "${PYCRYPTO_FILE}.exe"
          delete "${PYCRYPTO_FILE}.zip"
         ${EndIf}
SectionEnd

; Installs Reviewboard and all Easy_Install dependencies.
Section "Reviewboard" SEC_Reviewboard
SectionIn RO

         DetailPrint 'Installing Python Pytz module...'
        !insertmacro EXEC_OUT "ptz" '"${PYTHON_INST_DIR}\Scripts\easy_install pytz"' "Pytz" "true"

        DetailPrint 'Installing Python Dateutil...'
        !insertmacro EXEC_OUT "dtutil" '"${PYTHON_INST_DIR}\Scripts\easy_install python-dateutil"' "DateUtil" "true"

        DetailPrint 'Installing Reviewboard... this may take a few minutes.'
        !insertmacro EXEC_OUT "rvboard" '"${PYTHON_INST_DIR}\Scripts\easy_install reviewboard"' "ReviewBoard" "true"
SectionEnd
SectionGroupEnd

; Installs Memcached
Section "Memcached" SEC_Memcached
        ${If} $gMemcachedInstDir == ""
              MessageBox MB_OK "Memcached: No installation directory selected, Memcached install skipped."
        ${Else}
	       NSISdl::download "${MEMCACHED_DOWNLOAD_LOC}" ${MEMCACHED_FILE}
	
         	Pop $R0 ; Get the return value
          	Strcmp $R0 "success" +3
           		MessageBox MB_OK "Download failed: $R0"
             		Quit
             		
               ZipDLL::extractall ${MEMCACHED_FILE} $gMemcachedInstDir
               delete ${MEMCACHED_FILE}
               
               DetailPrint "Installing Memcached..."
               !insertmacro EXEC_OUT "memcached" '"$gMemcachedInstDir\memcached.exe -d install"' "Memcached" "false"
        ${EndIf}
SectionEnd

; Installs Amazon S3
Section "Amazon S3" SEC_Amazon
         DetailPrint 'Installing Amazon...'
	!insertmacro EXEC_OUT "a3" '"easy_install django-storages"' "Amazon S3" "false"
SectionEnd

SectionGroup "Database Bindings" SEC_Database
Section /o "MySQL" SEC_MySQL
        !insertmacro ISPYTHONPACKAGEINSTALLED "MySQLdb" "MySQL Python Bindings: MySQLdb"
        ${If} $0 != 0
        ;Check which version we're installing...
        StrCmp $pythonVersion "2.5" 0 else
	NSISdl::download "${MYSQLP2_DOWNLOAD_LOC}" ${MYSQLP_FILE}
        goto endif
	else:
	NSISdl::download "${MYSQLP_DOWNLOAD_LOC}" ${MYSQLP_FILE}
	endif:
	
        Pop $R0 ; Get the return value
        Strcmp $R0 "success" +3
             MessageBox MB_OK "Download failed: $R0"
             Abort "Download of ${MYSQLP2_DOWNLOAD_LOC} failed: $R0"

        ExecWait "${MYSQLP_FILE}" $output
        !insertmacro OUTPUTDETAILS "msql" "MySQL Python Bindings" "false"
        delete ${MYSQLP_FILE}
        ${EndIf}
SectionEnd
	
Section /o "PostgreSQL" SEC_POSTGRE
        !insertmacro ISPYTHONPACKAGEINSTALLED "psycopg2" "PostgreSQL Python Bindings: Psycopg"
        ${If} $0 != 0
        NSISdl::download "${POSTGRE_DOWNLOAD_LOC}" ${POSTGRE_FILE}
        
        Pop $R0 ; Get the return value
        Strcmp $R0 "success" +3
             MessageBox MB_OK "Download failed: $R0"
             Abort "Download of ${POSTGRE_DOWNLOAD_LOC} failed: $R0"

        ExecWait "${POSTGRE_FILE}" $output
        !insertmacro OUTPUTDETAILS "postgre" "PostgreSQL Python Bindings" "false"
        delete ${POSTGRE_FILE}
        ${EndIf}
SectionEnd

SectionGroupEnd

SectionGroup "Source Control Systems" SEC_SC
Section /o "Perforce" SEC_PER
	!insertmacro ISPYTHONPACKAGEINSTALLED "P4" "P4Python Python Bindings: P4"
        ${If} $0 != 0
        ;Check which version we're installing...
        StrCmp $pythonVersion "2.5" 0 else
	NSISdl::download "${P4PYTHON_2.5_DOWNLOAD_LOC}" ${P4PYTHON_FILE}
        goto endif
	else:
	NSISdl::download "${P4PYTHON_2.6_DOWNLOAD_LOC}" ${P4PYTHON_FILE}
	endif:
	
        Pop $R0 ; Get the return value
        Strcmp $R0 "success" +3
             MessageBox MB_OK "Download failed: $R0"
             Abort "Download of ${P4PYTHON_2.5_DOWNLOAD_LOC} failed: $R0"

        ExecWait "${P4PYTHON_FILE}" $output
        !insertmacro OUTPUTDETAILS "p4p" "P4Python Perforce Python Bindings" "false"
        delete ${P4PYTHON_FILE}
        ${EndIf}
SectionEnd
	
Section /o "Subversion" SEC_SVN
	!insertmacro ISPYTHONPACKAGEINSTALLED "pysvn" "PySVN Python Module: pysvn"
        ${If} $0 != 0
        StrCmp $pythonVersion "2.5" 0 else
	NSISdl::download "${PYSVN_DOWNLOAD_LOC}" ${PYSVN_FILE}
        goto endif
	else:
	NSISdl::download "${PYSVN2_DOWNLOAD_LOC}" ${PYSVN_FILE}
	endif:
	
        Pop $R0 ; Get the return value
        Strcmp $R0 "success" +3
             MessageBox MB_OK "Download failed: $R0"
             Abort "Download of ${PYSVN_DOWNLOAD_LOC} failed: $R0"

        ExecWait "${PYSVN_FILE}" $output
        !insertmacro OUTPUTDETAILS "svn" "PySVN Subversion Python Bindings" "false"
        delete ${PYSVN_FILE}
        ${EndIf}
SectionEnd
SectionGroupEnd

;---------------------------------------------------------------------------
;  Descriptions for each Section.
;---------------------------------------------------------------------------
LangString DESC_Section1 ${LANG_ENGLISH} "Required components of Reviewboard."
LangString DESC_Section12 ${LANG_ENGLISH} "Installs Python ${PYTHON_VERSION} and adds it to the PATH."
LangString DESC_Section13 ${LANG_ENGLISH} "Installs Python Setup Tools, a Python library for installing modules."
LangString DESC_Section14 ${LANG_ENGLISH} "Installs WinGNU Patch ${PATCH_VERSION}, used to create Reviewboard diff files."
LangString DESC_Section15 ${LANG_ENGLISH} "Installs Pycrypto."
LangString DESC_Section16 ${LANG_ENGLISH} "Installs Python Imaging Library."
LangString DESC_Section17 ${LANG_ENGLISH} "Installs Reviewboard, Django, and other dependencies."
LangString DESC_Section2 ${LANG_ENGLISH} "Depending on the database you intend to use, we must install the appropriate python bindings."
LangString DESC_Section3 ${LANG_ENGLISH} "Allows uploading screenshots."
LangString DESC_Section4 ${LANG_ENGLISH} "Installs Python bindings for MySQL ${MYSQL_VERSION} and lower. Allows reviewboard to work with a MySQL database."
LangString DESC_Section5 ${LANG_ENGLISH} "Installs Python bindings for PostgreSQL ${PG_VERSION}. Allows reviewboard to work with a PostgreSQL database."
LangString DESC_Section7 ${LANG_ENGLISH} "Speeds up performance."
LangString DESC_Section8 ${LANG_ENGLISH} "Reviewboard can work with Git, CVS, and Mercurial out of the box. For Perforce and SVN bindings are required."
LangString DESC_Section18 ${LANG_ENGLISH} "Installs P4Python to work with Perforce."
LangString DESC_Section19 ${LANG_ENGLISH} "Installs PySVN to work with Subversion"

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
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_Memcached} $(DESC_Section7)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_SC} $(DESC_Section8)
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

      ;default installation directory
      StrCpy $gMemcachedInstDir "C:\Program Files\Memcached"

      ;default version we install
      StrCpy $pythonVersion ${PYTHON_VERSION_DEF}

      Call GetPythonInstDir
      Call GetPatchInstDir
      
; Since we're downloading installs we have to set the size of the
; Components manually.
      SectionSetSize ${SEC_PST} 317
      SectionSetSize ${SEC_MySQL} 843
      SectionSetSize ${SEC_Python} 1337
      SectionSetSize ${SEC_Patch} 495
      SectionSetSize ${SEC_Pycrypto} 341
      SectionSetSize ${SEC_PIL} 678
      SectionSetSize ${SEC_Reviewboard} 163
      SectionSetSize ${SEC_MySQL} 843
      SectionSetSize ${SEC_POSTGRE} 597
      SectionSetSize ${SEC_Memcached} 84
      SectionSetSize ${SEC_Per} 554
      SectionSetSize ${SEC_SVN} 648
FunctionEnd

;Check to see if Python is installed, and where...
;We only check for "all users" and versions 2.5/2.6 -- don't support 2.4
Function GetPythonInstDir
        ReadRegStr $gPythonInstDir HKEY_LOCAL_MACHINE ${PYTHON6_INSTALL_KEY} ""
        StrCmp $gPythonInstDir "" check5 0
	StrCpy $pythonVersion "2.6"
        goto PythonInstalled
        
        check5:
        ReadRegStr $gPythonInstDir HKEY_LOCAL_MACHINE ${PYTHON5_INSTALL_KEY} ""
	StrCmp $gPythonInstDir "" donePython 0
	StrCpy $pythonVersion "2.5"

        PythonInstalled:
        ;python is installed
	StrCpy $gPythonInstalled "true"
	StrCpy $gPythonInstDir "$gPythonInstDir" -12
	
        donePython:
	;python is not installed
	StrCpy $gPythonInstDir ${DEFAULT_PYTHON_DIR}
FunctionEnd

; Searches the PATH for patch.exe. If found, sets the
; gPatchInstalled variable to "true", otherwise it's "".
Function GetPatchInstDir
         SearchPath $gPatchInstDir 'patch.exe'
         StrCmp $gPatchInstDir "" donePatch 0
         ;patch is installed
         StrCpy $gPatchInstalled "true"
         StrCpy $gPatchInstDir $gPatchInstDir -14
         DonePatch:
         ;patch is not installed
         StrCpy $gPatchInstDir ${DEFAULT_PATCH_DIR}
FunctionEnd


Function ForceHackyRO
!insertmacro SetSectionFlag ${SEC_Core} ${SF_RO}
FunctionEnd
