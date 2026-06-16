#!/bin/bash
# Nome: doc2pdf.sh
# Descricao: Converte arquivos .doc, .docx e .odt de um diretório para PDF. Opcionalmente
# aplica proteção contra cópia e impressão na exportação (LibreOffice >= 7.3).
# Dependencias necessárias (instale manualmente conforme a distro):
#   Debian/Ubuntu: sudo apt -y install libreoffice
#   Fedora:        sudo dnf -y install libreoffice
#   Flatpak:       flatpak install flathub org.libreoffice.LibreOffice
#   (LibreOffice via Flatpak é detectado e usado com preferência.)
# Autor: Gladiston Santana <gladiston[dot]santana[at]gmail[dot]com>
# Criacao: 02/10/2024
# Atualizado em: 16/06/2026
# Licenca: GPL (GNU General Public License)

###############################################################################
# Configurações (variáveis começam com 'v' em PascalCase)
###############################################################################
vDocOwnerPassword="a8b7X2z9"    # Senha de permissões (owner) na exportação PDF
vDocProtect=true                # true: protege PDFs (copia/impressão); false: não protege
vDocExportNotes=false           # true: tenta exportar notas como anotações PDF (pouco útil; padrão false)

# Padrões a ignorar silenciosamente (backup, temporários, scripts, versionamento)
# Qualquer arquivo cujo NOME contenha um destes padrões não terá mensagem 'Ignorando ...'
vIgnorePatterns=(".cmd" ".sh" ".ori" ".bak" ".old" ".tmp" ".temp" "~" ".swp")
vLibreOfficeFlatpakId="org.libreoffice.LibreOffice"
vLibreOfficeViaFlatpak=false

###############################################################################
# Funções
###############################################################################

print_usage() {  # uso resumido (erro)
  echo "Uso: $(basename "$0") [-h] [<dir_in> <dir_out>] [-doc_protect=true|false] [-doc_export_notes=true|false] [-doc_owner_password=xxxxx]"
  echo "Use '$(basename "$0") -h' para ver todas as opções e variáveis de ambiente."
}

print_help() {  # ajuda completa
  cat <<EOF
$(basename "$0") — Converte .doc, .docx e .odt para PDF (com proteção opcional).
Títulos/estilos de tópico do documento são exportados como marcadores (sumário) no PDF.
Por padrão, notas/comentários não são exportados como anotações PDF (-doc_export_notes=false).
A opção -doc_export_notes=true insere ícones no PDF, mas na prática a maioria dos leitores
não exibe o conteúdo ao passar o mouse (apenas ao clicar, se exibir) — uso limitado.

Uso:
  $(basename "$0") [-h] [<dir_in> <dir_out>] [opções]

Opções:
  -h, --help                 Exibe esta ajuda e encerra
  -doc_protect=true|false    Protege PDFs contra cópia e impressão (padrão: true)
  -doc_export_notes=true|false Exporta notas como anotações PDF (padrão: false; pouco útil)
  -doc_owner_password=senha  Senha de permissões na exportação PDF

Parâmetros posicionais:
  dir_in                     Diretório de entrada com os documentos
  dir_out                    Diretório de saída dos PDFs gerados

Variáveis de ambiente (substituem parâmetros quando omitidos):
  doc2pdf_in                 Equivalente a <dir_in>
  doc2pdf_out                Equivalente a <dir_out>
  doc2pdf_doc_protect        Equivalente a -doc_protect=true|false
  doc2pdf_doc_export_notes   Equivalente a -doc_export_notes=true|false
  doc2pdf_doc_owner_password Equivalente a -doc_owner_password=senha

Parâmetros na linha de comando têm prioridade sobre variáveis de ambiente.

Exemplos:
  $(basename "$0") ./entrada ./saida
  $(basename "$0") ./entrada ./saida -doc_protect=false
  doc2pdf_in=./entrada doc2pdf_out=./saida $(basename "$0")
EOF
}

handle_error() { # encerra com mensagem de erro
  local vMsg="$1"
  echo "ERRO: $vMsg" >&2
  exit 1
}


json_escape() { # escapa string para uso em valor JSON
  local vValue="$1"
  vValue="${vValue//\\/\\\\}"
  vValue="${vValue//\"/\\\"}"
  printf '%s' "$vValue"
}

build_pdf_convert_target() { # define filtro --convert-to (tópicos/marcadores sempre exportados)
  local vFilterParams vPwdJson vExportNotesJson

  if [[ "$vDocExportNotes" == true ]]; then
    vExportNotesJson="true"
  else
    vExportNotesJson="false"
  fi

  vFilterParams='"ExportBookmarks":{"type":"boolean","value":"true"}'
  vFilterParams+=',"ExportNotes":{"type":"boolean","value":"'${vExportNotesJson}'"}'
  vFilterParams+=',"ExportNotesInMargin":{"type":"boolean","value":"false"}'

  if [[ "$vDocProtect" == true ]]; then
    vPwdJson="$(json_escape "$vDocOwnerPassword")"
    vFilterParams+=',"RestrictPermissions":{"type":"boolean","value":"true"}'
    vFilterParams+=',"PermissionPassword":{"type":"string","value":"'${vPwdJson}'"}'
    vFilterParams+=',"Printing":{"type":"long","value":"0"}'
    vFilterParams+=',"EnableCopyingOfContent":{"type":"boolean","value":"false"}'
  fi

  printf '%s' "pdf:writer_pdf_Export:{${vFilterParams}}"
}

libreoffice_available_via_flatpak() {
  command -v flatpak >/dev/null 2>&1 \
    && flatpak info "$vLibreOfficeFlatpakId" >/dev/null 2>&1
}

suggest_libreoffice_install() {
  echo "LibreOffice não encontrado. Instale com um dos comandos abaixo:" >&2
  if command -v apt >/dev/null 2>&1; then
    echo "  sudo apt -y install libreoffice" >&2
  elif command -v dnf >/dev/null 2>&1; then
    echo "  sudo dnf -y install libreoffice" >&2
  fi
  echo "  flatpak install flathub $vLibreOfficeFlatpakId" >&2
}

ensure_libreoffice() {
  if libreoffice_available_via_flatpak; then
    vLibreOfficeViaFlatpak=true
    echo "Usando LibreOffice via Flatpak ($vLibreOfficeFlatpakId)."
    return 0
  fi
  if command -v libreoffice >/dev/null 2>&1; then
    vLibreOfficeViaFlatpak=false
    return 0
  fi
  suggest_libreoffice_install
  handle_error "LibreOffice não encontrado."
}

run_libreoffice() {
  if [[ "$vLibreOfficeViaFlatpak" == true ]]; then
    flatpak run "$vLibreOfficeFlatpakId" "$@"
  else
    libreoffice "$@"
  fi
}

ensure_out_dir() { # garante que vDirOut exista
  if [[ ! -d "$vDirOut" ]]; then
    read -p "Diretório $vDirOut não existe. Deseja criá-lo? (s/n) " vChoice
    if [[ "$vChoice" =~ ^[sS]$ ]]; then
      mkdir -p "$vDirOut"
      if [ $? -ne 0 ]; then
        handle_error "Falha ao criar diretório $vDirOut"
      fi
    else
      handle_error "Diretório de saída não disponível."
    fi
  fi
}

should_suppress_ignore_log() { # retorna 0 (verdadeiro) se deve suprimir 'Ignorando ...'
  local vNameLower="$1"
  local vFullPath="$2"
  # diretórios: não logar
  if [[ -d "$vFullPath" ]]; then
    return 0
  fi
  # padrões
  for pat in "${vIgnorePatterns[@]}"; do
    if [[ "$vNameLower" == *"$pat"* ]]; then
      return 0
    fi
  done
  return 1
}

convert_files() {  # faz a conversão LO -> PDF (com proteção opcional na exportação)
  local vConvertTo
  vConvertTo="$(build_pdf_convert_target)"

  # Permite que padrões sem correspondência expandam para vazio em vez de retornarem literalmente
  shopt -s nullglob
  for vFile in "$vDirIn"/*; do
    vBase="$(basename "$vFile")"
    vNameLower="${vBase,,}"

    case "$vFile" in
      *.doc|*.docx|*.odt)
        if [[ "$vDocProtect" == true ]]; then
          echo "Convertendo e protegendo $vBase..."
        else
          echo "Convertendo $vBase..."
        fi
        run_libreoffice --headless --convert-to "$vConvertTo" --outdir "$vDirOut" "$vFile"
        if [ $? -ne 0 ]; then
          handle_error "Falha ao converter $vBase"
        fi
        ;;
      *)
        if should_suppress_ignore_log "$vNameLower" "$vFile"; then
          continue
        fi
        echo "Ignorando $vFile (formato não suportado)."
        ;;
    esac
  done
  echo "Conversão concluída."
}

###############################################################################
# Início (validação e fluxo)
###############################################################################

# Valores opcionais a partir de variáveis de ambiente (podem ser sobrescritos na CLI)
[[ -n "${doc2pdf_doc_protect:-}" ]] && vDocProtect="$doc2pdf_doc_protect"
[[ -n "${doc2pdf_doc_export_notes:-}" ]] && vDocExportNotes="$doc2pdf_doc_export_notes"
[[ -n "${doc2pdf_doc_owner_password:-}" ]] && vDocOwnerPassword="$doc2pdf_doc_owner_password"

vDirIn=""
vDirOut=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -doc_protect=*)
      vDocProtect="${1#*=}"
      ;;
    -doc_export_notes=*)
      vDocExportNotes="${1#*=}"
      ;;
    -doc_owner_password=*)
      vDocOwnerPassword="${1#*=}"
      ;;
    -use_tool=*)
      echo "Aviso: parâmetro obsoleto '$1' (proteção agora é feita pelo LibreOffice na exportação)."
      ;;
    -*)
      echo "Aviso: parâmetro desconhecido '$1'"
      ;;
    *)
      if [[ -z "$vDirIn" ]]; then
        vDirIn="$1"
      elif [[ -z "$vDirOut" ]]; then
        vDirOut="$1"
      else
        echo "Aviso: parâmetro posicional ignorado '$1'"
      fi
      ;;
  esac
  shift
done

# Diretórios a partir de variáveis de ambiente, se omitidos na linha de comando
[[ -z "$vDirIn" && -n "${doc2pdf_in:-}" ]] && vDirIn="$doc2pdf_in"
[[ -z "$vDirOut" && -n "${doc2pdf_out:-}" ]] && vDirOut="$doc2pdf_out"

if [[ -z "$vDirIn" || -z "$vDirOut" ]]; then
  print_usage
  handle_error "Parâmetros obrigatórios ausentes (<dir_in> e <dir_out> ou doc2pdf_in/doc2pdf_out)."
fi

if [[ ! -d "$vDirIn" ]]; then
  handle_error "Diretório de entrada não encontrado: $vDirIn"
fi

# Verifica dependências (sugere instalação, não instala automaticamente)
ensure_libreoffice

# Garante saída e converte
ensure_out_dir
convert_files

# Fim
