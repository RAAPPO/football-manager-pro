
# 🏆 FootyPro
### Enterprise Football Management System

A professional-grade, full-stack administrative platform for football league operations.  
Built as a **DBMS Mini-Project** to demonstrate advanced database orchestration, complex SQL querying, and secure role-based access control.

![TypeScript](https://img.shields.io/badge/TypeScript-97%25-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![React](https://img.shields.io/badge/React_19-Frontend-61DAFB?style=for-the-badge&logo=react&logoColor=black)
![Node.js](https://img.shields.io/badge/Node.js-Backend-339933?style=for-the-badge&logo=node.js&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL_8.0-Database-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?style=for-the-badge&logo=docker&logoColor=white)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Database Design](#-database-design--dbms-concepts)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [API Reference](#-api-reference)
- [Role-Based Access Control](#-role-based-access-control-rbac)
- [DBMS Checklist](#-dbms-submission-checklist)

---

## 🌐 Overview

**FootyPro** is a containerized, multi-tier web application that provides a complete administrative interface for managing football league data. The system handles clubs, players, match schedules, stadium information, and player contracts — all secured behind a role-based login system.

The entire stack runs inside Docker containers, making it fully **platform-independent** across Fedora, Windows, and macOS.

---

## 🏗 Architecture

The system follows a modern **N-Tier Architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT BROWSER                          │
│           React 19 + Vite + Tailwind CSS v4                 │
│              http://localhost:5173                           │
└──────────────────────────┬──────────────────────────────────┘
                           │ Axios HTTP (REST)
┌──────────────────────────▼──────────────────────────────────┐
│                  BACKEND API LAYER                           │
│           Node.js + Express + TypeScript                     │
│              http://localhost:5000/api                       │
└──────────────────────────┬──────────────────────────────────┘
                           │ mysql2 Connection Pool
┌──────────────────────────▼──────────────────────────────────┐
│                   DATABASE LAYER                             │
│        MySQL 8.0 — Tables, Views, Triggers, Cursors         │
│              Internal Docker network: port 3306             │
└─────────────────────────────────────────────────────────────┘
```

All three layers are orchestrated by a single `docker-compose.yml`, linked via an internal Docker network. The frontend never directly touches the database.

---

## 🛠 Tech Stack

| Layer      | Technology                                                  |
|------------|-------------------------------------------------------------|
| Frontend   | React 19, Vite, Tailwind CSS v4, React Router v6, Axios, Lucide React |
| Backend    | Node.js, Express, TypeScript                                |
| Database   | MySQL 8.0                                                   |
| DevOps     | Docker, Docker Compose                                      |

---

## 📊 Database Design & DBMS Concepts

This project implements all mandatory DBMS concepts as per university guidelines.

### Schema — 8 Tables (`database/01_schema.sql`)

| Table          | Description                                                        |
|----------------|--------------------------------------------------------------------|
| `users`        | Stores admin and manager accounts with roles (`Admin` / `User`)   |
| `club`         | Football clubs — name, founded year, trophy count, owner, email   |
| `stadium`      | Stadium details — name, capacity, city                            |
| `player`       | Player details — name, DOB, position, address, club FK            |
| `player_phone` | Normalized multi-value phone numbers (1NF compliance)             |
| `contract`     | Player-to-club salary contracts with start/end dates              |
| `matches`      | Match records with home/away club FKs and stadium FK              |
| `player_log`   | Audit log table — auto-populated by the `AFTER DELETE` trigger    |

### Views (`database/02_views.sql`)

**`player_roster_view`** — Complex read-only view used by the Players page:
```sql
CREATE VIEW player_roster_view AS
SELECT 
    p.player_id,
    CONCAT(p.f_name, ' ', p.l_name) AS full_name,
    FLOOR(DATEDIFF(CURRENT_DATE, p.dob) / 365.25) AS age_calculated,
    UPPER(c.club_name) AS club_name,
    p.position
FROM player p
LEFT JOIN club c ON p.club_id = c.club_id;
```
- Uses `DATEDIFF` to calculate player age dynamically — no stored age column needed.
- Uses `CONCAT` for professional name formatting.
- Uses `UPPER` to normalise club name display.

**`player_contact_view`** — Updatable view for player contact details (no joins or aggregates).

### Triggers (`database/03_routines.sql`)

**Trigger 1: `before_player_insert`** — Age validation gate:
- Fires **BEFORE INSERT** on the `player` table.
- Raises `SQLSTATE '45000'` if the player's DOB makes them younger than 15 years old.
- The Express error handler catches this and returns a user-friendly `400` response.

**Trigger 2: `after_player_delete`** — Audit trail:
- Fires **AFTER DELETE** on the `player` table.
- Automatically inserts a record into `player_log` with the deleted `player_id` and a `CURRENT_TIMESTAMP`.

### Cursor / Stored Procedure (`database/03_routines.sql`)

**Procedure: `apply_loyalty_bonus()`**:
- Uses a **CURSOR** to iterate row-by-row over every contract.
- If a contract's `start_date` is more than **730 days (2 years)** old, the salary is increased by **10%**.
- Demonstrates row-level processing that cannot be done with a simple `UPDATE ... WHERE`.

### Aggregate Analytics (`backend/src/controllers/dashboardController.ts`)

The Dashboard uses **subquery aggregate functions** in a single query:
```sql
SELECT 
    (SELECT COUNT(*) FROM player)        AS total_players,
    (SELECT COUNT(*) FROM club)          AS total_clubs,
    (SELECT SUM(total_trophies) FROM club) AS total_trophies,
    (SELECT COUNT(*) FROM matches)       AS total_matches
```

### Complex Multi-Table Joins

The Match Schedule and Dashboard use **triple `INNER JOIN`** operations to resolve human-readable names from three separate tables in a single query:
```sql
SELECT m.match_id, h.club_name AS home_team, a.club_name AS away_team, s.stadium_name
FROM matches m
JOIN club h ON m.home_club_id = h.club_id
JOIN club a ON m.away_club_id = a.club_id
JOIN stadium s ON m.stadium_id = s.stadium_id;
```

---

## 📁 Project Structure

```
football-manager-pro/
│
├── docker-compose.yml              # Orchestrates all 3 containers
│
├── backend/                        # RESTful API — Express + TypeScript
│   ├── src/
│   │   ├── server.ts               # Entry point, route mounting, health check
│   │   ├── config/
│   │   │   └── db.ts               # MySQL2 connection pool (env-driven)
│   │   ├── controllers/
│   │   │   ├── authController.ts   # Login — username/password lookup
│   │   │   ├── clubController.ts   # CRUD for clubs
│   │   │   ├── playerController.ts # CRUD for players (uses view + trigger)
│   │   │   ├── matchController.ts  # CRUD for matches (triple joins)
│   │   │   ├── contractController.ts # CRUD for contracts
│   │   │   └── dashboardController.ts # Aggregate stats + match feeds
│   │   └── routes/
│   │       ├── authRoutes.ts
│   │       ├── clubRoutes.ts
│   │       ├── playerRoutes.ts
│   │       ├── matchRoutes.ts
│   │       ├── contractRoutes.ts
│   │       └── dashboardRoutes.ts
│   └── Dockerfile
│
├── database/                       # Pure SQL data layer
│   ├── 01_schema.sql               # DDL: All 8 tables with PK/FK constraints
│   ├── 02_views.sql                # player_roster_view + player_contact_view
│   ├── 03_routines.sql             # 2 Triggers + apply_loyalty_bonus Cursor
│   ├── 04_seed_data.sql            # DML: Sample clubs, players, matches, contracts
│   └── Dockerfile                  # Extends mysql:8.0, auto-runs all SQL scripts
│
└── frontend/                       # UI Layer — React 19 + Vite
    └── src/
        ├── App.tsx                 # BrowserRouter, auth state, protected routes
        ├── components/
        │   └── Layout.tsx          # Sidebar, nav, user badge, logout button
        ├── pages/
        │   ├── Login.tsx           # Auth form with test account hints
        │   ├── Dashboard.tsx       # Aggregate stat cards + match feed panels
        │   ├── Clubs.tsx           # Full CRUD table with modal form (Admin only)
        │   ├── Players.tsx         # Full CRUD using player_roster_view (Admin only)
        │   ├── Matches.tsx         # Full CRUD with multi-dropdown form (Admin only)
        │   └── Contracts.tsx       # Create & terminate contracts (Admin only)
        └── services/
            └── api.ts              # Axios instance pre-configured to backend URL
```

---

## 🚀 Getting Started

### Prerequisites

- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** (Windows / macOS)
- **Docker Engine + Docker Compose** (Linux / Fedora)
- **Git**

### Installation & Launch

**1. Clone the repository:**
```bash
git clone https://github.com/raappo/football-manager-pro.git
cd football-manager-pro
```

**2. Launch the full stack with commands in order:**
```bash
docker-compose up -d --build
docker-compose up
```

This command will:
- Build the MySQL 8.0 image and auto-execute all 4 SQL scripts in order.
- Build the Node.js/Express backend.
- Build the React/Vite frontend.
- Start all three containers in the background.

**3. Access the application:**

| Service         | URL                              |
|-----------------|----------------------------------|
| 🌐 Web Dashboard | http://localhost:5173            |
| ⚙️ API Health Check | http://localhost:5000/api/health |
| 🗄️ MySQL Database | `localhost:3306` (internal)      |

**4. To stop the application:**
```bash
docker-compose down
```

> **Note:** The first `docker-compose up --build` may take a couple of minutes as Docker pulls the base images and installs all npm dependencies. Subsequent starts will be much faster.

---

## 📡 API Reference

All endpoints are prefixed with `/api`.

| Method | Endpoint               | Description                              |
|--------|------------------------|------------------------------------------|
| `POST` | `/auth/login`          | Authenticate a user, returns role        |
| `GET`  | `/dashboard`           | Aggregate stats, upcoming & recent matches |
| `GET`  | `/clubs`               | List all clubs                           |
| `POST` | `/clubs`               | Create a new club                        |
| `PUT`  | `/clubs/:id`           | Update an existing club                  |
| `DELETE`| `/clubs/:id`          | Delete a club                            |
| `GET`  | `/players`             | List all players via `player_roster_view`|
| `GET`  | `/players/:id`         | Get raw player data for edit form        |
| `POST` | `/players`             | Create player (fires BEFORE INSERT trigger) |
| `PUT`  | `/players/:id`         | Update player details                    |
| `DELETE`| `/players/:id`        | Delete player (fires AFTER DELETE trigger) |
| `GET`  | `/matches`             | List all matches (triple join)           |
| `GET`  | `/matches/stadiums`    | List all stadiums for dropdowns          |
| `GET`  | `/matches/:id`         | Get single match for edit form           |
| `POST` | `/matches`             | Schedule a new match                     |
| `PUT`  | `/matches/:id`         | Update a match                           |
| `DELETE`| `/matches/:id`        | Delete a match                           |
| `GET`  | `/contracts`           | List all contracts                       |
| `POST` | `/contracts`           | Create a new contract                    |
| `DELETE`| `/contracts/:id`      | Terminate a contract                     |
| `GET`  | `/health`              | Backend & DB connectivity check          |

---

## 🔐 Role-Based Access Control (RBAC)

The application features a secure **Admin vs. Manager** login system. Authentication state is persisted in `localStorage` and passed through React Router's `Outlet` context. The UI dynamically hides all mutation controls based on the logged-in user's role.

| Account | Username  | Password   | Capability                                         |
|---------|-----------|------------|----------------------------------------------------|
| Admin   | `admin`   | `admin123` | **Full Access** — Can Add, Edit, and Delete all data |
| Manager | `manager` | `user123`  | **Read-Only** — All modification buttons are hidden; view-only access |

**How it works in the code:**
- The `Layout` component passes the `user` object via `<Outlet context={{ user }} />`.
- Every page reads the role with `const { user } = useOutletContext<any>()`.
- Action buttons are conditionally rendered: `{user?.role === 'Admin' && <button>...</button>}`.

---

## ✅ DBMS Submission Checklist

| Requirement                              | Status | Implementation Detail |
|------------------------------------------|--------|-----------------------|
| Platform Independent                     | ✅     | Fully Dockerized — works on Fedora, Windows, macOS |
| 5+ Tables                                | ✅     | 8 tables: `users`, `club`, `stadium`, `player`, `player_phone`, `contract`, `matches`, `player_log` |
| 5+ UI Pages                              | ✅     | Login, Dashboard, Clubs, Players, Matches, Contracts |
| Trigger — BEFORE INSERT                  | ✅     | `before_player_insert` — blocks players under 15 years old |
| Trigger — AFTER DELETE                   | ✅     | `after_player_delete` — auto-logs deleted players to `player_log` |
| Cursor (Stored Procedure)                | ✅     | `apply_loyalty_bonus()` — row-by-row contract salary processing |
| SQL Views                                | ✅     | `player_roster_view` (complex, read-only), `player_contact_view` (updatable) |
| Aggregate Functions                      | ✅     | `COUNT()`, `SUM()` on Dashboard; `AVG()` available via contract data |
| Complex Joins (3+ tables)                | ✅     | Match Schedule and Dashboard use triple JOINs across `matches`, `club`, `stadium` |
| Date Functions                           | ✅     | `DATEDIFF()`, `FLOOR()`, `DATE_FORMAT()`, `CURRENT_DATE` used across views and controllers |
| Front-to-Back Connectivity               | ✅     | Fully operational via Axios (frontend) → Express (backend) → MySQL (database) |
| Normalization (1NF)                      | ✅     | `player_phone` table handles multi-valued phone numbers |
| Referential Integrity (FK + CASCADE)     | ✅     | All FKs defined with `ON DELETE CASCADE` or `ON DELETE SET NULL` |

---

<div align="center">
  <sub>Built with ❤️ as a DBMS Mini-Project</sub>
</div>
