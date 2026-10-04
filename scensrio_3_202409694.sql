-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 3: Student Hostel Room Allocation
-- Student Number: 202409694

DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

-- 1. Create tables and add rooms

CREATE TABLE hostel_rooms (
    room_id INT PRIMARY KEY,
    room_name VARCHAR(50) NOT NULL,
    available_bed_spaces INT NOT NULL
        CHECK (available_bed_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(30) NOT NULL,
    room_id INT NOT NULL
        REFERENCES hostel_rooms(room_id),
    status VARCHAR(20) NOT NULL DEFAULT 'ALLOCATED',
    allocation_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO hostel_rooms
    (room_id, room_name, available_bed_spaces)
VALUES
    (301, 'Room A', 2),
    (302, 'Room B', 1),
    (303, 'Room C', 0);

-- 2. IF ELSIF ELSE

DO $$
DECLARE
    v_spaces INT;
BEGIN
    SELECT available_bed_spaces
    INTO v_spaces
    FROM hostel_rooms
    WHERE room_id = 301;

    IF v_spaces = 0 THEN
        RAISE NOTICE 'Room is full.';
    ELSIF v_spaces = 1 THEN
        RAISE NOTICE 'Room has one space left.';
    ELSE
        RAISE NOTICE
            'Room has several spaces: % available.',
            v_spaces;
    END IF;
END $$;

-- 3. WHILE and numeric FOR

DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE
            'Hostel inspection day %',
            i;

        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE
            'Room check %',
            i;
    END LOOP;
END $$;

-- 4. allocate_room procedure

CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number VARCHAR,
    p_room_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student_number IS NULL
       OR TRIM(p_student_number) = '' THEN

        RAISE EXCEPTION
            'Student number cannot be blank.';
    END IF;

    SELECT available_bed_spaces
    INTO v_spaces
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Room % does not exist.',
            p_room_id;
    END IF;

    IF v_spaces <= 0 THEN
        RAISE EXCEPTION
            'Room % is full.',
            p_room_id;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces =
        available_bed_spaces - 1
    WHERE room_id = p_room_id;

    INSERT INTO allocations
        (student_number, room_id, status)
    VALUES
        (p_student_number, p_room_id, 'ALLOCATED');

    RAISE NOTICE
        'Student % allocated to room %.',
        p_student_number,
        p_room_id;
END $$;

-- 5. Two valid allocations and one full-room allocation

CALL allocate_room(
    '202409694',
    301
);

CALL allocate_room(
    '202409695',
    302
);

DO $$
BEGIN
    BEGIN
        CALL allocate_room(
            '202409696',
            303
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE
            'Expected failed allocation: %',
            SQLERRM;
    END;
END $$;

SELECT * FROM hostel_rooms
ORDER BY room_id;

SELECT * FROM allocations
ORDER BY allocation_id;

-- 6. check_out procedure

CREATE OR REPLACE PROCEDURE check_out(
    p_allocation_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INT;
    v_status VARCHAR(20);
BEGIN
    SELECT room_id,
           status
    INTO v_room_id,
         v_status
    FROM allocations
    WHERE allocation_id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Allocation % does not exist.',
            p_allocation_id;
    END IF;

    IF v_status = 'COMPLETED' THEN
        RAISE NOTICE
            'Allocation % is already completed. No bed space released.',
            p_allocation_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces =
        available_bed_spaces + 1
    WHERE room_id = v_room_id;

    UPDATE allocations
    SET status = 'COMPLETED'
    WHERE allocation_id = p_allocation_id;

    RAISE NOTICE
        'Allocation % checked out.',
        p_allocation_id;
END $$;

CALL check_out(1);

CALL check_out(1);

-- 7. Explicit cursor

DO $$
DECLARE
    room_cursor CURSOR FOR
        SELECT room_id,
               room_name,
               available_bed_spaces
        FROM hostel_rooms
        WHERE available_bed_spaces <= 1
        ORDER BY room_id;

    v_id INT;
    v_name VARCHAR(50);
    v_spaces INT;
BEGIN
    OPEN room_cursor;

    LOOP
        FETCH room_cursor
        INTO v_id, v_name, v_spaces;

        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Full/nearly full room - ID: %, Room: %, Spaces: %',
            v_id, v_name, v_spaces;
    END LOOP;

    CLOSE room_cursor;
END $$;

-- 8. Blank student number and exception handling

DO $$
BEGIN
    BEGIN
        CALL allocate_room(
            '',
            301
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE
            'Invalid student number handled: %',
            SQLERRM;
    END;
END $$;

-- 9. Final queries

SELECT * FROM hostel_rooms
ORDER BY room_id;

SELECT * FROM allocations
ORDER BY allocation_id;