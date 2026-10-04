-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing
-- Student Number: 202409694

DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;

-- 1. Create tables and add medicines

CREATE TABLE medicines (
    medicine_id INT PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL
        CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    dispensing_id SERIAL PRIMARY KEY,
    medicine_id INT NOT NULL
        REFERENCES medicines(medicine_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED',
    dispensing_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO medicines
    (medicine_id, medicine_name, stock_quantity)
VALUES
    (401, 'Paracetamol', 20),
    (402, 'Amoxicillin', 8),
    (403, 'Vitamin C', 0);

-- 2. IF ELSIF ELSE

DO $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock_quantity
    INTO v_stock
    FROM medicines
    WHERE medicine_id = 401;

    IF v_stock = 0 THEN
        RAISE NOTICE
            'Medicine is out of stock.';
    ELSIF v_stock <= 5 THEN
        RAISE NOTICE
            'Medicine is low on stock: % remaining.',
            v_stock;
    ELSE
        RAISE NOTICE
            'Medicine is sufficiently stocked: % remaining.',
            v_stock;
    END IF;
END $$;

-- 3. WHILE and numeric FOR

DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE
            'Stock review day %',
            i;

        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE
            'Shelf inspection %',
            i;
    END LOOP;
END $$;

-- 4. dispense_medicine procedure

CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION
            'Invalid dispensing quantity: must be greater than zero.';
    END IF;

    SELECT stock_quantity
    INTO v_stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Medicine % does not exist.',
            p_medicine_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION
            'Insufficient stock. Requested %, available %.',
            p_quantity,
            v_stock;
    END IF;

    UPDATE medicines
    SET stock_quantity =
        stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records
        (medicine_id, student_number, quantity, status)
    VALUES
        (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

    RAISE NOTICE
        'Medicine dispensed successfully to student %.',
        p_student_number;
END $$;

-- 5. Two valid quantities and one exceeding stock

CALL dispense_medicine(
    401,
    '202409694',
    4
);

CALL dispense_medicine(
    402,
    '202409695',
    3
);

DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(
            402,
            '202409696',
            10
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE
            'Expected failed dispensing: %',
            SQLERRM;
    END;
END $$;

SELECT * FROM medicines
ORDER BY medicine_id;

SELECT * FROM dispensing_records
ORDER BY dispensing_id;

-- 6. reverse_dispensing procedure

CREATE OR REPLACE PROCEDURE reverse_dispensing(
    p_dispensing_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INT;
    v_quantity INT;
    v_status VARCHAR(20);
BEGIN
    SELECT medicine_id,
           quantity,
           status
    INTO v_medicine_id,
         v_quantity,
         v_status
    FROM dispensing_records
    WHERE dispensing_id = p_dispensing_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Dispensing record % does not exist.',
            p_dispensing_id;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE
            'Record % is already reversed. No stock restored.',
            p_dispensing_id;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity =
        stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;

    UPDATE dispensing_records
    SET status = 'REVERSED'
    WHERE dispensing_id = p_dispensing_id;

    RAISE NOTICE
        'Dispensing record % reversed and stock restored.',
        p_dispensing_id;
END $$;

CALL reverse_dispensing(1);

CALL reverse_dispensing(1);

-- 7. Explicit cursor

DO $$
DECLARE
    medicine_cursor CURSOR FOR
        SELECT medicine_id,
               medicine_name,
               stock_quantity
        FROM medicines
        WHERE stock_quantity < 5
        ORDER BY medicine_id;

    v_id INT;
    v_name VARCHAR(100);
    v_stock INT;
BEGIN
    OPEN medicine_cursor;

    LOOP
        FETCH medicine_cursor
        INTO v_id, v_name, v_stock;

        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Low stock - ID: %, Medicine: %, Stock: %',
            v_id, v_name, v_stock;
    END LOOP;

    CLOSE medicine_cursor;
END $$;

-- 8. Negative quantity and exception handling

DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(
            401,
            '202409697',
            -2
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE
            'Invalid negative quantity handled: %',
            SQLERRM;
    END;
END $$;

-- 9. Final queries

SELECT * FROM medicines
ORDER BY medicine_id;

SELECT * FROM dispensing_records
ORDER BY dispensing_id;