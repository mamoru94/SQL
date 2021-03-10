CREATE OR REPLACE PROCEDURE MONITORING.p_create_view (p_idreport IN NUMBER)
IS
    invalid_view_signature exception;
    PRAGMA EXCEPTION_INIT (invalid_view_signature, -20001);
    v_name        VARCHAR2 (30) := 'MONITORING_' || LPAD (TO_CHAR (p_idreport), 6, '0');
    cnt           NUMBER;
    signature     NUMBER;
    sql_columns   VARCHAR2 (32767) := '';
    select_clause VARCHAR2 (116)
            := 'SELECT   r.pos rwnum,
           l.idreport,
           l.datereport repdate,
           l.idmu idterritory,
           a.year,';
    col_clause VARCHAR2 (60)
            := 'MAX (CASE c.pos WHEN {pos} THEN a.data ELSE NULL END) c{pos}';
    rest_clause VARCHAR2 (1100)
            := '    FROM                       monitoring.op_crosstabdata a
                           INNER JOIN
                               monitoring.ref_report_row r
                           ON   a.rwnum = r.idrow
                       INNER JOIN
                           monitoring.ref_report_column c
                       ON  a.colnum = c.idcolumn
                   INNER JOIN
                       monitoring.v_op_log l
                   ON     a.id_log = l.id 
               LEFT JOIN
                   monitoring.ref_txtcell t
               ON a.colnum = t.colnum AND a.rwnum = t.rwnum
           INNER JOIN
               v_mis_sp_mureport v
           ON a.idreport = v.idreport AND a.idterritory = v.idmu
   WHERE   l.idreport = '
               || p_idreport
               || ' AND l.idreportstatus IN (1, 2)
GROUP BY   r.pos,
           l.idreport,
           l.datereport,
           l.idmu,
           a.year';
BEGIN
    SELECT   COUNT ( * )
      INTO   cnt
      FROM   user_views
     WHERE   view_name = v_name;

    IF cnt > 0
    THEN
        SELECT   TO_NUMBER (comments)
          INTO   signature
          FROM   user_tab_comments
         WHERE   table_name = v_name AND table_type = 'VIEW';

        IF signature IS NULL
        THEN
            RAISE invalid_view_signature;
        END IF;

        IF f_sign_view (v_name) <> signature
        THEN
            RAISE invalid_view_signature;
        END IF;
    END IF;

    FOR i IN (  SELECT   a.pos
                  FROM   ref_report_column a
                 WHERE   a.idreport = p_idreport
              ORDER BY   a.pos)
    LOOP
        IF LENGTH (sql_columns) > 0
        THEN
            sql_columns :=
                sql_columns || ', ' || CHR (10) || REPLACE (col_clause, '{pos}', i.pos);
        ELSE
            sql_columns :=
                '           ' || CHR (10) || REPLACE (col_clause, '{pos}', i.pos);
        END IF;
    END LOOP;

    EXECUTE IMMEDIATE   'CREATE OR REPLACE VIEW '
                     || v_name
                     || CHR (10)
                     || ' AS '
                     || CHR (10)
                     || select_clause
                     || sql_columns
                     || CHR (10)
                     || rest_clause;

    EXECUTE IMMEDIATE   'COMMENT ON TABLE '
                     || v_name
                     || ' IS '''
                     || TO_CHAR (f_sign_view (v_name))
                     || '''';
EXCEPTION
    WHEN invalid_view_signature
    THEN
        raise_application_error (
            -20001,
            'Представление было создано или изменено вне программы! Cоздание представления невозможно!');
END;                                                                        -- Procedure;
