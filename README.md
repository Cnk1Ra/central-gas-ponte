# Ponte da Bina — Central Gás (instalador)

App que faz a **bina aparecer ao vivo** na Central de Chamadas. Lê o caller-ID do
**HT814** (seu adaptador VoIP) e envia pro sistema. Não depende da JBFER.

## Instalar (Windows) — um clique

1. Baixe o **[INSTALAR-PONTE.bat](https://raw.githubusercontent.com/Cnk1Ra/central-gas-ponte/main/INSTALAR-PONTE.bat)** (clique com o botão direito → *Salvar link como…*).
2. **Dê dois cliques** no arquivo baixado.
   - Se o Windows mostrar um aviso azul (SmartScreen): *Mais informações → Executar assim mesmo*.
3. Quando pedir, **cole o TOKEN** e tecle Enter.
4. Pronto — a ponte fica rodando e **sobe sozinha quando o PC liga**.

## Configurar o HT814 (uma vez)

No painel do HT814 (http://192.168.2.2), em **Syslog**:
- **Syslog Server**: IP do PC onde você instalou.
- **Syslog Level**: `DEBUG`.

## Verificar se está tudo certo

Baixe e dê dois cliques no **[VERIFICAR.bat](https://raw.githubusercontent.com/Cnk1Ra/central-gas-ponte/main/VERIFICAR.bat)** —
ele mostra se a ponte está rodando, se sobe no boot, o IP do PC (pra pôr no HT814),
o firewall e as últimas linhas do log. Tire uma foto da tela e mande pro suporte.

## Testar

Faça uma ligação pro telefone da loja → deve aparecer na Central de Chamadas.

Se **não** aparecer, baixe e rode o **[APRENDER.bat](https://raw.githubusercontent.com/Cnk1Ra/central-gas-ponte/main/APRENDER.bat)**:
ele pausa a ponte e mostra na tela tudo que o HT814 mandar. Faça uma ligação de
teste, copie/fotografe o que aparecer e mande pro suporte. Depois rode o
**AUTOINICIO.bat** de novo pra religar a ponte normal.

---
*Não contém senha. A `service_role` nunca fica no PC; a ponte usa só a anon key + um token que entra na instalação.*
