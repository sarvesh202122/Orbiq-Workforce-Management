# ERMS — Employee & Project Management System

A full-stack DBMS project: normalized MySQL schema + Flask REST API + a live dashboard.
Domain (HR/Project tracking) mirrors SAP's own ERP modules, so it's an easy story to tell in interviews.

## Tech Stack
- **Database:** MySQL 8
- **Backend:** Node.js + Express + `mysql2`
- **Frontend:** Plain HTML/CSS/JS dashboard (no framework needed, keeps setup simple)

## Entity Relationships
- `Department (1) —— (N) Employee`
- `Employee (1) —— (N) Employee` (self-referencing `manager_id`, models org hierarchy)
- `Department (1) —— (N) Project`
- `Employee (M) —— (N) Project` via bridge table `Employee_Project`
- `Employee (1) —— (N) Leave_Request`, `Attendance`, `Salary_History`

Schema is in **3rd Normal Form** — no repeating groups, every non-key attribute depends only on the primary key.

## DBMS Concepts Demonstrated
| Concept | Where |
|---|---|
| Constraints (PK, FK, CHECK, UNIQUE) | `schema.sql` — e.g. salary ≥ 0, end_date ≥ start_date |
| Triggers | `trg_salary_change` (audit log), `trg_prevent_overlapping_leave` (business rule enforcement) |
| Stored Procedures | `sp_process_leave` (transactional), `sp_assign_employee_to_project`, `sp_give_department_raise` |
| Views | `vw_employee_details`, `vw_project_staffing`, `vw_department_summary` (multi-table joins + aggregation) |
| Transactions | `sp_process_leave` uses `START TRANSACTION` / `COMMIT` / `ROLLBACK` with an exit handler |
| Indexing | `idx_employee_dept`, unique composite key on `Attendance` |

## Setup
```bash
# 1. Create the database and objects
mysql -u root -p < schema.sql
mysql -u root -p < seed_data.sql

# 2. Install backend deps
npm install

# 3. Set DB credentials (or edit dbConfig in server.js)
export DB_USER=root
export DB_PASSWORD=yourpassword

# 4. Run
npm start
# Visit http://localhost:5000
```

## API Endpoints
| Method | Route | Purpose |
|---|---|---|
| GET | `/api/employees` | List employees with dept + manager (joined view) |
| POST | `/api/employees` | Add employee |
| PUT | `/api/employees/<id>` | Update salary (fires audit trigger) |
| GET | `/api/employees/<id>/salary-history` | Salary change log |
| GET | `/api/departments` | Department budget/headcount summary |
| GET | `/api/projects` | List projects |
| GET | `/api/projects/<id>/staffing` | Who's on a project |
| POST | `/api/projects/assign` | Assign employee to project (stored proc) |
| GET | `/api/leaves` | All leave requests |
| POST | `/api/leaves` | Apply for leave (blocked if overlapping) |
| POST | `/api/leaves/<id>/decision` | Approve/reject (transactional stored proc) |

ia `mysql2` — already used throughout `server.js`)
