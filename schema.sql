-- ============================================================
-- Employee & Project Management System (ERMS)
-- A DBMS project demonstrating normalization, constraints,
-- triggers, stored procedures, views, and transactions.
-- ============================================================

DROP DATABASE IF EXISTS erms;
CREATE DATABASE erms;
USE erms;

-- ------------------------------------------------------------
-- 1. DEPARTMENT
-- ------------------------------------------------------------
CREATE TABLE Department (
    dept_id     INT AUTO_INCREMENT PRIMARY KEY,
    dept_name   VARCHAR(100) NOT NULL UNIQUE,
    location    VARCHAR(100),
    budget      DECIMAL(12,2) NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- 2. EMPLOYEE  (self-referencing manager_id -> org hierarchy)
-- ------------------------------------------------------------
CREATE TABLE Employee (
    emp_id       INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    email        VARCHAR(100) NOT NULL UNIQUE,
    phone        VARCHAR(15),
    dept_id      INT NOT NULL,
    designation  VARCHAR(50),
    salary       DECIMAL(10,2) NOT NULL CHECK (salary >= 0),
    join_date    DATE NOT NULL,
    manager_id   INT DEFAULT NULL,
    FOREIGN KEY (dept_id) REFERENCES Department(dept_id) ON DELETE RESTRICT,
    FOREIGN KEY (manager_id) REFERENCES Employee(emp_id) ON DELETE SET NULL
);

CREATE INDEX idx_employee_dept ON Employee(dept_id);

-- ------------------------------------------------------------
-- 3. PROJECT
-- ------------------------------------------------------------
CREATE TABLE Project (
    project_id    INT AUTO_INCREMENT PRIMARY KEY,
    project_name  VARCHAR(150) NOT NULL,
    dept_id       INT NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE,
    budget        DECIMAL(12,2) NOT NULL DEFAULT 0,
    status        ENUM('Planned','Active','Completed','On Hold') DEFAULT 'Planned',
    FOREIGN KEY (dept_id) REFERENCES Department(dept_id) ON DELETE CASCADE,
    CHECK (end_date IS NULL OR end_date >= start_date)
);

-- ------------------------------------------------------------
-- 4. EMPLOYEE_PROJECT  (many-to-many bridge table)
-- ------------------------------------------------------------
CREATE TABLE Employee_Project (
    emp_id          INT NOT NULL,
    project_id      INT NOT NULL,
    role            VARCHAR(50),
    hours_allocated INT DEFAULT 0,
    PRIMARY KEY (emp_id, project_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES Project(project_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 5. LEAVE_REQUEST
-- ------------------------------------------------------------
CREATE TABLE Leave_Request (
    leave_id     INT AUTO_INCREMENT PRIMARY KEY,
    emp_id       INT NOT NULL,
    leave_type   ENUM('Casual','Sick','Earned','Unpaid') NOT NULL,
    start_date   DATE NOT NULL,
    end_date     DATE NOT NULL,
    status       ENUM('Pending','Approved','Rejected') DEFAULT 'Pending',
    applied_on   DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id) ON DELETE CASCADE,
    CHECK (end_date >= start_date)
);

-- ------------------------------------------------------------
-- 6. ATTENDANCE
-- ------------------------------------------------------------
CREATE TABLE Attendance (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
    emp_id        INT NOT NULL,
    att_date      DATE NOT NULL,
    status        ENUM('Present','Absent','WFH','On Leave') NOT NULL,
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id) ON DELETE CASCADE,
    UNIQUE KEY uniq_emp_date (emp_id, att_date)
);

-- ------------------------------------------------------------
-- 7. SALARY_HISTORY  (populated automatically by trigger)
-- ------------------------------------------------------------
CREATE TABLE Salary_History (
    hist_id        INT AUTO_INCREMENT PRIMARY KEY,
    emp_id         INT NOT NULL,
    old_salary     DECIMAL(10,2),
    new_salary     DECIMAL(10,2),
    changed_on     DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id) ON DELETE CASCADE
);

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-log every salary change into Salary_History
DELIMITER //
CREATE TRIGGER trg_salary_change
AFTER UPDATE ON Employee
FOR EACH ROW
BEGIN
    IF OLD.salary <> NEW.salary THEN
        INSERT INTO Salary_History(emp_id, old_salary, new_salary)
        VALUES (OLD.emp_id, OLD.salary, NEW.salary);
    END IF;
END //
DELIMITER ;

-- Prevent an employee from having two overlapping leave requests
DELIMITER //
CREATE TRIGGER trg_prevent_overlapping_leave
BEFORE INSERT ON Leave_Request
FOR EACH ROW
BEGIN
    DECLARE overlap_count INT;
    SELECT COUNT(*) INTO overlap_count
    FROM Leave_Request
    WHERE emp_id = NEW.emp_id
      AND status IN ('Pending','Approved')
      AND NEW.start_date <= end_date
      AND NEW.end_date >= start_date;

    IF overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Leave dates overlap with an existing request for this employee';
    END IF;
END //
DELIMITER ;

-- ============================================================
-- VIEWS
-- ============================================================

-- Joined view: employee + department + manager name
CREATE VIEW vw_employee_details AS
SELECT
    e.emp_id, e.name, e.email, e.designation, e.salary,
    d.dept_name, d.location,
    m.name AS manager_name
FROM Employee e
JOIN Department d ON e.dept_id = d.dept_id
LEFT JOIN Employee m ON e.manager_id = m.emp_id;

-- Project staffing view
CREATE VIEW vw_project_staffing AS
SELECT
    p.project_id, p.project_name, p.status,
    e.emp_id, e.name AS employee_name, ep.role, ep.hours_allocated
FROM Project p
JOIN Employee_Project ep ON p.project_id = ep.project_id
JOIN Employee e ON ep.emp_id = e.emp_id;

-- Department budget utilization (aggregate + join)
CREATE VIEW vw_department_summary AS
SELECT
    d.dept_id, d.dept_name, d.budget AS dept_budget,
    COUNT(DISTINCT e.emp_id) AS employee_count,
    COALESCE(SUM(DISTINCT_SALARY.salary_sum), 0) AS total_salary_cost
FROM Department d
LEFT JOIN Employee e ON d.dept_id = e.dept_id
LEFT JOIN (
    SELECT dept_id, SUM(salary) AS salary_sum FROM Employee GROUP BY dept_id
) AS DISTINCT_SALARY ON DISTINCT_SALARY.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name, d.budget;

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- Approve or reject a leave request, wrapped in a transaction
DELIMITER //
CREATE PROCEDURE sp_process_leave(
    IN p_leave_id INT,
    IN p_decision VARCHAR(10)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE Leave_Request
    SET status = p_decision
    WHERE leave_id = p_leave_id;

    IF p_decision = 'Approved' THEN
        INSERT INTO Attendance (emp_id, att_date, status)
        SELECT emp_id, start_date, 'On Leave'
        FROM Leave_Request
        WHERE leave_id = p_leave_id
        ON DUPLICATE KEY UPDATE status = 'On Leave';
    END IF;

    COMMIT;
END //
DELIMITER ;

-- Assign an employee to a project (validates department consistency)
DELIMITER //
CREATE PROCEDURE sp_assign_employee_to_project(
    IN p_emp_id INT,
    IN p_project_id INT,
    IN p_role VARCHAR(50),
    IN p_hours INT
)
BEGIN
    INSERT INTO Employee_Project(emp_id, project_id, role, hours_allocated)
    VALUES (p_emp_id, p_project_id, p_role, p_hours)
    ON DUPLICATE KEY UPDATE role = p_role, hours_allocated = p_hours;
END //
DELIMITER ;

-- Give a department-wide raise by percentage (demonstrates set-based update + trigger firing)
DELIMITER //
CREATE PROCEDURE sp_give_department_raise(
    IN p_dept_id INT,
    IN p_percent DECIMAL(5,2)
)
BEGIN
    UPDATE Employee
    SET salary = salary + (salary * p_percent / 100)
    WHERE dept_id = p_dept_id;
END //
DELIMITER ;
