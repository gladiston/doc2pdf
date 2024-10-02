# doc2pdf - PDF Converter Script
Converte documentos libreoffice/msoffice para PDF acrescentando proteção contra cópia de texto e impressão.

Este script Bash converte arquivos do Microsoft Word (.doc, .docx) e OpenDocument (.odt) para PDF usando o LibreOffice. 
O script oferece opções para proteger os arquivos PDF contra cópia, impressão e modificação, usando `pdftk` ou `qpdf`.

## Requisitos

- **LibreOffice** para converter os arquivos para PDF.
- **pdftk** ou **qpdf** para aplicar proteção aos PDFs.
  
### Instalação de dependências:

Para instalar as dependências, use os seguintes comandos:

```bash
sudo apt -y install libreoffice
sudo apt -y install pdftk
sudo apt -y install qpdf
```
## Uso 
Comando básico:  
```bash
./script.sh [diretório_de_entrada] [opções]
```
## Parâmetros:
diretório_de_entrada: O diretório onde os arquivos .doc, .docx, ou .odt estão localizados.  
Opções:  
*--dir_out*=path: Define o diretório de saída para os PDFs convertidos. Se não for especificado, será criado um diretório chamado pdf dentro do diretório de entrada.  
--doc_type=extensões: Especifica os tipos de arquivos a serem convertidos (por exemplo, --type=doc,docx,odt). O padrão é doc,docx,odt.  
--doc_protect=true/false: Aplica proteção aos PDFs. O padrão é true.  
--doc_owner_password=sua_senha: Define a senha do proprietário do PDF para criptografia (usada com pdftk ou qpdf).  
--use=pdftk/qpdf: Define a ferramenta a ser usada para proteger os PDFs. O padrão é pdftk.  
