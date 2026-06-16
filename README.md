# doc2pdf

Converte em lote arquivos **.doc**, **.docx** e **.odt** para **PDF** usando o LibreOffice, com opções de proteção e exportação de marcadores (sumário).

Disponível para **Linux** (`doc2pdf.sh`) e **Windows** (`doc2pdf.bat`), com a mesma interface de parâmetros e variáveis de ambiente.

## Recursos

- Conversão em lote de todos os documentos suportados em um diretório
- Exportação de **tópicos/marcadores** do documento como sumário navegável no PDF
- Proteção opcional contra **impressão** e **cópia/colar** (LibreOffice ≥ 7.3)
- Suporte a **variáveis de ambiente** para automação (cron, scripts, agendador de tarefas)
- Caminhos com **espaços** suportados (use aspas no Windows e no Linux)
- No Linux, detecta e prefere o LibreOffice instalado via **Flatpak**

## Requisitos

| Plataforma | Dependência |
|------------|-------------|
| Linux      | [LibreOffice](https://www.libreoffice.org/) (pacote nativo ou Flatpak) |
| Windows    | [LibreOffice](https://www.libreoffice.org/) (`soffice.exe`) |

### Instalação do LibreOffice

**Debian/Ubuntu:**
```bash
sudo apt install libreoffice
```

**Fedora:**
```bash
sudo dnf install libreoffice
```

**Flatpak (Linux):**
```bash
flatpak install flathub org.libreoffice.LibreOffice
```

**Windows:**
```bat
winget install TheDocumentFoundation.LibreOffice
```

O script **não instala** dependências automaticamente; apenas indica como instalar se o LibreOffice não for encontrado.

## Uso rápido

### Linux

```bash
chmod +x doc2pdf.sh
./doc2pdf.sh ./entrada ./saida
```

### Windows

```bat
doc2pdf.bat "C:\Meus Documentos\entrada" "C:\Meus Documentos\saida"
```

### Ajuda

```bash
./doc2pdf.sh -h
```

```bat
doc2pdf.bat -h
```

## Parâmetros

| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| `<dir_in>` | — | Diretório de entrada com os documentos |
| `<dir_out>` | — | Diretório de saída dos PDFs gerados |
| `-doc_protect=true\|false` | `true` | Protege PDFs contra cópia e impressão |
| `-doc_export_notes=true\|false` | `false` | Exporta notas como anotações PDF (uso limitado; ver abaixo) |
| `-doc_owner_password=senha` | `a8b7X2z9` | Senha de permissões (owner) na exportação |

Parâmetros na linha de comando têm **prioridade** sobre variáveis de ambiente.

## Variáveis de ambiente

| Variável | Equivalente |
|----------|-------------|
| `doc2pdf_in` | `<dir_in>` |
| `doc2pdf_out` | `<dir_out>` |
| `doc2pdf_doc_protect` | `-doc_protect=true\|false` |
| `doc2pdf_doc_export_notes` | `-doc_export_notes=true\|false` |
| `doc2pdf_doc_owner_password` | `-doc_owner_password=senha` |

### Exemplo com variáveis de ambiente

**Linux:**
```bash
doc2pdf_in=./entrada doc2pdf_out=./saida doc2pdf_doc_protect=false ./doc2pdf.sh
```

**Windows:**
```bat
set "doc2pdf_in=C:\Meus Documentos\entrada"
set "doc2pdf_out=C:\Meus Documentos\saida pdf"
set doc2pdf_doc_protect=false
doc2pdf.bat
```

## Exemplos

Converter sem proteção:
```bash
./doc2pdf.sh ./entrada ./saida -doc_protect=false
```

Converter com senha personalizada:
```bash
./doc2pdf.sh ./entrada ./saida -doc_owner_password=minhasenha
```

Caminhos com espaços (Windows):
```bat
doc2pdf.bat "D:\Trabalho\docs entrada" "D:\Trabalho\docs pdf" -doc_protect=false
```

Caminhos com espaços (Linux):
```bash
./doc2pdf.sh "./minha pasta/entrada" "./minha pasta/saida"
```

## Comportamento da exportação

O LibreOffice exporta com o filtro `writer_pdf_Export` configurado para:

| Opção | Valor | Efeito |
|-------|-------|--------|
| `ExportBookmarks` | `true` | Títulos/estilos de tópico viram marcadores no PDF |
| `ExportNotes` | conforme parâmetro | Anotações/comentários no PDF (padrão: desligado) |
| `ExportNotesInMargin` | `false` | Não exporta anotações na margem |
| `RestrictPermissions` | se `-doc_protect=true` | Restringe impressão e cópia |

Com `-doc_protect=true`, o PDF pode ser aberto normalmente, mas impressão e cópia do conteúdo ficam bloqueadas nos leitores que respeitam as permissões do PDF.

## Arquivos ignorados

São processados apenas `.doc`, `.docx` e `.odt`. Outros arquivos no diretório de entrada são ignorados. Alguns padrões no nome do arquivo são suprimidos silenciosamente (sem mensagem), como `.bak`, `.tmp`, `.sh`, `.cmd`, etc.

Se o diretório de saída não existir, o script pergunta se deseja criá-lo.

## Limitações conhecidas

- **Proteção PDF** não é inquebrável; impede uso casual, mas ferramentas especializadas podem contornar.
- **Notas de rodapé no PDF** são exportadas como links internos (“ir para…”), não como popup ao passar o mouse.
- **`-doc_export_notes=true`** insere ícones de anotação, mas a maioria dos leitores PDF não exibe o conteúdo no hover — por isso o padrão é `false`.
- Requer **LibreOffice 7.3+** para os parâmetros de proteção e filtro na linha de comando.

## Estrutura do repositório

```
doc2pdf.sh      # Script para Linux (bash)
doc2pdf.bat     # Script para Windows (CMD)
README.md       # Este arquivo
```

## Licença

GPL (GNU General Public License)

## Autor

Gladiston Santana — gladiston.santana@gmail.com
