@echo off
rem Nome: doc2pdf.bat
rem Descricao: Converte arquivos .doc, .docx e .odt de um diretorio para PDF. Opcionalmente
rem   aplica protecao contra copia e impressao na exportacao (LibreOffice >= 7.3).
rem Dependencia: LibreOffice instalado (soffice.exe no PATH ou em Program Files)
rem Autor: Gladiston Santana <gladiston[dot]santana[at]gmail[dot]com>
rem Criacao: 02/10/2024
rem Atualizado em: 16/06/2026
rem Licenca: GPL (GNU General Public License)

setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1

rem --- Configuracoes (variaveis com prefixo v em PascalCase) ---
set "vDocOwnerPassword=a8b7X2z9"
set "vDocProtect=true"
set "vDocExportNotes=false"
set "vDirIn="
set "vDirOut="
set "vSoffice="

rem --- Valores opcionais a partir de variaveis de ambiente ---
if defined doc2pdf_doc_protect set "vDocProtect=%doc2pdf_doc_protect%"
if defined doc2pdf_doc_export_notes set "vDocExportNotes=%doc2pdf_doc_export_notes%"
if defined doc2pdf_doc_owner_password set "vDocOwnerPassword=%doc2pdf_doc_owner_password%"

rem --- Parse de argumentos ---
:parse_args
if "%~1"=="" goto :parse_done

if /i "%~1"=="-h" goto :print_help
if /i "%~1"=="--help" goto :print_help

set "vArg=%~1"
if /i "!vArg:~0,14!"=="-doc_protect=" (
  set "vDocProtect=!vArg:~14!"
  goto :parse_shift
)
if /i "!vArg:~0,18!"=="-doc_export_notes=" (
  set "vDocExportNotes=!vArg:~18!"
  goto :parse_shift
)
if /i "!vArg:~0,21!"=="-doc_owner_password=" (
  set "vDocOwnerPassword=!vArg:~21!"
  goto :parse_shift
)
if /i "!vArg:~0,10!"=="-use_tool=" (
  echo Aviso: parametro obsoleto '!vArg!' ^(protecao agora e feita pelo LibreOffice na exportacao.^)
  goto :parse_shift
)

if "!vArg:~0,1!"=="-" (
  echo Aviso: parametro desconhecido '!vArg!'
  goto :parse_shift
)

if not defined vDirIn (
  set "vDirIn=%~f1"
  goto :parse_shift
)
if not defined vDirOut (
  set "vDirOut=%~f1"
  goto :parse_shift
)

echo Aviso: parametro posicional ignorado '%~1'
:parse_shift
shift
goto :parse_args

:parse_done
if not defined vDirIn if defined doc2pdf_in set "vDirIn=%doc2pdf_in%"
if not defined vDirOut if defined doc2pdf_out set "vDirOut=%doc2pdf_out%"

rem Normaliza caminhos (suporta relativos; use aspas em caminhos com espacos)
if defined vDirIn for %%I in ("!vDirIn!") do set "vDirIn=%%~fI"
if defined vDirOut for %%I in ("!vDirOut!") do set "vDirOut=%%~fI"

if not defined vDirIn goto :missing_dirs
if not defined vDirOut goto :missing_dirs
goto :dirs_ok

:missing_dirs
call :print_usage
call :handle_error "Parametros obrigatorios ausentes (^<dir_in^> e ^<dir_out^> ou doc2pdf_in/doc2pdf_out)."
exit /b 1

:dirs_ok
if not exist "%vDirIn%\" (
  call :handle_error "Diretorio de entrada nao encontrado: %vDirIn%"
  exit /b 1
)

call :ensure_libreoffice
if errorlevel 1 exit /b 1

call :ensure_out_dir
if errorlevel 1 exit /b 1

call :convert_files
if errorlevel 1 exit /b 1

echo Conversao concluida.
exit /b 0

rem ===========================================================================
rem Subrotinas
rem ===========================================================================

:print_usage
echo Uso: %~nx0 [-h] [^<dir_in^> ^<dir_out^>] [-doc_protect=true^|false] [-doc_export_notes=true^|false] [-doc_owner_password=xxxxx]
echo Use '%~nx0 -h' para ver todas as opcoes e variaveis de ambiente.
exit /b 0

:print_help
call :print_usage
echo.
echo %~nx0 — Converte .doc, .docx e .odt para PDF ^(com protecao opcional^).
echo Titulos/estilos de topico do documento sao exportados como marcadores ^(sumario^) no PDF.
echo Por padrao, notas/comentarios nao sao exportados como anotacoes PDF ^(-doc_export_notes=false^).
echo A opcao -doc_export_notes=true insere icones no PDF, mas na pratica a maioria dos leitores
echo nao exibe o conteudo ao passar o mouse ^(apenas ao clicar, se exibir^) — uso limitado.
echo.
echo Opcoes:
echo   -h, --help                 Exibe esta ajuda e encerra
echo   -doc_protect=true^|false    Protege PDFs contra copia e impressao ^(padrao: true^)
echo   -doc_export_notes=true^|false Exporta notas como anotacoes PDF ^(padrao: false; pouco util^)
echo   -doc_owner_password=senha  Senha de permissoes na exportacao PDF
echo.
echo Parametros posicionais:
echo   dir_in                     Diretorio de entrada com os documentos
echo   dir_out                    Diretorio de saida dos PDFs gerados
echo.
echo Variaveis de ambiente ^(substituem parametros quando omitidos^):
echo   doc2pdf_in                 Equivalente a ^<dir_in^>
echo   doc2pdf_out                Equivalente a ^<dir_out^>
echo   doc2pdf_doc_protect        Equivalente a -doc_protect=true^|false
echo   doc2pdf_doc_export_notes   Equivalente a -doc_export_notes=true^|false
echo   doc2pdf_doc_owner_password Equivalente a -doc_owner_password=senha
echo.
echo Parametros na linha de comando tem prioridade sobre variaveis de ambiente.
echo.
echo Exemplos:
echo   %~nx0 "C:\Meus Documentos\entrada" "C:\Meus Documentos\saida"
echo   %~nx0 ".\entrada" ".\saida" -doc_protect=false
echo   set doc2pdf_in=.\entrada^& set doc2pdf_out=.\saida^& %~nx0
exit /b 0

:handle_error
echo ERRO: %~1 1>&2
exit /b 1

:json_escape
set "vPwdJson=%~1"
set "vPwdJson=!vPwdJson:\=\\!"
set "vPwdJson=!vPwdJson:"=\"!"
exit /b 0

:build_pdf_convert_target
if /i "!vDocExportNotes!"=="true" (
  set "vExportNotesJson=true"
) else (
  set "vExportNotesJson=false"
)

rem JSON sem aspas externas no SET (formato exigido pelo soffice.exe no Windows)
set "vFilterParams={\"ExportBookmarks\":{\"type\":\"boolean\",\"value\":\"true\"}"
set "vFilterParams=!vFilterParams!,\"ExportNotes\":{\"type\":\"boolean\",\"value\":\"!vExportNotesJson!\"}"
set "vFilterParams=!vFilterParams!,\"ExportNotesInMargin\":{\"type\":\"boolean\",\"value\":\"false\"}"

if /i "!vDocProtect!"=="true" (
  call :json_escape "!vDocOwnerPassword!"
  set "vFilterParams=!vFilterParams!,\"RestrictPermissions\":{\"type\":\"boolean\",\"value\":\"true\"}"
  set "vFilterParams=!vFilterParams!,\"PermissionPassword\":{\"type\":\"string\",\"value\":\"!vPwdJson!\"}"
  set "vFilterParams=!vFilterParams!,\"Printing\":{\"type\":\"long\",\"value\":\"0\"}"
  set "vFilterParams=!vFilterParams!,\"EnableCopyingOfContent\":{\"type\":\"boolean\",\"value\":\"false\"}"
)

set "vConvertTo=pdf:writer_pdf_Export:!vFilterParams!}"
exit /b 0

:ensure_libreoffice
set "vSoffice="

if exist "%ProgramFiles%\LibreOffice\program\soffice.exe" (
  set "vSoffice=%ProgramFiles%\LibreOffice\program\soffice.exe"
  goto :ensure_libreoffice_ok
)
if exist "%ProgramFiles(x86)%\LibreOffice\program\soffice.exe" (
  set "vSoffice=%ProgramFiles(x86)%\LibreOffice\program\soffice.exe"
  goto :ensure_libreoffice_ok
)

for /f "delims=" %%I in ('where soffice.exe 2^>nul') do (
  if not defined vSoffice set "vSoffice=%%~fI"
)
if defined vSoffice goto :ensure_libreoffice_ok

echo LibreOffice nao encontrado. Instale com um dos comandos abaixo: 1>&2
echo   winget install TheDocumentFoundation.LibreOffice 1>&2
echo   https://www.libreoffice.org/download/download/ 1>&2
call :handle_error "LibreOffice nao encontrado."
exit /b 1

:ensure_libreoffice_ok
echo Usando LibreOffice: "!vSoffice!"
exit /b 0

:ensure_out_dir
if exist "%vDirOut%\" exit /b 0

set /p "vChoice=Diretorio %vDirOut% nao existe. Deseja cria-lo? (s/n) "
if /i "!vChoice!"=="s" (
  mkdir "%vDirOut%" 2>nul
  if errorlevel 1 (
    call :handle_error "Falha ao criar diretorio %vDirOut%"
    exit /b 1
  )
  exit /b 0
)
call :handle_error "Diretorio de saida nao disponivel."
exit /b 1

:should_suppress_ignore_log
rem Retorna ERRORLEVEL 0 (verdadeiro) se deve suprimir mensagem 'Ignorando ...'
set "vBase=%~1"
if exist "%~2\" exit /b 0

for %%P in (.cmd .sh .ori .bak .old .tmp .temp .swp) do (
  echo !vBase!| findstr /i /c:"%%P" >nul && exit /b 0
)
echo !vBase!| findstr /i /c:"~" >nul && exit /b 0
exit /b 1

:convert_files
call :build_pdf_convert_target

for %%F in ("%vDirIn%\*") do (
  set "vFile=%%~fF"
  set "vBase=%%~nxF"
  set "vExt=%%~xF"

  if exist "%%~fF\" (
    rem diretorio: ignorar silenciosamente
  ) else if /i "!vExt!"==".doc" (
    call :convert_one_file
    if errorlevel 1 exit /b 1
  ) else if /i "!vExt!"==".docx" (
    call :convert_one_file
    if errorlevel 1 exit /b 1
  ) else if /i "!vExt!"==".odt" (
    call :convert_one_file
    if errorlevel 1 exit /b 1
  ) else (
    call :should_suppress_ignore_log "!vBase!" "!vFile!"
    if errorlevel 1 echo Ignorando "!vFile!" ^(formato nao suportado.^)
  )
)
exit /b 0

:convert_one_file
if /i "!vDocProtect!"=="true" (
  echo Convertendo e protegendo !vBase!...
) else (
  echo Convertendo !vBase!...
)

"!vSoffice!" --headless --convert-to !vConvertTo! --outdir "%vDirOut%" "!vFile!"
if errorlevel 1 (
  call :handle_error "Falha ao converter !vBase!"
  exit /b 1
)
exit /b 0
