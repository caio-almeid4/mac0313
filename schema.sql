CREATE TYPE status_agendamento AS ENUM (
    'pendente',
    'confirmado',
    'cancelado',
    'concluido'
);

CREATE TYPE status_denuncia AS ENUM ('aberta', 'em_analise', 'fechada');

CREATE TYPE modo_atendimento AS ENUM ('online', 'presencial');

-- =========================
-- Institucional
-- =========================
CREATE TABLE
    instituto (
        nome VARCHAR(200) PRIMARY KEY,
        cidade VARCHAR(100),
        rua VARCHAR(200)
    );

CREATE TABLE
    numero_instituto (
        nome_instituto VARCHAR(200) NOT NULL,
        numero VARCHAR(50) NOT NULL,
        PRIMARY KEY (nome_instituto, numero),
        FOREIGN KEY (nome_instituto) REFERENCES instituto (nome) ON UPDATE CASCADE ON DELETE CASCADE
    );

CREATE TABLE
    disciplina (
        codigo VARCHAR(30) PRIMARY KEY,
        nome VARCHAR(200) NOT NULL
    );

CREATE TABLE
    curso (
        codigo VARCHAR(30) PRIMARY KEY,
        nome VARCHAR(200) NOT NULL,
        id_instituto VARCHAR(200),
        FOREIGN KEY (id_instituto) REFERENCES instituto (nome) ON UPDATE CASCADE ON DELETE CASCADE
    );

CREATE TABLE
    curso_disciplina (
        cod_curso VARCHAR(30) NOT NULL,
        cod_disciplina VARCHAR(30) NOT NULL,
        e_obrigatoria BOOLEAN NOT NULL,
        PRIMARY KEY (cod_curso, cod_disciplina),
        FOREIGN KEY (cod_curso) REFERENCES curso (codigo) ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (cod_disciplina) REFERENCES disciplina (codigo) ON UPDATE CASCADE ON DELETE CASCADE
    );

-- =========================
-- Pessoas
-- =========================
CREATE TABLE
    aluno (
        nusp VARCHAR(20) PRIMARY KEY,
        pnome VARCHAR(50) NOT NULL,
        mnome VARCHAR(50),
        fnome VARCHAR(50),
        email VARCHAR(200) UNIQUE NOT NULL,
        senha VARCHAR(200) NOT NULL,
        descricao_perfil TEXT,
        qtd_creditos NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (qtd_creditos >= 0),
        curso VARCHAR(30) NOT NULL,
        FOREIGN KEY (curso) REFERENCES curso (codigo) ON UPDATE CASCADE ON DELETE RESTRICT
    );

CREATE TABLE
    tutor (
        nusp VARCHAR(20) PRIMARY KEY,
        FOREIGN KEY (nusp) REFERENCES aluno (nusp) ON UPDATE CASCADE ON DELETE CASCADE
    );

CREATE TABLE
    tutor_disciplina (
        nusp_tutor VARCHAR(20) NOT NULL,
        cod_disciplina VARCHAR(30) NOT NULL,
        PRIMARY KEY (nusp_tutor, cod_disciplina),
        FOREIGN KEY (nusp_tutor) REFERENCES tutor (nusp) ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (cod_disciplina) REFERENCES disciplina (codigo) ON UPDATE CASCADE ON DELETE CASCADE
    );

CREATE TABLE
    disponibilidade_tutor (
        nusp_tutor VARCHAR(20) NOT NULL,
        data DATE NOT NULL,
        h_inicio TIME NOT NULL,
        h_fim TIME NOT NULL,
        PRIMARY KEY (nusp_tutor, data, h_inicio),
        FOREIGN KEY (nusp_tutor) REFERENCES tutor (nusp) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT hora_valida CHECK (h_inicio < h_fim)
    );

-- =========================
-- Pacotes de créditos
-- =========================
CREATE TABLE
    pacote (
        qtd_credito INTEGER PRIMARY KEY CHECK (qtd_credito >= 0),
        preco NUMERIC(10, 2) NOT NULL CHECK (preco >= 0)
    );

CREATE TABLE
    aluno_pacote (
        qtd_credito INTEGER NOT NULL,
        nusp_comprador VARCHAR(20) NOT NULL,
        timestamp_compra TIMESTAMP NOT NULL DEFAULT now (),
        PRIMARY KEY (qtd_credito, nusp_comprador, timestamp_compra),
        FOREIGN KEY (qtd_credito) REFERENCES pacote (qtd_credito) ON UPDATE RESTRICT ON DELETE RESTRICT,
        FOREIGN KEY (nusp_comprador) REFERENCES aluno (nusp) ON UPDATE CASCADE ON DELETE CASCADE
    );

-- =========================
-- Agendamento e aulas
-- =========================
CREATE TABLE
    agendamento (
        id SERIAL PRIMARY KEY,
        nusp_solicitante VARCHAR(20) NOT NULL,
        nusp_tutor VARCHAR(20) NOT NULL,
        h_inicio TIME NOT NULL,
        h_fim TIME NOT NULL,
        status status_agendamento NOT NULL DEFAULT 'pendente',
        data DATE NOT NULL DEFAULT CURRENT_DATE,
        preco NUMERIC(10, 2) NOT NULL DEFAULT 0,
        modo_atendimento modo_atendimento NOT NULL,
        localizacao VARCHAR(200),
        CONSTRAINT hora_agenda_valida CHECK (h_inicio < h_fim),
        CONSTRAINT preco_nao_neg CHECK (preco >= 0),
        FOREIGN KEY (nusp_solicitante) REFERENCES aluno (nusp) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (nusp_tutor) REFERENCES tutor (nusp) ON UPDATE CASCADE ON DELETE RESTRICT
    );

CREATE TABLE
    aula (
        id_agendamento INTEGER PRIMARY KEY,
        h_inicio TIME NOT NULL,
        h_fim TIME NOT NULL,
        data DATE NOT NULL,
        FOREIGN KEY (id_agendamento) REFERENCES agendamento (id) ON UPDATE CASCADE ON DELETE CASCADE,
        CONSTRAINT hora_aula_valida CHECK (h_inicio < h_fim)
    );

CREATE TABLE
    assunto_agendamento (
        id_agendamento INTEGER NOT NULL,
        assunto VARCHAR(150) NOT NULL,
        PRIMARY KEY (id_agendamento, assunto),
        FOREIGN KEY (id_agendamento) REFERENCES agendamento (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE
    assunto_aula (
        id_agendamento INTEGER NOT NULL,
        assunto VARCHAR(200) NOT NULL,
        PRIMARY KEY (id_agendamento, assunto),
        FOREIGN KEY (id_agendamento) REFERENCES agendamento (id) ON DELETE CASCADE ON UPDATE CASCADE
    );
    
CREATE TABLE
    aluno_aula (
        id_agendamento INTEGER NOT NULL,
        nusp_aluno VARCHAR(20) NOT NULL,
        PRIMARY KEY (id_agendamento, nusp_aluno),
        FOREIGN KEY (id_agendamento) REFERENCES aula (id_agendamento) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (nusp_aluno) REFERENCES aluno (nusp) ON DELETE CASCADE ON UPDATE CASCADE
    );

-- =========================
-- Chat e mensagens
-- =========================
CREATE TABLE
    chat (
        id_agendamento INTEGER NOT NULL,
        id_chat INTEGER NOT NULL,
        PRIMARY KEY (id_agendamento, id_chat),
        FOREIGN KEY (id_agendamento) REFERENCES agendamento (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE
    chat_aluno (
        id_chat INTEGER NOT NULL,
        id_agendamento INTEGER NOT NULL,
        nusp VARCHAR(20) NOT NULL,
        PRIMARY KEY (id_chat, id_agendamento, nusp),
        FOREIGN KEY (id_agendamento, id_chat) REFERENCES chat (id_agendamento, id_chat) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (nusp) REFERENCES aluno (nusp) ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE
    mensagem (
        id_chat INTEGER NOT NULL,
        id_agendamento INTEGER NOT NULL,
        id_mensagem SERIAL,
        nusp_remetente VARCHAR(20) NOT NULL,
        versao INTEGER DEFAULT 1,
        conteudo TEXT NOT NULL,
        foi_deletada BOOLEAN DEFAULT FALSE,
        horario TIMESTAMP DEFAULT now (),
        PRIMARY KEY (id_chat, id_agendamento, id_mensagem, versao),
        FOREIGN KEY (id_agendamento, id_chat) REFERENCES chat (id_agendamento, id_chat) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (nusp_remetente) REFERENCES aluno (nusp) ON DELETE RESTRICT ON UPDATE CASCADE
    );

-- =========================
-- Avaliações
-- =========================
CREATE TABLE
    avaliacao (
        id_agendamento INTEGER NOT NULL,
        nusp_avaliador VARCHAR(20) NOT NULL,
        nusp_avaliado VARCHAR(20) NOT NULL,
        nota NUMERIC(2, 1) NOT NULL,
        comentario TEXT,
        PRIMARY KEY (id_agendamento, nusp_avaliador, nusp_avaliado),
        FOREIGN KEY (id_agendamento) REFERENCES aula (id_agendamento) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (nusp_avaliador) REFERENCES aluno (nusp) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (nusp_avaliado) REFERENCES aluno (nusp) ON DELETE RESTRICT ON UPDATE CASCADE,
        CONSTRAINT nota_intervalo CHECK (
            nota >= 0
            AND nota <= 5
        )
    );

-- =========================
-- Denúncias
-- =========================
CREATE TABLE
    denuncia (
        nusp_denunciador VARCHAR(20) NOT NULL,
        nusp_alvo VARCHAR(20) NOT NULL,
        motivo TEXT NOT NULL,
        status status_denuncia DEFAULT 'aberta',
        criada_em TIMESTAMP DEFAULT now (),
        PRIMARY KEY (nusp_denunciador, nusp_alvo, criada_em),
        FOREIGN KEY (nusp_denunciador) REFERENCES aluno (nusp) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (nusp_alvo) REFERENCES aluno (nusp) ON UPDATE CASCADE ON DELETE RESTRICT
    );