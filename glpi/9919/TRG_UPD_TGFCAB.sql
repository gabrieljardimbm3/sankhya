CREATE OR REPLACE EDITIONABLE TRIGGER "GRUPOSOULPRD"."TRG_UPD_TGFCAB" 
BEFORE UPDATE ON TGFCAB FOR EACH ROW
DECLARE
    P_TIPRES                    CHAR(1);
    P_UPDSTATUS                 CHAR(1);
    P_ATUALV                    CHAR(1);
    P_UTILIZALOCAL              CHAR(1);
    P_PROVISAO                  CHAR(1);
    P_ATUALEST                  VARCHAR2(1);
    P_ATUALEST_D                VARCHAR2(1);
    P_ATUALFIN                  NUMBER(5);
    P_ATUALFIN_D                NUMBER(5);
    P_TIPATUALFIN               CHAR(1);
    P_TIPATUALFIN_D             CHAR(1);
    P_RESERVADO                 CHAR(1);
    P_GNREST                    NUMBER(10);
  P_GNRECTE                   NUMBER(10);
    P_TIPTITGNRESTRB            NUMBER(10);
    ERRMSG                      VARCHAR2(255);
    P_SOLICITANTE               CHAR(30);
    P_COUNT                     NUMBER(10) := 0;
    P_COUNT1                    NUMBER(10) := 0;
    P_ATIVO                     CHAR(1);
    P_TOTDESDOB                 FLOAT;
    P_MOTORISTA                 CHAR(1);
    P_ATUALFINTERC              CHAR(1);
    P_ATUALESTTERC              CHAR(1);
    P_TIPTIT_COMPENSACAO        NUMBER(10) := 0;
    ERROR                       EXCEPTION;
    P_VALIDAR                   BOOLEAN;
    P_CHAVE                     VARCHAR2(15);
    P_SINAL                     NUMBER(5);
    P_VLRTROCA                  FLOAT;
    P_ULTCOD                    NUMBER(10);
    P_ALTITEMPARCFAT            CHAR(1);
    P_INDPRESNFCE               CHAR(1);
  P_INTERMED              VARCHAR2(1);
  P_CODINTERM           NUMBER(10);
    P_EMPNFE                    TGFEMP.NFE%TYPE;
    P_TOPNFE                    TGFTOP.NFE%TYPE;
    P_TOPNFE_OLD                TGFTOP.NFE%TYPE;
    P_BASENUMERACAO             CHAR(1);
    P_CODTOPPREVENDA            NUMBER(10);
    P_CODVOLPARC                VARCHAR2(6);
    P_USACODVOLPARC             VARCHAR2(1);
    P_PERMFINMENORVLRNOTA       VARCHAR2(1);
    P_CODPARC_CLASSIFICMS       TGFPAR.CODPARC%TYPE;
BEGIN

  IF STP_GET_ATUALIZANDO THEN
    RETURN;
  END IF;
  /*
   Sincronização de dados
  */
  P_VALIDAR := Fpodevalidar('TGFCAB');
  IF UPDATING('NUNOTA') THEN
     ERRMSG := 'A coluna NUNOTA não pode ser alterada.';
     RAISE ERROR;
  END IF;

  IF :NEW.TIPMOV = 'V' AND :NEW.SERIENOTA = 'CF' AND NVL(:OLD.CODMAQ,0) <> :NEW.CODMAQ AND NVL(:OLD.CODMAQ,0) <> 0 THEN
    ERRMSG := 'Código da máquina (ECF) já está preenchido, não pode ser alterado devido ao SPED.';
    RAISE ERROR;
  END IF;

  IF :NEW.TIPMOV = 'V' AND :NEW.SERIENOTA = 'CF' AND NVL(:OLD.NROREDZ,0) <> :NEW.NROREDZ AND NVL(:OLD.NROREDZ,0) <> 0 THEN
    ERRMSG := 'Nro da redução Z (ECF) já está preenchido, não pode ser alterado devido ao SPED.';
    RAISE ERROR;
  END IF;

  IF :NEW.TIPMOV = 'V' AND :NEW.SERIENOTA = 'CF' AND NVL(:OLD.NUMNOTA,0) <> :NEW.NUMNOTA AND NVL(:OLD.NUMNOTA,0) <> 0 AND :NEW.STATUSNOTA = 'L' THEN
    ERRMSG := 'Cupom já foi numerado, não pode ser alterado devido ao SPED.';
    RAISE ERROR;
  END IF;

  P_GNREST := Get_Tsipar_Inteiro('TIPTITGNREST');
  P_GNRECTE := Get_Tsipar_Inteiro('TIPTITGNRECTE');

  P_TIPTITGNRESTRB := Get_Tsipar_Inteiro('TIPTITGNRESTRB');

  --VALIDA SE O TIPO DE CONTROLE DE PRODUTO E O MESMO PARA AS EMPRESAS QUE ESTÃO SENDO ALTERADAS OS 770482
  IF UPDATING('CODEMP') THEN
     SELECT COUNT(1) INTO P_COUNT
     FROM TGFITE ITE
     WHERE (SELECT NVL(PEM.TIPCONTEST, PRO.TIPCONTEST) AS TIPCONTEST
            FROM TGFPRO PRO
            LEFT JOIN TGFPEM PEM ON (PEM.CODPROD = PRO.CODPROD AND PEM.CODEMP = :NEW.CODEMP)
            WHERE PRO.CODPROD = ITE.CODPROD) <> (SELECT NVL(PEM.TIPCONTEST, PRO.TIPCONTEST) AS TIPCONTEST
                                                 FROM TGFPRO PRO
                                                 LEFT JOIN TGFPEM PEM ON (PEM.CODPROD = PRO.CODPROD AND PEM.CODEMP = :OLD.CODEMP)
                                                 WHERE PRO.CODPROD = ITE.CODPROD)
     AND ITE.NUNOTA = :OLD.NUNOTA;

     IF(P_COUNT > 0) THEN
       ERRMSG := 'Não é possível alterar a empresa '||:OLD.CODEMP||' para '||:NEW.CODEMP||' pois elas possuem diferenças no controle adicional de estoque. Remova os itens da nota.';
       RAISE ERROR;
     END IF;
    END IF;

  -- ATUALIZA CAMPO CODVOLPARC NA TGFITE, UTILIZANDO A TABELA TGFUNP, SOMENTE QUANDO É ALTERADO O CODIGO DO PARCEIRO
   IF UPDATING('CODPARC') THEN
      SELECT LOGICO
      INTO P_USACODVOLPARC
      FROM TSIPAR
      WHERE CHAVE = 'USACODVOLPARC';

      IF P_USACODVOLPARC = 'S' THEN

          IF NOT (VARIAVEIS_PKG.V_SBPRODUTO) THEN
            VARIAVEIS_PKG.V_SBPRODUTO := TRUE;
          END IF;

          FOR I IN (SELECT SEQUENCIA, CODVOL FROM TGFITE WHERE NUNOTA = :NEW.NUNOTA)
          LOOP
            BEGIN
              SELECT P.CODVOLPARC INTO P_CODVOLPARC
              FROM TGFUNP P
              WHERE P.CODPARC = :NEW.CODPARC
                AND P.CODVOL = I.CODVOL;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                P_CODVOLPARC := NULL;
            END;

            UPDATE TGFITE SET CODVOLPARC = P_CODVOLPARC
            WHERE NUNOTA = :NEW.NUNOTA
              AND SEQUENCIA = I.SEQUENCIA
              AND NVL(CODVOLPARC, ' ') <> NVL(P_CODVOLPARC, ' ');
          END LOOP;
    VARIAVEIS_PKG.V_SBPRODUTO := FALSE;
      END IF;
   END IF;

 IF ((:OLD.STATUSNOTA <> :NEW.STATUSNOTA) AND (:NEW.STATUSNOTA <> 'L')) AND-- :NEW.NUNOTA NOT IN (1607091)AND
    (NOT ((:OLD.CHAVENFE IS NOT NULL) AND (:NEW.CHAVENFE IS NULL) AND (:OLD.NULOTENFE IS NOT NULL) AND (:NEW.NULOTENFE IS NULL))) THEN
    ERRMSG := 'A única atualização permitida para o Status da Nota é a passagem deste para L.';
    RAISE ERROR;
 END IF;

  IF :OLD.STATUSNOTA = 'L' AND ((:OLD.NUNOTA <> :NEW.NUNOTA) OR (:OLD.CODEMP <> :NEW.CODEMP) OR (:OLD.CODEMPNEGOC <> :NEW.CODEMPNEGOC)
      OR (:OLD.NUMNOTA <> :NEW.NUMNOTA) OR (:OLD.SERIENOTA <> :NEW.SERIENOTA) OR (:OLD.DTNEG <> :NEW.DTNEG) OR (:OLD.DTFATUR <> :NEW.DTFATUR)
       OR (:OLD.DTVAL <> :NEW.DTVAL) OR (:OLD.DTENTSAI <> :NEW.DTENTSAI) OR (:OLD.DTMOV <> :NEW.DTMOV) OR (:OLD.CODPARC <> :NEW.CODPARC)
       OR (:OLD.BASEICMS <> :NEW.BASEICMS) OR (:OLD.VLRICMS <> :NEW.VLRICMS) OR (:OLD.BASEIPI <> :NEW.BASEIPI) OR (:OLD.VLRIPI <> :NEW.VLRIPI)
       OR (:OLD.VLRNOTA <> :NEW.VLRNOTA) OR (:OLD.TIPMOV <> :NEW.TIPMOV) OR (:OLD.VLRDESCTOT <> :NEW.VLRDESCTOT) OR (:OLD.TIPFRETE <> :NEW.TIPFRETE)
       OR (:OLD.BASEICMSFRETE <> :NEW.BASEICMSFRETE) OR (:OLD.ICMSFRETE <> :NEW.ICMSFRETE) OR (:OLD.VLRSEG <> :NEW.VLRSEG) OR (:OLD.VLRICMSSEG <> :NEW.VLRICMSSEG)
       OR (:OLD.VLREMB <> :NEW.VLREMB) OR (:OLD.TIPIPIEMB <> :NEW.TIPIPIEMB) OR (:OLD.VLRICMSEMB <> :NEW.VLRICMSEMB) OR (:OLD.BASEISS <> :NEW.BASEISS)
       OR (:OLD.ISSRETIDO <> :NEW.ISSRETIDO) OR (:OLD.VLRISS <> :NEW.VLRISS) OR (:OLD.VLRINSS <> :NEW.VLRINSS) OR (:OLD.CODTIPOPER <> :NEW.CODTIPOPER)
       OR (:OLD.CODOBSPADRAO <> :NEW.CODOBSPADRAO) OR (:OLD.IPIEMB <> :NEW.IPIEMB) OR (:OLD.VLRFRETE <> :NEW.VLRFRETE AND :NEW.TIPFRETE <> 'N') OR (:OLD.VLRDESTAQUE <> :NEW.VLRDESTAQUE)
       OR (:OLD.VLRJURO <> :NEW.VLRJURO) OR (:OLD.VLRDESCSERV <> :NEW.VLRDESCSERV) OR (:OLD.VLRSUBST <> :NEW.VLRSUBST) OR (:OLD.BASESUBSTIT <> :NEW.BASESUBSTIT)
       OR (:OLD.BASESUBSTSEMRED <> :NEW.BASESUBSTSEMRED) OR (:OLD.CODMODDOCNOTA <> :NEW.CODMODDOCNOTA) OR (:OLD.VLRIRF <> :NEW.VLRIRF)
       OR (:OLD.CODPARCDEST <> :NEW.CODPARCDEST) OR (:OLD.CODPARCREMETENTE <> :NEW.CODPARCREMETENTE) OR (:OLD.IRFRETIDO <> :NEW.IRFRETIDO)
       OR (:OLD.CHAVENFE <> :NEW.CHAVENFE) OR (:OLD.DTENTSAIINFO <> :NEW.DTENTSAIINFO) ) THEN

     SELECT COUNT(1) INTO P_COUNT FROM  TCBINT C WHERE  C.NUNICO = :OLD.NUNOTA AND C.ORIGEM = 'E' ;
     IF P_COUNT <> 0  --AND :NEW.NUNOTA NOT IN (1624963) 
                                             THEN
        ERRMSG := 'Nota já foi contabilizada, não pode ser alterada.';
        RAISE ERROR;
     END IF;

    SELECT COUNT(1) INTO P_COUNT
    FROM TGFLIV
    WHERE NUNOTA = :OLD.NUNOTA
    AND ORIGEM IN ('A', 'D', 'E');

    IF P_COUNT <> 0  --AND :NEW.NUNOTA NOT IN (1624963) 
                                              THEN
        ERRMSG := 'Nota já foi gerada no Livro Fiscal de ICMS/IPI, não pode ser alterada. ';
        RAISE ERROR;
    END IF;

    SELECT COUNT(1) INTO P_COUNT
    FROM TGFLIS
    WHERE NUNOTA = :OLD.NUNOTA
    AND ORIGEM = 'E';

    IF P_COUNT <> 0 THEN
        ERRMSG := 'Nota já foi gerada no Livro Fiscal de ISS, não pode ser alterada. ';
        RAISE ERROR;
    END IF;


  ELSIF (:OLD.STATUSNOTA = 'L' AND (NVL (:NEW.CODCENCUS, 0) <> NVL (:OLD.CODCENCUS, 0))) THEN

     SELECT COUNT(1)
     INTO P_COUNT
     FROM  TCBINT C
     , TCBLAN LAN
     WHERE  C.NUNICO = :OLD.NUNOTA
     AND C.ORIGEM = 'E'
     AND C.CODEMP = LAN.CODEMP
     AND C.REFERENCIA = LAN.REFERENCIA
     AND C.NUMLOTE = LAN.NUMLOTE
     AND C.NUMLANC = LAN.NUMLANC
     AND C.TIPLANC = LAN.TIPLANC
     AND C.SEQUENCIA = LAN.SEQUENCIA
     AND LAN.CODCENCUS <> 0;

     IF P_COUNT > 0 THEN
        ERRMSG := 'Nota já foi contabilizada, C.R. não pode ser alterado.';
        RAISE ERROR;
     END IF;

  END IF;

  IF UPDATING('CODNAT') THEN
     SELECT COUNT(1) INTO P_COUNT
     FROM TGFNAT N
     WHERE N.CODNAT = :NEW.CODNAT AND N.ATIVA= 'S' AND N.ANALITICA = 'S';
     IF (P_COUNT = 0) THEN
        Stp_Popula_Msg('TGFNAT');
     END IF;
  END IF;

  IF UPDATING('DTNEG') THEN
    SELECT COUNT(1) INTO P_COUNT
    FROM TCSBLO BLO
            , TCIIBE IBE
            , TGFTOP TP
    WHERE IBE.NUNOTA   = :OLD.NUNOTA
    AND BLO.CODPROD     = IBE.CODPROD
    AND BLO.CODBEM    = IBE.CODBEM
    AND BLO.NUMCONTRATO = :OLD.NUMCONTRATO
    AND BLO.DTINICIO    = :OLD.DTNEG
    AND TP.CODTIPOPER   = :OLD.CODTIPOPER
    AND TP.DHALTER      = :OLD.DHTIPOPER
    AND TP.ATUALBEM     = 'T';
    IF P_COUNT > 0 THEN
          ERRMSG := 'Data de Negociação não pode ser alterada com bens locados.';
          RAISE ERROR;
    END IF;
  END IF;

  IF UPDATING('DTENTSAI') THEN
    SELECT COUNT(1) INTO P_COUNT
    FROM TCSBLO BLO
            , TCIIBE IBE
            , TGFTOP TP
    WHERE IBE.NUNOTA   = :OLD.NUNOTA
    AND BLO.CODPROD     = IBE.CODPROD
    AND BLO.CODBEM    = IBE.CODBEM
    AND BLO.NUMCONTRATO = :OLD.NUMCONTRATO
    AND BLO.DTFIM      = :OLD.DTENTSAI
    AND TP.CODTIPOPER   = :OLD.CODTIPOPER
    AND TP.DHALTER      = :OLD.DHTIPOPER
    AND TP.ATUALBEM     = 'D';
  IF P_COUNT > 0 THEN
      ERRMSG := 'Data de Ent.\Sai. não pode ser alterada com bens locados.';
      RAISE ERROR;
  END IF;
  END IF;

  IF UPDATING('CODVEICULO') AND :NEW.CODVEICULO IS NOT NULL THEN
     Stp_Valida_Veiculo(:NEW.CODVEICULO);
  END IF;

  IF UPDATING('CODPARCDEST') AND (:NEW.CODPARCDEST IS NOT NULL) THEN
     SELECT COUNT(1)  INTO P_COUNT
     FROM  TGFPAR P
     WHERE P.CODPARC = :NEW.CODPARCDEST
       AND P.ATIVO = 'S';
     IF (P_COUNT = 0) THEN
        ERRMSG := 'Parceiro ' || TO_CHAR(:NEW.CODPARCDEST) || 'destino não está ativo. ';
        RAISE ERROR;
     END IF;
  END IF;

  IF UPDATING('NUMCONTRATO') AND (:NEW.NUMCONTRATO IS NOT NULL) THEN
     SELECT COUNT(1)  INTO P_COUNT
     FROM  TCSCON C
     WHERE C.NUMCONTRATO = :NEW.NUMCONTRATO
       AND C.ATIVO = 'S';
     IF (P_COUNT = 0) THEN
        ERRMSG := 'Contrato ' || TO_CHAR(:NEW.NUMCONTRATO) || ' não está ativo. ';
        RAISE ERROR;
     END IF;
  END IF;

  IF UPDATING('CODPROJ') AND (:NEW.CODPROJ IS NOT NULL) THEN
     SELECT COUNT(1)  INTO P_COUNT
     FROM  TCSPRJ P
     WHERE P.CODPROJ = :NEW.CODPROJ AND P.ATIVO = 'S'
       AND P.ANALITICO = 'S';
     IF (P_COUNT = 0) THEN
        ERRMSG := Erros_Pkg.ERRO_PROJETO_NAOATIVO;
        RAISE ERROR;
     END IF;
  END IF;

  IF UPDATING('CODEMP') THEN
     SELECT COUNT(1) INTO P_COUNT
     FROM TGFEMP E
     WHERE E.CODEMP = :NEW.CODEMP
     AND E.ATIVO = 'S';
     IF (P_COUNT = 0) THEN
        ERRMSG := 'Empresa ' || TO_CHAR(:NEW.CODEMP) || ' não está ativa. ';
        RAISE ERROR;
     END IF;
  END IF;

  IF UPDATING('CODCENCUS') AND (:NEW.CODCENCUS IS NOT NULL) AND (:NEW.CODCENCUS <> 0) THEN
     SELECT COUNT(1) INTO P_COUNT
     FROM TSICUS C
     WHERE C.CODCENCUS = :NEW.CODCENCUS AND C.ATIVO = 'S'
       AND C.ANALITICO = 'S';
     IF P_COUNT = 0 THEN
        Stp_Popula_Msg('TSICUS');
     END IF;
  END IF;

  IF UPDATING('CODEMPNEGOC') AND (:NEW.CODEMPNEGOC IS NOT NULL) AND (:NEW.CODEMP <> :NEW.CODEMPNEGOC) THEN
     SELECT COUNT(1) INTO P_COUNT
     FROM TGFEMP E
     WHERE E.CODEMP = :NEW.CODEMPNEGOC
     AND E.ATIVO = 'S';
     IF (P_COUNT = 0) THEN
        ERRMSG := 'Empresa de negociação ' || TO_CHAR(:NEW.CODEMPNEGOC) || ' não está ativa. ';
        RAISE ERROR;
     END IF;
  END IF;

  IF UPDATING('CODPARC') THEN
     SELECT COUNT(1)  INTO P_COUNT
     FROM  TGFPAR P
     WHERE P.CODPARC = :NEW.CODPARC
       AND P.ATIVO = 'S';
     IF (P_COUNT = 0) THEN
        ERRMSG := Erros_Pkg.ERRO_PARCEIRO_NAOATIVO;
        RAISE ERROR;
     END IF;
  END IF;

  IF UPDATING('CODPARCTRANSP') AND (:NEW.CODPARCTRANSP IS NOT NULL) THEN
     SELECT COUNT(1)  INTO P_COUNT
     FROM  TGFPAR P
     WHERE P.CODPARC = :NEW.CODPARCTRANSP
     AND P.ATIVO = 'S';
     IF (P_COUNT = 0) THEN
        ERRMSG := 'Transportadora ' || TO_CHAR(:NEW.CODPARCTRANSP) || ' não está ativa. ';
        RAISE ERROR;
     END IF;
  END IF;

  IF UPDATING('CODVEND') AND (:NEW.CODVEND IS NOT NULL) THEN
     SELECT COUNT(1) INTO P_COUNT
     FROM  TGFVEN V
     WHERE V.CODVEND = :NEW.CODVEND
       AND V.ATIVO = 'S';
     IF (P_COUNT = 0) THEN
        ERRMSG := Erros_Pkg.ERRO_VENDEDOR_NAOATIVO;
        RAISE ERROR;
     END IF;
  END IF;


  IF UPDATING('CODTIPOPER') OR UPDATING('DHTIPOPER') OR UPDATING('TIPMOV') THEN
    IF (:NEW.CODTIPOPER = 0) AND (:NEW.TIPMOV <> 'Z') THEN
       ERRMSG := 'Campo Top obrigatório.';
       RAISE ERROR;
    END IF;

    SELECT COUNT(1) INTO P_COUNT
    FROM  TGFTOP T
    WHERE :NEW.CODTIPOPER = T.CODTIPOPER
      AND :NEW.DHTIPOPER = T.DHALTER
      AND T.ATIVO = 'S';
    IF (P_COUNT = 0) THEN
        ERRMSG := Erros_Pkg.ERRO_TIPOPER_NAOATIVO;
        RAISE ERROR;
    END IF;

    IF (:NEW.TIPMOV <> 'Z') THEN

      SELECT COUNT(1) INTO P_COUNT
      FROM TGFTOP T
      WHERE T.CODTIPOPER = :NEW.CODTIPOPER
        AND T.DHALTER = :NEW.DHTIPOPER
        AND :NEW.TIPMOV <> T.TIPMOV;
      IF ( P_COUNT <> 0) THEN
         ERRMSG := 'Esta TOP ' || TO_CHAR(:NEW.CODTIPOPER) || ' não pode ser lançada nesta opção.';
         RAISE ERROR;
      END IF;
    END IF;

    IF (:NEW.APROVADO <> 'X') THEN
      SELECT T.ATUALFIN,  T.TIPATUALFIN, T.ATUALEST INTO
             P_ATUALFIN_D, P_TIPATUALFIN_D, P_ATUALEST_D
        FROM TGFTOP T
       WHERE T.CODTIPOPER = :OLD.CODTIPOPER
         AND T.DHALTER    = :OLD.DHTIPOPER;
      IF ((P_ATUALFIN_D <> P_ATUALFIN) OR (P_TIPATUALFIN_D <> P_TIPATUALFIN)) THEN
        SELECT COUNT(1) INTO P_COUNT
        FROM TGFFIN F
        WHERE F.NUNOTA = :NEW.NUNOTA
          AND F.VLRBAIXA > 0
          AND F.DTNEG <> F.DHBAIXA;
        IF (P_COUNT <> 0) THEN
            ERRMSG := 'Não foi possível atualizar a nota, pois a atualização da TOP ' || TO_CHAR(:NEW.CODTIPOPER) || ' é inválida.';
            RAISE ERROR;
        END IF;
      END IF;
    END IF;

  BEGIN
  SELECT T.ATUALFIN,T.TIPATUALFIN, T.ATUALEST, T.ATUALFINTERC, T.ATUALESTTERC, T.ALTITEMPARCFAT, T.INDPRESNFCE, T.CODINTERM, T.INTERMED, PERMFINMENORVLRNOTA
    INTO P_ATUALFIN,P_TIPATUALFIN, P_ATUALEST, P_ATUALFINTERC, P_ATUALESTTERC, P_ALTITEMPARCFAT, P_INDPRESNFCE, P_CODINTERM, P_INTERMED, P_PERMFINMENORVLRNOTA
  FROM  TGFTOP T
  WHERE T.CODTIPOPER = :NEW.CODTIPOPER
    AND T.DHALTER    = :NEW.DHTIPOPER;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    ERRMSG := 'Não foi encontrada a TOP ' || TO_CHAR(:NEW.CODTIPOPER) || ' com data de alteração igual a ' || TO_CHAR(:NEW.DHTIPOPER) || ' .';
    RAISE ERROR;
  END;

  END IF;



  IF (:NEW.TIPMOV = 'F') OR (:NEW.DTENTSAI IS NULL OR :NEW.DTENTSAI < :NEW.DTNEG) THEN
     :NEW.DTENTSAI := :NEW.DTNEG;
  END IF;

  IF :NEW.INDPRESNFCE IS NULL THEN
   :NEW.INDPRESNFCE := P_INDPRESNFCE;
  END IF;

  IF :NEW.CODINTERM IS NULL THEN
   :NEW.CODINTERM := P_CODINTERM;
  END IF;

  IF :NEW.INTERMED IS NULL THEN
   :NEW.INTERMED := P_INTERMED;
  END IF;

  IF (UPDATING('CODCONTATO') OR UPDATING('CODPARC')) AND (:NEW.CODCONTATO IS NOT NULL) THEN
    SELECT COUNT(1) INTO P_COUNT
    FROM  TGFCTT C
    WHERE :NEW.CODPARC = C.CODPARC
      AND :NEW.CODCONTATO = C.CODCONTATO
      AND C.ATIVO = 'S';
    IF (P_COUNT = 0) THEN
        ERRMSG := 'Contato ' || TO_CHAR(:NEW.CODCONTATO) || ' não está ativo. ';
        RAISE ERROR;
    END IF;
  END IF;

  IF (UPDATING('CODCONTATOENTREGA') OR UPDATING('CODPARC')) AND (:NEW.CODCONTATOENTREGA IS NOT NULL) THEN
    SELECT COUNT(1) INTO P_COUNT
    FROM  TGFCTT C
    WHERE :NEW.CODPARC = C.CODPARC
      AND :NEW.CODCONTATOENTREGA = C.CODCONTATO
      AND C.ATIVO = 'S';
    IF (P_COUNT = 0) THEN
        ERRMSG := 'Contato ' || TO_CHAR(:NEW.CODCONTATOENTREGA) || ' não está ativo. ';
        RAISE ERROR;
    END IF;
  END IF;
  IF (UPDATING('CODTIPVENDA') OR UPDATING('DHTIPVENDA')) THEN
    SELECT COUNT(1) INTO P_COUNT
    FROM  TGFTPV T
    WHERE :NEW.CODTIPVENDA = T.CODTIPVENDA
      AND :NEW.DHTIPVENDA = T.DHALTER
      AND T.ATIVO = 'S';
    IF (P_COUNT = 0) THEN
        ERRMSG := 'Verifique se o Tipo de Venda '  || TO_CHAR(:NEW.CODTIPVENDA, '9999')|| ' está ativo ou se sua data de alteração é menor ou igual a data de lançamento da nota. ';
        RAISE ERROR;
       --Stp_Popula_Msg('TGFTPV');
    END IF;

    /* Vendas tem tipo de negociação */
    IF (:NEW.TIPMOV = 'P') OR (:NEW.TIPMOV = 'V') OR (:NEW.TIPMOV = 'D') THEN
      IF (:NEW.CODTIPVENDA = 0) THEN
         ERRMSG := 'Campo Tipo de negociação obrigatório.';
         RAISE ERROR;
      END IF;
    END IF;
  END IF;

  /* testa se o ano digitada e valido */
  IF (UPDATING('DTMOV')
      OR UPDATING('DTNEG')
      OR UPDATING('DTENTSAI'))
    THEN
    SELECT NVL(P.INTEIRO,0) INTO P_COUNT
    FROM TSIPAR P
    WHERE P.CHAVE = 'LIMSUPANO';

    IF P_COUNT > 100 THEN
      P_COUNT := 100;
    END IF;

    IF  (P_COUNT <> 0)
                AND ( ( ( :NEW.DTMOV <> NULL )
                AND ( :NEW.DTMOV > ADD_MONTHS(SYSDATE, 12 * P_COUNT) ) )
                OR  ( ( :NEW.DTENTSAI <> NULL )
                AND ( :NEW.DTENTSAI > ADD_MONTHS(SYSDATE, 12 * P_COUNT) ) )
                OR  ( :NEW.DTNEG > ADD_MONTHS(SYSDATE, 12 * P_COUNT) )
        ) THEN
      ERRMSG := 'Ano superior ao limite permitido, veja o parâmetro de Limite Superior para Ano .';
      RAISE ERROR;
    END IF;

    BEGIN
      SELECT NVL(P.INTEIRO  ,0) INTO P_COUNT
      FROM TSIPAR P
      WHERE P.CHAVE = 'LIMINFANO';
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      P_COUNT := 0;
    WHEN OTHERS THEN
      ERRMSG := SUBSTR(SQLERRM,1,200);
      RAISE ERROR;
    END;

    IF P_COUNT > 100 THEN
      P_COUNT := 100;
    END IF;

    IF ( P_COUNT <> 0)
                AND ( ( ( :NEW.DTMOV <> NULL )
                AND ( :NEW.DTMOV < ADD_MONTHS(SYSDATE, 12 * -P_COUNT) ) )
                OR  ( ( :NEW.DTENTSAI <> NULL )
                AND ( :NEW.DTENTSAI < ADD_MONTHS(SYSDATE, 12 * -P_COUNT) ) )
                OR  ( :NEW.DTNEG < ADD_MONTHS(SYSDATE, 12 * -P_COUNT) )
          ) THEN
          ERRMSG := 'Ano inferior ao limite permitido, veja o parâmetro de Limite Inferior para Ano.';
          RAISE ERROR;
    END IF;
  END IF;
  IF (UPDATING('CODPARC') OR UPDATING('CODTIPVENDA') OR UPDATING('DHTIPVENDA') OR UPDATING('STATUSNOTA')) AND
     ((:NEW.TIPMOV = 'P') OR (:NEW.TIPMOV = 'V') OR (:NEW.TIPMOV = 'L')) THEN
     SELECT COUNT(1)   INTO P_COUNT
     FROM TGFPAR P, TGFTPV T
     WHERE :NEW.CODPARC = P.CODPARC
       AND :NEW.CODTIPVENDA = T.CODTIPVENDA
       AND :NEW.DHTIPVENDA = T.DHALTER
       AND T.SUBTIPOVENDA <> '1'
       AND T.SUBTIPOVENDA <> '6'
       AND T.SUBTIPOVENDA <> '7'
       AND T.SUBTIPOVENDA <> '8'
       AND (T.VALPRAZOCLIENTE = 'S') AND (P.PRAZOPAG = 0);
     IF (P_COUNT <> 0 ) THEN
        ERRMSG := 'Prazo bloqueado.';
        RAISE ERROR;
     END IF;

     SELECT COUNT(1) INTO P_COUNT
     FROM TGFPAR P, TGFTPV T
     WHERE :NEW.CODPARC = P.CODPARC
       AND :NEW.CODTIPVENDA = T.CODTIPVENDA
       AND :NEW.DHTIPVENDA = T.DHALTER
       AND T.SUBTIPOVENDA <> '1'
       AND T.SUBTIPOVENDA <> '6'
       AND T.SUBTIPOVENDA <> '7'
       AND T.SUBTIPOVENDA <> '8'
       AND P.BLOQUEAR = 'S';
     IF (P_COUNT <> 0 ) THEN
        ERRMSG := 'Venda a prazo bloqueada.';
        RAISE ERROR;
     END IF;
     /* valida se o parceiro da nota faz parte do grupo de alteração da Top */
     SELECT COUNT(1)  INTO P_COUNT
     FROM TGFTPV T, TGFPAR P
     WHERE :NEW.CODPARC = P.CODPARC
       AND :NEW.CODTIPVENDA = T.CODTIPVENDA
       AND :NEW.DHTIPVENDA = T.DHALTER
       AND T.GRUPOAUTOR > ''
       AND NOT (P.GRUPOAUTOR LIKE '%' || T.GRUPOAUTOR || '%');
     IF (P_COUNT <> 0 ) THEN
        ERRMSG := 'Tipo de negociação ' || TO_CHAR(:NEW.CODTIPVENDA) || ' não autorizado para este cliente! Ver Grupo autorização.';
        RAISE ERROR;
     END IF;
  END IF;

  IF (UPDATING('CODPARC') OR UPDATING('TIPMOV')) THEN
    SELECT COUNT(1)  INTO P_COUNT
      FROM TGFPAR P
     WHERE P.CODPARC = :NEW.CODPARC
       AND ( ( P.CODPARC = 0 AND :NEW.TIPMOV IN ('O', 'C', 'E', 'P', 'V', 'D', 'S', 'M', '1', '2', '3', '8', 'N') )
            OR ( :NEW.TIPMOV IN ('O', 'C', 'E')  AND  P.FORNECEDOR <> 'S')
            OR ( :NEW.TIPMOV IN ('P', 'V', 'D', '1', '2', '3', '8', 'N') AND P.CLIENTE <> 'S' ));
    IF (P_COUNT <> 0 ) THEN
       ERRMSG := 'O parceiro deve conter valor válido e dif. de zero.' ||
                 ' Para op. de compra, ped. de compra e dev. de compra, o parc. deve ser um fornecedor.' ||
                 ' Já para op. de venda, ped. de venda e dev. de venda, o parc. deve ser um cliente.';
       RAISE ERROR;
    END IF;
  END IF;

  IF (:NEW.CODEMP = :NEW.CODEMPNEGOC) AND (:NEW.TIPMOV = 'T') THEN
    SELECT P.LOGICO INTO P_UTILIZALOCAL
    FROM TSIPAR P
    WHERE P.CHAVE = 'UTILIZALOCAL';
    IF (P_UTILIZALOCAL = 'N') THEN
        ERRMSG := 'Empresa de destino deve ser diferente da empresa de origem.';
        RAISE ERROR;
    END IF;
  END IF;
  /* não posso atualizar a DTNEG, CODTIPVENDA, DHTIPVENDA E VLRNOTA se já foi baixado algum registro na TGFFin */
  IF (:NEW.APROVADO <> 'X')
     AND NOT(:NEW.TIPMOV IN ('P', 'O') AND P_TIPATUALFIN = 'P' AND P_ALTITEMPARCFAT = 'S')
     AND( (:NEW.DTNEG <> :OLD.DTNEG)OR  (:NEW.CODTIPVENDA<>:OLD.CODTIPVENDA) OR
          (:NEW.DHTIPVENDA <> :OLD.DHTIPVENDA) OR (:NEW.VLRNOTA<>:OLD.VLRNOTA)) THEN
    BEGIN
       SELECT INTEIRO INTO P_TIPTIT_COMPENSACAO FROM TSIPAR WHERE CHAVE = 'TIPTITCREDCLI';
    EXCEPTION WHEN NO_DATA_FOUND THEN
      P_TIPTIT_COMPENSACAO := 0;
    WHEN OTHERS THEN
      RAISE;
    END;

    SELECT COUNT(1) INTO P_COUNT
    FROM TGFFIN F
    WHERE F.NUNOTA = :NEW.NUNOTA
    AND F.VLRBAIXA > 0
    AND F.NUFIN > 0
    AND ( P_TIPTIT_COMPENSACAO = 0 OR F.CODTIPTIT <> P_TIPTIT_COMPENSACAO )
    AND (DESDOBDUPL IS NULL OR DESDOBDUPL NOT IN ('M', 'V', 'K', 'F'));
    IF (P_COUNT <> 0 ) THEN
       ERRMSG := 'Não se pode atualizar a data de negociação, o código do tipo de negociação ou o valor da nota de uma nota que já foi baixada no financeiro.';
       RAISE ERROR;
    END IF;
  END IF;

  IF (:OLD.STATUSNOTA <> :NEW.STATUSNOTA) THEN
    /* Stp_Valida_Dentroestado(:NEW.NUNOTA);  */
    /* ======  Se a provisao do financeiro ' de um só tipo e correta ====== */
    IF (P_ATUALFIN <> 0) THEN
        IF P_TIPATUALFIN = 'P' THEN
          P_PROVISAO := 'S';
        ELSE
          P_PROVISAO := 'N';
        END IF;
        SELECT COUNT(1) INTO P_COUNT
        FROM TGFFIN
        WHERE NUNOTA = :NEW.NUNOTA
          AND PROVISAO <> P_PROVISAO;
        IF (P_COUNT <> 0) THEN
           ERRMSG := 'O financeiro está provisionando e não provisionando. Só um dos dois pode acontecer.';
           RAISE ERROR;
        END IF;

       /* PARA ATUALIZAR O CRÉDITO DE CARTÃO FIDELIDADE  */
       SELECT COUNT(1) INTO P_COUNT
       FROM TGFCFM
       WHERE NUNOTA = :NEW.NUNOTA
         AND SINAL = 1;
       IF P_COUNT > 0 THEN
         UPDATE TGFCFM SET VALOR = :NEW.VLRNOTA
         WHERE NUNOTA = :NEW.NUNOTA
         AND SINAL = 1;
       END IF;
    END IF;

/* Verifica se o financeiro é da geração do conhecimento de transporte
    SELECT COUNT(1) INTO P_COUNT  FROM TGFFIN
    WHERE NUNOTA = :NEW.NUNOTA
     AND DESDOBDUPL = 'T';

    IF (P_COUNT = 0) THEN  (VALIDAÇÃO COMENTADA OS 470978) */
     /* ======  Verificando valores de desdobramento do Financeiro  ====== */

     SELECT SUM(NVL(VLRDESDOB,0) * RECDESP) INTO P_TOTDESDOB
   FROM TGFFIN FIN
   JOIN TGFPAR PAR ON (:NEW.CODPARC = PAR.CODPARC)
   LEFT JOIN TSICID CID ON (PAR.CODCID = CID.CODCID AND CID.CODCID <> 0)
   LEFT JOIN TSIUFS UFS ON (UFS.CODUF = CID.UF AND UFS.CODUF <> 0)
       WHERE FIN.NUNOTA = :NEW.NUNOTA
       AND (DESDOBDUPL IS NULL OR DESDOBDUPL NOT IN ('M', 'V', 'K', 'F', 'T'))
       AND ((CODTIPTIT <> P_GNREST) OR(P_GNREST = 0))
     AND ((CODTIPTIT <> P_GNRECTE) OR(P_GNRECTE = 0))
       AND ((CODTIPTIT <> P_TIPTITGNRESTRB) OR(P_TIPTITGNRESTRB = 0))
       AND NOT EXISTS ( SELECT 1
              FROM TGFFPI FPI
              WHERE FPI.CODTIPTIT = FIN.CODTIPTIT
              AND FPI.CODUF = UFS.CODUF);

      IF (P_ATUALFIN = 0) THEN
        IF (P_TOTDESDOB IS NOT NULL) THEN
           ERRMSG := 'Esta TOP não pode atualizar o financeiro.';
           RAISE ERROR;
        END IF;
      ELSIF ROUND((P_TOTDESDOB * P_ATUALFIN),2) < ROUND(:NEW.VLRNOTA,2) THEN
        IF(P_ATUALFINTERC = 'N') AND (P_ATUALESTTERC <>'N') THEN
                        Tgfcab_Upd_Pkg.V_CONTADOR := Tgfcab_Upd_Pkg.V_CONTADOR + 1;
            Tgfcab_Upd_Pkg.V_NUNOTA(Tgfcab_Upd_Pkg.V_CONTADOR) := :NEW.NUNOTA;
            Tgfcab_Upd_Pkg.V_TOTDESDOB(Tgfcab_Upd_Pkg.V_CONTADOR) := ROUND((P_TOTDESDOB * P_ATUALFIN),2);
            Tgfcab_Upd_Pkg.V_VLRNOTA(Tgfcab_Upd_Pkg.V_CONTADOR) := :NEW.VLRNOTA;
        ELSE
          IF P_PERMFINMENORVLRNOTA <> 'S' THEN
          ERRMSG := 'A somatória dos valores do financeiro ('||TO_CHAR((P_TOTDESDOB * P_ATUALFIN), '999999.99') ||
                    ') não corresponde ao total da nota (' || TO_CHAR(:NEW.VLRNOTA, '9999999.99') || ').';
          RAISE ERROR;
        END IF;
      END IF;
      END IF;
    /*END IF;*/
  END IF;

  IF UPDATING('CODMOTORISTA') AND (:NEW.CODMOTORISTA <> 0) THEN
     SELECT MOTORISTA, ATIVO INTO P_MOTORISTA, P_ATIVO
      FROM TGFPAR
     WHERE CODPARC = :NEW.CODMOTORISTA;
    IF (P_MOTORISTA <> 'S') THEN
        ERRMSG := 'Parceiro ' || TO_CHAR(:NEW.CODMOTORISTA) || ' não está marcado como Motorista.';
        RAISE ERROR;
    END IF;

    IF (P_ATIVO <> 'S') THEN
        ERRMSG := 'Motorista ' || TO_CHAR(:NEW.CODMOTORISTA) || 'não está ativo.';
        RAISE ERROR;
    END IF;
  END IF;

  IF (:NEW.STATUSNOTA = 'L') AND (:NEW.TIPMOV IN ('P','O','C','D','V')) THEN -- OS 447451
    SELECT COUNT(1), MIN(CHAVE)
    INTO P_COUNT, P_CHAVE
    FROM TSIPAR
    WHERE CHAVE IN ('TOPSACUMTROCA','TOPSUSATROCA')
    AND TEXTO IS NOT NULL
    AND  (',' || trim(REPLACE(TEXTO,' ','')) || ',') LIKE '%,' || :NEW.CODTIPOPER || ',%';
  IF P_COUNT <> 0 THEN
      IF P_COUNT > 1 THEN
        ERRMSG := 'Uma TOP não pode participar do param.TOPSACUMTROCA e do param.TOPSUSATROCA simultâneamente.';
        RAISE ERROR;
      ELSIF P_COUNT = 1 THEN
        --VERIFICANDO SE A NOTA ESTÁ LIGADA.
            SELECT COUNT (1)
              INTO P_COUNT
              FROM TGFVAR
             WHERE :NEW.NUNOTA IN (NUNOTA, NUNOTAORIG) AND NUNOTA <> NUNOTAORIG AND SEQUENCIA = 0 AND SEQUENCIAORIG = 0;

            IF ( P_COUNT > 0 )
          AND (    (:OLD.STATUSNOTA = 'L')
            AND (:NEW.TIPMOV NOT IN ('D', 'P'))
            AND NOT (UPDATING('NUMNOTA') OR
             UPDATING ('PENDENTE') OR
                     UPDATING('SERIENOTA') OR
                     UPDATING('TPEMISNFE') OR
                     UPDATING('DTALTER') OR
                     UPDATING('CODUSU') OR
                     UPDATING('NUMALEATORIO') OR
                     UPDATING('CHAVENFE') OR
                     UPDATING('DHPROTOC') OR
                     UPDATING('NUMPROTOC') OR
                     UPDATING('STATUSNFE'))
           ) THEN
         ERRMSG := 'Não é permitido alterar uma nota de troca já confirmada.';
          RAISE ERROR;
        END IF;

        IF P_CHAVE = 'TOPSACUMTROCA' THEN
          IF :NEW.TIPMOV NOT IN ('O', 'C', 'D','V') THEN
              ERRMSG := 'Param.TOPSACUMTROCA deve ter TOP de: Compra, Pedido de Compra ou Devolução de Venda.';
              RAISE ERROR;
          END IF;
          P_SINAL := 1;
        ELSE
          P_SINAL := -1;
        END IF;

        IF P_CHAVE = 'TOPSUSATROCA' THEN
          P_VLRTROCA := :NEW.VLRNOTA;
        ELSE
          --VERIFICANDO SE TODOS OS ITENS POSSUEM O VLRTROCA
          SELECT SUM(CASE WHEN VLRTROCA IS NULL THEN 1 ELSE 0 END), SUM(VLRTROCA)
          INTO P_COUNT, P_VLRTROCA
          FROM TGFITE
          WHERE NUNOTA = :NEW.NUNOTA
          AND SEQUENCIA > 0;
          IF P_COUNT > 0 THEN
            ERRMSG := 'Não é permitido confirmar, pois a TOP é de troca (parâmetro "TOPSACUMTROCA"). O preço base dos produtos deve ser atualizado através da rotina Atualizar Preço de Produtos para Acumular Saldo de Troca.';
            RAISE ERROR;
          END IF;

        IF (:OLD.STATUSNOTA <> 'L') THEN
          SELECT COUNT(1) INTO P_ULTCOD
          FROM TGFNUM
          WHERE ARQUIVO = 'TGFMST';

          IF P_ULTCOD = 0 THEN
            P_ULTCOD := 1;
            INSERT INTO TGFNUM(ARQUIVO
            , CODEMP
            , ULTCOD
            , ULTNOTATALAO)VALUES('TGFMST'
            , :NEW.CODEMP
            , 1
            , 999999999);
          ELSE
            SELECT MAX(NVL(ULTCOD, 0)) + 1 INTO P_ULTCOD
            FROM TGFNUM
            WHERE ARQUIVO = 'TGFMST';

            UPDATE TGFNUM SET ULTCOD = P_ULTCOD
            WHERE ARQUIVO = 'TGFMST';
          END IF;

          INSERT INTO TGFMST(NUMST
            , NUNOTA
            , CODVEND
            , CODPARC
            , VALOR
            , OBSERVACAO
            , SINAL
            , CODUSU)
          VALUES(P_ULTCOD
            , :NEW.NUNOTA
            , :NEW.CODVEND
            , :NEW.CODPARC
            , P_VLRTROCA
            , 'Inclusão efetuada na confirmação da nota.'
            , P_SINAL
            , 0);
        END IF;
      END IF;
  END IF;
  END IF;
   END IF;

  IF (:NEW.CODEMP <> :OLD.CODEMP OR :NEW.CODEMPNEGOC <> :OLD.CODEMPNEGOC) THEN
    INSERT INTO TGFCAB_UPT ( NUNOTA,      CODEMPNOV,   CODEMPANT , CODEMPNEGOCNOV ,  CODEMPNEGOCANT)
                    VALUES (:NEW.NUNOTA, :NEW.CODEMP, :OLD.CODEMP,:NEW.CODEMPNEGOC, :OLD.CODEMPNEGOC);
  END IF;

  -- ALTERACAO PRODNFE OS 673279
  P_CODTOPPREVENDA := GET_TSIPAR_INTEIRO('CODTOPPREVENDA');

  SELECT EMP.NFE, TPO.NFE, TPO.BASENUMERACAO, TPO_OLD.NFE
    INTO P_EMPNFE, P_TOPNFE, P_BASENUMERACAO, P_TOPNFE_OLD
  FROM TGFEMP EMP
     , TGFTOP TPO
     , TGFTOP TPO_OLD
  WHERE EMP.CODEMP = :NEW.CODEMP
    AND TPO.CODTIPOPER = :NEW.CODTIPOPER
    AND TPO.DHALTER = :NEW.DHTIPOPER
    AND TPO_OLD.CODTIPOPER = :OLD.CODTIPOPER
    AND TPO_OLD.DHALTER = :OLD.DHTIPOPER;

  IF (((:NEW.CODTIPOPER <> :OLD.CODTIPOPER) OR (:NEW.DHTIPOPER <> :OLD.DHTIPOPER))
      AND NVL(P_TOPNFE, 'M') NOT IN ('M', 'T')
      AND P_TOPNFE_OLD IN ('M', 'T')) THEN

    INSERT INTO TGFCAB_UPT (NUNOTA, PRODUTONFE) VALUES (:NEW.NUNOTA, 'S');

  END IF;

/*
  **MARCELO
  ATENCAO NAO PODE SER MODIFICADO O CODIGO DA EMPRESA E NEM O CODIGO DO
  PARCEIRO NO UPDATE DA TGFFIN , POR CAUSA DOS VALORES LANCADOS
  EM OUTROS E FRETE, TAMBEM POR CAUSA DO TIPO DE NEGOCIACAO QUE ESTES
  CAMPOS SAO LIVRES.
*/
  IF (:NEW.NUMNOTA <> :OLD.NUMNOTA OR
      :NEW.DTENTSAI <> :OLD.DTENTSAI OR
      :NEW.DTNEG <> :OLD.DTNEG OR
      :NEW.CODTIPOPER <> :OLD.CODTIPOPER OR
      :NEW.DHTIPOPER <> :OLD.DHTIPOPER) THEN
    SELECT COUNT(1) INTO P_COUNT
  FROM TGFFIN
  WHERE NUNOTA = :NEW.NUNOTA
      AND (DESDOBDUPL IS NULL OR DESDOBDUPL NOT IN ('M', 'V', 'K', 'F'));
  IF P_COUNT > 0 THEN
      UPDATE TGFFIN SET
       NUMNOTA      = :NEW.NUMNOTA,
       DTENTSAI     = :NEW.DTENTSAI,
       DTNEG        = :NEW.DTNEG,
       CODTIPOPER   = :NEW.CODTIPOPER,
       DHTIPOPER    = :NEW.DHTIPOPER
      WHERE NUNOTA = :NEW.NUNOTA
        AND (DESDOBDUPL IS NULL OR DESDOBDUPL NOT IN ('M', 'V', 'K', 'F'));
    END IF;
  END IF;

  IF (:NEW.SERIENOTA <> :OLD.SERIENOTA OR
      :NEW.CODVEND <> :OLD.CODVEND OR
      :NEW.CODMOEDA <> :OLD.CODMOEDA OR
      :NEW.CODVEICULO <> :OLD.CODVEICULO OR
    :NEW.CODUSU<> :OLD.CODUSU) THEN
  SELECT COUNT(1) INTO P_COUNT
  FROM TGFFIN
  WHERE NUNOTA = :NEW.NUNOTA
      AND (DESDOBDUPL IS NULL OR DESDOBDUPL NOT IN ('M', 'V', 'K', 'F'));
  IF P_COUNT > 0 THEN
    BEGIN
      Tgffin_Pkg.V_VALIDA_FINANCEIRO := FALSE;
        UPDATE TGFFIN SET
         SERIENOTA    = :NEW.SERIENOTA,
         CODVEND      = :NEW.CODVEND,
         CODMOEDA     = :NEW.CODMOEDA,
         CODVEICULO = :NEW.CODVEICULO,
       CODUSU = :NEW.CODUSU
        WHERE NUNOTA = :NEW.NUNOTA
          AND (DESDOBDUPL IS NULL OR DESDOBDUPL NOT IN ('M', 'V', 'K', 'F'));
    Tgffin_Pkg.V_VALIDA_FINANCEIRO := TRUE;
    EXCEPTION WHEN OTHERS THEN
      Tgffin_Pkg.V_VALIDA_FINANCEIRO := TRUE;
    RAISE;
    END;
    END IF;
  END IF;

  IF :NEW.VLRNOTA <> :OLD.VLRNOTA AND :NEW.APROVADO = 'S' THEN
    :NEW.APROVADO := 'N';
  END IF;
  --ERRMSG := 'NVL(:NEW.VLRFRETE, 0): '||NVL(:NEW.VLRFRETE, 0)||' NVL(:OLD.VLRFRETE, 0): '||NVL(:OLD.VLRFRETE, 0)||' RATEXTNOTAFRINC:'||GET_TSIPAR_LOGICO('RATFRETEEXTNOTA')|| ':NEW.TIPFRETE: '||:NEW.TIPFRETE;


  IF (GET_TSIPAR_LOGICO('RATEXTNOTAFRINC') = 'S' AND :NEW.TIPFRETE = 'S' AND NVL(:NEW.VLRFRETE, 0) <> NVL(:OLD.VLRFRETE, 0)) THEN
    :NEW.VLRFRETETOTAL := NVL(:NEW.VLRFRETETOTAL, 0) + NVL(:NEW.VLRFRETE, 0) - NVL(:OLD.VLRFRETE, 0);
  END IF;

  IF NVL(:NEW.CODPARCDEST, 0) <> 0 AND NVL(:NEW.CODPARCREMETENTE, 0) <> 0 AND NVL(:NEW.CODCONTATOENTREGA, 0) <> 0 AND
    :NEW.TIPMOV IN ('V', 'C') AND GET_TSIPAR_LOGICO('USAPARREMDESCPA') = 'S' THEN
    ERRMSG := 'Contato de entrega não pode ser em venda ordem (Parceiro remetente e destinatário preenchidos).';
    RAISE ERROR;
  END IF;

  IF :NEW.STATUSNOTA = 'L' THEN

     IF (:OLD.STATUSNOTA <> :NEW.STATUSNOTA OR
         :OLD.CODEMP <> :NEW.CODEMP OR
         :OLD.CODPARC <> :NEW.CODPARC OR
         NVL(:OLD.CODCONTATOENTREGA,0) <> NVL(:NEW.CODCONTATOENTREGA,0)) THEN
        SNK_ORIGEM_DESTINO_ENTREGA(0,
                                    :NEW.CODEMP,
                                    :NEW.CODEMPNEGOC,
                                    :NEW.CODPARC,
                                    :NEW.CODPARCDEST,
                                    :NEW.CODPARCREMETENTE,
                                    :NEW.CODCONTATOENTREGA,
                                    :NEW.TIPMOV,
                                    :NEW.CODCIDORIGEM,
                                    :NEW.CODCIDDESTINO,
                                    :NEW.CODCIDENTREGA,
                                    :NEW.CODUFORIGEM,
                                    :NEW.CODUFDESTINO,
                                    :NEW.CODUFENTREGA);
     END IF;

     IF :OLD.STATUSNOTA <> :NEW.STATUSNOTA OR :OLD.CODTIPOPER <> :NEW.CODTIPOPER OR :OLD.DHTIPOPER <> :NEW.DHTIPOPER THEN
        IF (NVL(:NEW.CODPARCDEST, 0) <> 0 AND
            (:NEW.TIPMOV = 'T' OR
             (:NEW.TIPMOV = 'V' AND NVL(:NEW.CODPARCREMETENTE, 0) <> 0) OR
             (:NEW.TIPMOV = 'C' AND NVL(:NEW.CODPARCREMETENTE, 0) <> 0 AND GET_TSIPAR_LOGICO('USAPARREMDESCPA') = 'S'))) THEN
            P_CODPARC_CLASSIFICMS := :NEW.CODPARCDEST;
        ELSIF NVL(:NEW.CODPARC, 0) <> 0 THEN
            P_CODPARC_CLASSIFICMS := :NEW.CODPARC;
        ELSE
            P_CODPARC_CLASSIFICMS := 0;
            :NEW.CLASSIFICMS := 'R';
        END IF;

        IF P_CODPARC_CLASSIFICMS <> 0 THEN
            :NEW.CLASSIFICMS := SNK_GET_CLASSIFICMS(0, :NEW.CODEMP, P_CODPARC_CLASSIFICMS, NULL, NULL, :NEW.CODTIPOPER, :NEW.DHTIPOPER);

            IF :NEW.CLASSIFICMS = 'T' THEN
                  RAISE_APPLICATION_ERROR(-20101, 'Classificação de ICMS do parceiro inválida para ser usada com esta TOP.');
            END IF;
        END IF;
     END IF;

      SELECT COUNT(1) INTO P_COUNT
      FROM TGFIXN
      WHERE NUNOTA = :NEW.NUNOTA;
      IF P_COUNT > 0 THEN
        UPDATE TGFIXN SET    DTCONFIRMACAO = SYSDATE, STATUS = 5
        WHERE NUNOTA = :NEW.NUNOTA;
      END IF;
  END IF;

  RETURN;
EXCEPTION
  WHEN ERROR THEN
    VARIAVEIS_PKG.V_SBPRODUTO := FALSE;
    ERRMSG := ERRMSG || 'Nota de Nro Único: '|| TO_CHAR(:NEW.NUNOTA);
    /*
    Sincronização de dados não faz validações
    */
    IF (P_VALIDAR) THEN
      RAISE_APPLICATION_ERROR(-20101, ERRMSG);
    END IF;
  WHEN OTHERS THEN
    VARIAVEIS_PKG.V_SBPRODUTO := FALSE;
END;

/
ALTER TRIGGER "GRUPOSOULPRD"."TRG_UPD_TGFCAB" ENABLE;