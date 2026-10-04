-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 2: Computer Laboratory Reservations
-- Student Number: 202409694

DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;

-- 1. Create tables and add sessions

CREATE TABLE lab_sessions (
    session_id INT PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL
        CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT NOT NULL
        REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    number_of_workstations INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'RESERVED',
    reservation_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO lab_sessions
    (session_id, session_name, available_workstations)
VALUES
    (201, 'Database Practical', 20),
    (202, 'Networking Practical', 10),
    (203, 'Programming Practical', 5);

-- 2. IF ELSIF ELSE

DO $$
DECLARE
    v_available INT;
BEGIN
    SELECT available_workstations
    INTO v_available
    FROM lab_sessions
    WHERE session_id = 201;

    IF v_available = 0 THEN
        RAISE NOTICE 'Session is full.';
    ELSIF v_available <= 5 THEN
        RAISE NOTICE
            'Session is nearly full: % workstations available.',
            v_available;
    ELSE
        RAISE NOTICE
            'Session has enough workstations: % available.',
            v_available;
    END IF;
END $$;

-- 3. WHILE and numeric FOR

DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE
            'Session preparation reminder %',
            i;

        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE
            'Workstation check %',
            i;
    END LOOP;
END $$;

-- 4. reserve_workstations procedure

CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer VARCHAR,
    p_workstations INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION
            'Invalid number of workstations: must be greater than zero.';
    END IF;

    SELECT available_workstations
    INTO v_available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Lab session % does not exist.',
            p_session_id;
    END IF;

    IF v_available < p_workstations THEN
        RAISE EXCEPTION
            'Insufficient workstations. Requested %, available %.',
            p_workstations, v_available;
    END IF;

    UPDATE lab_sessions
    SET available_workstations =
        available_workstations - p_workstations
    WHERE session_id = p_session_id;

    INSERT INTO reservations
        (session_id, lecturer, number_of_workstations, status)
    VALUES
        (p_session_id, p_lecturer, p_workstations, 'RESERVED');

    RAISE NOTICE
        'Reservation recorded successfully.';
END $$;

-- 5. Two valid reservations and one exceeding capacity

CALL reserve_workstations(
    201,
    'Mr Nyirenda',
    8
);

CALL reserve_workstations(
    202,
    'Mrs Bwalya',
    4
);

DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(
            203,
            'Mr Banda',
            8
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE
            'Expected failed reservation: %',
            SQLERRM;
    END;
END $$;

SELECT * FROM lab_sessions
ORDER BY session_id;

SELECT * FROM reservations
ORDER BY reservation_id;

-- 6. cancel_reservation procedure

CREATE OR REPLACE PROCEDURE cancel_reservation(
    p_reservation_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INT;
    v_workstations INT;
    v_status VARCHAR(20);
BEGIN
    SELECT session_id,
           number_of_workstations,
           status
    INTO v_session_id,
         v_workstations,
         v_status
    FROM reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Reservation % does not exist.',
            p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE
            'Reservation % is already cancelled. No workstations released.',
            p_reservation_id;
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations =
        available_workstations + v_workstations
    WHERE session_id = v_session_id;

    UPDATE reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;

    RAISE NOTICE
        'Reservation % cancelled.',
        p_reservation_id;
END $$;

CALL cancel_reservation(1);

CALL cancel_reservation(1);

-- 7. Explicit cursor

DO $$
DECLARE
    session_cursor CURSOR FOR
        SELECT session_id,
               session_name,
               available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 5
        ORDER BY session_id;

    v_id INT;
    v_name VARCHAR(100);
    v_available INT;
BEGIN
    OPEN session_cursor;

    LOOP
        FETCH session_cursor
        INTO v_id, v_name, v_available;

        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Few workstations - ID: %, Session: %, Available: %',
            v_id, v_name, v_available;
    END LOOP;

    CLOSE session_cursor;
END $$;

-- 8. Zero workstations and exception handling

DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(
            201,
            'Invalid Lecturer',
            0
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE
            'Invalid quantity handled: %',
            SQLERRM;
    END;
END $$;

-- 9. Final queries

SELECT * FROM lab_sessions
ORDER BY session_id;

SELECT * FROM reservations
ORDER BY reservation_id;