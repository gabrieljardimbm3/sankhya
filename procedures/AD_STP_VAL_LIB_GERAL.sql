CREATE OR REPLACE EDITIONABLE PROCEDURE "GRUPOSOULPRD"."AD_STP_VAL_LIB_GERAL" (
                                P_NUNOTA      INT,
                                P_SUCESSO     OUT   VARCHAR,
                                P_MENSAGEM    OUT   VARCHAR2,
                                P_CODUSULIB   OUT   NUMERIC
)
/**************************************************************************************
 *AUTOR: GIOVANI                                                                      *
 *MOTIVO: EXIGIR LIBERAC?O DA CONTROLADORIA ANTES DE CONFIRMAR                        *
 *DATA: 15/08/2022                                                                    *
 *DEPENDENCIAS: GLPI:                                                                 *
 *GLPI 9796 - Alçada de Aprovação – Central de Compras até R$5000 - Gabriel Jardim    *
 **************************************************************************************/
AS
    P_TOP INT;
    P_USER INT;
    V_VLRNOTA FLOAT;
    V_CODCENCUS INT;
BEGIN

    -- 1. BUSCAR O VALOR TOTAL E O CENTRO DE CUSTO DO PEDIDO NA TGFCAB
    BEGIN
        SELECT NVL(VLRNOTA, 0), NVL(CODCENCUS, 0)
        INTO V_VLRNOTA, V_CODCENCUS
        FROM TGFCAB
        WHERE NUNOTA = P_NUNOTA;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            V_VLRNOTA := 0;
            V_CODCENCUS := 0;
    END;

    -- 2. NOVA REGRA DE ALÇADA (Até R$ 5.000,00 exclusivamente para os CRs 30113 e 20113)
    IF V_CODCENCUS IN (30113, 20113) AND V_VLRNOTA <= 5000 THEN
        P_SUCESSO := 'S';
        P_MENSAGEM := 'Liberado automaticamente: Valor dentro da alçada (< R$ 5.000,00) para o Centro de Custo ' || V_CODCENCUS || '.';
        RETURN; -- Encerra a procedure aqui, o pedido é confirmado sem parar para liberação
    END IF;

    -- 3. CÓDIGO ORIGINAL (Aplica o bloqueio para outros CRs ou valores acima de R$ 5.000,00)
    P_SUCESSO := 'N';
    P_MENSAGEM := 'ESTA TOP EXIGE LIBERAÇÃO DA CONTROLADORIA ANTES DA CONFIRMAÇÃO.';

  /*BUSCA A TOP DA NOTA PARA DIFINIR O LIBERADOR*/
    P_USER := stp_get_codusulogado;

    BEGIN
        SELECT NVL(codcencuspad,0) INTO P_TOP FROM TSIUSU WHERE CODUSU = P_USER;
    END;

    BEGIN
        SELECT nvl(codusuresp,0) into P_CODUSULIB FROM TSICUS WHERE codcencus = P_TOP;
    END;

  /*DEFINE LIBERADOR PARA CADA TOP DE SOLICITAC?O DE COMPRA
  IF(P_TOP = 22) THEN
  P_CODUSULIB := 1;
  P_MENSAGEM := 'MSG ESPECIFICA';
  ELSIF(P_TOP = 23) THEN
  P_CODUSULIB := 2;
  P_MENSAGEM := 'MSG ESPECIFICA';
  ELSIF(P_TOP = 24) THEN
  P_CODUSULIB := 3;
  P_MENSAGEM := 'MSG ESPECIFICA';
  /*E ASSIM POR DIANTE PARA QUALQUER TOP. BASTA COPIAR O ELSIF
  END IF;*/

END;
/
