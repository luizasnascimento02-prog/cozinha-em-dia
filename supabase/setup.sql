-- =====================================================================
-- Cozinha em Dia: configuração do banco de dados (Supabase)
-- Cole TUDO isto no "SQL Editor" do Supabase e clique em "Run".
-- Pode rodar de novo sem problema: o script não apaga dados.
-- =====================================================================
--
-- Como o acesso funciona
-- * Cada pessoa entra com CPF + senha. O CPF vira um código (hash) e a
--   conta no Supabase usa o e-mail técnico "<hash>@cozinhaemdia.app".
--   Ninguém recebe e-mail; é só a forma de guardar o login.
-- * Só consegue criar senha quem tem o CPF liberado pela administração.
-- * A PRIMEIRA pessoa que criar senha vira a administração do app.
-- * O CPF em texto fica só na tabela "liberados", que apenas a
--   administração consegue ler (LGPD: dado pessoal, acesso restrito).

-- ---------- tabelas ----------
create table if not exists public.liberados (
  cpf_hash  text primary key,
  nome      text not null check (char_length(nome) <= 80),
  cpf       text not null check (cpf ~ '^\d{11}$'),
  criado_em timestamptz not null default now()
);

create table if not exists public.admins (
  cpf_hash text primary key
);

create table if not exists public.dados (
  cpf_hash      text primary key,
  conteudo      jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now()
);

create table if not exists public.uso (
  cpf_hash         text primary key,
  admin            boolean not null default false,
  acessos          int not null default 0,
  primeiro_acesso  timestamptz not null default now(),
  ultimo_acesso    timestamptz not null default now(),
  ultima_atividade timestamptz not null default now(),
  receitas         int not null default 0,
  refeicoes        int not null default 0
);

create table if not exists public.sac (
  cpf_hash  text primary key,
  mensagens jsonb not null default '[]'::jsonb,
  pendente  boolean not null default false,
  ultima    timestamptz not null default now()
);

-- ---------- funções de apoio ----------
create or replace function public.meu_hash() returns text
language sql stable as $$
  select split_part(coalesce(auth.jwt() ->> 'email', ''), '@', 1)
$$;

create or replace function public.sou_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where cpf_hash = meu_hash() and meu_hash() <> '')
$$;

create or replace function public.estou_liberado() returns boolean
language sql stable security definer set search_path = public as $$
  select meu_hash() <> '' and (
    exists (select 1 from liberados where cpf_hash = meu_hash())
    or exists (select 1 from admins where cpf_hash = meu_hash()))
$$;

-- Diz à tela de entrada o que fazer com um CPF (já em hash):
-- 'primeiro' = ainda não há administração; quem entrar agora vira admin
-- 'conta'    = já tem senha, é só digitar
-- 'novo'     = liberado, mas ainda precisa criar a senha
-- 'bloqueado'= CPF não liberado
create or replace function public.situacao_cpf(h text) returns text
language plpgsql stable security definer set search_path = public, auth as $$
declare
  liberado boolean;
begin
  if h !~ '^[0-9a-f]{40}$' then return 'bloqueado'; end if;
  if not exists (select 1 from public.admins) then return 'primeiro'; end if;
  liberado := exists (select 1 from public.liberados where cpf_hash = h)
           or exists (select 1 from public.admins where cpf_hash = h);
  if not liberado then return 'bloqueado'; end if;
  if exists (select 1 from auth.users where email = h || '@cozinhaemdia.app') then return 'conta'; end if;
  return 'novo';
end $$;

-- Impede que alguém crie conta sem estar liberado.
create or replace function public.checar_cadastro() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  h text := split_part(new.email, '@', 1);
begin
  if new.email is null or new.email !~ '^[0-9a-f]{40}@cozinhaemdia\.app$' then
    raise exception 'CPF_NAO_LIBERADO';
  end if;
  if not exists (select 1 from admins) then
    insert into admins (cpf_hash) values (h);
    return new;
  end if;
  if exists (select 1 from liberados where cpf_hash = h)
     or exists (select 1 from admins where cpf_hash = h) then
    return new;
  end if;
  raise exception 'CPF_NAO_LIBERADO';
end $$;

drop trigger if exists checar_cadastro on auth.users;
create trigger checar_cadastro before insert on auth.users
  for each row execute function public.checar_cadastro();

-- Conta acessos e atividade de quem está usando.
create or replace function public.registrar_uso(novo boolean, n_receitas int, n_refeicoes int) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not estou_liberado() then return; end if;
  insert into uso (cpf_hash, admin, acessos, receitas, refeicoes)
  values (meu_hash(), sou_admin(), case when novo then 1 else 0 end, coalesce(n_receitas,0), coalesce(n_refeicoes,0))
  on conflict (cpf_hash) do update set
    admin            = excluded.admin,
    acessos          = uso.acessos + excluded.acessos,
    ultimo_acesso    = case when novo then now() else uso.ultimo_acesso end,
    ultima_atividade = now(),
    receitas         = excluded.receitas,
    refeicoes        = excluded.refeicoes;
end $$;

-- Administração: tirar o acesso de alguém (apaga também a senha).
create or replace function public.admin_remover(h text) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if not sou_admin() then raise exception 'SO_ADMIN'; end if;
  delete from public.liberados where cpf_hash = h;
  delete from auth.users where email = h || '@cozinhaemdia.app'
    and not exists (select 1 from public.admins where cpf_hash = h);
end $$;

-- Administração: pessoa esqueceu a senha. Apaga só a senha; os dados
-- dela continuam guardados e ela cria uma senha nova ao entrar.
create or replace function public.admin_resetar_senha(h text) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if not sou_admin() then raise exception 'SO_ADMIN'; end if;
  delete from auth.users where email = h || '@cozinhaemdia.app'
    and not exists (select 1 from public.admins where cpf_hash = h);
end $$;

-- ---------- segurança (RLS) ----------
alter table public.liberados enable row level security;
alter table public.admins    enable row level security;
alter table public.dados     enable row level security;
alter table public.uso       enable row level security;
alter table public.sac       enable row level security;

drop policy if exists "admin gerencia liberados" on public.liberados;
create policy "admin gerencia liberados" on public.liberados
  for all to authenticated using (sou_admin()) with check (sou_admin());

-- admins: nenhuma política = ninguém lê nem altera pelo app.

drop policy if exists "cada um le seus dados" on public.dados;
create policy "cada um le seus dados" on public.dados
  for select to authenticated using (cpf_hash = meu_hash() and estou_liberado());
drop policy if exists "cada um cria seus dados" on public.dados;
create policy "cada um cria seus dados" on public.dados
  for insert to authenticated with check (cpf_hash = meu_hash() and estou_liberado());
drop policy if exists "cada um altera seus dados" on public.dados;
create policy "cada um altera seus dados" on public.dados
  for update to authenticated using (cpf_hash = meu_hash() and estou_liberado())
  with check (cpf_hash = meu_hash());

drop policy if exists "admin ve uso" on public.uso;
create policy "admin ve uso" on public.uso
  for select to authenticated using (sou_admin());

drop policy if exists "sac leitura" on public.sac;
create policy "sac leitura" on public.sac
  for select to authenticated using ((cpf_hash = meu_hash() and estou_liberado()) or sou_admin());
drop policy if exists "sac criar" on public.sac;
create policy "sac criar" on public.sac
  for insert to authenticated with check (cpf_hash = meu_hash() and estou_liberado());
drop policy if exists "sac alterar" on public.sac;
create policy "sac alterar" on public.sac
  for update to authenticated using ((cpf_hash = meu_hash() and estou_liberado()) or sou_admin())
  with check ((cpf_hash = meu_hash()) or sou_admin());

-- ---------- permissões ----------
revoke all on public.liberados, public.admins, public.dados, public.uso, public.sac from anon;
grant select, insert, update, delete on public.liberados to authenticated;
grant select, insert, update on public.dados to authenticated;
grant select on public.uso to authenticated;
grant select, insert, update on public.sac to authenticated;

revoke execute on function public.checar_cadastro() from public, anon, authenticated;
grant execute on function public.situacao_cpf(text) to anon, authenticated;
grant execute on function public.sou_admin(), public.estou_liberado(), public.meu_hash() to authenticated;
grant execute on function public.registrar_uso(boolean, int, int) to authenticated;
grant execute on function public.admin_remover(text), public.admin_resetar_senha(text) to authenticated;
revoke execute on function public.registrar_uso(boolean, int, int), public.admin_remover(text), public.admin_resetar_senha(text) from anon;
