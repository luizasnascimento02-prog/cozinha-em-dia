# Cozinha em Dia 🍳💗

App para planejar as refeições da semana (café, almoço, lanche e jantar), guardar receitas, ver pratos fáceis, calcular calorias (base TACO), montar a lista de compras e acompanhar o peso. Tem acesso só por CPF liberado, painel de administração com o uso de cada pessoa e SAC.

Funciona como **app instalável** (PWA): dá para colocar na tela inicial do celular, abre em tela cheia e continua funcionando sem internet (as mudanças são enviadas quando a conexão volta).

## Como as pessoas entram

1. A pessoa digita o CPF.
2. Se o CPF foi liberado pela administração, no primeiro acesso ela cria uma senha (mínimo 6 caracteres). Nos próximos, só digita a senha.
3. **A primeira pessoa que criar senha vira a administração do app.** Por isso, entre você primeiro, logo depois de publicar.

Se alguém esquecer a senha: Ajustes (engrenagem) → Administração → CPFs liberados → **Nova senha**. Os dados da pessoa continuam guardados e ela cria outra senha no próximo acesso.

## Colocando no ar (passo a passo)

### 1. Banco de dados (Supabase, grátis)
1. Crie uma conta em [supabase.com](https://supabase.com) (pode entrar com o GitHub).
2. **New project** → dê o nome `cozinha-em-dia`, crie uma senha para o banco (guarde) e escolha a região **South America (São Paulo)**.
3. No menu da esquerda abra **SQL Editor**, cole todo o conteúdo do arquivo [`supabase/setup.sql`](supabase/setup.sql) e clique em **Run**. Deve aparecer "Success".
4. Menu **Authentication → Sign In / Providers → Email**: **desligue "Confirm email"** e salve. (Ninguém recebe e-mail; o login é por CPF e senha.)
5. Clique em **Connect** (no topo) ou **Project Settings → API** e copie:
   - **Project URL** (algo como `https://abcd1234.supabase.co`)
   - a chave **publishable** (começa com `sb_publishable_`) ou, em projetos antigos, a **anon public**.
6. Cole esses dois valores no arquivo [`config.js`](config.js) (ou mande para o Claude colocar).

### 2. Hospedagem (Vercel, grátis)
1. Crie uma conta em [vercel.com](https://vercel.com) usando **Continue with GitHub**.
2. **Add New… → Project** → escolha o repositório `cozinha-em-dia` → **Import**.
3. Não precisa mudar nada (Framework: *Other*). Clique em **Deploy**.
4. Pronto! O endereço do app aparece no fim (algo como `cozinha-em-dia.vercel.app`).

Toda vez que um arquivo mudar no GitHub, a Vercel publica a nova versão sozinha.

### 3. Instalar no celular
- **Android (Chrome):** abra o endereço do app → menu ⋮ → **Instalar app** (ou "Adicionar à tela inicial").
- **iPhone (Safari):** abra o endereço → botão **Compartilhar** (quadrado com seta) → **Adicionar à Tela de Início**.

## Privacidade (LGPD)
- O CPF em texto fica só na tabela `liberados`, que apenas a administração consegue ler.
- O login usa um código gerado a partir do CPF (hash), não o CPF em si.
- Cada pessoa só lê e altera os próprios dados; as regras estão no banco (RLS) em `supabase/setup.sql`.

## Arquivos
| Arquivo | Para que serve |
|---|---|
| `index.html` | O app inteiro (telas, receitas, calorias, admin, SAC) |
| `config.js` | Endereço e chave pública do Supabase |
| `supabase/setup.sql` | Cria as tabelas e as regras de segurança |
| `manifest.webmanifest`, `icons/` | Nome, cores e ícone do app instalado |
| `sw.js` | Faz o app abrir sem internet. Ao mudar arquivos do app, aumente a `VERSAO` |
| `vendor/supabase.js` | Biblioteca do Supabase (v2.117.3) |
| `img/` | Ilustrações e tela de abertura |
