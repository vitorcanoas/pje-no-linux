# speckit.agent

Leia o arquivo `TECH_STACK.md` integralmente. Com base na descrição do projeto fornecida pelo usuário (`$ARGUMENTS`), preencha o documento tomando decisões técnicas em cada pergunta.

## O que fazer

1. Leia cada seção e cada pergunta do `TECH_STACK.md`.
2. Com base na descrição do projeto (`$ARGUMENTS`), escolha a opção mais adequada para cada pergunta usando os critérios abaixo.
3. Edite o arquivo `TECH_STACK.md`:
   - Mantenha apenas a opção escolhida e remova a outra.
   - Logo abaixo da opção escolhida, adicione: `> 💡 Motivo: [justificativa de 1 a 2 linhas]`
4. Ao final, apresente um resumo das decisões tomadas, agrupadas por seção.

## Critérios de decisão

- **MVP / fase inicial:** priorize simplicidade e velocidade de entrega.
- **Equipe pequena (1–3 devs):** evite complexidade desnecessária.
- **Dados sensíveis (financeiro, saúde):** priorize segurança e auditoria.
- **SaaS:** atenção a multi-tenancy, planos e faturamento.
- **SEO importante:** prefira SSR a SPA.
- **Alta concorrência esperada:** considere cache, filas e indexação.
- **Dúvida:** escolha a opção mais simples e documente o motivo.

## Uso

/speckit.agent [descrição do projeto em 1-3 frases]

Exemplo:
/speckit.agent SaaS de gestão financeira para pequenas empresas, time de 2 devs, MVP com planos Free e Pro
