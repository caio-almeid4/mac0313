CREATE OR REPLACE FUNCTION cancelar_agendamento(
    p_id_agendamento INTEGER,
    p_nusp_cancelador VARCHAR(20)
) RETURNS VOID AS $$
DECLARE
    v_preco NUMERIC(10,2);
    v_nusp_solicitante VARCHAR(20);
    v_nusp_tutor VARCHAR(20);
    v_status status_agendamento;
BEGIN
    SELECT status, preco, nusp_solicitante, nusp_tutor
    INTO v_status, v_preco, v_nusp_solicitante, v_nusp_tutor
    FROM agendamento
    WHERE id = p_id_agendamento;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento não encontrado';
    END IF;
    
    IF v_status NOT IN ('pendente', 'confirmado') THEN
        RAISE EXCEPTION 'Não pode cancelar';
    END IF;
    
    -- Se confirmado, reverte transação
    IF v_status = 'confirmado' THEN
        -- Reembolsa aluno
        UPDATE aluno 
        SET qtd_creditos = qtd_creditos + v_preco
        WHERE nusp = v_nusp_solicitante;
        
        -- Debita tutor (MESMO valor)
        UPDATE aluno 
        SET qtd_creditos = qtd_creditos - v_preco
        WHERE nusp = v_nusp_tutor;
    END IF;
    
    UPDATE agendamento
    SET status = 'cancelado'
    WHERE id = p_id_agendamento;
END;
$$ LANGUAGE plpgsql;