#!/bin/bash

# Este script converte arquivos MSWord do tipo .doc, .docx ou .odt que estiverem
# na pasta fornecida como primeiro argumento e os converte para PDF, colocando-os
# na pasta informada pela variável $vdir_out.
# Se a proteção estiver ativada, o PDF será protegido contra cópia de texto e impressão.
# Dependencias necessárias:
# 1) Requer o LibreOffice instalado. Se não estiver instalado, use:
#    sudo apt -y install libreoffice
# 2) Se o pdftk não estiver instalado, use: 
#    sudo apt -y install pdftk
# 3) Se o qpdf não estiver instalado, use:
#    sudo apt -y install qpdf
#
# Autor: Gladiston Santana <gladiston[dot]santana[at]gmail[dot]com>
# Data: 02/10/2024
#
# Licença: GPL (GNU General Public License)
#
# Variáveis padrão de saída, tipos de arquivos e proteção
vdir_out=""
vdoc_types="doc,docx,odt"
vuse_tool="pdftk"  # O padrão será o pdftk, mas pode ser alterado para qpdf
vdoc_protect=true  # Por padrão, aplica proteção contra cópia e impressão
vdoc_owner_password="a8b7X2z9"  # Senha padrão para criptografia, usada apenas para proteção

# Função para tratar erros e encerrar o script
handle_error() {
  echo "Erro: $1"
  exit 1
}

# Verificar se libreoffice está instalado
if ! command -v libreoffice &> /dev/null; then
  handle_error "O LibreOffice não está instalado. Instale-o com:
    sudo apt -y install libreoffice"
fi

# Se o primeiro argumento for um diretório existente, assuma como vdir_in
if [ -d "$1" ]; then
  vdir_in="$1"
  shift
else
  handle_error "O primeiro argumento deve ser um diretório válido."
fi

# Processar os argumentos da linha de comando
for varg in "$@"; do
  case $varg in
    --dir_out=*)
      vdir_out="${varg#*=}"
      shift
      ;;
    --doc_type=*)
      vdoc_types="${varg#*=}"
      shift
      ;;
    --doc_protect=false)
      vdoc_protect=false
      shift
      ;;
    --doc_owner_password=*)
      vdoc_owner_password="${varg#*=}"
      shift
      ;;
    --use=*)
      vuse_tool="${varg#*=}"
      shift
      ;;
    *)
      # Argumento desconhecido
      echo "Uso: $0 [diretorio] [--dir_out=path] [--doc_type=extensoes] [--doc_protect=true/false] [--doc_owner_password=sua_senha] [--use=pdftk/qpdf]"
      exit 1
      ;;
  esac
done

# Se vdir_out não foi especificado na linha de comando, assume-se vdir_in/pdf
if [ -z "$vdir_out" ]; then
  vdir_out="$vdir_in/pdf"
fi

# Verificar se a pasta vdir_out existe, e se não, criar a pasta
if [ ! -d "$vdir_out" ]; then
  vparent_dir=$(dirname "$vdir_out")
  if [ -d "$vparent_dir" ]; then
    echo "Criando diretório de saída: $vdir_out"
    mkdir -p "$vdir_out" || handle_error "Falha ao criar o diretório $vdir_out"
  else
    handle_error "O diretório pai $vparent_dir não existe. Não foi possível criar $vdir_out."
  fi
fi

# Verificar a ferramenta a ser usada com base no argumento --use
if [ "$vuse_tool" = "pdftk" ]; then
  if ! command -v pdftk &> /dev/null; then
    handle_error "O pdftk não está instalado. Instale-o com:
      sudo apt -y install pdftk"
  fi
elif [ "$vuse_tool" = "qpdf" ]; then
  if ! command -v qpdf &> /dev/null; then
    handle_error "O qpdf não está instalado. Instale-o com:
      sudo apt -y install qpdf"
  fi
else
  handle_error "O argumento --use deve ser 'pdftk' ou 'qpdf'."
fi

# Converte a lista de tipos de arquivos em um array
IFS=',' read -r -a vtypes_array <<< "$vdoc_types"

# Loop para encontrar e converter arquivos de cada tipo especificado
for ext in "${vtypes_array[@]}"; do
  for file in "$vdir_in"/*."$ext"; do
    if [ -f "$file" ]; then
      # Obtém o nome do arquivo sem a extensão
      vfilename=$(basename "$file")
      vbase_filename="${vfilename%.*}"

      # Define o caminho do arquivo PDF de saída
      vpdf_file="$vdir_out/$vbase_filename.pdf"

      # Verifica se o arquivo PDF já existe e o apaga antes de criar um novo
      if [ -f "$vpdf_file" ]; then
        echo "Removendo arquivo PDF existente: $vpdf_file"
        rm -f "$vpdf_file" || handle_error "Erro ao remover $vpdf_file"
      fi

      echo "Convertendo $file para PDF..."
      libreoffice --headless --convert-to pdf --outdir "$vdir_out" "$file" || handle_error "$file"

      # Montar as permissões para pdftk ou qpdf com base no argumento --use e na variável vdoc_protect
      if [ -f "$vpdf_file" ]; then
        if [ "$vuse_tool" = "pdftk" ]; then
          if [ "$vdoc_protect" = true ]; then
            pdftk "$vpdf_file" output "${vpdf_file%.pdf}-protected.pdf" owner_pw "$vdoc_owner_password" allow AllFeatures || handle_error "$vpdf_file"
            mv "${vpdf_file%.pdf}-protected.pdf" "$vpdf_file" || handle_error "$vpdf_file"
            echo "Proteção aplicada em $vpdf_file com pdftk"
          else
            echo "Nenhuma proteção aplicada em $vpdf_file"
          fi
        elif [ "$vuse_tool" = "qpdf" ]; then
          if [ "$vdoc_protect" = true ]; then
            qpdf --encrypt "" "$vdoc_owner_password" 256 \
                 --print=none --modify=none --extract=n \
                 -- "$vpdf_file" "${vpdf_file%.pdf}-protected.pdf" || handle_error "$vpdf_file"
          else
            qpdf --encrypt "" "$vdoc_owner_password" 256 \
                 -- "$vpdf_file" "${vpdf_file%.pdf}-protected.pdf" || handle_error "$vpdf_file"
          fi
          mv "${vpdf_file%.pdf}-protected.pdf" "$vpdf_file" || handle_error "$vpdf_file"
          echo "Proteção aplicada em $vpdf_file com qpdf"
        fi
      else
        handle_error "$vpdf_file"
      fi
    fi
  done
done

echo "Conversão concluída."

