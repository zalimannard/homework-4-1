CREATE OR REPLACE FUNCTION ставки_сотрудника(employee_id INTEGER) RETURNS TABLE (
    табельный_номер VARCHAR(10),
    фамилия VARCHAR(30),
    имя VARCHAR(30),
    отчество VARCHAR(30),
    пол VARCHAR(7),
    военнообязанный VARCHAR(3),
    приказ_о_приеме VARCHAR(20),
    дата_приема DATE,
    условие_приема VARCHAR(100),
    состояние VARCHAR(30),
    дата_рождения DATE,
    год_рождения INTEGER,
    возраст INTEGER,
    подразделение VARCHAR(80),
    должность VARCHAR(40),
    стаж_работы VARCHAR(8),
    стаж_работы_в_организации VARCHAR(8),
    ИНН VARCHAR(12),
    СНИЛС VARCHAR(11),
    статус VARCHAR(20),
    ставка VARCHAR(5),
    телефон VARCHAR(12),
    паспорт_серия VARCHAR(4),
    паспорт_номер VARCHAR(6),
    паспорт_дата_выдачи DATE,
    кем_выдан_паспорт VARCHAR(300),
    адрес_по_паспорту VARCHAR(300),
    адрес_фактический VARCHAR(300)
) AS $$
DECLARE
    дата_приёма_на_работу DATE;
    лет INTEGER;
    месяцев INTEGER;
    дней INTEGER;
BEGIN
    SELECT MIN(дата)
    INTO дата_приёма_на_работу
    FROM журнал_приема_перевода
    WHERE id_сотрудника = employee_id;

    SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE, дата_приёма_на_работу)) AS лет,
           EXTRACT(MONTH FROM AGE(CURRENT_DATE, дата_приёма_на_работу)) AS месяцев,
           EXTRACT(DAY FROM AGE(CURRENT_DATE, дата_приёма_на_работу)) AS дней
    INTO лет, месяцев, дней;

    RETURN QUERY
    SELECT
        сотрудники.табельный_номер,
        физлица.фамилия,
        физлица.имя,
        физлица.отчество,
        физлица.пол,
        CASE WHEN информация_о_воинском_учете.id IS NOT NULL THEN 'да'::VARCHAR ELSE 'нет'::VARCHAR END,
        журнал_приказов.номер_дока,
        журнал_приказов.дата,
        условия_приема.название,
        журнал_места_работы.состояние,
        физлица.дата_рождения,
        EXTRACT(YEAR FROM физлица.дата_рождения)::INTEGER,
        EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER - EXTRACT(YEAR FROM физлица.дата_рождения)::INTEGER,
        структурные_подразделения.название,
        должности.название,
        физлица.стаж,
        (лет || '.' || месяцев || '.' || дней)::VARCHAR,
        физлица.ИНН,
        физлица.СНИЛС,
        журнал_приказов.статус,
        журнал_места_работы.ставка,
        физлица.телефон,
        физлица.паспорт_серия,
        физлица.паспорт_номер,
        физлица.паспорт_дата_выдачи,
        физлица.паспорт_выдан,
        физлица.адрес_по_паспорту,
        физлица.адрес_фактический
    FROM сотрудники
    INNER JOIN физлица ON сотрудники.id_физлица = физлица.id
    LEFT JOIN информация_о_воинском_учете ON физлица.id = информация_о_воинском_учете.id_физлица
    LEFT JOIN журнал_места_работы ON сотрудники.id = журнал_места_работы.id_сотрудника
    LEFT JOIN журнал_приказов ON журнал_места_работы.id_журнала_приказов = журнал_приказов.id
    LEFT JOIN условия_приема ON журнал_места_работы.id_условия = условия_приема.id
    LEFT JOIN структурные_подразделения ON журнал_места_работы.id_подразделения = структурные_подразделения.id
    LEFT JOIN должности ON журнал_места_работы.id_должности = должности.id
    WHERE сотрудники.id = employee_id AND журнал_места_работы.состояние = 'Работает';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION приказ_увольнение(employee_id INTEGER, с_даты DATE) RETURNS TABLE (
    фамилия VARCHAR(100),
    имя VARCHAR(100),
    отчество VARCHAR(100),
    дата_рождения DATE,
    снилс VARCHAR(11),
    дата_увольнения DATE,
    сведения_об_увольнении VARCHAR(100),
    должность_и_подразделение VARCHAR(200),
    причина_увольнения VARCHAR(100),
    наименование_документа VARCHAR(50),
    дата_документа DATE,
    приказ_о_приеме VARCHAR(50)
) AS $$
DECLARE
    должность VARCHAR;
    подразделение VARCHAR;
BEGIN
    SELECT должности.название AS должность, структурные_подразделения.название AS подразделение
    INTO должность, подразделение
    FROM физлица
    INNER JOIN приказы_приема ON приказы_приема.id_физлица = физлица.id
    INNER JOIN должности ON приказы_приема.id_должности = должности.id
    INNER JOIN структурные_подразделения ON приказы_приема.id_подразделения = структурные_подразделения.id
    INNER JOIN сотрудники ON сотрудники.id_физлица = физлица.id
    WHERE сотрудники.id = employee_id;


    RETURN QUERY
    SELECT
        физлица.фамилия,
        физлица.имя,
        физлица.отчество,
        физлица.дата_рождения,
        физлица.СНИЛС,
        приказы_увольнения.док_дата,
        приказы_увольнения.заявление_сотрудника,
        (должность || ', ' || подразделение)::VARCHAR,
        приказы_увольнения.основание,
        типы_приказов.название,
        журнал_приказов.дата,
        журнал_приказов.номер_дока
    FROM физлица
    INNER JOIN сотрудники ON физлица.id = сотрудники.id_физлица
    LEFT JOIN приказы_увольнения ON сотрудники.id = приказы_увольнения.id_сотрудника
    LEFT JOIN журнал_приказов ON приказы_увольнения.id_журнала_приказов = журнал_приказов.id
    LEFT JOIN типы_приказов ON журнал_приказов.id_типа = типы_приказов.id
    WHERE сотрудники.id = employee_id AND приказы_увольнения.дата_увольнения > с_даты;
END;
$$ LANGUAGE plpgsql;
