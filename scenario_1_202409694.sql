-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 1: University Library Book Loans
-- Student Number: 202409694

DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

-- 1. Create tables and add books

CREATE TABLE books (
    book_id INT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT NOT NULL REFERENCES books(book_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INT NOT NULL,
    loan_status VARCHAR(20) NOT NULL DEFAULT 'BORROWED',
    loan_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO books (book_id, title, available_copies)
VALUES
(101, 'Database Systems', 5),
(102, 'Computer Networks', 2),
(103, 'Algorithms and Data Structures', 0);

-- 2. IF ELSIF ELSE

DO $$
DECLARE
    v_copies INT;
BEGIN
    SELECT available_copies
    INTO v_copies
    FROM books
    WHERE book_id = 101;

    IF v_copies = 0 THEN
        RAISE NOTICE 'Database Systems is unavailable.';
    ELSIF v_copies <= 2 THEN
        RAISE NOTICE 'Database Systems is low on copies: % remaining.', v_copies;
    ELSE
        RAISE NOTICE 'Database Systems is sufficiently stocked: % copies remaining.', v_copies;
    END IF;
END $$;

-- 3. WHILE and numeric FOR

DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number %', i;
    END LOOP;
END $$;

-- 4. borrow_book procedure

CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION
            'Invalid quantity: quantity must be greater than zero.';
    END IF;

    SELECT available_copies
    INTO v_available
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book % does not exist.', p_book_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE EXCEPTION
            'Insufficient copies. Requested %, available %.',
            p_quantity, v_available;
    END IF;

    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;

    INSERT INTO book_loans
        (book_id, student_number, quantity, loan_status)
    VALUES
        (p_book_id, p_student_number, p_quantity, 'BORROWED');

    RAISE NOTICE
        'Loan recorded successfully for student %.',
        p_student_number;
END $$;

-- 5. Two valid loans and one exceeding available copies

CALL borrow_book(101, '202409694', 2);

CALL borrow_book(102, '202409695', 1);

DO $$
BEGIN
    BEGIN
        CALL borrow_book(102, '202409696', 5);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed loan: %', SQLERRM;
    END;
END $$;

SELECT * FROM books
ORDER BY book_id;

SELECT * FROM book_loans
ORDER BY loan_id;

-- 6. return_book procedure

CREATE OR REPLACE PROCEDURE return_book(
    p_loan_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INT;
    v_quantity INT;
    v_status VARCHAR(20);
BEGIN
    SELECT book_id, quantity, loan_status
    INTO v_book_id, v_quantity, v_status
    FROM book_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Loan % does not exist.',
            p_loan_id;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE
            'Loan % is already returned. No stock restored.',
            p_loan_id;
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies + v_quantity
    WHERE book_id = v_book_id;

    UPDATE book_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;

    RAISE NOTICE
        'Loan % returned and copies restored.',
        p_loan_id;
END $$;

CALL return_book(1);

CALL return_book(1);

-- 7. Explicit cursor

DO $$
DECLARE
    book_cursor CURSOR FOR
        SELECT book_id, title, available_copies
        FROM books
        WHERE available_copies <= 2
        ORDER BY book_id;

    v_id INT;
    v_title VARCHAR(100);
    v_copies INT;
BEGIN
    OPEN book_cursor;

    LOOP
        FETCH book_cursor
        INTO v_id, v_title, v_copies;

        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Few copies - ID: %, Title: %, Copies: %',
            v_id, v_title, v_copies;
    END LOOP;

    CLOSE book_cursor;
END $$;

-- 8. Invalid zero quantity and exception handling

DO $$
BEGIN
    BEGIN
        CALL borrow_book(101, '202409697', 0);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE
            'Invalid quantity handled: %',
            SQLERRM;
    END;
END $$;

-- 9. Final queries

SELECT * FROM books
ORDER BY book_id;

SELECT * FROM book_loans
ORDER BY loan_id;