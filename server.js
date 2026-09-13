/**
 * Employee & Project Management System (ERMS)
 * Node.js + Express REST API backend over MySQL.
 *
 * Run:
 *   npm install
 *   npm start
 *
 * Set DB credentials via environment variables, or edit dbConfig below.
 */

const express = require("express");
const mysql = require("mysql2/promise");
const path = require("path");

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "static")));

const dbConfig = {
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "erms",
};

let pool;
async function getPool() {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
  }
  return pool;
}

// ---------------------------------------------------------------
// Static frontend
// ---------------------------------------------------------------
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "static", "index.html"));
});

// ---------------------------------------------------------------
// Departments
// ---------------------------------------------------------------
app.get("/api/departments", async (req, res) => {
  const db = await getPool();
  const [rows] = await db.query("SELECT * FROM vw_department_summary");
  res.json(rows);
});

app.post("/api/departments", async (req, res) => {
  const { dept_name, location, budget } = req.body;
  const db = await getPool();
  const [result] = await db.query(
    "INSERT INTO Department (dept_name, location, budget) VALUES (?, ?, ?)",
    [dept_name, location || null, budget || 0]
  );
  res.status(201).json({ affected_rows: result.affectedRows, last_id: result.insertId });
});

// ---------------------------------------------------------------
// Employees
// ---------------------------------------------------------------
app.get("/api/employees", async (req, res) => {
  const db = await getPool();
  const [rows] = await db.query("SELECT * FROM vw_employee_details");
  res.json(rows);
});

app.post("/api/employees", async (req, res) => {
  const { name, email, phone, dept_id, designation, salary, join_date, manager_id } = req.body;
  const db = await getPool();
  const [result] = await db.query(
    `INSERT INTO Employee (name, email, phone, dept_id, designation, salary, join_date, manager_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [name, email, phone || null, dept_id, designation || null, salary, join_date, manager_id || null]
  );
  res.status(201).json({ affected_rows: result.affectedRows, last_id: result.insertId });
});

app.put("/api/employees/:id", async (req, res) => {
  const { salary } = req.body;
  const db = await getPool();
  const [result] = await db.query(
    "UPDATE Employee SET salary = ? WHERE emp_id = ?",
    [salary, req.params.id]
  );
  res.json({ affected_rows: result.affectedRows });
});

app.get("/api/employees/:id/salary-history", async (req, res) => {
  const db = await getPool();
  const [rows] = await db.query(
    "SELECT * FROM Salary_History WHERE emp_id = ? ORDER BY changed_on DESC",
    [req.params.id]
  );
  res.json(rows);
});

// ---------------------------------------------------------------
// Projects
// ---------------------------------------------------------------
app.get("/api/projects", async (req, res) => {
  const db = await getPool();
  const [rows] = await db.query("SELECT * FROM Project");
  res.json(rows);
});

app.get("/api/projects/:id/staffing", async (req, res) => {
  const db = await getPool();
  const [rows] = await db.query(
    "SELECT * FROM vw_project_staffing WHERE project_id = ?",
    [req.params.id]
  );
  res.json(rows);
});

app.post("/api/projects/assign", async (req, res) => {
  const { emp_id, project_id, role, hours } = req.body;
  const db = await getPool();
  const conn = await db.getConnection();
  try {
    await conn.query("CALL sp_assign_employee_to_project(?, ?, ?, ?)", [
      emp_id,
      project_id,
      role || null,
      hours || 0,
    ]);
    res.status(201).json({ status: "assigned" });
  } finally {
    conn.release();
  }
});

// ---------------------------------------------------------------
// Leave requests
// ---------------------------------------------------------------
app.get("/api/leaves", async (req, res) => {
  const db = await getPool();
  const [rows] = await db.query(
    `SELECT l.*, e.name AS employee_name
     FROM Leave_Request l JOIN Employee e ON l.emp_id = e.emp_id
     ORDER BY l.applied_on DESC`
  );
  res.json(rows);
});

app.post("/api/leaves", async (req, res) => {
  const { emp_id, leave_type, start_date, end_date } = req.body;
  const db = await getPool();
  try {
    const [result] = await db.query(
      `INSERT INTO Leave_Request (emp_id, leave_type, start_date, end_date)
       VALUES (?, ?, ?, ?)`,
      [emp_id, leave_type, start_date, end_date]
    );
    res.status(201).json({ affected_rows: result.affectedRows, last_id: result.insertId });
  } catch (err) {
    // Catches the trg_prevent_overlapping_leave SIGNAL from MySQL
    res.status(400).json({ error: err.sqlMessage || err.message });
  }
});

app.post("/api/leaves/:id/decision", async (req, res) => {
  const { decision } = req.body; // 'Approved' or 'Rejected'
  const db = await getPool();
  const conn = await db.getConnection();
  try {
    await conn.query("CALL sp_process_leave(?, ?)", [req.params.id, decision]);
    res.json({ status: decision });
  } finally {
    conn.release();
  }
});

// ---------------------------------------------------------------
// Reports
// ---------------------------------------------------------------
app.get("/api/reports/department-summary", async (req, res) => {
  const db = await getPool();
  const [rows] = await db.query("SELECT * FROM vw_department_summary");
  res.json(rows);
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`ERMS server running on http://localhost:${PORT}`));
