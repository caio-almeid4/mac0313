CREATE OR REPLACE FUNCTION criar_agendamento(
    p_nusp_solicitante VARCHAR(20),
    p_nusp_tutor VARCHAR(20),
    p_data DATE,
    p_h_inicio TIME,
    p_h_fim TIME,
    p_modo_atendimento modo_atendimento,
    p_localizacao VARCHAR(200),
    p_assuntos TEXT[]
) RETURNS INTEGER AS $$
DECLARE
    v_id_agendamento INTEGER;
    v_creditos_aluno NUMERIC(10,2);
    v_creditos_necessarios INTEGER;
    v_duracao_minutos INTEGER;
    v_assunto TEXT;
BEGIN
    -- Calcula duração
    v_duracao_minutos := EXTRACT(EPOCH FROM (p_h_fim - p_h_inicio)) / 60;
    
    IF v_duracao_minutos < 30 THEN
        RAISE EXCEPTION 'Duração mínima: 30 minutos';
    END IF;
    
    -- 1 crédito = 30 minutos (SEMPRE)
    v_creditos_necessarios := CEIL(v_duracao_minutos / 30.0);
    
    -- Verifica créditos do aluno
    SELECT qtd_creditos INTO v_creditos_aluno
    FROM aluno WHERE nusp = p_nusp_solicitante;
    
    IF v_creditos_aluno < v_creditos_necessarios THEN
        RAISE EXCEPTION 'Créditos insuficientes. Necessário: %, Disponível: %', 
            v_creditos_necessarios, v_creditos_aluno;
    END IF;
    
    -- Verifica disponibilidade
    IF NOT EXISTS (
        SELECT 1 FROM disponibilidade_tutor
        WHERE nusp_tutor = p_nusp_tutor
        AND data = p_data
        AND h_inicio <= p_h_inicio
        AND h_fim >= p_h_fim
    ) THEN
        RAISE EXCEPTION 'Tutor não disponível';
    END IF;
    
    -- Cria agendamento
    INSERT INTO agendamento (
        nusp_solicitante, nusp_tutor, data, h_inicio, h_fim,
        modo_atendimento, localizacao, preco, status
    ) VALUES (
        p_nusp_solicitante, p_nusp_tutor, p_data, p_h_inicio, p_h_fim,
        p_modo_atendimento, p_localizacao, v_creditos_necessarios, 'pendente'
    ) RETURNING id INTO v_id_agendamento;
    
    -- Adiciona assuntos
    FOREACH v_assunto IN ARRAY p_assuntos LOOP
        INSERT INTO assunto_agendamento (id_agendamento, assunto)
        VALUES (v_id_agendamento, v_assunto);
    END LOOP;
    
    RETURN v_id_agendamento;
END;
$$ LANGUAGE plpgsql;