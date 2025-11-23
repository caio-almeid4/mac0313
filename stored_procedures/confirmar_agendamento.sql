CREATE OR REPLACE FUNCTION confirmar_agendamento(
    p_id_agendamento INTEGER,
    p_nusp_tutor VARCHAR(20)
) RETURNS VOID AS $$
DECLARE
    v_creditos_aluno_pagou NUMERIC(10,2);
    v_creditos_tutor_recebe INTEGER;
    v_nusp_solicitante VARCHAR(20);
    v_duracao_minutos INTEGER;
    v_h_inicio TIME;
    v_h_fim TIME;
BEGIN
    -- Busca dados do agendamento
    SELECT preco, nusp_solicitante, h_inicio, h_fim
    INTO v_creditos_aluno_pagou, v_nusp_solicitante, v_h_inicio, v_h_fim
    FROM agendamento
    WHERE id = p_id_agendamento AND nusp_tutor = p_nusp_tutor AND status = 'pendente';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento não encontrado ou já processado';
    END IF;
    
    -- Calcula quanto o tutor deve receber (valor integral)
    v_duracao_minutos := EXTRACT(EPOCH FROM (v_h_fim - v_h_inicio)) / 60;
    v_creditos_tutor_recebe := CEIL(v_duracao_minutos / 30.0);
    
    -- Debita do aluno (com desconto)
    UPDATE aluno
    SET qtd_creditos = qtd_creditos - v_creditos_aluno_pagou
    WHERE nusp = v_nusp_solicitante;
    
    -- Credita ao tutor (valor integral)
    UPDATE aluno
    SET qtd_creditos = qtd_creditos + v_creditos_tutor_recebe
    WHERE nusp = p_nusp_tutor;
    
    -- Atualiza status
    UPDATE agendamento
    SET status = 'confirmado'
    WHERE id = p_id_agendamento;
    
    RAISE NOTICE 'Agendamento confirmado! Aluno pagou: % | Tutor recebeu: % | Subsídio plataforma: %',
        v_creditos_aluno_pagou, v_creditos_tutor_recebe, 
        v_creditos_tutor_recebe - v_creditos_aluno_pagou;
END;
$$ LANGUAGE plpgsql;