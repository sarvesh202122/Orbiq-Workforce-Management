USE erms;

INSERT INTO Department (dept_name, location, budget) VALUES
('Engineering', 'Bengaluru', 5000000),
('Human Resources', 'Mumbai', 1200000),
('Sales', 'Delhi', 2000000);

INSERT INTO Employee (name, email, phone, dept_id, designation, salary, join_date, manager_id) VALUES
('Anita Rao', 'anita.rao@erms.com', '9000000001', 1, 'Engineering Manager', 180000, '2019-01-10', NULL),
('Rahul Verma', 'rahul.verma@erms.com', '9000000002', 1, 'Software Engineer', 90000, '2021-03-15', 1),
('Sneha Iyer', 'sneha.iyer@erms.com', '9000000003', 1, 'Software Engineer', 92000, '2020-07-01', 1),
('Karthik Nair', 'karthik.nair@erms.com', '9000000004', 2, 'HR Manager', 140000, '2018-05-20', NULL),
('Divya Menon', 'divya.menon@erms.com', '9000000005', 2, 'HR Executive', 60000, '2022-01-11', 4),
('Arjun Das', 'arjun.das@erms.com', '9000000006', 3, 'Sales Manager', 150000, '2017-11-01', NULL);

INSERT INTO Project (project_name, dept_id, start_date, end_date, budget, status) VALUES
('Core Banking Migration', 1, '2025-01-01', '2025-12-31', 2500000, 'Active'),
('Employee Portal Revamp', 2, '2025-03-01', NULL, 800000, 'Active'),
('Q4 Sales Campaign', 3, '2025-10-01', '2025-12-31', 500000, 'Planned');

INSERT INTO Employee_Project (emp_id, project_id, role, hours_allocated) VALUES
(2, 1, 'Backend Developer', 120),
(3, 1, 'Database Engineer', 100),
(5, 2, 'Coordinator', 60),
(6, 3, 'Lead', 80);

INSERT INTO Leave_Request (emp_id, leave_type, start_date, end_date, status) VALUES
(2, 'Casual', '2026-09-20', '2026-09-21', 'Pending'),
(3, 'Sick', '2026-09-10', '2026-09-10', 'Approved');

INSERT INTO Attendance (emp_id, att_date, status) VALUES
(2, '2026-09-12', 'Present'),
(3, '2026-09-12', 'WFH'),
(6, '2026-09-12', 'Present');
