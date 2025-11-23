-- ============================================================================
-- STORED PROCEDURE: adicionar_aluno_aula
-- ============================================================================
-- Adiciona alunos extras a uma aula (para aulas em grupo)
-- ============================================================================

CREATE OR REPLACE FUNCTION adicionar_aluno_aula(
    p_id_agendamento INTEGER,
    p_nusp_aluno VARCHAR(20)
) RETURNS VOID AS $$
DECLARE
    v_status status_agendamento;
    v_nusp_tutor VARCHAR(20);
BEGIN
    -- Verifica se o agendamento existe e está concluído
    SELECT status, nusp_tutor
    INTO v_status, v_nusp_tutor
    FROM agendamento
    WHERE id = p_id_agendamento;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento não encontrado';
    END IF;
    
    -- Só pode adicionar alunos em aulas já finalizadas
    IF v_status != 'concluido' THEN
        RAISE EXCEPTION 'Só é possível adicionar alunos a aulas já finalizadas';
    END IF;
    
    -- Verifica se o aluno existe
    IF NOT EXISTS (SELECT 1 FROM aluno WHERE nusp = p_nusp_aluno) THEN
        RAISE EXCEPTION 'Aluno % não encontrado', p_nusp_aluno;
    END IF;
    
    -- Não permite adicionar o tutor como aluno
    IF p_nusp_aluno = v_nusp_tutor THEN
        RAISE EXCEPTION 'Não é possível adicionar o tutor como aluno da aula';
    END IF;
    
    -- Verifica se já não está na aula
    IF EXISTS (
        SELECT 1 FROM aluno_aula 
        WHERE id_agendamento = p_id_agendamento 
        AND nusp_aluno = p_nusp_aluno
    ) THEN
        RAISE EXCEPTION 'Aluno já está registrado nesta aula';
    END IF;
    
    -- Adiciona o aluno à aula
    INSERT INTO aluno_aula (id_agendamento, nusp_aluno)
    VALUES (p_id_agendamento, p_nusp_aluno);
    
    RAISE NOTICE 'Aluno % adicionado à aula %', p_nusp_aluno, p_id_agendamento;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- STORED PROCEDURE: remover_aluno_aula
-- ============================================================================
-- Remove um aluno de uma aula (caso tenha sido adicionado por engano)
-- ============================================================================

CREATE OR REPLACE FUNCTION remover_aluno_aula(
    p_id_agendamento INTEGER,
    p_nusp_aluno VARCHAR(20)
) RETURNS VOID AS $$
DECLARE
    v_nusp_solicitante VARCHAR(20);
BEGIN
    -- Busca o solicitante original
    SELECT nusp_solicitante INTO v_nusp_solicitante
    FROM agendamento
    WHERE id = p_id_agendamento;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento não encontrado';
    END IF;
    
    -- Não permite remover o aluno solicitante original
    IF p_nusp_aluno = v_nusp_solicitante THEN
        RAISE EXCEPTION 'Não é possível remover o aluno solicitante da aula';
    END IF;
    
    -- Remove o aluno
    DELETE FROM aluno_aula
    WHERE id_agendamento = p_id_agendamento
    AND nusp_aluno = p_nusp_aluno;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aluno não estava registrado nesta aula';
    END IF;
    
    RAISE NOTICE 'Aluno % removido da aula %', p_nusp_aluno, p_id_agendamento;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- STORED PROCEDURE: listar_alunos_aula
-- ============================================================================
-- Lista todos os alunos de uma aula
-- ============================================================================

CREATE OR REPLACE FUNCTION listar_alunos_aula(
    p_id_agendamento INTEGER
) RETURNS TABLE(
    nusp VARCHAR(20),
    nome_completo TEXT,
    email VARCHAR(200),
    e_solicitante BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        aa.nusp_aluno,
        a.pnome || ' ' || COALESCE(a.mnome || ' ', '') || COALESCE(a.fnome, '') as nome_completo,
        a.email,
        (aa.nusp_aluno = ag.nusp_solicitante) as e_solicitante
    FROM aluno_aula aa
    JOIN aluno a ON aa.nusp_aluno = a.nusp
    JOIN agendamento ag ON aa.id_agendamento = ag.id
    WHERE aa.id_agendamento = p_id_agendamento
    ORDER BY e_solicitante DESC, a.pnome;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- EXEMPLOS DE USO
-- ============================================================================

-- Exemplo 1: Finalizar aula (já registra o solicitante automaticamente)
SELECT finalizar_aula(1, '14:05', '16:10', '2025-12-15');
-- Resultado: Aula finalizada, aluno solicitante já está em aluno_aula

-- Exemplo 2: Adicionar aluno extra (aula em grupo)
SELECT adicionar_aluno_aula(1, '67890');
-- Adiciona outro aluno que também participou da aula

-- Exemplo 3: Adicionar mais alunos
SELECT adicionar_aluno_aula(1, '11111');
SELECT adicionar_aluno_aula(1, '22222');
-- Aula em grupo com 4 alunos agora

-- Exemplo 4: Listar todos os alunos de uma aula
SELECT * FROM listar_alunos_aula(1);
-- Resultado:
-- nusp  | nome_completo      | email             | e_solicitante
-- ------|-------------------|-------------------|---------------
-- 12345 | João Silva        | joao@usp.br       | true
-- 67890 | Maria Santos      | maria@usp.br      | false
-- 11111 | Pedro Oliveira    | pedro@usp.br      | false
-- 22222 | Ana Costa         | ana@usp.br        | false

-- Exemplo 5: Remover aluno (caso tenha sido adicionado por engano)
SELECT remover_aluno_aula(1, '22222');
-- Remove Ana da aula

-- Exemplo 6: Consultar número de alunos por aula
SELECT 
    a.id_agendamento,
    au.data,
    COUNT(aa.nusp_aluno) as total_alunos,
    t.nusp as tutor
FROM aula au
JOIN aluno_aula aa ON au.id_agendamento = aa.id_agendamento
JOIN agendamento a ON au.id_agendamento = a.id
JOIN tutor t ON a.nusp_tutor = t.nusp
GROUP BY a.id_agendamento, au.data, t.nusp
ORDER BY total_alunos DESC;


-- ============================================================================
-- TRIGGER: Validar que aluno não está duplicado
-- ============================================================================

CREATE OR REPLACE FUNCTION validar_aluno_aula_unico()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM aluno_aula
        WHERE id_agendamento = NEW.id_agendamento
        AND nusp_aluno = NEW.nusp_aluno
    ) THEN
        RAISE EXCEPTION 'Aluno já está registrado nesta aula';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_valida_aluno_aula_unico
BEFORE INSERT ON aluno_aula
FOR EACH ROW
EXECUTE FUNCTION validar_aluno_aula_unico();


-- ============================================================================
-- VIEW: Estatísticas de aulas em grupo
-- ============================================================================

CREATE OR REPLACE VIEW view_estatisticas_aulas_grupo AS
SELECT 
    a.id as id_agendamento,
    a.nusp_tutor,
    al.pnome || ' ' || al.fnome as nome_tutor,
    au.data,
    au.h_inicio,
    au.h_fim,
    COUNT(aa.nusp_aluno) as total_alunos,
    CASE 
        WHEN COUNT(aa.nusp_aluno) = 1 THEN 'Individual'
        WHEN COUNT(aa.nusp_aluno) BETWEEN 2 AND 3 THEN 'Pequeno Grupo'
        WHEN COUNT(aa.nusp_aluno) BETWEEN 4 AND 6 THEN 'Grupo Médio'
        ELSE 'Grupo Grande'
    END as tipo_aula
FROM agendamento a
JOIN aula au ON a.id = au.id_agendamento
JOIN aluno_aula aa ON a.id = aa.id_agendamento
JOIN aluno al ON a.nusp_tutor = al.nusp
WHERE a.status = 'concluido'
GROUP BY a.id, a.nusp_tutor, al.pnome, al.fnome, au.data, au.h_inicio, au.h_fim
ORDER BY au.data DESC, au.h_inicio DESC;

-- Exemplo de uso da view
SELECT * FROM view_estatisticas_aulas_grupo
WHERE tipo_aula != 'Individual';


-- ============================================================================
-- QUERY: Alunos que mais participaram de aulas
-- ============================================================================

SELECT 
    aa.nusp_aluno,
    a.pnome || ' ' || a.fnome as nome_aluno,
    COUNT(*) as total_aulas_participadas,
    COUNT(*) FILTER (WHERE ag.nusp_solicitante = aa.nusp_aluno) as aulas_como_solicitante,
    COUNT(*) FILTER (WHERE ag.nusp_solicitante != aa.nusp_aluno) as aulas_como_extra
FROM aluno_aula aa
JOIN aluno a ON aa.nusp_aluno = a.nusp
JOIN agendamento ag ON aa.id_agendamento = ag.id
WHERE ag.status = 'concluido'
GROUP BY aa.nusp_aluno, a.pnome, a.fnome
ORDER BY total_aulas_participadas DESC
LIMIT 10;