# PJe no Linux — Para Advogados ⚖️

**Você é advogado, acabou de instalar o Linux e não consegue usar o PJeOffice nem o eSAJ?**
Este repositório resolve tudo isso com **um único comando** — sem precisar entender de tecnologia.

Feito por um advogado, para advogados. Depois de horas de luta, reunimos aqui tudo que você precisa.

---

## O que isso instala?

Rodando **um único comando** no terminal, você terá:

| O que | Para que serve |
|---|---|
| **Google Chrome** | Navegador necessário para o eSAJ e outros sistemas judiciais |
| **PJeOffice Pro** | Assinador digital dos tribunais (CNJ) |
| **Driver do token** | Para o computador reconhecer seu certificado A3 (pendrive do certificado) |
| **Web Signer** | Plugin para assinar documentos no eSAJ/TJSP e outros tribunais SAJ |

---

## Como instalar — 3 passos simples

### Passo 1 — Abrir o Terminal

No Linux, o "Terminal" é equivalente ao Prompt de Comando do Windows. Para abrir:

- Pressione as teclas **Ctrl + Alt + T** ao mesmo tempo
- Ou procure por "Terminal" no menu de aplicativos

Uma janela preta com texto vai abrir. Não se assuste — é normal!

### Passo 2 — Copiar e colar o comando

Clique na área abaixo para copiar, depois cole no terminal com **Ctrl + Shift + V** e pressione **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/vitorcanoas/pje-no-linux/main/instalar.sh | bash
```

O script vai pedir sua **senha de administrador** (a mesma senha que você usa para ligar o computador). Quando digitar a senha, as letras não aparecem na tela — isso é normal, é uma proteção do sistema.

### Passo 3 — Aguardar a instalação

O processo leva alguns minutos dependendo da sua internet. Quando terminar, vai aparecer uma mensagem de sucesso com as instruções finais.

---

## Após a instalação — configurar o Web Signer para o eSAJ

O Web Signer precisa de uma configuração rápida no navegador. Faça isso uma única vez:

1. Abra o **Google Chrome** (instalado pelo script)
2. Acesse o **eSAJ** do seu tribunal
3. Clique em **"Certificado digital"**
4. Clique no ícone do **Web Signer** na barra do Chrome (ícone de escudo azul)
5. Vá em **Configurações** (ícone de engrenagem ⚙️)
6. Clique na aba **"Cripto Dispositivos"**
7. No campo **"Nome do arquivo SO"**, digite exatamente: `libeToken.so`
8. Clique no botão **+**
9. Volte para o eSAJ e clique em **Recarregar**

Pronto! Seu certificado vai aparecer na lista e você poderá entrar com o PIN.

> ⚠️ **Atenção:** Use sempre o **Google Chrome instalado pelo script** — não o Chrome que veio pré-instalado no sistema (que pode ser uma versão diferente incompatível com o Web Signer).

---

## Meu token funciona com este script?

| Como é o token | Nome | Funciona? |
|---|---|---|
| Pendrive preto ou cinza com logo SafeNet/Certisign | eToken 5100 ou 5110 | ✅ Sim |
| Pendrive azul com logo G&D ou Certisign | GD Starsign | ✅ Sim |
| Cartão com chip + leitor USB | Smart card | ✅ Sim |

**Não sabe qual é o seu?** Olhe o token físico — o fabricante está impresso nele. Se vier da Certisign em formato de pendrive preto/cinza, é SafeNet eToken.

---

## Sistemas operacionais compatíveis

| Sistema | Versão | Testado |
|---|---|---|
| Zorin OS | 17 e 18 | ✅ |
| Ubuntu | 22.04 e 24.04 | ✅ |
| Linux Mint | 21 e 22 | ✅ |

---

## Dúvidas frequentes

**"O PJeOffice abriu mas a lista de certificados está vazia"**
→ Verifique se o token está bem encaixado na porta USB. Tente em outra porta USB. Desconecte e reconecte.

**"O certificado aparece em vermelho"**
→ Certificado vencido. Selecione o que está em preto — é o válido. Os vermelhos são versões antigas expiradas.

**"O site do tribunal diz que o PJeOffice não está instalado"**
→ Abra o PJeOffice primeiro (ícone na área de trabalho), espere ele carregar, depois acesse o site.

**"Esqueci o PIN do token"**
→ Entre em contato com o emissor do seu certificado (Certisign, OAB, Serasa, etc.). Eles podem desbloquear.

**"Instalei mas não funcionou"**
→ Abra uma [dúvida aqui](https://github.com/vitorcanoas/pje-no-linux/issues) informando seu sistema operacional e o modelo do token. Tentaremos ajudar.

---

## Precisa reinstalar? (ex: formatou o computador)

Basta rodar o mesmo comando novamente:

```bash
curl -fsSL https://raw.githubusercontent.com/vitorcanoas/pje-no-linux/main/instalar.sh | bash
```

---

## Quer contribuir?

Se este guia te ajudou e você quer ajudar outros colegas advogados:
- Compartilhe com sua OAB seccional
- Abra um [Pull Request](https://github.com/vitorcanoas/pje-no-linux/pulls) com melhorias
- Reporte problemas em [Issues](https://github.com/vitorcanoas/pje-no-linux/issues)

---

*Feito com ☕ e muita paciência por [Vitor Canoas](https://github.com/vitorcanoas) — advogado que migrou para o Linux e sobreviveu para contar a história.*
